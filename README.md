# dotfiles-public — v0.4.2

My everyday shell setup for **Debian, WSL and Windows**: familiar shortcuts,
useful terminal tools, readable prompts, and a little history. I still prefer
zsh over fish, still use Ctrl-a in tmux, and my directory colours go back to 1996 :P

One installer per system. Choose what you want, review the plan, and apply it.
The shell configuration lives here; the Neovim configuration has its own repo:
[dotfiles-nvim](https://github.com/wjk22/dotfiles-nvim).

## What's new in 0.4.2

- **Simpler commands:** `./install.sh` on Linux, `.\install.ps1` on Windows.
  There is no extra `linux` or `windows` argument.
- **Editable Windows package lists:** choose your Chocolatey and Scoop packages
  in a local config file, without editing installer code.
- **Visible installs:** Linux commands, Scoop and Chocolatey show live output
  and keep logs. A Chocolatey failure is reported without stopping the remaining steps.
  Saying no to Chocolatey disables its optional apps too.
- **The old colours are back:** the original 1996 palette now lives in a readable
  `dircolors` file, with matching colours for newer archive, image and video formats.
- **Optional root and mail setup:** a private root-owned shell snapshot, and a
  Gruvbox-inspired NeoMutt layout using your existing Neovim composer.
- **A nicer `cat`:** `cat` and `bcat` use bat in zsh and PowerShell, with syntax
  highlighting and line numbers. Personal aliases and settings live outside the repo.

## Getting started

Clone the repo and run the installer as your normal user. On Debian, Git and
sudo must already be available; package installation uses sudo. On Windows,
Chocolatey uses one UAC prompt and can run under a separate administrator account.

### Debian 13+ / WSL

```sh
git clone https://github.com/wjk22/dotfiles-public.git
cd dotfiles-public
./install.sh
```

### Windows 10/11

Prefer a checkout on a Windows drive, for example `C:\dev\Workspace\dotfiles-public`.
This lets the installer link the PowerShell config with a directory junction.
A checkout inside WSL also works, but the config is copied instead; rerun the
installer to refresh that copy after changes.

```powershell
git clone https://github.com/wjk22/dotfiles-public.git
cd dotfiles-public
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

If your PowerShell execution policy already permits local scripts, just use
`.\install.ps1`.

Enter accepts each suggested answer. The final plan lets you toggle steps by
number, apply with `a`, or quit with `q`. On later runs, your previous choices
become the suggestions. `--yes` on Linux and `-Yes` on Windows accept those
suggestions and apply without asking; they do not mean "enable every step."
Use `./install.sh --help` or `.\install.ps1 -Help` for usage.

Two optional Linux modes are also available: `./install.sh root` for root's
shell and `./install.sh mail` for NeoMutt. The plain `./install.sh` still only
configures your normal account. Both optional modes need Python 3 (standard
library only) and show a preview before applying; `--yes` accepts the plan.

After installation, open a new zsh or **PowerShell 7** window and run
`help-dots` for the [command and keyboard cheat sheet](HELP.md).
In Windows Terminal, select **MesloLGS NF** as the font for the profiles you use.
The Windows installer installs the fonts but does not change Terminal settings.

## What gets installed

Both setups include lazygit, lazydocker, ripgrep, fzf, fd, bat, eza, zoxide,
btop, dust, gdu, duf and tealdeer. Windows package choices are configurable.

### Linux

The installer offers five steps: packages, Oh My Zsh and plugins, zsh as your
login shell, fonts, and dotfile links. Debian packages also include Neovim,
tmux, htop, Midnight Commander, inxi and networking tools. Lazydocker comes
from a pinned GitHub release with a checked checksum.

The shell uses **Oh My Zsh and Powerlevel10k**, autosuggestions, syntax
highlighting, fzf and zoxide. It links `.zshrc`, `.alias`, `.p10k.zsh`,
`.dir_colors` and `.config/tmux/tmux.conf` from this checkout into your home.
Keep the checkout where it is while those links are in use.

Install commands and their output stream to the terminal and the run's log,
including apt output, Git progress and download progress. Failures keep their
exit status and stop the Linux installer with the log location.

Tmux uses **Ctrl-a** as its prefix. `Ctrl-a v` / `Ctrl-a h` split panes;
`Ctrl-Space` zooms a pane. The clipboard configuration uses OSC 52 for terminals
that support it, including Windows Terminal.

Everyday listings (`ls`, `ll`, `lla`, `el`, `es`, `esa`) use eza with automatic
Nerd Font icons. Ordinary directories are white; special folders such as
Downloads, Documents, Pictures, `.aws` and `.docker` have the same softer colours
as the Windows Terminal-Icons theme. Archives are blue, executables red, images
magenta and links cyan. Writable WSL folders keep a plain background. Icons and
colours are automatic, so piped listings stay plain.

The readable theme is [`linux/.config/eza/theme.yml`](linux/.config/eza/theme.yml).
The shell points eza at this shared file; root uses the copy in its private
snapshot. The eza wrapper clears `LS_COLORS`/`EXA_COLORS` only for that command,
so the historical palette cannot override the theme. Personal `EZA_COLORS` or
`EZA_CONFIG_DIR` settings in `~/.zshrc.local` can override it. Eza's
[theme configuration](https://github.com/eza-community/eza/blob/v0.21.0/man/eza_colors-explanation.5.md)
is supported by Debian 13's eza 0.21; glyphs can differ slightly between versions.

`command ls --color=auto` still invokes GNU ls with the original 1996 palette:
blue directories, cyan links, green executables, red archives, magenta images and
white videos. GNU `dircolors -b` loads it from `~/.dir_colors`; zsh completion uses
it too. Modern extensions follow the original groups. If eza is unavailable,
the listing aliases fall back to GNU ls.

### The same shell for root

After the normal Linux setup, run this **as your normal user**, from a clean,
committed checkout:

```sh
./install.sh root
```

The privileged part needs sudo to inspect and write root's home and change root's
login shell. It shows the destination files before asking for `a` to apply.
It reuses the shell files and the existing installer's plugin, backup and link
steps. Root mode does not install packages or fonts: system Git and zsh must
already be installed; the normal setup supplies the other system tools.

Root's config links point into **`/root/.dotfiles/<commit>/`**, a root-owned
snapshot of allowlisted, committed regular files, never into your checkout.
Snapshots use private directories and files. Oh My Zsh, Powerlevel10k and the
plugins live separately under **`/root/.oh-my-zsh`**, cloned from the same
upstream repositories as the normal setup. Your personal plugins, aliases,
credentials and user-local executables are not copied into root's environment.

The receiver starts with a clean environment. It checks ownership, write
permissions and links in the root paths it uses, rejects links into user homes,
and keeps existing config backups under `/root/.dotfiles-backup/` and next to
the originals as timestamped `.bak` files. `/root/.zshrc.local` and
`/root/.alias.local` are retained and loaded last; these and any existing root
startup files must be root-owned and not writable by other users. Stale compiled
`.zwc` versions of managed configs must be moved aside before installation. As with any
root shell, root's own local overrides and the upstream plugin code are trusted
code: review them before adding commands that source other files.

Rerun `./install.sh root` after updating this repo to refresh root's snapshot and
plugins. Unchanged snapshots and config links are kept. A new log is written
under `/root/.local/state/dotfiles/logs/`; older snapshots remain for recovery.
Use `sudo -i` after installation to start root's new login shell. Root does not
need a separate font installation; the terminal renders both sessions.

### NeoMutt and the existing Neovim composer

```sh
./install.sh mail
neomutt
```

In zsh, `nmutt` is the short alias for `neomutt`, like `nvim` for Neovim.
Open a new shell or run `source ~/.alias` to load it.

The mail mode installs only the `neomutt` package if needed and creates a private
loader in `~/.config/neomutt/neomuttrc` (honouring `XDG_CONFIG_HOME`). It requires
an existing `nvim` executable and does not install or change your editor config.
The current `dotfiles-nvim` setup uses **NeoSolarized dark with a transparent
background**, Solarized lualine, two-space indentation and a Space leader.
The mail theme complements it with Gruvbox-inspired warm text and amber,
muted teal accents and a transparent background. It uses 256 colours and needs
no theme plugin, sync daemon, indexer or HTML renderer.

Presentation lives in [`linux/neomutt/`](linux/neomutt/): separate layout,
colours and key files. Threads are grouped with newest activity first, the pager
keeps a small index visible, and unread, flagged, deleted and quoted text have
distinct highlighting. Standard Mutt navigation/reply/send/delete keys remain;
`F2` toggles the sidebar, `F3`/`F4` select a mailbox, and `F5` opens it. The sidebar
uses the mailboxes you declare in your private account config.

Composing runs your existing `nvim` with mail filetype, wrapping and a 72-column
text width for that buffer. It does not use `-u`, another Neovim setup or another
editor theme. Your Neovim mappings and personal overrides continue to apply.

The installation creates three **private files outside Git**:

| File in `~/.config/neomutt/` | Purpose |
|---|---|
| `accounts.local` | Accounts, mailboxes, transport and credential-helper settings |
| `aliases.local` | Saved address aliases |
| `settings.local` | Personal settings and key overrides, loaded last |

Start with [`accounts.example`](linux/neomutt/accounts.example); its account
details are commented placeholders. Configure your own account before reading or
sending mail. NeoMutt can prompt for passwords, so storing passwords is optional.
The installer creates private files with mode `0600` and a `0700` directory;
it does not overwrite existing private files. These filenames are also ignored
by Git as a precaution, but keep actual accounts and secrets outside the repo.

When an existing Mutt/NeoMutt config is found in a standard location, the loader
sources it after the shared presentation so accounts, handling and shortcuts
take precedence. A replaced loader gets both a neighbouring `.bak` and a copy
under `~/.dotfiles-backup/neomutt-<timestamp>/`. Existing config contents are
neither printed nor executed during installation. Custom `-F` locations and
version-suffixed configs must be sourced explicitly from `accounts.local` or
`settings.local`; a version-suffixed NeoMutt config can take precedence over the
new unversioned loader. Reruns leave unchanged files alone.

This setup has no preconfigured account, OAuth provider or mail-sync service.
Account-specific setup remains private. Appearance and syntax can be checked
without contacting mail servers:

```sh
neomutt -n -F ./linux/neomutt/neomuttrc -Q editor -Q use_threads
```

See NeoMutt's [configuration guide](https://neomutt.org/guide/configuration) and
[sidebar guide](https://neomutt.org/feature/sidebar) for the underlying options.

### Windows

The six selectable steps are:

1. **Chocolatey system packages:** PowerShell 7, Everything and Total Commander
   by default, plus the PSWindowsUpdate module for all users.
2. **Optional Chocolatey apps:** Ditto, ImageGlass, Chrome, Firefox, PotPlayer,
   System Informer, VS Code, VLC, Python and Seafile by default.
3. **Scoop tools:** the shared terminal tools, Git, Neovim, gsudo, Oh My Posh
   and Wox, installed for the current user.
4. **PowerShell modules:** PSReadLine, Terminal-Icons and PSFzf. This step needs
   PowerShell 7.4 or newer.
5. **MesloLGS NF fonts:** installed for the current user.
6. **PowerShell config:** the config folder, a small `$PROFILE` bootstrap,
   and the `DOTFILES` environment variable used by `help-dots`.

The prompt uses **Oh My Posh with the Takuya theme**: path, Git status, time
and command status. It is a similar two-line setup to Linux, with its own theme.
PSReadLine uses vi mode and history suggestions; `Ctrl+r` searches history and
`Ctrl+f` selects files through fzf. Installing Oh My Posh alone does not activate
the prompt: the PowerShell config step connects it to your profile.

Scoop output appears in the main terminal; Chocolatey output appears in its
elevated window. Both are logged. If Chocolatey fails or elevation is cancelled,
the installer continues and finishes with warnings. If PowerShell itself is
missing or too old, the dependent steps are skipped and reported. Other failures
still stop their run; the installer does not claim that failed work succeeded.

OpenVPN and NetLimiter are not included in the package lists.
`windows\install-admin.ps1` can also run directly from an elevated shell;
add `-Apps` to include the optional Chocolatey group.

## Choose your Windows packages

The defaults are in [`windows/packages.psd1`](windows/packages.psd1). Copy that
file to **`windows/packages.local.psd1`**, then add or remove quoted package IDs,
one per line, in these groups:

| Group | Used by |
|---|---|
| `ChocolateySystem` | The main Chocolatey step |
| `ChocolateyApps` | The optional apps step |
| `Scoop` | The per-user Scoop step; package IDs from the main/extras buckets |

The local file replaces all three lists; it is not merged with the defaults.
It is ignored by Git, so personal choices do not trip the installer's
clean-checkout check. The main installer and elevated helper use the same file.
Delete the local file to return to the shared defaults.

Use `@()` for an empty group. Removing a package stops this installer from
installing or updating it; it does **not** uninstall an existing application.
Fonts and PowerShell modules are configured by their separate installer steps;
PSWindowsUpdate remains part of the Chocolatey step.

## Personal settings and everyday commands

Keep machine-specific settings in these files, loaded after the shared defaults:

| System | File | Purpose |
|---|---|---|
| Linux / WSL | `~/.zshrc.local` | Shell settings and PATH additions |
| Linux / WSL | `~/.alias.local` | Personal aliases; `eall` edits and reloads them |
| Windows | `~\.config\powershell.local.ps1` | Personal PowerShell settings and aliases |

Existing custom lines are not automatically merged into the new shared config.
The installer points out file names and line numbers to review and preserves
the originals in backups. Move the settings you still want into the local files.
On Linux, `eal` edits the shared aliases; use `eall` for your own additions.

A few favourites:

- `cat file` or `bcat file`: bat, called `batcat` on Debian. For the original
  reader, use `command cat` on Linux or `Get-Content` in PowerShell.
- `ls`, `ll`, `lla`, `el`, `es`, `esa`: eza listings with icons; `z project` / `zi project`: jump with zoxide.
- `v` / `vim`: Neovim. This repo installs the program and aliases, not its config.
- `help-dots`: the full cheat sheet. `q` closes the viewer.
- Windows: `gsudo command` elevates one command; `tc` opens Total Commander,
  preferring TC Ultima Prime when installed.

The separate [Neovim setup](https://github.com/wjk22/dotfiles-nvim) has its own
requirements and installers. Installing the distro's `nvim` package here does
not guarantee that it meets that configuration's required version.

## Updates, backups and logs

Pull the repo and rerun the same installer. The scripts require a clean checkout;
keep personal edits in the local files above. Linked shell files reflect repo
changes in new shells; copied Windows configs need another installer run.

Before replacing existing shell configs, the installers preserve timestamped
`.bak` paths and keep regular config files/folders under
`~/.dotfiles-backup/<timestamp>/`. Windows renames an existing link to `.bak`
without touching its target. Backup paths are never overwritten, and redirected
parent paths are checked before config changes.

Each applied run has a log, and the final summary prints its location:

- Linux: `~/.local/state/dotfiles/logs/`, or `$XDG_STATE_HOME/dotfiles/logs/` when set.
- Windows: `%LOCALAPPDATA%\dotfiles\logs\`.

The ten newest installer logs are retained. Failed downloads or packages remain
visible in the logs even when the rest of a Windows run completes.

Developer checks: `bash -n install.sh` and
`PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests -v`.
Root integration tests require bubblewrap and user namespaces and mount a
disposable `/root`; they must never be replaced with a live root install.
Mail tests require NeoMutt (or `NEOMUTT_TEST_BINARY` pointing to a test binary).

## A little history

- **0.4.2:** configurable Windows packages, simpler installer commands, live
  package output, Chocolatey failure isolation, the 1996 palette, bat aliases,
  isolated root shell installation and optional NeoMutt presentation.
- **0.3:** guided installers, modern terminal tools and `help-dots`; Neovim moved
  to its own repository, and Node was removed from the base setup.
- **0.25:** Windows scripts, fzf and PowerShell line editing.
- **0.22:** the first Linux client installer.
- **0.2 / 0.14 / 0.1:** Linux server notes, zsh dotfiles, and the beginning.

I also use Bitwarden, Seafile and a private Git server for my own setup.
[Total Commander Ultima Prime](https://www.tcup.pl/index.php/en/) remains a
personal favourite; see [Total Commander](https://www.ghisler.com/) for licensing.
More favourites live in my [awesome-list](https://github.com/wjk22/awesome-list).
Mac: no installer here — I stopped using it :P

Inspired to publish my version by [Craftzdog](https://github.com/craftzdog/dotfiles-public).

---

... follow the white rabbit, there is no spoon, and may the force be with you ...

Wojciech Kalka <wojciech.kalka@skynet-services.net>
