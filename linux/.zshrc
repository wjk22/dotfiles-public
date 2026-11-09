# A root login must not inherit a user's plugin/cache paths or executables.
if (( EUID == 0 )); then
  export HOME=/root
  export XDG_CONFIG_HOME=/root/.config XDG_CACHE_HOME=/root/.cache
  export XDG_DATA_HOME=/root/.local/share XDG_STATE_HOME=/root/.local/state
  unset ZSH_CUSTOM ZSH_CACHE_DIR ZSH_COMPDUMP ZDOTDIR EZA_CONFIG_DIR EZA_COLORS EXA_COLORS
  # Debian system functions only; do not inherit a normal user's FPATH.
  # Recursive: the completions live one level deeper (functions/Completion/Unix, ...).
  fpath=(/usr/local/share/zsh/site-functions /usr/share/zsh/vendor-functions
         /usr/share/zsh/vendor-completions /usr/share/zsh/functions/**/*(N/))
  path=(/root/.local/bin /usr/local/sbin /usr/local/bin /usr/sbin /usr/bin /sbin /bin)
fi

# Powerlevel10k instant prompt. Keep it close to the top; anything that asks
# for input (passwords, y/n) must go above this block.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# macOS: Homebrew on Apple silicon lives outside the default PATH; the plugins
# below need its tools (fzf, zoxide). Intel's /usr/local/bin is already there.
if [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
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
# On macOS, GNU dircolors comes from Homebrew's coreutils as gdircolors.
for _dircolors in dircolors gdircolors; do
  if (( $+commands[$_dircolors] )) && [[ -r ~/.dir_colors ]]; then
    eval "$($_dircolors -b ~/.dir_colors)"
    break
  fi
done
unset _dircolors
zstyle ':completion:*:default' list-colors "${(s.:.)LS_COLORS}"

# Put personal settings (PATH additions, tokens, ...) in ~/.zshrc.local.
# Loaded last so they can override the shared defaults without editing this file.
[[ ! -r ~/.zshrc.local ]] || source ~/.zshrc.local
