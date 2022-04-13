#!/bin/bash

red='tput setaf 1'
nc='tput setaf 7'

useConfirm=true

current_time=$(date "+%Y.%m.%d-%H.%M.%S")
echo "Current Time : $current_time"

confirm() {
     	[ "$useConfirm" = true ] && read -p "Proceed? (Enter) -  (^C to abort)"
}

copyfile () {
	echo "Updating $1 with $2"
	[ -f $1  ] && mv -v $1 $1.$current_time
	cp -v $2 $1 
}
$red ; echo "Installing Tek's environment....."
$nc
echo "Please make sure you did sudo apt install tmux zsh git curl"
echo "And type exit after Oh-my-zsh installs"
$nc

confirm

#Install OH MY ZSH
echo "Installing OH MY ZSH"
sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

sleep 2 
$nc

#Install plugins
$red
echo "Installing some oh-my-zsh plugins"
$nc 

git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
sleep 2
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
sleep 2
git clone https://github.com/agkozak/zsh-z ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-z

$red ; echo "Installing P10K"
$nc

#Install theme
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k

sleep 1
$red ; echo "Installing MesloLGS Font"

mkdir -v -p ~/.local/share/fonts
cd ~/.local/share.fonts
wget https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Regular.ttf
wget https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Bold%20Italic.ttf
wget https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Italic.ttf
wget https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Bold.ttf
ls  -l
fc-cache-f

$red ; echo "Copying settings" 
$nc 

confirm

#mkdir ~/.bak -v -p

file_org=~/.zshrc
file_new=.zshrc

copyfile $file_org $file_new

file_org=~/.alias
file_new=.alias

copyfile $file_org $file_new

file_org=~/.p10k.zsh
file_new=.p10k.zsh

copyfile $file_org $file_new

file_org=~/.dir_colors
file_new=.dir_colors

copyfile $file_org $file_new

file_org=~/.oh-my-zsh/plugins/tmux/tmux.only.conf
file_new=.oh-my-zsh/plugins/tmux/tmux.only.conf

copyfile -v $file_new $file_org


