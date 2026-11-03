"""Exercise per-user installs in temporary homes, without network or elevation."""
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest


REPO = Path(__file__).resolve().parents[1]


@unittest.skipIf(os.geteuid() == 0, 'requires a normal user; never install into live root')
class UserInstallTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.work = Path(self.temp.name)
        self.repo = REPO
        self.home = self.work / 'home'
        self.home.mkdir()
        self.bin = self.work / 'bin'
        self.bin.mkdir()
        # A restricted PATH genuinely has no sudo unless a test adds it.
        for name in ('awk', 'bash', 'cat', 'chmod', 'cmp', 'cp', 'cut', 'date', 'df',
                     'dirname', 'find', 'grep', 'head', 'id', 'ln', 'locale',
                     'mkdir', 'mv', 'paste', 'readlink', 'rm', 'sed', 'sleep', 'sort',
                     'tail', 'tee', 'tr', 'uname', 'wc', 'zsh'):
            source = shutil.which(name)
            if source:
                (self.bin / name).symlink_to(source)
        self.command('git', '''case "$*" in
  *"status --porcelain") exit 0;;
  *"rev-parse HEAD") echo 0123456789012345678901234567890123456789;;
  *"diff --name-only") exit 0;;
  *"symbolic-ref --short HEAD") echo master;;
  *"ls-remote origin refs/heads/master") printf '0123456789012345678901234567890123456789\\trefs/heads/master\\n';;
  clone*) for destination do :; done; mkdir -p "$destination/.git";;
  *) echo "Unexpected git operation: $*" >&2; exit 98;;
esac
''')
        self.command('getent', 'echo "fixture:x:1000:1000:fixture:/home/fixture:/bin/bash"\n')
        self.command('dpkg-query', 'exit 1\n')  # System packages are absent.
        self.command('nvim', 'echo "Editor must not be launched during install" >&2; exit 98\n')
        (self.bin / 'python3').symlink_to(sys.executable)
        self.env = dict(os.environ, HOME=str(self.home), PATH=str(self.bin),
                        XDG_CONFIG_HOME=str(self.home / '.config'),
                        XDG_STATE_HOME=str(self.home / '.local/state'),
                        XDG_DATA_HOME=str(self.home / '.local/share'),
                        XDG_CACHE_HOME=str(self.home / '.cache'),
                        ZSH_CUSTOM=str(self.home / '.oh-my-zsh/custom'))
        (self.home / '.zshrc').write_text('# original user config\n')
        (self.home / '.alias.local').write_text('alias private_test=true\n')

    def command(self, name, content):
        path = self.bin / name
        path.write_text('#!/bin/sh\n' + content)
        path.chmod(0o755)

    def install(self, *flags, packages='yes', shell='yes', mail='no'):
        state = self.home / '.local/state/dotfiles'
        state.mkdir(parents=True, exist_ok=True)
        (state / 'linux.state').write_text(
            f'packages={packages}\nohmyzsh=yes\nshell={shell}\nfonts=no\nlinks=yes\nmail={mail}\n')
        result = subprocess.run(['/bin/bash', str(self.repo / 'install.sh'), '--yes', *flags],
                                env=self.env, capture_output=True, text=True, timeout=20)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertTrue((self.home / '.zshrc').is_symlink())
        self.assertEqual((self.home / '.zshrc').resolve(), self.repo / 'linux/.zshrc')
        self.assertEqual(next(self.home.glob('.zshrc.*.bak')).read_text(), '# original user config\n')
        self.assertEqual((self.home / '.alias.local').read_text(), 'alias private_test=true\n')
        self.assertTrue((self.home / '.oh-my-zsh/custom/themes/powerlevel10k/.git').is_dir())
        return result

    def test_edited_checkout_installs_worktree_and_preserves_git_state(self):
        self.repo = self.work / 'checkout'
        shutil.copytree(REPO, self.repo, ignore=shutil.ignore_patterns('.git', 'temp', '__pycache__'))
        git_binary = shutil.which('git')
        def git(*args):
            return subprocess.check_output([git_binary, '-C', str(self.repo), *args], text=True)
        git('init', '-q')
        git('add', '.')
        git('-c', 'user.name=Fixture', '-c', 'user.email=fixture@example.invalid',
            '-c', 'commit.gpgsign=false', 'commit', '-qm', 'fixture')
        staged = self.repo / 'linux/.alias'
        staged.write_text(staged.read_text() + '\n# staged customization\n')
        git('add', 'linux/.alias')
        unstaged = self.repo / 'linux/.zshrc'
        unstaged.write_text(unstaged.read_text() + '\n# unstaged customization\n')
        untracked = self.repo / 'personal-notes.txt'
        untracked.write_text('keep this untracked file\n')
        before = (git('status', '--porcelain'), git('diff'), git('diff', '--cached'))
        stub = (self.bin / 'git').read_text()
        (self.bin / 'git').write_text(stub.replace('#!/bin/sh\n',
            f'#!/bin/sh\nif [ "$2" = "{self.repo}" ]; then exec "{git_binary}" "$@"; fi\n', 1))
        result = self.install(packages='no', shell='no')
        self.assertIn('with local changes; installing current checkout files', result.stdout)
        self.assertIn('# unstaged customization', (self.home / '.zshrc').read_text())
        self.assertIn('# staged customization', (self.home / '.alias').read_text())
        self.assertEqual(untracked.read_text(), 'keep this untracked file\n')
        self.assertEqual(before, (git('status', '--porcelain'), git('diff'), git('diff', '--cached')))

    def test_missing_sudo_keeps_per_user_steps(self):
        result = self.install('--sudo', mail='yes')
        self.assertIn('System package step skipped', result.stdout)
        self.assertIn('Login shell unchanged', result.stdout)
        self.assertIn('neomutt package still needed', result.stdout)
        self.assertTrue((self.home / '.config/neomutt/neomuttrc').is_file())
        # Skipping an unavailable system change does not erase the user's choice.
        self.assertIn('packages=yes', (self.home / '.local/state/dotfiles/linux.state').read_text())

    def test_denied_sudo_keeps_per_user_steps(self):
        self.command('sudo', 'echo "$*" >> "$HOME/sudo-calls"; exit 1\n')
        result = self.install('--sudo', mail='yes')
        self.assertIn('Continuing with per-user setup', result.stdout)
        self.assertEqual((self.home / 'sudo-calls').read_text(), '-v\n')
        self.assertTrue((self.home / '.config/neomutt/neomuttrc').is_file())

    def test_no_sudo_flag_never_invokes_sudo(self):
        self.command('sudo', 'echo "$*" >> "$HOME/sudo-calls"; exit 99\n')
        self.install('--no-sudo', mail='yes')
        self.assertFalse((self.home / 'sudo-calls').exists())

    def test_default_never_invokes_sudo_even_when_available(self):
        self.command('sudo', 'echo "$*" >> "$HOME/sudo-calls"; exit 0\n')
        self.install(mail='yes')
        self.assertFalse((self.home / 'sudo-calls').exists())

    def test_user_only_plan_never_checks_sudo(self):
        self.command('sudo', 'echo "$*" >> "$HOME/sudo-calls"; exit 99\n')
        self.install(packages='no', shell='no')
        self.assertFalse((self.home / 'sudo-calls').exists())

    def test_authorized_sudo_still_changes_login_shell(self):
        self.command('sudo', 'echo "$*" >> "$HOME/sudo-calls"; exit 0\n')
        result = self.install('--sudo', packages='no')
        self.assertIn('-n chsh -s ', (self.home / 'sudo-calls').read_text())
        self.assertNotIn('Login shell unchanged', result.stdout)

    def test_missing_mail_prerequisite_does_not_abort_other_steps(self):
        (self.bin / 'nvim').unlink()
        result = self.install('--no-sudo', mail='yes')
        self.assertIn('Mail setup skipped because nvim is missing', result.stdout)
        self.assertFalse((self.home / '.config/neomutt').exists())

    def test_standalone_mail_without_sudo(self):
        result = subprocess.run([sys.executable, str(REPO / 'tools/install-mail.py'), 'yes'],
                                env=self.env, capture_output=True, text=True, timeout=20)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertTrue((self.home / '.config/neomutt/neomuttrc').is_file())
        self.assertIn('Ask an administrator to install the neomutt package', result.stdout)

    def test_standalone_mail_default_does_not_invoke_available_sudo(self):
        self.command('sudo', 'echo "$*" >> "$HOME/sudo-calls"; exit 99\n')
        result = subprocess.run(['/bin/bash', str(REPO / 'install.sh'), 'mail', '--yes'],
                                env=self.env, capture_output=True, text=True, timeout=20)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertFalse((self.home / 'sudo-calls').exists())
        self.assertTrue((self.home / '.config/neomutt/neomuttrc').is_file())

    def test_standalone_mail_sudo_is_opt_in_and_failure_keeps_config(self):
        self.command('sudo', 'echo "$*" >> "$HOME/sudo-calls"; exit 1\n')
        result = subprocess.run(['/bin/bash', str(REPO / 'install.sh'), 'mail', '--yes', '--sudo'],
                                env=self.env, capture_output=True, text=True, timeout=20)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn('apt-get install -y neomutt', (self.home / 'sudo-calls').read_text())
        self.assertTrue((self.home / '.config/neomutt/neomuttrc').is_file())

    def test_root_mode_requires_sudo_opt_in(self):
        self.command('sudo', 'echo "$*" >> "$HOME/sudo-calls"; exit 99\n')
        result = subprocess.run(['/bin/bash', str(REPO / 'install.sh'), 'root', '--yes'],
                                env=self.env, capture_output=True, text=True, timeout=20)
        self.assertEqual(result.returncode, 2)
        self.assertIn('requires --sudo', result.stderr)
        self.assertFalse((self.home / 'sudo-calls').exists())


if __name__ == '__main__':
    unittest.main()
