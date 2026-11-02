# Powerlevel10k instant prompt. Keep it close to the top; anything that asks
# for input (passwords, y/n) must go above this block.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# The repo this file is linked from (help-dots reads HELP.md there).
export DOTFILES=${${(%):-%x}:A:h:h}

export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"

# tmux config lives outside oh-my-zsh, so omz updates can't overwrite it.
ZSH_TMUX_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/tmux/tmux.conf"

# zsh-syntax-highlighting goes last, as its README asks.
plugins=(
  git
  zsh-autosuggestions
  tmux
  zoxide
  fzf
  zsh-syntax-highlighting
)

source $ZSH/oh-my-zsh.sh

typeset -U path
path=("$HOME/.local/bin" $path)

# To customize the prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

source ~/.alias

# Keep the 1996 palette in one data file; do not overwrite it with /etc defaults.
if (( $+commands[dircolors] )) && [[ -r ~/.dir_colors ]]; then
  eval "$(dircolors -b ~/.dir_colors)"
fi
zstyle ':completion:*:default' list-colors "${(s.:.)LS_COLORS}"

# Put personal settings (PATH additions, tokens, ...) in ~/.zshrc.local.
# Loaded last so they can override the shared defaults without editing this file.
[[ ! -r ~/.zshrc.local ]] || source ~/.zshrc.local
