#!/bin/bash

echo "Installing Tek's environment....."

#Install OH MY ZSH
echo "Installing OH MY ZSH"
sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

sleep 1 
echo "Installing OH MY ZSH Plugins"

#Install plugins
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions

sleep 1

git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting

echo "Installing P10K"

#Install theme
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k

sleep 1


useConfirm=true

confirm() {
   [ "$useConfirm" = true ] && read -p "Proceed? (Enter) - (^C to abort)"
}

echo "Copying settings" 
confirm

current_time=$(date "+%Y.%m.%d-%H.%M.%S")
echo "Current Time : $current_time"

mv -v ~/.zshrc ~/zshrc.$current_time
cp -v .zshrc ~/.zshrc
mv -v ~/.alias ~/.alias.$current_time
cp -v .alias ~/.alias
mv -v ~/.p10k.zsh ~/.p10k.zsh.$current_time
cp -v .p10k.zsh ~/.p10k.zsh
