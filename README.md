# public dotfiles ..

Just my own setup for Windows and Linux as my work environment etc

Btw I use bitwarden/duo/2fa for nearly all my logins and store my own data encrypted
at my own seafile server or my own gogs/gitea server.

Latest Updates<br>
v0.3 One guided installer per system (`./install.sh linux`, `.\install.ps1 windows`), modern tools, `help-dots` cheat sheet. Neovim moved to [dotfiles-nvim](https://github.com/wjk22/dotfiles-nvim), Node is gone <br>
v0.25 Added some basic windows scripts and more features like fzf, readline for windows etc <br>
v0.22 Added a rudimentary linux client install script run cd linux, run bash install.sh <br>
v0.2 Added Linux Server information<br>
0.14 Added Linux Zsh dotfiles<br>
0.1 Started this project<br>

## Install

One command after `git clone`. It checks the machine first, asks a few questions with a
suggested answer (Enter takes it), shows you the whole plan and only does something when
you say `a`. Run it again any time to update: it shows what's new in the checkout, suggests
your last answers and changes only what differs. Anything it replaces is kept twice first:
next to itself as `<file>.<timestamp>.bak` and in `~/.dotfiles-backup/<timestamp>/` (private
to you, never overwritten). Every run has its own log. It never prints what's inside your
configs: for lines it won't carry over it shows only the file and the line numbers.

```
./install.sh linux                                              # Debian 13+, also in WSL
powershell -ExecutionPolicy Bypass -File .\install.ps1 windows  # Windows 10/11
```

Then open a new shell and type `help-dots`: the cheat sheet for all of it ([HELP.md](HELP.md)).

What you get on both systems: lazygit, lazydocker, ripgrep, fzf, fd, bat, eza, zoxide, btop,
dust, gdu, duf, tealdeer (and inxi on Linux).

## Windows

0. Setup two users user/admin admin password protected, work only as normal user.

1. Clone this repo on the Windows side (e.g. `C:\Users\you\src`), not inside WSL: the
   PowerShell config is linked with a junction, and junctions can't point into `\\wsl$\`.

2. Run `.\install.ps1 windows` as your normal user. It does:
   - [Chocolatey](https://chocolatey.org/) for the system installs, with one UAC prompt (your admin account):
     PowerShell 7, Everything, Total Commander, PSWindowsUpdate, and if you want the apps:
     ditto imageglass googlechrome firefox potplayer systeminformer vscode vlc python3 seafile-client
     Answering no to Chocolatey skips all its installs and the optional-apps question.
   - [scoop](https://scoop.sh/) for everything that works per user: git, neovim, gsudo,
     [oh-my-posh](https://ohmyposh.dev/), wox and the tools above
   - PSReadLine, [Terminal Icons](https://github.com/devblackops/Terminal-Icons) and PSFzf for PowerShell 7
   - the MesloLGS NF fonts, per user
   - `%USERPROFILE%\.config\powershell` as a junction to this repo, and `$PROFILE` as a two-line bootstrap

   `windows\install-admin.ps1` is the Chocolatey part on its own, if you want to run it from an elevated shell.

   Package lists live in [`windows/packages.psd1`](windows/packages.psd1).
   For your own choices, copy it to `windows/packages.local.psd1` and edit that copy:
   add or remove package IDs in `ChocolateySystem`, `ChocolateyApps`, and `Scoop`.
   The local file replaces all three default lists and is ignored by Git, so the
   installer's clean-checkout check still passes. Both installers read the same file.
   Use `@()` for an empty group. Removing an entry stops installing/updating it;
   it does not uninstall an existing app. Scoop IDs come from the main/extras buckets.
   PowerShell modules and fonts remain separate installer steps.

3. Install Total Commander Ultima Prime from https://www.tcup.pl/index.php/en/, buy a license from https://www.ghisler.com/ (
This is imho the best file commander ever invented, please prove me wrong..) The `tc` alias takes TCUP if it's there.

4. Buy a Netlimiter license - https://www.netlimiter.com/

5. Use Windows Terminal, set **MesloLGS NF** as the font. Work as user, elevate with gsudo.

6. Install WSL with Debian: `wsl --install -d Debian` (https://learn.microsoft.com/windows/wsl/install), then follow the Linux part inside it.

7. Use Seafile if you use a seafile server, highly recommended. I keep all
my data in my own cloud encrypted and on a backup drive.

8. Install Bitwarden for Chrome/Firefox/Windows and connect it to your own server.

9. Install Duo Security as dual factor login for your windows/remote desktops, bitwarden server etc pp. It is free for a 10 user or less environment.

## Linux (Debian, also in WSL2)

// I am old school I prefer zsh over fish ..

1. `git clone https://github.com/wjk22/dotfiles-public.git && cd dotfiles-public && ./install.sh linux`
   - the packages: zsh, tmux, git, curl, neovim, htop, mc, mtr-tiny, tcpdump, iptraf-ng, dnsutils, rsync, sl and the tools above from apt; lazydocker from its GitHub release, checksum checked
   - [Oh my ZSH](https://ohmyz.sh) with [zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions),
     [zsh-syntax-highlighting](https://github.com/zsh-users/zsh-syntax-highlighting) and [P10K](https://github.com/romkatv/powerlevel10k)
   - zsh as login shell, the MesloLGS NF fonts (not needed in WSL, Windows Terminal uses the Windows fonts)
   - `.zshrc`, `.alias`, `.p10k.zsh`, `.dir_colors` and the tmux config linked from `linux/`

2. Your own machine-only stuff goes into `~/.zshrc.local` (shell settings, PATH, tokens)
   and `~/.alias.local` (aliases). The main files load these last, so your settings override
   the shared defaults; you only need to change the local files. `eall` edits `~/.alias.local`
   and reloads aliases; `eal` still edits the shared `~/.alias`. If your current
   `~/.zshrc` has such lines, move them there before the first run; the old file lands in the backup anyway.

3. [zoxide](https://github.com/ajeetdsouza/zoxide) - `z` directory jumper, same on Windows. An old `~/.z` from zsh-z is imported once.

4. My tmux uses the old screen binding Ctrl-a, config in `~/.config/tmux/tmux.conf`

5. Neovim: this repo installs only the `nvim` program and the `v`/`vim` aliases; the config lives in https://github.com/wjk22/dotfiles-nvim and is never touched here

6. Install vscode from https://code.visualstudio.com/download

## Mac

hehe stopped using a mac two years ago :P

## Stuff to try

`help-dots` shows all of it, here the favourites:

eall opens your local aliases in vim and rereads aliases; eal edits the shared aliases

#### Windows
Alt-space opens wox

#### Linux
Ctrl-r in zsh searches in your history

### Links

Have a look at my awesome-list (https://github.com/wjk22/awesome-list) and you can see what kind of
stuff I recommend

Inspired to publish my version by Craftzdog https://github.com/craftzdog/dotfiles-public#readme

---
... follow the white rabbit, no there is no spoon and may the force be with you .. <br>
Wojciech Kalka <wojciech.kalka@skynet-services.net>
