#!/usr/bin/env python3
"""Install a private NeoMutt loader around shared presentation-only files."""
import datetime
import os
from pathlib import Path
import shutil
import subprocess
import sys

MARKER = '# Managed by dotfiles-public: NeoMutt presentation loader v1\n'


def quote(path):
    text = str(path)
    if any(c in text for c in '\r\n"`$'):
        raise ValueError('Config paths must not contain quotes, substitutions or newlines')
    return '"' + text.replace('\\', '\\\\') + '"'


def check_parents(path):
    for parent in (path, *path.parents):
        if parent.is_symlink() or (parent.exists() and not parent.is_dir()):
            raise ValueError(f'Redirected or non-directory config parent: {parent}')


def main():
    if os.geteuid() == 0:
        raise ValueError('Run ./install.sh mail as your normal user')
    home = Path.home()
    repo = Path(__file__).resolve().parents[1]
    base = Path(os.environ.get('XDG_CONFIG_HOME', str(home / '.config')))
    if not base.is_absolute():
        raise ValueError('XDG_CONFIG_HOME must be absolute')
    directory = base / 'neomutt'
    target = directory / 'neomuttrc'
    check_parents(directory)
    check_parents(home / '.dotfiles-backup')
    if target.exists() and not target.is_symlink() and not target.is_file():
        raise ValueError(f'{target} must be a regular file')
    for name in ('accounts.local', 'settings.local', 'aliases.local'):
        path = directory / name
        if path.is_symlink() or (path.exists() and not path.is_file()):
            raise ValueError(f'Private config must be a regular file: {path}')
    if not shutil.which('nvim'):
        raise ValueError('Install your existing Neovim setup first; the mail installer does not replace it')
    # Never print or execute account files during inspection/installation.
    candidates = [target, directory / 'muttrc', base / 'mutt/neomuttrc', base / 'mutt/muttrc',
                  home / '.neomutt/neomuttrc', home / '.neomutt/muttrc',
                  home / '.mutt/neomuttrc', home / '.mutt/muttrc', home / '.neomuttrc', home / '.muttrc']
    existing = next((p for p in candidates if p.is_file()), None)
    current = target.read_text() if target.is_file() and not target.is_symlink() else ''
    managed = current.startswith(MARKER)
    stamp = datetime.datetime.now().strftime('%Y%m%d-%H%M%S-%f')
    bak = Path(str(target) + '.' + stamp + '.bak')
    backup = home / '.dotfiles-backup' / ('neomutt-' + stamp)
    # A managed rerun retains its original account source; it never sources itself.
    legacy = [line for line in current.splitlines() if line.startswith('source ') and '# existing config' in line] if managed else []
    if not managed and existing:
        legacy = ['source ' + quote(bak if existing == target else existing) + ' # existing config']
    content = MARKER + 'source ' + quote(repo / 'linux/neomutt/neomuttrc') + '\n'
    content += 'set alias_file = ' + quote(directory / 'aliases.local') + '\n'
    content += '\n'.join(legacy) + ('\n' if legacy else '')
    for name in ('accounts.local', 'aliases.local', 'settings.local'):
        content += 'source ' + quote(directory / name) + '\n'
    print('NeoMutt preview:')
    print(f'  {target}: ' + ('already current' if current == content else 'create/replace private loader'))
    print(f'  Existing config: {existing or "none; start with private account settings"}')
    if current != content and (target.exists() or target.is_symlink()):
        print(f'  Backups: {bak} and {backup}/neomuttrc')
    print('  Existing account settings and shortcuts load after the shared appearance.')
    print('  Neovim config stays in use; no editor config, mailbox or credentials are copied into Git.')
    if not shutil.which('neomutt'):
        print('  Install the neomutt package with sudo apt-get install neomutt.')
    if (len(sys.argv) < 2 or sys.argv[1] != 'yes') and input('Apply [a], or quit [q]? ').strip().lower() != 'a':
        print('Nothing changed.')
        return
    if not shutil.which('neomutt'):
        subprocess.run(['sudo', 'apt-get', 'install', '-y', 'neomutt'], check=True)
    # Config parsing is covered by the test suite. Do not launch NeoMutt here:
    # private config may execute password commands or contact a mail server.
    directory.mkdir(parents=True, exist_ok=True, mode=0o700)
    directory.chmod(0o700)
    if current != content:
        if target.exists() or target.is_symlink():
            if bak.exists() or bak.is_symlink() or backup.exists():
                raise ValueError('Backup path already exists; nothing overwritten')
            (home / '.dotfiles-backup').mkdir(exist_ok=True, mode=0o700)
            (home / '.dotfiles-backup').chmod(0o700)
            backup.mkdir(mode=0o700)
            shutil.copy2(target, backup / 'neomuttrc', follow_symlinks=False)
            if not (backup / 'neomuttrc').is_symlink():
                (backup / 'neomuttrc').chmod(0o600)
            target.rename(bak)
            if not bak.is_symlink():
                bak.chmod(0o600)
        with target.open('x') as output:
            output.write(content)
        target.chmod(0o600)
    for name in ('accounts.local', 'settings.local', 'aliases.local'):
        path = directory / name
        if not path.exists():
            with path.open('x') as output:
                output.write('# Private NeoMutt ' + name + '; kept outside Git.\n')
            path.chmod(0o600)
    print(f'Ready. Add your account in {directory / "accounts.local"}, then run neomutt.')
    print(f'Example: {repo / "linux/neomutt/accounts.example"}; F2 sidebar, F3/F4 select, F5 open.')


if __name__ == '__main__':
    try:
        main()
    except (ValueError, OSError, EOFError, subprocess.CalledProcessError) as error:
        sys.exit(f'Mail install stopped: {error}')
