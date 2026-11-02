"""Exercise the real eza binary, including terminal/pipe behaviour."""
import fcntl
import os
from pathlib import Path
import pty
import shutil
import subprocess
import struct
import termios
import tempfile
import unittest

REPO = Path(__file__).resolve().parents[1]
HISTORICAL = 'di=01;34:ow=30;42:*.zip=01;31'


@unittest.skipUnless(shutil.which('eza') and shutil.which('zsh'), 'eza and zsh required')
class ListingTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name)
        for name in ('ordinary', 'Downloads', 'Documents', 'Pictures', '.aws', '.config', 'writable'):
            (self.home / name).mkdir()
        (self.home / 'writable').chmod(0o777)
        for name in ('sample.zip', 'sample.sh', 'sample.png'):
            (self.home / name).touch()
        (self.home / 'sample.sh').chmod(0o755)
        self.env = dict(os.environ, HOME=str(self.home), DOTFILES=str(REPO),
                        TERM='xterm-256color', EZA_CONFIG_DIR='', EZA_COLORS='',
                        EXA_COLORS='', LS_COLORS=HISTORICAL)

    def command(self, text):
        return ['zsh', '-f', '-c', 'source "$DOTFILES/linux/.alias"; eval "$1"', 'check-listings', text]

    def run_listing(self, text):
        result = subprocess.run(self.command(text), env=self.env, cwd=self.home,
                                stdin=subprocess.DEVNULL, capture_output=True, text=True, timeout=10)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stderr, '')
        return result.stdout

    def test_palette_beats_old_ls_colors(self):
        output = self.run_listing('ls -1a --color=always --icons=always .')
        expected = {'ordinary': (216, 216, 216), 'writable': (216, 216, 216),
                    'Downloads': (201, 191, 167), 'Documents': (136, 191, 224),
                    'Pictures': (197, 139, 217), '.aws': (221, 166, 108),
                    '.config': (141, 188, 168), 'sample.zip': (140, 172, 226),
                    'sample.sh': (215, 130, 126), 'sample.png': (197, 139, 217)}
        for name, rgb in expected.items():
            line = next(line for line in output.splitlines() if name in line)
            self.assertIn('38;2;' + ';'.join(map(str, rgb)) + 'm', line, line)
        self.assertNotRegex(output, r'\x1b\[(?:[0-9]+;)*4[0-7](?:;[0-9]+)*m')
        preserved = self.run_listing('ls -1 . >/dev/null; print -r -- "$LS_COLORS"')
        self.assertEqual(preserved.strip(), HISTORICAL)
        original = self.run_listing('command ls -d --color=always ordinary')
        self.assertIn('01;34m', original)

    def test_all_aliases_are_plain_when_piped(self):
        for alias in ('ls', 'll', 'lla', 'el', 'es', 'esa'):
            output = self.run_listing(alias + ' .')
            self.assertIn('ordinary', output)
            self.assertTrue(output.isascii(), repr(output))
            self.assertNotIn('\x1b', output)

    def test_icons_are_automatic_in_terminal(self):
        master, slave = pty.openpty()
        fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack("HHHH", 32, 120, 0, 0))
        try:
            process = subprocess.Popen(self.command('ls .'), cwd=self.home, env=self.env,
                                       stdin=slave, stdout=slave, stderr=slave)
            os.close(slave)
            slave = None
            output = b''
            while True:
                try:
                    chunk = os.read(master, 65536)
                    if not chunk:
                        break
                    output += chunk
                except OSError:
                    break
            self.assertEqual(process.wait(timeout=10), 0)
            text = output.decode()
            self.assertIn('ordinary', text)
            self.assertIn('\uf019', text)  # Downloads icon, same on Debian 13/current eza
            self.assertIn('38;2;216;216;216m', text)
        finally:
            if slave is not None:
                os.close(slave)
            os.close(master)


if __name__ == '__main__':
    unittest.main()
