#!/usr/bin/env python3
"""Snapshot the reviewed shell config, then reuse install.sh inside /root.

The privileged receiver reads file bytes, never sources the invoking checkout.
Only committed, allowlisted regular files enter the root-owned snapshot.
"""
import io
import os
from pathlib import Path
import re
import stat
import subprocess
import sys
import tarfile

ROOT = Path('/root')
FILES = (
    'install.sh', 'HELP.md', 'tools/root-shell.py',
    'linux/.zshrc', 'linux/.alias', 'linux/.p10k.zsh',
    'linux/.dir_colors', 'linux/.config/tmux/tmux.conf', 'linux/.config/eza/theme.yml',
)
MANAGED = ('.zshrc', '.alias', '.p10k.zsh', '.dir_colors', '.config/tmux/tmux.conf')
SAFE_PATH = '/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin'


def secure(path, tree=False, seen=None):
    """No writable foreign code, redirected parents, or links leaving /root."""
    path = Path(os.path.abspath(path))
    if path != ROOT and ROOT not in path.parents:
        raise ValueError(f'Path escapes /root: {path}')
    seen = set() if seen is None else seen
    info = ROOT.lstat()
    if not stat.S_ISDIR(info.st_mode) or info.st_uid != 0 or info.st_mode & 0o022:
        raise ValueError('/root must be a real, root-owned directory without group/other write access')
    current = ROOT
    for component in path.relative_to(ROOT).parts:
        current /= component
        if not current.exists() and not current.is_symlink():
            return
        info = current.lstat()
        if not (stat.S_ISREG(info.st_mode) or stat.S_ISDIR(info.st_mode) or stat.S_ISLNK(info.st_mode)):
            raise ValueError(f'Special file in root configuration: {current}')
        if info.st_uid != 0 or (not stat.S_ISLNK(info.st_mode) and info.st_mode & 0o022):
            raise ValueError(f'Not root-owned or writable by others: {current}')
        if stat.S_ISLNK(info.st_mode):
            if current in seen:
                raise ValueError(f'Link loop: {current}')
            target = Path(os.path.abspath(current.parent / os.readlink(current)))
            secure(target, tree=True, seen=seen | {current})
    if tree and path.is_dir():
        for child in path.iterdir():
            secure(child, tree=True, seen=seen)


def audit():
    secure(ROOT)
    for name in ('.dotfiles', '.dotfiles-backup', '.config', '.config/tmux',
                 '.local', '.local/share', '.local/state', '.cache'):
        path = ROOT / name
        secure(path)
        if path.is_symlink():
            raise ValueError(f'Redirected install parent: {path}')
    for name in ('.oh-my-zsh', '.local/bin', '.local/state/dotfiles',
                 '.zshrc.local', '.alias.local', '.zshenv', '.zprofile', '.zlogin', '.zlogout'):
        secure(ROOT / name, tree=True)
        secure(ROOT / (name + '.zwc'), tree=True)
    for pattern in ('p10k-*', '.zcompdump*'):
        directory = ROOT / '.cache' if pattern == 'p10k-*' else ROOT
        for path in directory.glob(pattern):
            secure(path, tree=True)
    # Replaced links are backed up as links, never followed for writing.
    for name in MANAGED:
        path = ROOT / name
        compiled = Path(str(path) + '.zwc')
        if compiled.exists() or compiled.is_symlink():
            raise ValueError(f'Remove or back up stale compiled config before installing: {compiled}')
        if path.is_dir() and not path.is_symlink():
            raise ValueError(f'Expected a config file, found a directory: {path}')
        if path.exists() and not path.is_symlink() and not path.is_file():
            raise ValueError(f'Expected a config file, found a special file: {path}')


def receive(revision, yes):
    if os.geteuid() != 0 or not re.fullmatch(r'[0-9a-f]{40,64}', revision):
        raise ValueError('Receiver requires root and a Git revision')
    audit()
    data = sys.stdin.buffer.read(8 * 1024 * 1024 + 1)
    if len(data) > 8 * 1024 * 1024:
        raise ValueError('Root snapshot is unexpectedly large')
    contents = {}
    with tarfile.open(fileobj=io.BytesIO(data)) as archive:
        for item in archive:
            if item.isdir():
                continue
            if item.name not in FILES or not item.isfile() or item.name in contents:
                raise ValueError(f'Unexpected file or link in snapshot: {item.name}')
            contents[item.name] = archive.extractfile(item).read()
    if set(contents) != set(FILES):
        raise ValueError('Incomplete root snapshot')
    destination = ROOT / '.dotfiles' / revision
    secure(destination, tree=True)
    print(f'Root shell preview: snapshot {revision[:12]} -> {destination}', flush=True)
    for name in MANAGED:
        path = ROOT / name
        if path.is_symlink() and os.readlink(path) == str(destination / 'linux' / name):
            action = 'already linked'
        else:
            action = 'replace with timestamped backups' if path.exists() or path.is_symlink() else 'create'
        print(f'  {path}: {action}')
    print('  /root/.oh-my-zsh: root-owned upstream plugins; root login shell: zsh')
    print('  Local overrides kept; no system packages, fonts or normal-user config copied.', flush=True)
    if not yes:
        # A buffered read/write stream (r+) requires seeking; a TTY cannot seek.
        # Keep separate streams while stdin remains reserved for the archive.
        with open('/dev/tty', 'w') as prompt, open('/dev/tty', 'r') as reply:
            prompt.write('Apply [a], or quit [q]? ')
            prompt.flush()
            if reply.readline().strip().lower() != 'a':
                print('Nothing changed.')
                return
    os.umask(0o077)
    destination.mkdir(parents=True, exist_ok=True, mode=0o700)
    for name, content in {**contents, '.revision': (revision + '\n').encode()}.items():
        path = destination / name
        if path.is_symlink():
            raise ValueError(f'Snapshot must contain regular files: {path}')
        if path.exists():
            if path.read_bytes() != content:
                raise ValueError(f'Existing snapshot differs: {path}')
        else:
            path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
            with path.open('xb') as output:
                output.write(content)
            path.chmod(0o600)
    secure(destination, tree=True)
    environment = {'HOME': '/root', 'USER': 'root', 'LOGNAME': 'root', 'PATH': SAFE_PATH,
                   'LANG': 'C.UTF-8', 'TERM': os.environ.get('TERM', 'xterm-256color')}
    os.chdir(ROOT)
    os.execve('/bin/bash', ['bash', str(destination / 'install.sh'), '--root-apply', '--yes'], environment)


def main():
    if len(sys.argv) > 1 and sys.argv[1] == '--receive':
        receive(sys.argv[2], sys.argv[3] == 'yes')
    elif len(sys.argv) > 1 and sys.argv[1] == '--audit':
        path = Path(sys.argv[2]).absolute()
        if os.geteuid() != 0 or path.parent != ROOT / '.dotfiles' or not re.fullmatch(r'[0-9a-f]{40,64}', path.name):
            raise ValueError('Internal root mode requires a root-owned snapshot')
        audit()
        secure(path, tree=True)
    else:
        if os.geteuid() == 0:
            raise ValueError('Invoke ./install.sh root --sudo as your normal user')
        repo = Path(__file__).resolve().parents[1]
        if subprocess.check_output(['git', '-C', str(repo), 'status', '--porcelain']):
            raise ValueError('Commit or stash checkout changes first; root uses committed files only')
        revision = subprocess.check_output(['git', '-C', str(repo), 'rev-parse', 'HEAD'], text=True).strip()
        payload = subprocess.check_output(['git', '-C', str(repo), 'archive', revision, *FILES])
        receiver = subprocess.check_output(['git', '-C', str(repo), 'show', revision + ':tools/root-shell.py'], text=True)
        # -I and env -i exclude user Python modules, shell hooks and PATH overrides.
        subprocess.run(['sudo', '/usr/bin/env', '-i', 'HOME=/root', f'PATH={SAFE_PATH}',
                        'LANG=C.UTF-8', f'TERM={os.environ.get("TERM", "xterm-256color")}',
                        '/usr/bin/python3', '-I', '-c', receiver, '--receive', revision,
                        sys.argv[1] if len(sys.argv) > 1 else 'no'], input=payload, check=True)


if __name__ == '__main__':
    try:
        main()
    except subprocess.CalledProcessError as error:
        # The sudo argv includes the whole receiver: never dump it on failure.
        sys.exit(f'Root install stopped: {error.cmd[0]} failed (exit {error.returncode}); see the error above.')
    except (ValueError, OSError, tarfile.TarError) as error:
        sys.exit(f'Root install stopped: {error}')
