"""Run with python3 -m unittest discover -s tests -v. No live root writes.

Root integration tests require bubblewrap user namespaces. NeoMutt tests use
NEOMUTT_TEST_BINARY when set, otherwise the installed neomutt executable.
"""
import fcntl
import hashlib
import importlib.util
import io
import os
import pty
import select
import signal
import struct
import termios
import time
from pathlib import Path
import shutil
import subprocess
import tarfile
import tempfile
import unittest

REPO = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('root_shell', REPO / 'tools/root-shell.py')
root_shell = importlib.util.module_from_spec(spec)
spec.loader.exec_module(root_shell)


@unittest.skipUnless(shutil.which('bwrap'), 'bubblewrap required; never substitute live root')
class RootTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.work = Path(self.temp.name)
        self.home = self.work / 'root'
        self.home.mkdir(mode=0o700)
        (self.home / '.zshrc').write_text('# original root config\n')
        (self.home / '.alias.local').write_text('alias root_local_test=true\n')
        for relative in ('', '/custom/plugins/zsh-autosuggestions', '/custom/plugins/zsh-syntax-highlighting', '/custom/themes/powerlevel10k'):
            (self.home / ('.oh-my-zsh' + relative) / '.git').mkdir(parents=True)
        self.git = self.work / 'git'
        self.git.write_text('''#!/bin/sh
case "$*" in
  *"diff --name-only") exit 0;;
  *"symbolic-ref --short HEAD") echo master;;
  *"ls-remote origin refs/heads/master") printf '123456\\trefs/heads/master\\n';;
  *"rev-parse HEAD") echo 123456;;
  *) echo "Unexpected git operation: $*" >&2; exit 98;;
esac
''')
        self.git.chmod(0o755)
        self.getent = self.work / 'getent'
        self.getent.write_text('#!/bin/sh\necho "root:x:0:0:root:/root:/usr/bin/zsh"\n')
        self.getent.chmod(0o755)

    def payload(self, unsafe=False):
        buffer = io.BytesIO()
        with tarfile.open(fileobj=buffer, mode='w') as archive:
            for name in root_shell.FILES:
                info = tarfile.TarInfo(name)
                data = (REPO / name).read_bytes()
                if unsafe and name == 'linux/.alias':
                    info.type = tarfile.SYMTYPE
                    info.linkname = '/home/user/.alias'
                else:
                    info.size = len(data)
                archive.addfile(info, io.BytesIO(data))
        return buffer.getvalue()

    def run_root(self, unsafe=False):
        payload = self.payload(unsafe)
        revision = hashlib.sha256(payload).hexdigest()
        command = ['bwrap', '--unshare-user', '--uid', '0', '--gid', '0', '--unshare-pid',
                   '--unshare-net', '--die-with-parent', '--ro-bind', '/', '/',
                   '--bind', str(self.home), '/root', '--tmpfs', '/tmp', '--proc', '/proc',
                   '--dev', '/dev', '--ro-bind', str(self.git), '/usr/bin/git',
                   '--ro-bind', str(self.getent), '/usr/bin/getent', '--chdir', '/root',
                   '--setenv', 'HOME', '/root', '/usr/bin/python3', '-I',
                   str(REPO / 'tools/root-shell.py'), '--receive', revision, 'yes']
        return subprocess.run(command, input=payload, capture_output=True, timeout=30)

    def test_install_backup_and_idempotence(self):
        first = self.run_root()
        self.assertEqual(first.returncode, 0, first.stdout.decode() + first.stderr.decode())
        link = self.home / '.zshrc'
        self.assertTrue(link.is_symlink())
        self.assertTrue(os.readlink(link).startswith('/root/.dotfiles/'))
        backups = list(self.home.glob('.zshrc.*.bak'))
        self.assertEqual(len(backups), 1)
        for path in (self.home / '.dotfiles').rglob('*'):
            self.assertEqual(path.lstat().st_mode & 0o077, 0, str(path))
        self.assertEqual(backups[0].read_text(), '# original root config\n')
        central = list((self.home / '.dotfiles-backup').glob('*/.zshrc'))
        self.assertEqual(central[0].read_text(), '# original root config\n')
        self.assertEqual((self.home / '.alias.local').read_text(), 'alias root_local_test=true\n')
        before = {str(p.relative_to(self.home)): p.lstat().st_mtime_ns for p in self.home.rglob('*')
                  if '/logs' not in str(p) and p.is_file()}
        second = self.run_root()
        self.assertEqual(second.returncode, 0, second.stdout.decode() + second.stderr.decode())
        after = {str(p.relative_to(self.home)): p.lstat().st_mtime_ns for p in self.home.rglob('*')
                 if '/logs' not in str(p) and p.is_file()}
        self.assertEqual(before, after)
        self.assertEqual(len(list(self.home.glob('.zshrc.*.bak'))), 1)

    def test_reject_user_plugin_link(self):
        shutil.rmtree(self.home / '.oh-my-zsh')
        (self.home / '.oh-my-zsh').symlink_to('/home/wjk/.oh-my-zsh')
        result = self.run_root()
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse((self.home / '.dotfiles').exists())

    def test_reject_writable_local_config(self):
        (self.home / '.alias.local').chmod(0o666)
        self.assertNotEqual(self.run_root().returncode, 0)
        self.assertFalse((self.home / '.dotfiles').exists())

    def test_reject_redirected_parent(self):
        (self.home / '.config').symlink_to('/tmp')
        self.assertNotEqual(self.run_root().returncode, 0)
        self.assertFalse((self.home / '.dotfiles').exists())

    def test_reject_stale_compiled_config(self):
        (self.home / '.zshrc.zwc').write_bytes(b'stale bytecode')
        self.assertNotEqual(self.run_root().returncode, 0)
        self.assertFalse((self.home / '.dotfiles').exists())

    def test_reject_snapshot_symlink(self):
        self.assertNotEqual(self.run_root(unsafe=True).returncode, 0)
        self.assertFalse((self.home / '.dotfiles').exists())


NEOMUTT = os.environ.get('NEOMUTT_TEST_BINARY') or shutil.which('neomutt')


@unittest.skipUnless(NEOMUTT, 'NeoMutt binary required for config validation')
class MailTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name)
        self.bin = self.home / 'bin'
        self.bin.mkdir()
        (self.bin / 'neomutt').symlink_to(NEOMUTT)
        self.env = dict(os.environ, HOME=str(self.home), XDG_CONFIG_HOME=str(self.home / '.config'),
                        PATH=str(self.bin) + ':' + os.environ['PATH'], TERM='xterm-256color')

    def install(self, answer='yes'):
        return subprocess.run(['python3', str(REPO / 'tools/install-mail.py'), answer],
                              input='q\n', text=True, capture_output=True, env=self.env, timeout=20)

    def main_install(self, mail=None):
        # Exercise the real main installer and helper with other steps disabled.
        # Git only supplies read-only checkout metadata; sudo must never run.
        git = self.bin / 'git'
        git.write_text('''#!/bin/sh
case "$*" in
  *"status --porcelain") exit 0;;
  *"rev-parse HEAD") echo 0123456789012345678901234567890123456789;;
  *) echo "Unexpected git operation" >&2; exit 98;;
esac
''')
        git.chmod(0o755)
        sudo = self.bin / 'sudo'
        sudo.write_text('#!/bin/sh\necho "Unexpected sudo operation" >&2\nexit 99\n')
        sudo.chmod(0o755)
        state = self.home / '.local/state/dotfiles'
        state.mkdir(parents=True)
        choices = ''.join(key + '=no\n' for key in ('packages', 'ohmyzsh', 'shell', 'fonts', 'links'))
        if mail is not None:
            choices += 'mail=' + mail + '\n'
        (state / 'linux.state').write_text(choices)
        env = dict(self.env, XDG_STATE_HOME=str(self.home / '.local/state'))
        return subprocess.run(['bash', str(REPO / 'install.sh'), '--yes'],
                              capture_output=True, text=True, env=env, timeout=20)

    def test_main_installer_includes_mail_by_default(self):
        result = self.main_install()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertTrue((self.home / '.config/neomutt/neomuttrc').is_file())
        self.assertIn('mail=yes', (self.home / '.local/state/dotfiles/linux.state').read_text())
        self.assertIn('NeoMutt preview:', result.stdout)

    def test_main_installer_remembers_mail_no(self):
        result = self.main_install('no')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertFalse((self.home / '.config/neomutt').exists())
        self.assertIn('mail=no', (self.home / '.local/state/dotfiles/linux.state').read_text())

    def test_fresh_and_idempotent(self):
        result = self.install()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        folder = self.home / '.config/neomutt'
        before = {p.name: p.stat().st_mtime_ns for p in folder.iterdir()}
        self.assertEqual(self.install().returncode, 0)
        self.assertEqual(before, {p.name: p.stat().st_mtime_ns for p in folder.iterdir()})
        query = subprocess.run([NEOMUTT, '-n', '-F', str(folder / 'neomuttrc'), '-Q', 'editor',
                                '-Q', 'sidebar_visible', '-Q', 'use_threads'],
                               capture_output=True, text=True, env=self.env)
        # NeoMutt 20250510 (Debian 13) exits 1 after successful info queries.
        # Check diagnostics and the actual values, not just that exit status.
        self.assertIn(query.returncode, (0, 1))
        self.assertEqual(query.stderr, "")
        self.assertIn('set editor = "nvim', query.stdout)
        self.assertIn('set use_threads = threads', query.stdout)
        self.assertIn('set sidebar_visible = yes', query.stdout)
        self.assertEqual((folder / 'accounts.local').stat().st_mode & 0o777, 0o600)

    def test_presentation_in_terminal(self):
        # A local read-only mailbox exercises colour parsing (skipped by -Q)
        # and the actual sidebar/thread UI, without accounts or network access.
        mailbox = self.home / 'Inbox'
        mailbox.write_text('From test@example.invalid Tue Nov  3 10:00:00 2026\n'
                           'From: Penguin <test@example.invalid>\n'
                           'To: test@example.invalid\n'
                           'Date: Tue, 3 Nov 2026 10:00:00 +0100\n'
                           'Subject: Penguin review\n\nOffline fixture.\n\n')
        config = self.home / 'review.rc'
        config.write_text(f'source "{REPO}/linux/neomutt/neomuttrc"\nset folder = "{self.home}"\nmailboxes "{mailbox}"\n')
        pid, terminal = pty.fork()
        if pid == 0:
            fcntl.ioctl(0, termios.TIOCSWINSZ, struct.pack('HHHH', 32, 120, 0, 0))
            os.execve(NEOMUTT, [NEOMUTT, '-n', '-R', '-F', str(config), '-f', str(mailbox)], self.env)
        output = b''
        try:
            deadline = time.monotonic() + 5
            while time.monotonic() < deadline:
                if select.select([terminal], [], [], 0.1)[0]:
                    try:
                        output += os.read(terminal, 65536)
                    except OSError:
                        break
                    if b'Penguin review' in output and b'Inbox' in output:
                        break
            text = output.decode(errors='replace')
            self.assertIn('Penguin review', text)
            self.assertIn('Inbox', text)
            self.assertNotIn('Error in', text)
            self.assertNotIn('unknown command', text)
            self.assertIn('38;5;', text)  # 256-colour palette rendered
        finally:
            os.close(terminal)
            try:
                os.kill(pid, signal.SIGTERM)
            except ProcessLookupError:
                pass
            os.waitpid(pid, 0)

    def test_preserve_existing_config_without_executing_it(self):
        folder = self.home / '.config/neomutt'
        folder.mkdir(parents=True)
        config = folder / 'neomuttrc'
        private = 'set from = "test@example.invalid"\nset imap_pass = `touch ' + str(self.home / 'executed') + '`\n'
        config.write_text(private)
        result = self.install()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertFalse((self.home / 'executed').exists())
        self.assertEqual(next(folder.glob('neomuttrc.*.bak')).read_text(), private)
        self.assertEqual(next((self.home / '.dotfiles-backup').glob('*/neomuttrc')).read_text(), private)
        self.assertIn('# existing config', config.read_text())
        self.assertEqual(self.install().returncode, 0)
        self.assertEqual(len(list(folder.glob('neomuttrc.*.bak'))), 1)

    def test_quit_and_symlink_safety(self):
        self.assertEqual(self.install('no').returncode, 0)
        self.assertFalse((self.home / '.config').exists())
        elsewhere = self.home / 'elsewhere'
        elsewhere.mkdir()
        (self.home / '.config').symlink_to(elsewhere)
        self.assertNotEqual(self.install().returncode, 0)
        self.assertEqual(list(elsewhere.iterdir()), [])


if __name__ == '__main__':
    unittest.main()
