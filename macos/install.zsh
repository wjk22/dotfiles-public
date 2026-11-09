#!/bin/zsh
# Install or update the dotfiles on macOS. ./install.sh hands over to this on a
# Mac: macOS still ships bash 3.2, too old for the Linux installer, and every
# Mac has zsh. Safe to run again: it asks first, changes only what differs and
# backs up what it replaces.
#   ./install.sh [mail] [--yes] [--sudo]
emulate -R zsh
setopt err_exit no_unset pipe_fail
zmodload zsh/datetime

repo=${0:A:h:h}
started=$EPOCHSECONDS

usage() {
    cat <<'EOF'
Usage: ./install.sh [mail] [--yes] [--sudo]

  macOS 13 or newer: Homebrew, the same tools as on Linux, Ghostty,
  oh-my-zsh, p10k, tmux, fonts, NeoMutt and the dotfiles from linux/.

  mail      install the NeoMutt presentation config for your user

  --yes     accept every suggested answer and apply without asking
  --sudo    allow sudo, needed once to install Homebrew itself;
            without it, only per-user setup runs (no sudo prompts)
EOF
}

assume_yes=no; mode=user; allow_sudo=no
for arg in "$@"; do
    case $arg in
        --yes|-y) assume_yes=yes ;;
        --sudo) allow_sudo=yes ;;
        --no-sudo) allow_sudo=no ;;
        mail) [[ $mode == user ]] || { usage >&2; exit 2 }; mode=mail ;;
        root) print -u2 'Root setup is Linux only; on a Mac, root keeps the system shell.'; exit 2 ;;
        -h|--help) usage; exit 0 ;;
        *) usage >&2; exit 2 ;;
    esac
done

# Homebrew lives in /opt/homebrew on Apple silicon, /usr/local on Intel.
brew_bin=''
find_brew() {
    local candidate
    for candidate in /opt/homebrew/bin/brew /usr/local/bin/brew; do
        if [[ -x $candidate ]]; then brew_bin=$candidate; return 0; fi
    done
    return 0
}
find_brew
if [[ -n $brew_bin ]]; then eval "$("$brew_bin" shellenv)"; fi

if [[ $mode == mail ]]; then
    if (( ! $+commands[neomutt] )) && [[ -n $brew_bin ]]; then brew install neomutt; fi
    exec /usr/bin/python3 "$repo/tools/install-mail.py" "$assume_yes" no-packages
fi

# ---------------------------------------------------------------- output ---
ok='OK'; failed='FAIL'; arrow='->'; green=''; red=''; bold=''; reset=''
title='dotfiles - install macos'
if [[ -t 1 ]]; then
    if [[ $(locale charmap 2>/dev/null || true) == UTF-8 ]]; then
        ok='✓'; failed='✗'; arrow='→'; title='🐇 dotfiles · install macos'
    fi
    if (( ! ${+NO_COLOR} )); then
        green=$'\e[32m'; red=$'\e[31m'; bold=$'\e[1m'; reset=$'\e[0m'
    fi
fi

die() { printf '  %s%s%s %s\n' "$red" "$failed" "$reset" "$1" >&2; exit 1 }
check_ok() { printf '  %s%s%s %-12s %s\n' "$green" "$ok" "$reset" "$1" "$2" }
check_warn() { printf '  %s!%s %-12s %s\n' "$red" "$reset" "$1" "$2" }
duration() {
    if (( $1 >= 60 )); then printf '%dm %ds' $(( $1 / 60 )) $(( $1 % 60 )); else printf '%ds' $1; fi
}

# ---------------------------------------------------------------- checks ---
# Nothing is written before these pass, not even the log.
printf '\n%s%s%s\n\n' "$bold" "$title" "$reset"

[[ $(uname -s) == Darwin ]] || die 'This is not macOS; run ./install.sh on Linux or .\install.ps1 on Windows.'
os_version=$(sw_vers -productVersion)
# Ghostty needs Ventura (13) or newer.
(( ${os_version%%.*} >= 13 )) || die "macOS $os_version is too old; Ghostty needs macOS 13 or newer."
check_ok System "macOS $os_version ($(uname -m))"

locale_name=${LC_ALL:-${LC_CTYPE:-${LANG:-POSIX}}}
locale_warning=''
if [[ $(locale charmap 2>/dev/null || true) == UTF-8 ]]; then
    check_ok Locale "$locale_name"
else
    locale_warning="The locale ($locale_name) is not UTF-8: btop won't start and glyphs break. Add export LANG=en_US.UTF-8 to ~/.zshrc.local."
    check_warn Locale "$locale_name is not UTF-8 (see the end)"
fi

(( EUID != 0 )) || die 'Run this as your normal user.'
# /usr/bin/git is only a stub until the Command Line Tools are installed.
xcode-select -p >/dev/null 2>&1 || die 'The Command Line Tools are missing; run xcode-select --install, then this again.'
check_ok User "$USER, Command Line Tools present (sudo is optional)"

dirty=$(git -C "$repo" status --porcelain 2>/dev/null) || die "$repo is not a git checkout; clone the repo and run it from there."
new_commit=$(git -C "$repo" rev-parse HEAD)
if [[ -n $dirty ]]; then check_ok Repo "${new_commit:0:7} with local changes; installing current checkout files"
else check_ok Repo "clean at ${new_commit:0:7}"; fi

if [[ -n $brew_bin ]]; then check_ok Homebrew "${brew_bin:h:h}"
else check_warn Homebrew 'not installed yet; step 1 installs it with --sudo'; fi

# Backups go to ~/.dotfiles-backup (private, 0700); never through a link.
if [[ -L $HOME/.dotfiles-backup ]] || { [[ -e $HOME/.dotfiles-backup ]] && [[ ! -d $HOME/.dotfiles-backup ]] }; then
    die '~/.dotfiles-backup is a symlink or not a folder; move it away first, backups never go through a link.'
fi

free_kb=$(df -Pk "$HOME" | awk 'NR==2 {print $4}')
(( ${free_kb:-0} >= 3000000 )) || die "Only $(( ${free_kb:-0} / 1000 )) MB free in $HOME; Homebrew and the tools need at least 3 GB."
check_ok Disk "$(awk -v k="$free_kb" 'BEGIN {printf "%.1f GB free", k*1024/1e9}')"

# ----------------------------------------------------------------- state ---
state_dir=${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles
state_file=$state_dir/macos.state
state() { if [[ -r $state_file ]]; then sed -n "s/^$1=//p" "$state_file" | tail -n 1; fi }

old_commit=$(state commit)
printf '\n'
if [[ -z $old_commit ]]; then
    printf '  %s %s %s\n' 'not installed yet' "$arrow" "${new_commit:0:7}"
elif [[ $old_commit == $new_commit ]]; then
    printf '  %s, same base; applying current checkout files\n' "${new_commit:0:7}"
else
    printf '  %s %s %s' "${old_commit:0:7}" "$arrow" "${new_commit:0:7}"
    if git -C "$repo" merge-base --is-ancestor "$old_commit" "$new_commit" 2>/dev/null; then
        count=$(git -C "$repo" rev-list --count "$old_commit..$new_commit")
        if [[ $count == 1 ]]; then printf ' - 1 new commit'; else printf ' - %s new commits' "$count"; fi
    fi
    printf '\n'
fi

# ------------------------------------------------------------- questions ---
# The same tool set as on Linux and Windows. macOS has its own curl, zsh,
# tcpdump, dig, unzip and python3; coreutils brings GNU ls and dircolors.
formulae=(git tmux neovim htop midnight-commander mtr rsync wget coreutils sl
    lazygit ripgrep fzf fd bat eza zoxide btop dust gdu duf tealdeer inxi lazydocker)
casks=(ghostty)
# Homebrew's own installer, pinned like every other download here.
homebrew_install_commit=7986efac25016e41eed7e471666140c06f9d97cf
homebrew_install_sha256=5f333bbe53bc490e51e7ccb1df8779b3dd6ee73a1a7379efda216edb08ccb148
fonts_url=https://github.com/romkatv/powerlevel10k-media/raw/145eb9fbc2f42ee408dacd9b22d8e6e0e553f83d
typeset -A font_sha256
font_sha256=(
    'MesloLGS NF Regular.ttf' d97946186e97f8d7c0139e8983abf40a1d2d086924f2c5dbf1c29bd8f2c6e57d
    'MesloLGS NF Bold.ttf' b6c0199cf7c7483c8343ea020658925e6de0aeb318b89908152fcb4d19226003
    'MesloLGS NF Italic.ttf' 6f357bcbe2597704e157a915625928bca38364a89c22a4ac36e7a116dcd392ef
    'MesloLGS NF Bold Italic.ttf' 56b4131adecec052c4b324efb818dd326d586dbc316fc68f98f1cae2eb8d1220
)
# Place in $HOME -> repo file. The shell files are the Linux ones.
typeset -A link_source
link_source=(
    .zshrc linux/.zshrc
    .alias linux/.alias
    .p10k.zsh linux/.p10k.zsh
    .dir_colors linux/.dir_colors
    .config/tmux/tmux.conf linux/.config/tmux/tmux.conf
    .config/ghostty/config.ghostty macos/.config/ghostty/config.ghostty
)
links=(.zshrc .alias .p10k.zsh .dir_colors .config/tmux/tmux.conf .config/ghostty/config.ghostty)
# Lines only in the user's copy of these are reported: they may be machine-local.
typeset -A local_file
local_file=(.zshrc '~/.zshrc.local' .alias '~/.alias.local')
stamp=$(strftime %Y%m%d-%H%M%S $EPOCHSECONDS)

keys=(packages ohmyzsh shell fonts links mail)
labels=(
    'Homebrew, packages, tools and Ghostty (Homebrew itself requires --sudo)'
    'oh-my-zsh, plugins and p10k (install or update)'
    'zsh as login shell'
    'MesloLGS NF fonts'
    'Link the dotfiles (backup first)'
    'NeoMutt + NeoSolarized theme + existing Neovim composer'
)
details=(
    "${formulae[*]}; ${casks[*]}"
    'ohmyzsh, zsh-autosuggestions, zsh-syntax-highlighting, powerlevel10k'
    'chsh to /bin/zsh (the macOS default, asks your password if it changes)'
    'into ~/Library/Fonts'
    "~/${(j: ~/:)links}"
    'neomutt from Homebrew, private config with backups; accounts stay outside Git'
)
typeset -A answer
for key in $keys; do
    answer[$key]=yes
    previous=$(state $key)
    case $previous in yes|no) answer[$key]=$previous ;; esac
done

yn() { if [[ $1 == yes ]]; then printf 'Y/n'; else printf 'y/N'; fi }

if [[ $assume_yes == no ]]; then
    [[ -t 0 ]] || die 'No terminal to ask questions on; run it in a terminal or add --yes.'
    printf '\n  Enter accepts the suggestion in brackets, q quits.\n\n'
    for i in {1..$#keys}; do
        key=$keys[i]
        printf '  %d. %s\n     %s\n' $i "$labels[i]" "$details[i]"
        while :; do
            printf '     [%s] ' "$(yn $answer[$key])"
            IFS= read -r reply || die 'Input ended; nothing was changed.'
            case $reply in
                '') break ;;
                [Yy]|[Yy]es) answer[$key]=yes; break ;;
                [Nn]|[Nn]o) answer[$key]=no; break ;;
                [Qq]) printf '\n  Nothing was changed.\n'; exit 0 ;;
            esac
        done
    done
fi

# --------------------------------------------------- existing configs ---
# Looked at before anything changes: what gets replaced, its .bak, and lines
# that exist only in the user's copy. Links are never followed for writing.
replace_plan=(); local_notes=(); config_problem=''
only_in_user() {
    # Line numbers of the non-blank, non-comment lines of $1 that the repo file
    # $2 doesn't have. Numbers only: the lines can hold paths, tokens or passwords.
    awk 'NR == FNR { sub(/^[ \t]+/, ""); sub(/[ \t]+$/, ""); repo[$0] = 1; next }
         { line = $0; sub(/^[ \t]+/, "", line); sub(/[ \t]+$/, "", line)
           if (line != "" && line !~ /^#/ && !(line in repo)) print FNR }' "$2" "$1"
}
inspect_configs() {
    local rel dest source_file parent target kind lines numbers count
    replace_plan=(); local_notes=(); config_problem=''
    for rel in $links; do
        source_file=$repo/$link_source[$rel]
        dest=$HOME/$rel
        parent=${rel:h}
        while [[ $parent != . ]]; do
            if [[ -L $HOME/$parent ]]; then
                config_problem="~/$parent is a symlink; move it away or link ~/$rel yourself, so nothing writes through it."
                return 0
            fi
            parent=${parent:h}
        done
        if [[ -L $dest ]]; then
            target=$(readlink -- "$dest")
            [[ $target != $source_file ]] || continue
            kind="link to $target"
        elif [[ -d $dest ]]; then
            config_problem="~/$rel is a directory; move it away first."
            return 0
        elif [[ -e $dest ]]; then
            if cmp -s -- "$dest" "$source_file"; then kind='same as the repo'; else kind='differs from the repo'; fi
        else
            continue
        fi
        replace_plan+=("~/$rel ($kind) -> backup ~/$rel.$stamp.bak")
        if [[ -n ${local_file[$rel]:-} && -f $dest ]]; then
            lines=$(only_in_user "$dest" "$source_file")
            [[ -n $lines ]] || continue
            count=${#${(f)lines}}
            numbers=${(j:, :)${${(f)lines}[1,12]}}
            (( count <= 12 )) || numbers="$numbers, …"
            local_notes+=("~/$rel: $count line(s) not in the new file (line $numbers). Kept in ~/$rel.$stamp.bak; move what you still need into ${local_file[$rel]}.")
        fi
    done
    return 0
}
show_config_plan() {
    [[ $answer[links] == yes ]] || return 0
    if (( $#replace_plan )); then
        printf '\n  Existing configs that step 5 replaces (also kept in ~/.dotfiles-backup/%s/):\n' "$stamp"
        printf '    %s\n' $replace_plan
    fi
    if (( $#local_notes )); then
        printf '\n  %sCheck:%s machine-local settings are not carried over automatically.\n' "$bold" "$reset"
        printf '    %s\n' $local_notes
    fi
}
inspect_configs

# A plan that would fail half-way is refused before anything changes.
validate() {
    if [[ $answer[links] == yes && -n $config_problem ]]; then
        print -r -- "$config_problem"; return 0
    fi
    if [[ $answer[mail] == yes && $answer[packages] == no ]] && (( ! $+commands[nvim] )); then
        print -r -- 'nvim is needed for mail; enable step 1 or install Neovim first.'; return 0
    fi
}

summary() {
    printf '\n'
    for i in {1..$#keys}; do
        printf '  %d. %-52s %s\n' $i "$labels[i]" "$answer[$keys[i]]"
    done
}

while :; do
    summary
    show_config_plan
    problem=$(validate)
    if [[ -n $problem ]]; then
        printf '\n  %s%s%s %s\n' "$red" "$failed" "$reset" "$problem"
        [[ $assume_yes == no ]] || exit 1
    elif [[ $assume_yes == yes ]]; then
        break
    fi
    printf '\n  Number to change, a to apply, q to quit: '
    IFS= read -r reply || die 'Input ended; nothing was changed.'
    case $reply in
        a|A) [[ -n $problem ]] || break ;;
        q|Q) printf '\n  Nothing was changed.\n'; exit 0 ;;
        [1-9])
            if (( reply <= $#keys )); then
                key=$keys[reply]
                if [[ $answer[$key] == yes ]]; then answer[$key]=no; else answer[$key]=yes; fi
            fi ;;
    esac
done

# --------------------------------------------------------------- planning ---
# Only installing Homebrew itself needs sudo; brew refuses to run as root.
sudo_keeper=''; skip_packages=no; warnings=()
if [[ $answer[packages] == yes && -z $brew_bin ]]; then
    if [[ $allow_sudo == yes ]] && printf '\n' && sudo -v; then
        # Keep the sudo timestamp fresh while Homebrew installs; ends with this script.
        ( while sleep 50; do sudo -n -v 2>/dev/null || exit 0; done ) </dev/null >/dev/null 2>&1 &
        sudo_keeper=$!
    else
        skip_packages=yes
        if [[ $allow_sudo == yes ]]; then
            warnings+=('Packages skipped: sudo was denied, and installing Homebrew needs it once. Run ./install.sh --sudo again.')
        else
            warnings+=('Packages skipped: Homebrew is not installed yet; run ./install.sh --sudo once to install it.')
        fi
        printf '\n  Continuing with per-user setup; step 1 needs Homebrew (see the end).\n'
    fi
fi
[[ -z $locale_warning ]] || warnings+=("$locale_warning")

# ------------------------------------------------------------------- log ---
umask 022
mkdir -p "$state_dir/logs"
log="$state_dir/logs/install-macos-$(date -u +%Y%m%dT%H%M%SZ).log"
( setopt no_clobber; : > "$log" ) || exit 1
chmod 600 "$log"
old_logs=("$state_dir"/logs/install-macos-*.log(N.On))
for old_log in ${old_logs[11,-1]}; do rm -f -- "$old_log"; done
printf 'dotfiles install macos, %s, %s\n' "$(date -u +%FT%TZ)" "$new_commit" >> "$log"

backup_dir=''
backup_root=$HOME/.dotfiles-backup/$stamp
backup() {
    # Moves (or copies with "copy") one path under $HOME into this run's backup.
    # The folders are private (0700); mv and cp -a keep each file's own mode.
    # Not "path": in zsh that is the PATH array.
    local original=$1 mode=${2:-move} rel
    rel=${original#$HOME/}
    if [[ -z $backup_dir ]]; then
        [[ ! -L $HOME/.dotfiles-backup ]] || fail '~/.dotfiles-backup is a symlink; nothing was replaced.'
        [[ -d $HOME/.dotfiles-backup ]] || mkdir -m 700 -- "$HOME/.dotfiles-backup" 2>> "$log" || fail 'Cannot create ~/.dotfiles-backup; nothing was replaced.'
        chmod 700 -- "$HOME/.dotfiles-backup" 2>> "$log" || fail 'Cannot make ~/.dotfiles-backup private; nothing was replaced.'
        mkdir -m 700 -- "$backup_root" 2>> "$log" || fail "Cannot create $backup_root (it may exist already); nothing was replaced."
        backup_dir=$backup_root
    fi
    ( umask 077 && mkdir -p -- "$backup_dir/${rel:h}" ) 2>> "$log" || fail "Cannot create a folder in $backup_dir; nothing was replaced."
    if [[ -e $backup_dir/$rel || -L $backup_dir/$rel ]]; then fail "$backup_dir/$rel already exists; not overwriting a backup."; fi
    if [[ $mode == copy ]]; then cp -a -- "$original" "$backup_dir/$rel" 2>> "$log" || fail "Backup of $original failed; nothing was replaced."
    else mv -- "$original" "$backup_dir/$rel" 2>> "$log" || fail "Backup of $original failed; nothing was replaced."; fi
    printf 'backup: %s -> %s\n' "$original" "$backup_dir/$rel" >> "$log"
}

changes=(); replaced=()

# ----------------------------------------------------------------- steps ---
step_name=''; step_started=$started
step() {
    step_name=$1
    printf '\n--- %s ---\n' "$1" >> "$log"
    step_started=$EPOCHSECONDS
    printf '  %-12s %s\n' "$1" "$2"
}
passed() {
    printf '  %s%s%s %-12s %s (%s)\n' "$green" "$ok" "$reset" "$step_name" "$1" "$(duration $(( EPOCHSECONDS - step_started )))"
    step_name=''
}
show_error() {
    printf '  %s%s%s %-12s %s (%s)\n' "$red" "$failed" "$reset" "${step_name:-Install}" "$1" "$(duration $(( EPOCHSECONDS - step_started )))" >&2
    tail -n 30 "$log" >&2
    printf '\n  Log: %s\n' "$log" >&2
    [[ -z $backup_dir ]] || printf '  Backups: %s\n' "$backup_dir" >&2
    step_name=''
}
TRAPEXIT() { [[ -z $sudo_keeper ]] || kill $sudo_keeper 2>/dev/null || true }
TRAPINT() { show_error 'Install interrupted.'; exit 130 }
TRAPTERM() { show_error 'Install interrupted.'; exit 143 }
TRAPHUP() { show_error 'Install interrupted.'; exit 129 }
run_logged() {
    # The command and its output go to the terminal and the log.
    print -r -- "  + ${(j: :)${(q-)@}}" | tee -a "$log"
    "$@" < /dev/null 2>&1 | tee -a "$log"
}
run() {
    local code=0
    run_logged "$@" || code=$?
    if (( code )); then show_error "Install stopped: $* failed."; exit $code; fi
}
fail() { printf '%s\n' "$1" >> "$log"; show_error "$1"; exit 1 }
download() {
    # download URL FILE: retries on transient errors, fails on HTTP errors.
    run curl -fL --retry 3 --retry-delay 2 --connect-timeout 15 --progress-bar -o "$2" "$1"
}
sha256() { shasum -a 256 < "$1" | cut -d' ' -f1 }

printf '\n'

if [[ $answer[packages] == yes && $skip_packages == no ]]; then
    step Packages "Homebrew, $#formulae formulae, Ghostty"
    done_packages=()
    if [[ -z $brew_bin ]]; then
        sudo -n true 2>/dev/null || fail 'sudo needs the password again (its timeout ran out); run ./install.sh --sudo again.'
        tmp=$(mktemp -d)
        download "https://raw.githubusercontent.com/Homebrew/install/$homebrew_install_commit/install.sh" "$tmp/install.sh"
        [[ $(sha256 "$tmp/install.sh") == $homebrew_install_sha256 ]] || { rm -rf -- "$tmp"; fail 'Checksum mismatch for the Homebrew installer.'; }
        # Non-interactive: our questions are already answered, and sudo is cached.
        run env NONINTERACTIVE=1 /bin/bash "$tmp/install.sh"
        rm -rf -- "$tmp"
        find_brew
        [[ -n $brew_bin ]] || fail 'Homebrew installed, but brew was not found in /opt/homebrew or /usr/local.'
        eval "$("$brew_bin" shellenv)"
        done_packages+=(Homebrew)
    fi
    export HOMEBREW_NO_ENV_HINTS=1
    installed_formulae=(${(f)"$(brew list --formula -1 2>> "$log")"})
    missing=(${formulae:|installed_formulae})
    if (( $#missing )); then
        run brew install $missing
        done_packages+=($missing)
    fi
    rehash  # zsh caches command lookups; see what brew just installed
    for cask in $casks; do
        # A copy installed by hand stays; brew would refuse to overwrite it anyway.
        if ! brew list --cask $cask >/dev/null 2>&1 && [[ ! -d /Applications/${(C)cask}.app ]]; then
            run brew install --cask $cask
            done_packages+=($cask)
        fi
    done
    # tealdeer needs its page cache once; later updates are `tldr --update`.
    # Optional: a failure here is a warning, not a stop.
    if (( $+commands[tldr] )) && [[ ! -d ${XDG_CACHE_HOME:-$HOME/.cache}/tealdeer/tldr-pages && ! -d $HOME/Library/Caches/tealdeer/tldr-pages ]]; then
        if run_logged tldr --update; then done_packages+=('tldr pages')
        else warnings+=('tldr --update failed (network?); run it later, tldr works without pages until then.'); fi
    fi
    # zoxide replaces zsh-z: carry the old directory history over, once, while
    # zoxide has no database of its own yet. ~/.z itself stays as it is.
    zoxide_db=${_ZO_DATA_DIR:-$HOME/Library/Application Support/zoxide}/db.zo
    if [[ -s $HOME/.z && ! -e $zoxide_db ]] && (( $+commands[zoxide] )); then
        # zoxide 0.9 takes --from z PATH; 0.10 reads ~/.z itself.
        if [[ $(zoxide import --help 2>/dev/null || true) == *--from* ]]; then zoxide_import=(zoxide import --from z "$HOME/.z")
        else zoxide_import=(zoxide import zsh-z); fi
        if run_logged $zoxide_import; then done_packages+=('z history imported into zoxide')
        else warnings+=("importing ~/.z into zoxide failed; it's optional, see the log (${zoxide_import[*]})."); fi
    fi
    if (( ! $#done_packages )); then
        passed "all $(( $#formulae + $#casks )) installed"
    else
        changes+=("packages: ${done_packages[*]}")
        passed "installed ${done_packages[*]}"
    fi
fi

if [[ $answer[ohmyzsh] == yes ]]; then
    step oh-my-zsh 'oh-my-zsh, 2 plugins, p10k'
    zsh_dir=$HOME/.oh-my-zsh
    custom=${ZSH_CUSTOM:-$zsh_dir/custom}
    updated=(); installed=()
    # name|url|directory; oh-my-zsh first, the others live inside it.
    for entry in \
        "oh-my-zsh|https://github.com/ohmyzsh/ohmyzsh.git|$zsh_dir" \
        "zsh-autosuggestions|https://github.com/zsh-users/zsh-autosuggestions.git|$custom/plugins/zsh-autosuggestions" \
        "zsh-syntax-highlighting|https://github.com/zsh-users/zsh-syntax-highlighting.git|$custom/plugins/zsh-syntax-highlighting" \
        "powerlevel10k|https://github.com/romkatv/powerlevel10k.git|$custom/themes/powerlevel10k"
    do
        IFS='|' read -r name url dir <<< "$entry"
        if [[ -d $dir/.git ]]; then
            modified=(${(f)"$(git -C "$dir" diff --name-only 2>> "$log" || true)"})
            # Earlier setups copied files over ones oh-my-zsh owns; keep a backup,
            # then give it its file back. ($path would be zsh's PATH array.)
            for changed_file in $modified; do
                backup "$dir/$changed_file" copy
                run git -C "$dir" checkout -- "$changed_file"
                changes+=("$name: restored $changed_file (local copy in backup)")
            done
            # Ask the remote first: pulling when nothing is new still writes
            # FETCH_HEAD/ORIG_HEAD, and a rerun should leave everything as it was.
            branch=$(git -C "$dir" symbolic-ref --short HEAD 2>/dev/null) || fail "$name in $dir is not on a branch."
            remote_head=$(git -C "$dir" ls-remote origin "refs/heads/$branch" 2>> "$log" | cut -f1 || true)
            [[ -n $remote_head ]] || fail "Cannot reach the $name repository."
            if [[ $remote_head != $(git -C "$dir" rev-parse HEAD) ]]; then
                run git -C "$dir" pull --ff-only --progress
                updated+=($name)
            fi
        else
            [[ ! -e $dir ]] || backup "$dir"
            mkdir -p -- "${dir:h}"
            # The git settings oh-my-zsh's own installer uses, without running it.
            run git clone --progress --depth=1 \
                -c core.eol=lf -c core.autocrlf=false \
                -c fsck.zeroPaddedFilemode=ignore -c fetch.fsck.zeroPaddedFilemode=ignore \
                -c receive.fsck.zeroPaddedFilemode=ignore \
                "$url" "$dir"
            installed+=($name)
        fi
    done
    result=''
    (( ! $#installed )) || result="installed ${installed[*]}"
    (( ! $#updated )) || result="${result:+$result; }updated ${updated[*]}"
    if [[ -n $result ]]; then changes+=("oh-my-zsh: $result"); else result='all up to date'; fi
    passed "$result"
fi

if [[ $answer[shell] == yes ]]; then
    step Shell 'zsh as login shell'
    login_shell=$(dscl . -read "/Users/$USER" UserShell 2>/dev/null | awk '{print $2}')
    if [[ $login_shell == */zsh ]]; then
        passed "already $login_shell"
    elif [[ -t 0 ]]; then
        # chsh asks for your own password, not an administrator's.
        chsh -s /bin/zsh || fail 'chsh -s /bin/zsh failed.'
        changes+=("login shell: $login_shell $arrow /bin/zsh")
        passed "$login_shell $arrow /bin/zsh"
    else
        warnings+=("Login shell is still $login_shell; run chsh -s /bin/zsh in a terminal.")
        passed 'skipped (no terminal for the password)'
    fi
fi

if [[ $answer[fonts] == yes ]]; then
    step Fonts 'MesloLGS NF'
    font_dir=$HOME/Library/Fonts
    mkdir -p -- "$font_dir"
    new_fonts=0
    for font in ${(k)font_sha256}; do
        if [[ -f $font_dir/$font && $(sha256 "$font_dir/$font") == $font_sha256[$font] ]]; then
            continue
        fi
        tmp=$(mktemp)
        download "$fonts_url/${font// /%20}" "$tmp"
        [[ $(sha256 "$tmp") == $font_sha256[$font] ]] || { rm -f -- "$tmp"; fail "Checksum mismatch for $font."; }
        [[ ! -e $font_dir/$font ]] || backup "$font_dir/$font"
        mv -- "$tmp" "$font_dir/$font"
        chmod 644 "$font_dir/$font"
        (( new_fonts += 1 ))
    done
    if (( new_fonts )); then
        changes+=("fonts: $new_fonts MesloLGS NF files")
        passed "installed $new_fonts"
    else
        passed 'all 4 installed'
    fi
fi

if [[ $answer[links] == yes ]]; then
    step Links "$#links dotfiles"
    linked=()
    for rel in $links; do
        source_file=$repo/$link_source[$rel]
        dest=$HOME/$rel
        [[ -f $source_file ]] || fail "Missing in the repo: $link_source[$rel]"
        [[ $(readlink -- "$dest" 2>/dev/null || true) != $source_file ]] || continue
        if [[ -e $dest || -L $dest ]]; then
            [[ ! -d $dest || -L $dest ]] || fail "~/$rel is a directory; nothing was replaced."
            bak=$dest.$stamp.bak
            # Never overwrite a backup; cp -P copies a symlink itself, not its target.
            if [[ -e $bak || -L $bak ]]; then fail "$bak already exists; nothing was replaced."; fi
            cp -P -p -- "$dest" "$bak" 2>> "$log" || fail "Backup of ~/$rel failed; nothing was replaced."
            backup "$dest"
            replaced+=("~/$rel -> $bak")
        fi
        mkdir -p -- "${dest:h}"
        ln -sn -- "$source_file" "$dest"
        printf 'link: %s -> %s\n' "$dest" "$source_file" >> "$log"
        linked+=("~/$rel")
    done
    if (( $#linked )); then
        changes+=("links: ${linked[*]}")
        passed "linked ${linked[*]}"
    else
        passed 'all linked'
    fi
fi

if [[ $answer[mail] == yes ]]; then
    step NeoMutt 'mail client, theme and Neovim composer'
    if (( ! $+commands[neomutt] )) && [[ -n $brew_bin ]]; then run brew install neomutt; rehash; fi
    if (( ! $+commands[nvim] )); then
        warnings+=('Mail setup skipped because nvim is missing; run step 1 (packages) first.')
        passed 'skipped (nvim missing)'
    else
        run /usr/bin/python3 -u "$repo/tools/install-mail.py" yes no-packages
        if (( $+commands[neomutt] )); then
            changes+=('NeoMutt: package and themed configuration checked; run nmutt')
            passed 'ready; launch nmutt (or neomutt)'
        else
            changes+=('NeoMutt: themed configuration prepared')
            warnings+=('NeoMutt is not installed yet; it comes with Homebrew (./install.sh --sudo).')
            passed 'configuration ready; neomutt package still needed'
        fi
    fi
fi

# Remember this run for the next one; rewritten only when something differs.
new_state=$(printf 'commit=%s\n' "$new_commit"; for key in $keys; do printf '%s=%s\n' "$key" "$answer[$key]"; done)
if [[ $new_state != $(cat "$state_file" 2>/dev/null || true) ]]; then
    printf '%s\n' "$new_state" > "$state_file"
fi

# --------------------------------------------------------------- summary ---
printf '\n'
if (( ! $#changes )); then
    printf '  Nothing changed; everything was already in place.\n'
else
    printf '  Changed:\n'
    printf '    %s\n' $changes
fi
if (( $#replaced )); then
    printf '  Replaced configs (originals kept):\n'
    printf '    %s\n' $replaced
fi
if (( $#replaced && $#local_notes )); then
    printf '  %sCheck:%s\n' "$bold" "$reset"
    printf '    %s\n' $local_notes
fi
if (( $#warnings )); then
    printf '  Warnings:\n'
    printf '    %s\n' $warnings
fi
[[ -z $backup_dir ]] || printf '  Backups: %s\n' "$backup_dir"
printf '  Log:     %s\n' "$log"
printf '\n  Done in %s. Open Ghostty (or a new shell: exec zsh), then run %shelp-dots%s for the cheat sheet.\n' \
    "$(duration $(( EPOCHSECONDS - started )))" "$bold" "$reset"
