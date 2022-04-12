#!/bin/bash

red='tput setaf 1'
nc='tput setaf 7'

useConfirm=true
confirm() {
   [ "$useConfirm" = true ] && read -p "Proceed? (Enter) -  (^C to abort)C"
}

$red ; echo "Installing Tek's environment....."
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



$red ; echo "Copying settings" 
$nc 

confirm

current_time=$(date "+%Y.%m.%d-%H.%M.%S")
echo "Current Time : $current_time"

mkdir ~/.bak -v -p

file_org=~/.zshrc
file_new=.zshrc

[ -f $file_org  ] && mv -v $file_org $fileorg.$current_time
cp -v $file_new $file_org

file_org=~/.alias
file_new=.alias

[ -f $file_org  ] && mv -v $file_org $fileorg.$current_time
cp -v $file_new $file_org

file_org=~/.p10k.zsh
file_new=.p10k.zsh

[ -f $file_org  ] && mv -v $file_org $fileorg.$current_time
cp -v $file_new $file_org

file_org=~/.dir_colors
file_new=.dir_colors

[ -f $file_org  ] && mv -v $file_org $fileorg.$current_time
cp -v $file_new $file_org

file_org=~/.oh-my-zsh/plugins/tmux/tmux.only.conf
file_new=.oh-my-zsh/plugins/tmux/tmux.only.conf

[ -f $file_org  ] && mv -v $file_org $fileorg.$current_time
cp -v $file_new $file_org

