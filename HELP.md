# help-dots

The cheat sheet for this setup. `help-dots` shows it in the terminal (zsh and
PowerShell); `q` closes it.

## Tools (Linux and Windows)

| Tool | What it's for | The keys that matter |
|---|---|---|
| **lazygit** | git in a terminal UI | `space` stage, `c` commit, `P` push / `p` pull, `?` all keys |
| **lazydocker** | containers, logs and stats in one screen | `[` / `]` switch tabs (logs, stats), `x` actions menu, `q` quit |
| **ripgrep** | search file contents, fast | `rg word`, `rg -i word` (any case), `rg -l word` (file names only) |
| **fzf** | fuzzy finder | zsh: `Ctrl-r` history, `Ctrl-t` insert a file, `Alt-c` cd into a folder; PowerShell: `Ctrl+r` history, `Ctrl+f` file |
| **fd** | find files by name | `fd name`, `fd -e md` (by extension), `fd -H name` (hidden files too) |
| **bat** | cat with colours and line numbers | `bat file`, `bat -p file` (plain), `bat -l json` (pick a language) |
| **eza** | ls with colours, git status, icons | `el` long, `esa` long with hidden, `eza --tree -L 2` |
| **zoxide** | jump to folders you've used | `z proj` jumps to the best match, `zi proj` picks from a list, `z -` back |
| **btop** | processes, CPU, memory, disks, network | `f` filter, `k` kill the selected process, `q` quit |
| **dust** | quick overview: what's taking the space | `dust`, `dust -d 2` (two levels), `dust ~/Downloads` |
| **gdu** | interactive cleanup of a disk or folder | `gdu ~`, then `d` delete, `s` / `n` sort by size / name, `q` quit |
| **duf** | free space on all drives | `duf`, `duf --only local` |
| **tealdeer** | short examples for any command | `tldr tar`, `tldr --update` (refresh the pages) |
| **inxi** (Linux) | what's in this machine | `inxi -b` (basic), `inxi -Fxz` (everything, private data hidden) |

On Debian, `bat` and `fd` are `batcat` and `fdfind`; the aliases make both names work.

## zsh (Linux)

- **Prompt:** powerlevel10k. `p10k configure` builds a new one.
- **Autosuggestions:** grey text after the cursor comes from your history; `→` accepts it.
- **Local settings:** `~/.zshrc.local` and `~/.alias.local` are loaded if they exist and never go into the repo. Put PATH additions, tokens and machine-only aliases there.
- **Aliases**

  | Alias | Does |
  |---|---|
  | `eal` | edit `~/.alias` and reload it |
  | `el` `es` `esa` | eza long / short / long with hidden |
  | `ll` `lla` `lt` | ls -l / all / folder sizes sorted |
  | `v` `vi` `vim` `evi` | nvim / edit the nvim config |
  | `g` `c` `h` `hh` | git / clear / history / last 10 |
  | `..` `...` | up one / two folders |
  | `cpv` | copy with a progress bar (rsync) |
  | `ports` | listening ports and connections (ss) |
  | `help-dots` | this page |

## tmux (Linux)

The prefix is `Ctrl-a`; press it, let go, then the key.

| Keys | Does |
|---|---|
| `Ctrl-a v` / `Ctrl-a h` | split side by side / one above the other |
| `Alt-←` / `Alt-→` | previous / next window |
| `Ctrl-Space` | zoom the current pane in and out (no prefix) |
| `Ctrl-a k` | kill the window |
| `Ctrl-a [` then `v`, `y` | copy mode: select, copy (also to the system clipboard) |
| `Ctrl-a r` | reload the config |

oh-my-zsh's tmux plugin adds `ta` (attach), `ts` (new session), `tl` (list) and `tksv` (kill server).

## PowerShell (Windows)

- **Prompt:** oh-my-posh with the takuya theme (`~\.config\powershell\takuya.omp.json`).
- **Editing:** PSReadLine in **vi mode**: `Esc` for normal mode, `i` to insert. Grey predictions come from your history; `→` accepts them.
- **Local settings:** `~\.config\powershell.local.ps1` is loaded if it exists and never goes into the repo.
- **Aliases and functions**

  | Name | Does |
  |---|---|
  | `eal` / `epro` | edit the aliases / the profile |
  | `. repo` | reload the profile |
  | `el` `es` `esa` | eza long / short / long with hidden |
  | `v` `vim` | nvim |
  | `tc` | Total Commander |
  | `which name` | where a command lives |
  | `..` | up one folder |
  | `gsudo command` | run one command elevated |
  | `help-dots` | this page |

- **Wox:** `Alt-Space` opens the launcher.
- **Everything:** finds any file by name, instantly.

## Updating

Pull the repo and run the installer again: `./install.sh linux` or
`.\install.ps1 windows`. It shows what's new, asks with your last answers as
suggestions, and changes only what differs.
