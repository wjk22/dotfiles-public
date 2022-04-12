#!/bin/bash

red='tput setaf 1'
nc='tput setaf 7'

$red ; echo "Installing Tek's environment....."
$nc

#Install OH MY ZSH
echo "Installing OH MY ZSH"
sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"


sleep 1 
$red ; echo "Installing OH MY ZSH Plugins"
$nc

#Install plugins
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions

sleep 1

git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting

$red ; echo "Installing P10K"
$nc

#Install theme
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k

sleep 1


useConfirm=true

confirm() {
   [ "$useConfirm" = true ] && read -p "$Proceed? (Enter) -  (^C to abort)C"
}

$red ; echo "Copying settings" 
$nc 

confirm

current_time=$(date "+%Y.%m.%d-%H.%M.%S")
echo "Current Time : $current_time"

mkdir ~/.bak -v

[ -f ~/.zshrc ] && mv -v ~/.zshrc ~/.bak/zshrc.$current_time
cp -v .zshrc ~/.zshrc

[ -f ~/.alias ] && mv -v ~/.alias ~/.bak/alias.$current_time
cp -v .alias ~/.alias

[ -f ~/.p1-k] && mv -v ~/.p10k.zsh ~/.bak/p10k.zsh.$current_time
cp -v .p10k.zsh ~/.p10k.zsh

[ -f ~/.dir_colors ] && mv -v ~/.alias ~/.bak/dir_colors.$current_time
cp -v .dir_colors ~/.dir_colors

#[ -f ~/.dir_colors ] && mv -v ~/.alias ~/.bak/dir_colors.$current_time
#cp -v .dir_colors ~/.dir_colors
