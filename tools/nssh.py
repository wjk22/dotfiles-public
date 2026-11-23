#!/usr/bin/env python3
"""nssh: ssh that remembers where you connect.

  nssh                      the list: Enter connects, r rename, d delete,
                            e edit the list, l log, / search, q or Esc quit
  nssh [ssh options] host   connect and remember the arguments
  nssh 3 | nssh name        connect to an entry of the list
  nssh list                 print the list, numbered
  nssh log                  print the connection log
  nssh r 3 name             name an entry
  nssh d 3                  delete an entry

Everything lives in ~/.ssh/nssh: "hosts" (one "time<TAB>name<TAB>args" line per
entry, most recent first) and "log" (one "start<TAB>end<TAB>name<TAB>args<TAB>exit"
line per connection). Hosts from ~/.ssh/config are offered too; a failed
connection (ssh exits 255) is logged but not remembered.
"""
import os
from pathlib import Path
import re
import shlex
import shutil
import signal
import subprocess
import sys
import time

HOME = Path.home()
DIR = HOME / '.ssh' / 'nssh'
HOSTS = DIR / 'hosts'
LOG = DIR / 'log'
SSH_CONFIG = HOME / '.ssh' / 'config'
RESERVED = {'list', 'log', 'r', 'd'}
HELP_LINE = 'Enter connect  r rename  d delete  e edit  l log  / search  q quit'


class Entry:
    def __init__(self, when, name, args):
        self.when, self.name, self.args = when, name, args

    @property
    def from_config(self):
        return self.when < 0

    def label(self):
        return self.name or self.args


# ------------------------------------------------------------------ storage ---
def migrate():
    """The first versions kept the list elsewhere; copy it once, keep the original."""
    if HOSTS.exists():
        return
    old = [Path(os.environ.get('XDG_DATA_HOME') or HOME / '.local' / 'share') / 'nssh' / 'hosts']
    if os.environ.get('LOCALAPPDATA'):
        old.append(Path(os.environ['LOCALAPPDATA']) / 'nssh' / 'hosts')
    for path in old:
        if path.is_file():
            DIR.mkdir(parents=True, exist_ok=True)
            HOSTS.write_text(path.read_text(encoding='utf-8'), encoding='utf-8')
            return


def config_hosts():
    try:
        lines = SSH_CONFIG.read_text(encoding='utf-8', errors='replace').splitlines()
    except OSError:
        return []
    hosts = []
    for line in lines:
        words = line.split()
        if len(words) > 1 and words[0].lower() == 'host':
            hosts += [h for h in words[1:] if not re.search(r'[*?!]', h)]
    return hosts


def load():
    entries = []
    try:
        lines = HOSTS.read_text(encoding='utf-8').splitlines()
    except OSError:
        lines = []
    for line in lines:
        if not line.strip():
            continue
        parts = line.split('\t', 2)
        if len(parts) == 3 and parts[0].isdigit():
            entries.append(Entry(int(parts[0]), parts[1], parts[2]))
        else:
            entries.append(Entry(0, '', line))  # a line from before names and times
    known = {e.args for e in entries} | {e.name for e in entries if e.name}
    for host in config_hosts():
        if host not in known:
            known.add(host)
            entries.append(Entry(-1, host, host))
    return entries


def save(entries):
    DIR.mkdir(parents=True, exist_ok=True)
    kept = sorted((e for e in entries if not e.from_config), key=lambda e: -e.when)
    tmp = HOSTS.with_name('hosts.tmp')
    tmp.write_text(''.join(f'{e.when}\t{e.name}\t{e.args}\n' for e in kept), encoding='utf-8')
    os.replace(tmp, HOSTS)


def log_lines():
    try:
        lines = LOG.read_text(encoding='utf-8').splitlines()
    except OSError:
        return []
    rows = []
    for line in reversed(lines):
        parts = line.split('\t')
        if len(parts) == 5 and parts[0].isdigit() and parts[1].isdigit():
            start, end, name, args, code = parts
            start, end = int(start), int(end)
            result = 'ok' if code == '0' else 'failed' if code == '255' else f'exit {code}'
            rows.append((name or args, f'{stamp(start)} -> {time.strftime("%H:%M", time.localtime(end))}  '
                                       f'{duration(end - start):>7}  {result:<7}  {name or "-":<12}  {args}'))
    return rows


# ------------------------------------------------------------------ helpers ---
def ago(when):
    if when < 0:
        return 'ssh config'
    if when == 0:
        return '-'
    d = int(time.time()) - when
    if d < 60:
        return 'just now'
    if d < 3600:
        return f'{d // 60}m ago'
    if d < 86400:
        return f'{d // 3600}h ago'
    if d < 7 * 86400:
        return f'{d // 86400}d ago'
    return time.strftime('%Y-%m-%d', time.localtime(when))


def stamp(when):
    return time.strftime('%Y-%m-%d %H:%M', time.localtime(when))


def duration(seconds):
    if seconds < 60:
        return f'{seconds}s'
    if seconds < 3600:
        return f'{seconds // 60}m'
    return f'{seconds // 3600}h{seconds % 3600 // 60:02d}m'


def rows(entries):
    width = max([4] + [len(e.name) for e in entries])
    return [f'{e.name:<{width}}  {ago(e.when):<10}  {e.args}' for e in entries]


def find(entries, key):
    if key.isdigit() and 1 <= int(key) <= len(entries):
        return int(key) - 1
    if not key.isdigit():
        for i, e in enumerate(entries):
            if e.name == key:
                return i
    return None


def name_problem(entries, index, name):
    if not name or re.search(r'\s', name) or name.isdigit() or name in RESERVED:
        return 'a name is one word, not a number or list/log/r/d'
    if any(e.name == name and i != index for i, e in enumerate(entries)):
        return f'{name} is taken'
    return ''


def rename(entries, index, name):
    entries[index].name = name
    if entries[index].from_config:
        entries[index].when = 0  # now it is ours to keep
    save(entries)


def editor():
    for candidate in (os.environ.get('VISUAL'), os.environ.get('EDITOR'), 'nvim', 'vim', 'vi', 'notepad'):
        if candidate and shutil.which(candidate.split()[0]):
            return shlex.split(candidate) if os.name != 'nt' else candidate.split()
    return None


def connect(args, name=''):
    """Runs ssh in this terminal, then logs the session and remembers it."""
    line = shlex.join(args)
    start = int(time.time())
    previous = signal.signal(signal.SIGINT, signal.SIG_IGN)  # Ctrl-C belongs to ssh
    try:
        code = subprocess.call(['ssh', *args])
    except FileNotFoundError:
        print('nssh: ssh not found', file=sys.stderr)
        return 127
    finally:
        signal.signal(signal.SIGINT, previous)
    end = int(time.time())
    entries = load()
    match = next((e for e in entries if e.args == line), None)
    name = name or (match.name if match else '')
    DIR.mkdir(parents=True, exist_ok=True)
    with LOG.open('a', encoding='utf-8') as log:
        log.write(f'{start}\t{end}\t{name}\t{line}\t{code}\n')
    if code != 255:
        if match:
            entries.remove(match)
        entries.insert(0, Entry(end, name, line))
        save(entries)
    return code


# ----------------------------------------------------------------------- tui ---
def tui(entries):
    """Returns the entry to connect to, or None."""
    os.environ.setdefault('ESCDELAY', '25')
    try:
        import curses
    except ImportError:
        hint = 'py -m pip install windows-curses' if os.name == 'nt' else 'install python3 with curses'
        print(f'nssh: the list needs curses ({hint}); nssh list and nssh 3 work without it.', file=sys.stderr)
        return None
    return curses.wrapper(lambda screen: Tui(screen, curses, entries).run())


class Tui:
    def __init__(self, screen, curses, entries):
        self.s, self.c, self.entries = screen, curses, entries
        self.cursor, self.top, self.query, self.message = 0, 0, '', ''
        curses.curs_set(0)
        try:
            curses.use_default_colors()
            curses.init_pair(1, curses.COLOR_CYAN, -1)
            curses.init_pair(2, curses.COLOR_GREEN, -1)
            self.accent, self.ok = curses.color_pair(1), curses.color_pair(2)
        except curses.error:
            self.accent = self.ok = 0

    def visible(self):
        q = self.query.lower()
        return [i for i, e in enumerate(self.entries) if q in e.name.lower() or q in e.args.lower()]

    def line(self, y, x, text, attr=0):
        h, w = self.s.getmaxyx()
        if 0 <= y < h and x < w:
            try:
                self.s.addnstr(y, x, text, w - x - 1, attr)
            except self.c.error:
                pass

    def draw(self):
        self.s.erase()
        h, w = self.s.getmaxyx()
        shown = self.visible()
        self.cursor = max(0, min(self.cursor, len(shown) - 1))
        body = max(1, h - 3)
        if self.cursor < self.top:
            self.top = self.cursor
        elif self.cursor >= self.top + body:
            self.top = self.cursor - body + 1
        title = 'nssh' + (f'  /{self.query}' if self.query else '')
        self.line(0, 0, title, self.accent | self.c.A_BOLD)
        texts = rows(self.entries)
        if not shown:
            self.line(2, 2, 'nothing remembered yet: nssh user@host connects and remembers it'
                      if not self.entries else 'no match')
        for row, i in enumerate(shown[self.top:self.top + body]):
            attr = self.c.A_REVERSE if row + self.top == self.cursor else (self.c.A_DIM if self.entries[i].from_config else 0)
            self.line(row + 1, 0, f'{i + 1:3}  {texts[i]}'.ljust(w), attr)
        self.line(h - 1, 0, self.message or HELP_LINE, self.ok if self.message else self.c.A_DIM)
        self.s.refresh()

    def ask(self, prompt, value=''):
        """A one-line input at the bottom; Enter returns it, Esc returns None."""
        self.c.curs_set(1)
        try:
            while True:
                h, w = self.s.getmaxyx()
                self.s.move(h - 1, 0)
                self.s.clrtoeol()
                self.line(h - 1, 0, prompt + value, self.accent)
                self.s.move(h - 1, min(w - 1, len(prompt) + len(value)))
                key = self.s.get_wch()
                if key in ('\n', '\r', self.c.KEY_ENTER):
                    return value
                if key == '\x1b':
                    return None
                if key in (self.c.KEY_BACKSPACE, '\x7f', '\b'):
                    value = value[:-1]
                elif isinstance(key, str) and key.isprintable():
                    value += key
        finally:
            self.c.curs_set(0)

    def confirm(self, prompt):
        """One key: y is yes, anything else is no."""
        h, _ = self.s.getmaxyx()
        self.s.move(h - 1, 0)
        self.s.clrtoeol()
        self.line(h - 1, 0, prompt, self.accent | self.c.A_BOLD)
        self.s.refresh()
        return self.s.get_wch() in ('y', 'Y')

    def current(self):
        shown = self.visible()
        return shown[self.cursor] if shown else None

    def run(self):
        while True:
            self.draw()
            key = self.s.get_wch()
            self.message = ''
            i = self.current()
            if key in ('q', '\x1b'):
                if key == '\x1b' and self.query:
                    self.query = ''
                    continue
                return None
            if key in (self.c.KEY_UP, 'k'):
                self.cursor -= 1
            elif key in (self.c.KEY_DOWN, 'j'):
                self.cursor += 1
            elif key == self.c.KEY_PPAGE:
                self.cursor -= self.s.getmaxyx()[0] - 3
            elif key == self.c.KEY_NPAGE:
                self.cursor += self.s.getmaxyx()[0] - 3
            elif key in (self.c.KEY_HOME, 'g'):
                self.cursor = 0
            elif key in (self.c.KEY_END, 'G'):
                self.cursor = len(self.visible()) - 1
            elif key in ('\n', '\r', self.c.KEY_ENTER) and i is not None:
                return self.entries[i]
            elif key == '/':
                query = self.ask('/', self.query)
                self.query = query if query is not None else self.query
                self.cursor = 0
            elif key == 'r' and i is not None:
                name = self.ask('name: ', self.entries[i].name)
                if name is not None:
                    problem = name_problem(self.entries, i, name.strip())
                    if problem:
                        self.message = problem
                    else:
                        rename(self.entries, i, name.strip())
                        self.message = f'named {name.strip()}'
            elif key == 'd' and i is not None:
                e = self.entries[i]
                if e.from_config:
                    self.message = f'{e.args} comes from ~/.ssh/config; remove it there'
                elif self.confirm(f'delete {e.label()}? y/n'):
                    del self.entries[i]
                    save(self.entries)
                    self.message = f'deleted {e.label()}'
            elif key == 'e':
                self.edit()
            elif key == 'l':
                self.log()
            elif key == self.c.KEY_RESIZE:
                pass

    def edit(self):
        command = editor()
        if not command:
            self.message = 'no editor found; set EDITOR'
            return
        save(self.entries)  # the file exists and holds what is shown
        self.c.endwin()
        subprocess.call([*command, str(HOSTS)])
        self.s.refresh()
        self.entries[:] = load()

    def log(self):
        lines = [text for _, text in log_lines()]
        top = 0
        while True:
            self.s.erase()
            h, w = self.s.getmaxyx()
            body = max(1, h - 2)
            top = max(0, min(top, len(lines) - body))
            self.line(0, 0, f'nssh log  ({len(lines)} connections, newest first)', self.accent | self.c.A_BOLD)
            if not lines:
                self.line(2, 2, 'no connections logged yet')
            for row, text in enumerate(lines[top:top + body]):
                self.line(row + 1, 0, text, self.c.A_DIM if '  failed ' in text else 0)
            self.line(h - 1, 0, 'arrows, PgUp/PgDn scroll  Esc back', self.c.A_DIM)
            self.s.refresh()
            key = self.s.get_wch()
            if key in ('\x1b', 'q', 'l'):
                return
            if key in (self.c.KEY_UP, 'k'):
                top -= 1
            elif key in (self.c.KEY_DOWN, 'j'):
                top += 1
            elif key == self.c.KEY_PPAGE:
                top -= body
            elif key == self.c.KEY_NPAGE:
                top += body
            elif key in (self.c.KEY_HOME, 'g'):
                top = 0
            elif key in (self.c.KEY_END, 'G'):
                top = len(lines)


# ----------------------------------------------------------------------- cli ---
def main(argv):
    migrate()
    entries = load()
    if not argv:
        chosen = tui(entries)
        return connect(shlex.split(chosen.args), chosen.name) if chosen else 0
    if argv == ['list']:
        for i, text in enumerate(rows(entries), 1):
            print(f'{i:3}  {text}')
        return 0
    if argv == ['log']:
        for _, text in log_lines():
            print(text)
        return 0
    if argv[0] in ('-h', '--help') and len(argv) == 1:
        print(__doc__.strip())
        return 0
    if len(argv) == 3 and argv[0] == 'r':
        i = find(entries, argv[1])
        if i is None:
            print(f'nssh: no entry {argv[1]} (see nssh list)', file=sys.stderr)
            return 1
        problem = name_problem(entries, i, argv[2])
        if problem:
            print(f'nssh: {problem}', file=sys.stderr)
            return 1
        rename(entries, i, argv[2])
        return main(['list'])
    if len(argv) == 2 and argv[0] == 'd':
        i = find(entries, argv[1])
        if i is None:
            print(f'nssh: no entry {argv[1]} (see nssh list)', file=sys.stderr)
            return 1
        if entries[i].from_config:
            print(f'nssh: {entries[i].args} comes from ~/.ssh/config; remove it there', file=sys.stderr)
            return 1
        del entries[i]
        save(entries)
        return main(['list'])
    if len(argv) == 1:
        i = find(entries, argv[0])
        if i is not None:
            return connect(shlex.split(entries[i].args), entries[i].name)
    return connect(argv)


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
