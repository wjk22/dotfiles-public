#!/usr/bin/env python3
"""nssh: ssh that remembers where you connect.

  nssh                      the list, in the next lines of the terminal: Enter
                            connects, r rename, d delete, e edit the list, l log,
                            / search, q or Esc quit
  nssh lm                   lazy mode: the same list full screen (curses)
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
RESERVED = {'list', 'log', 'lm', 'r', 'd'}
INLINE_ROWS = 10
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


def totals():
    """Time spent per command line, from the log; failed connections don't count."""
    spent = {}
    try:
        lines = LOG.read_text(encoding='utf-8').splitlines()
    except OSError:
        return spent
    for line in lines:
        parts = line.split('\t')
        if len(parts) == 5 and parts[0].isdigit() and parts[1].isdigit() and parts[4] != '255':
            spent[parts[3]] = spent.get(parts[3], 0) + int(parts[1]) - int(parts[0])
    return spent


def columns(entries):
    """Rows and their header: command, name, last connection, total time."""
    spent = totals()
    cut = lambda text, width: text if len(text) <= width else text[:width - 1] + '…'
    aw = min(40, max([7] + [len(e.args) for e in entries]))
    nw = min(24, max([4] + [len(e.name) for e in entries]))
    header = f'{"#":>3}  {"command":<{aw}}  {"name":<{nw}}  {"last":<10}  {"total":>7}'
    rows = [f'{cut(e.args, aw):<{aw}}  {cut(e.name, nw):<{nw}}  {ago(e.when):<10}  '
            f'{duration(spent[e.args]) if e.args in spent else "-":>7}' for e in entries]
    return header, rows


def rows(entries):
    return columns(entries)[1]


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
        return 'a name is one word, not a number or list/log/lm/r/d'
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


SSH_VALUE_FLAGS = set('BbcDEeFIiJLlmOoPpQRSWw')


def destination(args):
    """The host ssh connects to, without user@ and :port, or ''."""
    skip = False
    for arg in args:
        if skip:
            skip = False
        elif arg == '--':
            continue
        elif arg.startswith('-') and len(arg) > 1:
            # -p 22 takes the next argument, -p22 carries it
            skip = arg[-1] in SSH_VALUE_FLAGS and not any(c in SSH_VALUE_FLAGS for c in arg[1:-1])
        else:
            host = arg.removeprefix('ssh://').rsplit('@', 1)[-1]
            return host.split(':', 1)[0] if host.count(':') == 1 else host
    return ''


def tmux(*command):
    return subprocess.run(['tmux', *command], capture_output=True, text=True).stdout.strip()


def tmux_title(title):
    """Names the tmux window after the host; returns how to restore it."""
    pane = os.environ.get('TMUX_PANE')
    if not os.environ.get('TMUX') or not pane or not title or not shutil.which('tmux'):
        return None
    try:
        old = tmux('display-message', '-p', '-t', pane, '#{automatic-rename}\t#{window_name}')
        tmux('rename-window', '-t', pane, title)
    except OSError:
        return None
    automatic, _, name = old.partition('\t')
    return pane, automatic == '1', name


def tmux_restore(saved):
    if not saved:
        return
    pane, automatic, name = saved
    try:
        if automatic:
            tmux('set-window-option', '-t', pane, 'automatic-rename', 'on')
        else:
            tmux('rename-window', '-t', pane, name)
    except OSError:
        pass


def connect(args, name=''):
    """Runs ssh in this terminal, then logs the session and remembers it."""
    line = shlex.join(args)
    start = int(time.time())
    title = tmux_title(name or destination(args))  # the window shows the host, not python3
    previous = signal.signal(signal.SIGINT, signal.SIG_IGN)  # Ctrl-C belongs to ssh
    try:
        code = subprocess.call(['ssh', *args])
    except FileNotFoundError:
        print('nssh: ssh not found', file=sys.stderr)
        return 127
    finally:
        signal.signal(signal.SIGINT, previous)
        tmux_restore(title)
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
def tui(entries, lazy=False):
    """Returns the entry to connect to, or None. Lazy mode is full screen."""
    if not lazy:
        with Inline(INLINE_ROWS + 3) as screen:
            return Tui(screen, screen, entries).run()
    os.environ.setdefault('ESCDELAY', '25')
    try:
        import curses
    except ImportError:
        hint = 'py -m pip install windows-curses' if os.name == 'nt' else 'install python3 with curses'
        print(f'nssh: lazy mode needs curses ({hint}); plain nssh works without it.', file=sys.stderr)
        return None
    return curses.wrapper(lambda screen: Tui(screen, curses, entries).run())


class Inline:
    """The few curses calls Tui uses, drawn in the next lines below the prompt
    instead of a full screen. Both the screen and its "curses" module."""
    KEY_UP, KEY_DOWN, KEY_PPAGE, KEY_NPAGE, KEY_HOME, KEY_END = range(1001, 1007)
    KEY_ENTER, KEY_BACKSPACE, KEY_RESIZE = 1007, 1008, 1009
    A_BOLD, A_DIM, A_REVERSE = 1, 2, 4
    COLOR_CYAN, COLOR_GREEN = 36, 32
    error = OSError
    SGR = ((1, '1'), (2, '2'), (4, '7'), (8, '36'), (16, '32'))
    POSIX_KEYS = {'[A': KEY_UP, 'OA': KEY_UP, '[B': KEY_DOWN, 'OB': KEY_DOWN, '[5~': KEY_PPAGE,
                  '[6~': KEY_NPAGE, '[H': KEY_HOME, 'OH': KEY_HOME, '[1~': KEY_HOME, '[7~': KEY_HOME,
                  '[F': KEY_END, 'OF': KEY_END, '[4~': KEY_END, '[8~': KEY_END}
    WINDOWS_KEYS = {'H': KEY_UP, 'P': KEY_DOWN, 'I': KEY_PPAGE, 'Q': KEY_NPAGE, 'G': KEY_HOME, 'O': KEY_END}

    def __init__(self, rows):
        self.rows, self.active, self.at, self.cursor_on = rows, False, 0, True
        self.erase()
        self.cy = self.cx = 0

    def __enter__(self):
        self.start()
        return self

    def __exit__(self, *_):
        self.endwin()

    # terminal
    def start(self):
        self.h = max(3, min(self.rows, shutil.get_terminal_size().lines - 1))
        if os.name == 'nt':
            import ctypes  # VT sequences: Windows Terminal has them, conhost needs the flag
            kernel = ctypes.windll.kernel32
            handle, mode = kernel.GetStdHandle(-11), ctypes.c_uint()
            if kernel.GetConsoleMode(handle, ctypes.byref(mode)):
                kernel.SetConsoleMode(handle, mode.value | 4)
        else:
            import termios
            import tty
            self.fd = sys.stdin.fileno()
            self.saved = termios.tcgetattr(self.fd)
            tty.setcbreak(self.fd)  # keys one by one, no echo; Ctrl-C still interrupts
        # Room below the prompt: scrolls up when the prompt sits at the bottom.
        self.out('\n' * (self.h - 1) + f'\x1b[{self.h - 1}A\r' if self.h > 1 else '\r')
        self.at, self.active = 0, True

    def endwin(self):
        if not self.active:
            return
        self.out((f'\x1b[{self.at}A' if self.at else '') + '\r\x1b[J\x1b[?25h')
        if os.name != 'nt':
            import termios
            termios.tcsetattr(self.fd, termios.TCSADRAIN, self.saved)
        self.active = False

    def out(self, text):
        sys.stdout.write(text)
        sys.stdout.flush()

    # drawing
    def getmaxyx(self):
        return self.h if self.active else self.rows, shutil.get_terminal_size().columns

    def erase(self):
        self.buffer = [[] for _ in range(getattr(self, 'h', self.rows))]

    def addnstr(self, y, x, text, n, attr=0):
        if 0 <= y < len(self.buffer):
            row = [(t, a) for t, a in self.buffer[y]]
            length = sum(len(t) for t, _ in row)
            if x > length:
                row.append((' ' * (x - length), 0))
            self.buffer[y] = self.cut(row, x) + [(text[:max(0, n)], attr)]

    @staticmethod
    def cut(row, x):
        kept, length = [], 0
        for text, attr in row:
            if length >= x:
                break
            kept.append((text[:x - length], attr))
            length += len(kept[-1][0])
        return kept

    def move(self, y, x):
        self.cy, self.cx = y, x

    def clrtoeol(self):
        if 0 <= self.cy < len(self.buffer):
            self.buffer[self.cy] = self.cut(self.buffer[self.cy], self.cx)

    def refresh(self):
        if not self.active:
            self.start()
        parts = [f'\x1b[{self.at}A' if self.at else '', '\r']
        for y, row in enumerate(self.buffer[:self.h]):
            parts.append('\x1b[2K')
            for text, attr in row:
                codes = ';'.join(code for bit, code in self.SGR if attr & bit)
                parts.append(f'\x1b[{codes}m{text}\x1b[0m' if codes else text)
            if y < self.h - 1:
                parts.append('\r\n')
        cy = min(max(self.cy, 0), self.h - 1)
        if self.h - 1 > cy:
            parts.append(f'\x1b[{self.h - 1 - cy}A')
        parts.append('\r' + (f'\x1b[{self.cx}C' if self.cx else ''))
        parts.append('\x1b[?25h' if self.cursor_on else '\x1b[?25l')
        self.at = cy
        self.out(''.join(parts))

    # curses module look-alikes
    def curs_set(self, visible):
        self.cursor_on = bool(visible)

    def use_default_colors(self):
        pass

    def init_pair(self, *_):
        pass

    def color_pair(self, number):
        return {1: 8, 2: 16}.get(number, 0)

    # keys
    def get_wch(self):
        self.refresh()
        if os.name == 'nt':
            import msvcrt
            key = msvcrt.getwch()
            if key == '\x03':
                raise KeyboardInterrupt
            if key in ('\x00', '\xe0'):
                return self.WINDOWS_KEYS.get(msvcrt.getwch(), self.KEY_RESIZE)
            return self.KEY_BACKSPACE if key == '\b' else key
        key = self.char()
        if key == '\x1b':
            # An arrow arrives as ESC [ A in one go; a lone Esc has nothing after it.
            sequence = ''
            while len(sequence) < 6 and self.waiting(0.01 if sequence else 0.03):
                sequence += self.char()
                if len(sequence) > 1 and (sequence[-1].isalpha() or sequence[-1] == '~'):
                    break
            if not sequence:
                return key
            return self.POSIX_KEYS.get(sequence, self.KEY_RESIZE)
        return self.KEY_BACKSPACE if key in ('\x7f', '\b') else key

    def waiting(self, seconds):
        import select
        return bool(select.select([self.fd], [], [], seconds)[0])

    def char(self):
        first = os.read(self.fd, 1)
        if not first:
            raise KeyboardInterrupt  # input closed
        more = 3 if first[0] >= 0xF0 else 2 if first[0] >= 0xE0 else 1 if first[0] >= 0xC0 else 0
        return (first + (os.read(self.fd, more) if more else b'')).decode('utf-8', 'replace')


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
        header, texts = columns(self.entries)
        self.line(0, 0, header + (f'    /{self.query}' if self.query else ''), self.accent | self.c.A_BOLD)
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
    if argv == ['lm']:
        chosen = tui(entries, lazy=True)
        return connect(shlex.split(chosen.args), chosen.name) if chosen else 0
    if argv == ['list']:
        header, texts = columns(entries)
        print(header)
        for i, text in enumerate(texts, 1):
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
    try:
        sys.exit(main(sys.argv[1:]))
    except KeyboardInterrupt:
        # Ctrl-C in the list or a prompt just leaves, like q.
        sys.exit(130)
