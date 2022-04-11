# public dotfiles .. 
Just my own setup for Windows and Linux as my work environment etc


## Windows

0. Setup two users user/admin admin password protected, work only as normal user.  

1. Install [Chocolatey](https://chocolatey.org/) - Windows App Installer and some basic apps <br>
` choco install totalcommander powershell-core ditto imageglass everything git googlechrome firefox openvpn potplayer processhacker gsudo vscode vim wox wlc python3`

2. Install Total Commander Ultima Prime from https://www.tcup.pl/index.php/en/, buy a license from https://www.ghisler.com/ (
This is imho the best file commander ever invented, please prove me wrong..)

3. Install Netlimiter and buy a license - https://www.netlimiter.com/

4. Install Windows Terminal or Windows Terminal Preview.

5. Download and install these Fonts
   - [MesloLGS NF Regular.ttf](
       https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Regular.ttf)
   - [MesloLGS NF Bold.ttf](
       https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Bold.ttf)
   - [MesloLGS NF Italic.ttf](
       https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Italic.ttf)
   - [MesloLGS NF Bold Italic.ttf](
       https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Bold%20Italic.ttf)

6. Install [Oh My Posh](https://ohmyposh.dev/) - Prompt Engine

7. Install [Terminal Icons](https://github.com/devblackops/Terminal-Icons) - Folder and File Icons

8. Install scoop a command line user installer
`Invoke-Expression (New-Object System.Net.WebClient).DownloadString('https://get.scoop.sh')`
`scoop install curl` 

9. Install z for Windows Powershell 
`Install-Module -Name z`

9. Install WSL -> https://docs.microsoft.com/en-us/windows/wsl/install

10. Install Debian from the Microsoft Store ..and change WSL to Version II

## Linux (Debian in WSL2)

// I am old school I prefer zsh over fish .. 

0. Install zsh, tmux, htop, vim, mtr-tiny, curl, iptraf,git, tcpdump, mc // I use Debian so apt install ....

1. Install [Oh my ZSH](https://ohmyz.sh),[ZSH-Autosuggestion](https://github.com/zsh-users/zsh-autosuggestions),  enable plugins<br>

`.sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"` <br>
`git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions` <br>
`git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting`


2. Install P10K from https://github.com/romkatv/powerlevel10k
`git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k` <br>

3. [z for zsh](https://github.com/agkozak/zsh-z) - Z Directory jumper for ZSH

4. Setup my tmux, I use old screen bindings Ctrl-a

5. Install vscode from https://code.visualstudio.com/download

6. Install NodeJS
`sudo curl -sL https://deb.nodesource.com/setup_17.x | sudo bash -` 

7. 
 
## Mac 
 
hehe stopped using a mac two years ago :P 

## Stuff to try

eal opens aliases in vim and rereads aliases

#### Windows
Alt-space opens wox

#### Linux
Crlt-r in zsh searches in your history

### Links
Inspired to publish my version by Craftzdog
https://github.com/craftzdog/dotfiles-public#readme

---
... follow the white rabbit, no there is no spoon and may the force be with you .. 
Wojciech Kalka <wojciech.kalka@skynet-services.net>
