#!/usr/bin/env bash
# Install or update the dotfiles on Debian (also in WSL). Safe to run again:
# it asks first, changes only what differs and backs up what it replaces.
#   ./install.sh [--yes]
# shellcheck disable=SC2088 # "~/..." strings are labels for people, not paths
set -euo pipefail

repo=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
started=$(date +%s)

usage() {
    cat <<'EOF'
Usage: ./install.sh [root|mail] [--yes] [--sudo]

  Debian 13 or newer, also in WSL: packages, zsh, oh-my-zsh, p10k,
  tmux, fonts, NeoMutt and the dotfiles from linux/.
  On Windows, run .\install.ps1 in PowerShell instead.

  root      same shell for root, from a private root-owned snapshot
  mail      install the NeoMutt presentation config for your user

  --yes     accept every suggested answer and apply without asking
  --sudo    allow sudo for system packages and login-shell changes
            without it, only per-user setup runs (no sudo prompts)
EOF
}

assume_yes=no; mode=user; allow_sudo=no
for arg in "$@"; do
    case $arg in
        --yes|-y) assume_yes=yes ;;
        --sudo) allow_sudo=yes ;;
        --no-sudo) allow_sudo=no ;;
        root|mail|--root-apply) [ "$mode" = user ] || { usage >&2; exit 2; }; mode=$arg ;;
        -h|--help) usage; exit 0 ;;
        *) usage >&2; exit 2 ;;
    esac
done

if [ "$mode" = root ]; then
    [ "$allow_sudo" = yes ] || { echo 'Root setup requires --sudo: ./install.sh root --sudo' >&2; exit 2; }
    exec /usr/bin/python3 "$repo/tools/root-shell.py" "$assume_yes"
elif [ "$mode" = mail ]; then
    [ "$allow_sudo" = no ] || exec /usr/bin/python3 "$repo/tools/install-mail.py" "$assume_yes" with-sudo
    exec /usr/bin/python3 "$repo/tools/install-mail.py" "$assume_yes" no-packages
fi
root_mode=no
if [ "$mode" = --root-apply ]; then
    [ "$(id -u)" = 0 ] && [ "$HOME" = /root ] || { echo 'Internal root mode requires root and HOME=/root.' >&2; exit 1; }
    /usr/bin/python3 -I "$repo/tools/root-shell.py" --audit "$repo"
    root_mode=yes
fi

# ---------------------------------------------------------------- output ---
ok='OK'; failed='FAIL'; arrow='->'; green=''; red=''; bold=''; reset=''
title='dotfiles - install linux'
if [ -t 1 ]; then
    case $(locale charmap 2>/dev/null || true) in
        UTF-8|utf8|UTF8) ok='✓'; failed='✗'; arrow='→'; title='🐇 dotfiles · install linux' ;;
    esac
    if [ -z "${NO_COLOR+x}" ]; then
        green=$(printf '\033[32m'); red=$(printf '\033[31m'); bold=$(printf '\033[1m'); reset=$(printf '\033[0m')
    fi
fi

die() { printf '  %s%s%s %s\n' "$red" "$failed" "$reset" "$1" >&2; exit 1; }
check_ok() { printf '  %s%s%s %-12s %s\n' "$green" "$ok" "$reset" "$1" "$2"; }
check_warn() { printf '  %s!%s %-12s %s\n' "$red" "$reset" "$1" "$2"; }
duration() {
    awk -v seconds="$1" 'BEGIN {if (seconds >= 60) printf "%dm %ds", seconds/60, seconds%60; else printf "%ds", seconds}'
}

# ---------------------------------------------------------------- checks ---
# Nothing is written before these pass, not even the log.
printf '\n%s%s%s\n\n' "$bold" "$title" "$reset"

[ "$(uname -s)" = Linux ] || die 'This is not Linux; on Windows run .\install.ps1 in PowerShell.'
[ -r /etc/os-release ] || die 'Cannot read /etc/os-release, so this does not look like Debian.'
# shellcheck source=/dev/null
IFS='|' read -r os_id os_version os_name < <(. /etc/os-release; printf '%s|%s|%s\n' "${ID:-}" "${VERSION_ID:-}" "${PRETTY_NAME:-${ID:-}}")
[ "$os_id" = debian ] || die "This installer is for Debian; this system is $os_name."
# Testing and sid have no VERSION_ID. eza and lazygit need trixie (13) or newer.
if [ -n "$os_version" ] && [ "${os_version%%.*}" -lt 13 ]; then
    die "Debian $os_version is too old; eza and lazygit need Debian 13 (trixie) or newer."
fi
wsl=no
if [ -e /proc/sys/fs/binfmt_misc/WSLInterop ] || grep -qi microsoft /proc/sys/kernel/osrelease 2>/dev/null; then wsl=yes; fi
check_ok System "$os_name$([ "$wsl" = yes ] && printf ' (WSL)')"

# btop refuses to start without a UTF-8 locale, and tmux, p10k and eza need it for
# their glyphs. A warning, not a stop: the user may fix it after the install.
locale_name=${LC_ALL:-${LC_CTYPE:-${LANG:-POSIX}}}
locale_warning=''
if [ "$(locale charmap 2>/dev/null || true)" = UTF-8 ]; then
    check_ok Locale "$locale_name"
else
    locale_warning="The locale ($locale_name) is not UTF-8: btop won't start and glyphs break. Add export LANG=C.UTF-8 to ~/.zshrc.local."
    check_warn Locale "$locale_name is not UTF-8 (see the end)"
fi

if [ "$root_mode" = no ]; then
    [ "$(id -u)" -ne 0 ] || die 'Run this as your normal user; use ./install.sh root --sudo for root.'
fi
command -v git >/dev/null || die 'git is missing; ask an administrator to install it first.'
if [ "$root_mode" = yes ]; then check_ok User 'root, private snapshot and clean environment'
else check_ok User "$(id -un), git present (sudo is optional)"; fi

if [ "$root_mode" = yes ]; then
    new_commit=$(cat "$repo/.revision")
    command -v zsh >/dev/null || die 'Install zsh with the normal installer first.'
else
    dirty=$(git -C "$repo" status --porcelain 2>/dev/null) || die "$repo is not a git checkout; clone the repo and run it from there."
    [ -z "$dirty" ] || die "The repo has uncommitted changes; commit or stash them first ($(printf '%s\n' "$dirty" | awk '{print $2}' | paste -sd ' ' -))."
    new_commit=$(git -C "$repo" rev-parse HEAD)
fi
check_ok Repo "clean at ${new_commit:0:7}"

# Backups go to ~/.dotfiles-backup (private, 0700); never through a link.
if [ -L "$HOME/.dotfiles-backup" ] || { [ -e "$HOME/.dotfiles-backup" ] && [ ! -d "$HOME/.dotfiles-backup" ]; }; then
    die '~/.dotfiles-backup is a symlink or not a folder; move it away first, backups never go through a link.'
fi

free_kb=$(df -Pk "$HOME" | awk 'NR==2 {print $4}')
[ "${free_kb:-0}" -ge 1000000 ] || die "Only $((${free_kb:-0} / 1000)) MB free in $HOME; the install needs at least 1 GB."
check_ok Disk "$(awk -v k="$free_kb" 'BEGIN {printf "%.1f GB free", k*1024/1e9}')"

# ----------------------------------------------------------------- state ---
state_dir=${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles
state_file=$state_dir/linux.state
state() { [ -r "$state_file" ] && sed -n "s/^$1=//p" "$state_file" | tail -n 1; }

old_commit=$(state commit || true)
printf '\n'
if [ -z "$old_commit" ]; then
    printf '  %s %s %s\n' 'not installed yet' "$arrow" "${new_commit:0:7}"
elif [ "$old_commit" = "$new_commit" ]; then
    printf '  %s, nothing new in this checkout\n' "${new_commit:0:7}"
else
    printf '  %s %s %s' "${old_commit:0:7}" "$arrow" "${new_commit:0:7}"
    if [ "$root_mode" = no ] && git -C "$repo" merge-base --is-ancestor "$old_commit" "$new_commit" 2>/dev/null; then
        count=$(git -C "$repo" rev-list --count "$old_commit..$new_commit")
        if [ "$count" = 1 ]; then printf ' - 1 new commit'; else printf ' - %s new commits' "$count"; fi
    fi
    printf '\n'
fi

# ------------------------------------------------------------- questions ---
base_packages=(zsh tmux git curl wget ca-certificates neovim htop mc mtr-tiny tcpdump iptraf-ng
    bind9-dnsutils rsync unzip iproute2 sl python3)
# The tool set, the same on Windows (scoop); lazydocker isn't in Debian.
tool_packages=(lazygit ripgrep fzf fd-find bat eza zoxide btop du-dust gdu duf tealdeer inxi)
lazydocker_version=0.25.2
declare -A lazydocker_sha256=(
    [x86_64]=0d9dbfc26068b218e7ed84b104748cadc6e3cf733c0afd35465306fb39b9523c
    [arm64]=005c38b685aaa557e7d646d83a3dadb5024340eeed8c6a2e1949eee6f530de23
)
fonts_url=https://github.com/romkatv/powerlevel10k-media/raw/145eb9fbc2f42ee408dacd9b22d8e6e0e553f83d
declare -A font_sha256=(
    ['MesloLGS NF Regular.ttf']=d97946186e97f8d7c0139e8983abf40a1d2d086924f2c5dbf1c29bd8f2c6e57d
    ['MesloLGS NF Bold.ttf']=b6c0199cf7c7483c8343ea020658925e6de0aeb318b89908152fcb4d19226003
    ['MesloLGS NF Italic.ttf']=6f357bcbe2597704e157a915625928bca38364a89c22a4ac36e7a116dcd392ef
    ['MesloLGS NF Bold Italic.ttf']=56b4131adecec052c4b324efb818dd326d586dbc316fc68f98f1cae2eb8d1220
)
# Repo file (under linux/) -> place in $HOME
links=(.zshrc .alias .p10k.zsh .dir_colors .config/tmux/tmux.conf)
# Lines only in the user's copy of these are reported: they may be machine-local.
declare -A local_file=([.zshrc]='~/.zshrc.local' [.alias]='~/.alias.local')
stamp=$(date +%Y%m%d-%H%M%S)
[ "$root_mode" = no ] || stamp=$(date +%Y%m%d-%H%M%S-%N)

link_list=$(printf '~/%s ' "${links[@]}")

keys=(packages ohmyzsh shell fonts links mail)
labels=(
    'Packages and tools (system packages require --sudo)'
    'oh-my-zsh, plugins and p10k (install or update)'
    'zsh as login shell (changes require --sudo)'
    'MesloLGS NF fonts'
    'Link the dotfiles (backup first)'
    'NeoMutt + NeoSolarized theme + existing Neovim composer'
)
details=(
    "${base_packages[*]} ${tool_packages[*]}; lazydocker $lazydocker_version (checksum-checked)"
    'ohmyzsh, zsh-autosuggestions, zsh-syntax-highlighting, powerlevel10k'
    "chsh to $(command -v zsh || echo /usr/bin/zsh)"
    "$([ "$wsl" = yes ] && echo 'WSL: Windows Terminal uses Windows fonts, install.ps1 installs those' || echo 'into ~/.local/share/fonts')"
    "$link_list"
    'neomutt package, private config with backups; accounts stay outside Git'
)
declare -A answer
for key in "${keys[@]}"; do answer[$key]=yes; done
[ "$wsl" = no ] || answer[fonts]=no
for key in "${keys[@]}"; do
    previous=$(state "$key" || true)
    case $previous in yes|no) answer[$key]=$previous ;; esac
done

if [ "$root_mode" = yes ]; then
    keys=(ohmyzsh shell links)
    labels=('Root-owned oh-my-zsh, plugins and p10k' 'zsh as root login shell' 'Root shell config (backup first)')
    details=('/root/.oh-my-zsh, cloned from upstream' '/usr/bin/zsh' "$link_list")
    answer[packages]=no; answer[fonts]=no; answer[mail]=no
    answer[ohmyzsh]=yes; answer[shell]=yes; answer[links]=yes
fi

yn() { if [ "$1" = yes ]; then printf 'Y/n'; else printf 'y/N'; fi; }

if [ "$assume_yes" = no ]; then
    [ -t 0 ] || die 'No terminal to ask questions on; run it in a terminal or add --yes.'
    printf '\n  Enter accepts the suggestion in brackets, q quits.\n\n'
    for i in "${!keys[@]}"; do
        key=${keys[$i]}
        printf '  %d. %s\n     %s\n' "$((i + 1))" "${labels[$i]}" "${details[$i]}"
        while :; do
            printf '     [%s] ' "$(yn "${answer[$key]}")"
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
    for rel in "${links[@]}"; do
        source_file=$repo/linux/$rel
        dest=$HOME/$rel
        parent=$(dirname -- "$rel")
        while [ "$parent" != . ]; do
            if [ -L "$HOME/$parent" ]; then
                config_problem="~/$parent is a symlink; move it away or link ~/$rel yourself, so nothing writes through it."
                return
            fi
            parent=$(dirname -- "$parent")
        done
        if [ -L "$dest" ]; then
            target=$(readlink -- "$dest")
            [ "$target" != "$source_file" ] || continue
            kind="link to $target"
        elif [ -d "$dest" ]; then
            config_problem="~/$rel is a directory; move it away first."
            return
        elif [ -e "$dest" ]; then
            if cmp -s -- "$dest" "$source_file"; then kind='same as the repo'; else kind='differs from the repo'; fi
        else
            continue
        fi
        replace_plan+=("~/$rel ($kind) -> backup ~/$rel.$stamp.bak")
        if [ -n "${local_file[$rel]:-}" ] && [ -f "$dest" ]; then
            lines=$(only_in_user "$dest" "$source_file")
            [ -n "$lines" ] || continue
            count=$(printf '%s\n' "$lines" | wc -l)
            numbers=$(printf '%s\n' "$lines" | head -n 12 | paste -sd ',' - | sed 's/,/, /g')
            [ "$count" -le 12 ] || numbers="$numbers, …"
            local_notes+=("~/$rel: $count line(s) not in the new file (line $numbers). Kept in ~/$rel.$stamp.bak; move what you still need into ${local_file[$rel]}.")
        fi
    done
}
show_config_plan() {
    [ "${answer[links]}" = yes ] || return 0
    if [ "${#replace_plan[@]}" -gt 0 ]; then
        printf '\n  Existing configs that step 5 replaces (also kept in ~/.dotfiles-backup/%s/):\n' "$stamp"
        printf '    %s\n' "${replace_plan[@]}"
    fi
    if [ "${#local_notes[@]}" -gt 0 ]; then
        printf '\n  %sCheck:%s machine-local settings are not carried over automatically.\n' "$bold" "$reset"
        printf '    %s\n' "${local_notes[@]}"
    fi
}
inspect_configs

# A plan that would fail half-way is refused before anything changes.
validate() {
    if [ "${answer[links]}" = yes ] && [ -n "$config_problem" ]; then
        echo "$config_problem"; return
    fi
    if [ "${answer[mail]}" = yes ] && [ "${answer[packages]}" = no ]; then
        for tool in python3 nvim; do
            command -v "$tool" >/dev/null || { echo "$tool is needed for mail; enable core packages or install it first."; return; }
        done
    fi
    if [ "${answer[packages]}" = no ]; then
        for tool in curl zsh; do
            if ! command -v "$tool" >/dev/null; then
                case $tool in
                    curl) [ "${answer[fonts]}" = no ] && continue ;;
                    zsh) [ "${answer[shell]}" = no ] && continue ;;
                esac
                echo "$tool is missing; answer yes to 1 (core packages) or install it first."; return
            fi
        done
    fi
}

summary() {
    printf '\n'
    for i in "${!keys[@]}"; do
        printf '  %d. %-52s %s\n' "$((i + 1))" "${labels[$i]}" "${answer[${keys[$i]}]}"
    done
}

while :; do
    summary
    show_config_plan
    problem=$(validate)
    if [ -n "$problem" ]; then
        printf '\n  %s%s%s %s\n' "$red" "$failed" "$reset" "$problem"
        [ "$assume_yes" = no ] || exit 1
    elif [ "$assume_yes" = yes ]; then
        break
    fi
    printf '\n  Number to change, a to apply, q to quit: '
    IFS= read -r reply || die 'Input ended; nothing was changed.'
    case $reply in
        a|A) [ -z "$problem" ] && break ;;
        q|Q) printf '\n  Nothing was changed.\n'; exit 0 ;;
        [1-9])
            if [ "$reply" -le "${#keys[@]}" ]; then
                key=${keys[$((reply - 1))]}
                if [ "${answer[$key]}" = yes ]; then answer[$key]=no; else answer[$key]=yes; fi
            fi ;;
    esac
done

# --------------------------------------------------------------- planning ---
missing_packages() {
    local package
    for package in "$@"; do
        dpkg-query -W -f='${db:Status-Status}' "$package" 2>/dev/null | grep -qx installed || printf '%s\n' "$package"
    done
}
want_packages=(); want_fontconfig=()
[ "${answer[packages]}" = no ] || mapfile -t want_packages < <(missing_packages "${base_packages[@]}" "${tool_packages[@]}")
[ "${answer[fonts]}" = no ] || mapfile -t want_fontconfig < <(missing_packages fontconfig)
login_shell=$(getent passwd "$(id -un)" | cut -d: -f7)

need_sudo=no
[ "${#want_packages[@]}${#want_fontconfig[@]}" = 00 ] || need_sudo=yes
if [ "${answer[shell]}" = yes ] && [ "$login_shell" != "$(command -v zsh || echo /usr/bin/zsh)" ]; then need_sudo=yes; fi
if [ "${answer[mail]}" = yes ] && ! command -v neomutt >/dev/null; then need_sudo=yes; fi
sudo_keeper=''; admin_available=$allow_sudo
skip_packages=no; skip_shell=no; skip_fonts=no; skip_mail=no; admin_warnings=()
[ "$root_mode" = no ] || admin_available=yes
if [ "$need_sudo" = yes ] && [ "$admin_available" = yes ]; then
    if [ "$root_mode" = yes ]; then
        need_sudo=no
    else
        printf '\n'
        if command -v sudo >/dev/null && sudo -v; then
            # Keep the sudo timestamp fresh during long apt runs; ends with this script.
            (while sleep 50; do sudo -n -v 2>/dev/null || exit 0; done) </dev/null >/dev/null 2>&1 & sudo_keeper=$!
        else
            admin_available=no
        fi
    fi
fi
if [ "$admin_available" = no ]; then
    if [ "$allow_sudo" = yes ]; then
        printf '\n  Continuing with per-user setup; sudo is unavailable or was denied.\n'
    else
        printf '\n  Continuing with per-user setup; use --sudo to allow system changes.\n'
    fi
    if [ "${#want_packages[@]}" -gt 0 ]; then
        skip_packages=yes
        admin_warnings+=("System package step skipped; ask an administrator to install: ${want_packages[*]}.")
    fi
    if [ "${answer[shell]}" = yes ] && [ "$login_shell" != "$(command -v zsh || echo /usr/bin/zsh)" ]; then
        skip_shell=yes
        admin_warnings+=("Login shell unchanged; use exec zsh for this session, or ask an administrator to change the login shell for $(id -un).")
    fi
    if [ "${#want_fontconfig[@]}" -gt 0 ]; then
        want_fontconfig=()
        admin_warnings+=('fontconfig package skipped; font files can still be installed in ~/.local/share/fonts.')
    fi
    if [ "${answer[fonts]}" = yes ] && ! command -v curl >/dev/null; then
        skip_fonts=yes
        admin_warnings+=('Font downloads skipped because curl is missing; ask an administrator to install curl.')
    fi
    if [ "${answer[mail]}" = yes ]; then
        for tool in python3 nvim; do
            if ! command -v "$tool" >/dev/null; then
                skip_mail=yes
                admin_warnings+=("Mail setup skipped because $tool is missing; ask an administrator to install it.")
            fi
        done
    fi
fi

# ------------------------------------------------------------------- log ---
umask 022
mkdir -p "$state_dir/logs"
log="$state_dir/logs/install-linux-$(date -u +%Y%m%dT%H%M%SZ).log"
[ "$root_mode" = no ] || log="$state_dir/logs/install-linux-root-$(date -u +%Y%m%dT%H%M%S-%NZ).log"
(set -C; : > "$log") || exit 1
chmod 600 "$log"
find "$state_dir/logs" -maxdepth 1 -type f -name 'install-linux-*.log' | LC_ALL=C sort -r | sed '1,10d' |
    while IFS= read -r old_log; do rm -f -- "$old_log"; done
printf 'dotfiles install linux, %s, %s\n' "$(date -u +%FT%TZ)" "$new_commit" >> "$log"

backup_dir=''
backup_root=$HOME/.dotfiles-backup/$stamp
backup() {
    # Moves (or copies with "copy") one path under $HOME into this run's backup.
    # The folders are private (0700); mv and cp -a keep each file's own mode.
    local path=$1 mode=${2:-move} rel
    rel=${path#"$HOME"/}
    if [ -z "$backup_dir" ]; then
        [ ! -L "$HOME/.dotfiles-backup" ] || fail '~/.dotfiles-backup is a symlink; nothing was replaced.'
        [ -d "$HOME/.dotfiles-backup" ] || mkdir -m 700 -- "$HOME/.dotfiles-backup" 2>> "$log" || fail 'Cannot create ~/.dotfiles-backup; nothing was replaced.'
        chmod 700 -- "$HOME/.dotfiles-backup" 2>> "$log" || fail 'Cannot make ~/.dotfiles-backup private; nothing was replaced.'
        mkdir -m 700 -- "$backup_root" 2>> "$log" || fail "Cannot create $backup_root (it may exist already); nothing was replaced."
        backup_dir=$backup_root
    fi
    (umask 077 && mkdir -p -- "$backup_dir/$(dirname -- "$rel")") 2>> "$log" || fail "Cannot create a folder in $backup_dir; nothing was replaced."
    if [ -e "$backup_dir/$rel" ] || [ -L "$backup_dir/$rel" ]; then fail "$backup_dir/$rel already exists; not overwriting a backup."; fi
    if [ "$mode" = copy ]; then cp -a -- "$path" "$backup_dir/$rel" 2>> "$log" || fail "Backup of $path failed; nothing was replaced."
    else mv -- "$path" "$backup_dir/$rel" 2>> "$log" || fail "Backup of $path failed; nothing was replaced."; fi
    printf 'backup: %s -> %s\n' "$path" "$backup_dir/$rel" >> "$log"
}

changes=(); warnings=("${admin_warnings[@]}"); replaced=()
[ -z "$locale_warning" ] || warnings+=("$locale_warning")

# ----------------------------------------------------------------- steps ---
command_pid=''; step_name=''
step() {
    step_name=$1
    printf '\n--- %s ---\n' "$1" >> "$log"
    step_started=$(date +%s)
    printf '  %-12s %s\n' "$1" "$2"
}
passed() {
    printf '  %s%s%s %-12s %s (%s)\n' "$green" "$ok" "$reset" "$step_name" "$1" "$(duration "$(($(date +%s) - step_started))")"
    step_name=''
}
show_error() {
    printf '  %s%s%s %-12s %s (%s)\n' "$red" "$failed" "$reset" "${step_name:-Install}" "$1" "$(duration "$(($(date +%s) - ${step_started:-$started}))")" >&2
    tail -n 30 "$log" >&2
    printf '\n  Log: %s\n' "$log" >&2
    [ -z "$backup_dir" ] || printf '  Backups: %s\n' "$backup_dir" >&2
    step_name=''
}
interrupt() {
    if [ -n "$command_pid" ]; then kill "$command_pid" 2>/dev/null || true; wait "$command_pid" 2>/dev/null || true; fi
    show_error 'Install interrupted.'
    exit "$1"
}
trap '[ -z "$sudo_keeper" ] || kill "$sudo_keeper" 2>/dev/null || true' EXIT
trap 'interrupt 130' INT
trap 'interrupt 143' HUP TERM
run_logged() {
    local code=0 output_code=0 output_fd output_pid
    { printf '  +'; printf ' %q' "$@"; printf '\n'; } | tee -a "$log" || return $?
    # Keep the real command PID for cancellation, and wait for tee to flush
    # before returning so later log reads include all command output.
    exec {output_fd}> >(tee -a "$log")
    output_pid=$!
    "$@" >&"$output_fd" 2>&1 < /dev/null & command_pid=$!
    exec {output_fd}>&-
    wait "$command_pid" || code=$?
    command_pid=''
    wait "$output_pid" || output_code=$?
    if [ "$code" -eq 0 ]; then code=$output_code; fi
    return "$code"
}
run() {
    local code=0
    run_logged "$@" || code=$?
    if [ "$code" -ne 0 ]; then show_error "Install stopped: $* failed."; exit "$code"; fi
}
fail() { printf '%s\n' "$1" >> "$log"; show_error "$1"; exit 1; }

sudo_ready() {
    [ "$root_mode" = no ] || return 0
    sudo -n true 2>/dev/null || fail 'sudo needs the password again (its timeout ran out); run ./install.sh again.'
}
apt_install() {
    sudo_ready
    run sudo -n apt-get update
    run sudo -n env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "$@"
}

printf '\n'

if [ "${answer[packages]}" = yes ] && [ "$skip_packages" = no ]; then
    package_count=$((${#base_packages[@]} + ${#tool_packages[@]}))
    step Packages "$package_count apt packages, lazydocker"
    done_packages=()
    if [ "${#want_packages[@]}" -gt 0 ]; then
        apt_install "${want_packages[@]}"
        done_packages+=("${want_packages[@]}")
    fi
    case $(dpkg --print-architecture) in
        amd64) arch=x86_64 ;; arm64) arch=arm64 ;; *) arch='' ;;
    esac
    lazydocker=$HOME/.local/bin/lazydocker
    if [ -z "$arch" ]; then
        printf 'lazydocker: no pinned build for %s, skipped\n' "$(dpkg --print-architecture)" >> "$log"
    elif ! "$lazydocker" --version 2>/dev/null | grep -qx "Version: $lazydocker_version"; then
        tmp=$(mktemp -d)
        file=lazydocker_${lazydocker_version}_Linux_$arch.tar.gz
        run curl -fL --progress-bar -o "$tmp/$file" "https://github.com/jesseduffield/lazydocker/releases/download/v$lazydocker_version/$file"
        printf '%s  %s\n' "${lazydocker_sha256[$arch]}" "$tmp/$file" > "$tmp/sum"
        run sha256sum -c "$tmp/sum"
        run tar -xzf "$tmp/$file" -C "$tmp" lazydocker
        mkdir -p "$HOME/.local/bin"
        [ ! -e "$lazydocker" ] || backup "$lazydocker"
        run install -m 755 "$tmp/lazydocker" "$lazydocker"
        rm -rf -- "$tmp"
        done_packages+=("lazydocker $lazydocker_version")
    fi
    # tealdeer needs its page cache once; later updates are `tldr --update`.
    # Optional: a failure here is a warning, not a stop.
    if command -v tldr >/dev/null && [ ! -d "${XDG_CACHE_HOME:-$HOME/.cache}/tealdeer/tldr-pages" ]; then
        if run_logged tldr --update; then done_packages+=('tldr pages')
        else warnings+=('tldr --update failed (network?); run it later, tldr works without pages until then.'); fi
    fi
    # zoxide replaces zsh-z: carry the old directory history over, once, while
    # zoxide has no database of its own yet. ~/.z itself stays as it is.
    zoxide_db=${_ZO_DATA_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/zoxide}/db.zo
    if [ -s "$HOME/.z" ] && [ ! -e "$zoxide_db" ] && command -v zoxide >/dev/null; then
        # zoxide 0.9 (trixie) takes --from z PATH; 0.10 reads ~/.z itself.
        zoxide_help=$(zoxide import --help 2>/dev/null || true)
        case $zoxide_help in
            *--from*) zoxide_import=(zoxide import --from z "$HOME/.z") ;;
            *) zoxide_import=(zoxide import zsh-z) ;;
        esac
        if run_logged "${zoxide_import[@]}"; then done_packages+=('z history imported into zoxide')
        else warnings+=("importing ~/.z into zoxide failed; it's optional, see the log (${zoxide_import[*]})."); fi
    fi
    if [ "${#done_packages[@]}" -eq 0 ]; then
        passed "all $package_count installed, lazydocker $lazydocker_version"
    else
        changes+=("packages: ${done_packages[*]}")
        passed "installed ${done_packages[*]}"
    fi
fi

if [ "${answer[ohmyzsh]}" = yes ]; then
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
        if [ -d "$dir/.git" ]; then
            # Earlier versions of this setup copied a tmux config over a file
            # oh-my-zsh owns; keep a backup, then give omz its file back.
            mapfile -t modified < <(git -C "$dir" diff --name-only)
            for path in "${modified[@]}"; do
                [ -n "$path" ] || continue
                backup "$dir/$path" copy
                run git -C "$dir" checkout -- "$path"
                changes+=("$name: restored $path (local copy in backup)")
            done
            # Ask the remote first: pulling when nothing is new still writes
            # FETCH_HEAD/ORIG_HEAD, and a rerun should leave everything as it was.
            branch=$(git -C "$dir" symbolic-ref --short HEAD 2>/dev/null) || fail "$name in $dir is not on a branch."
            remote_head=$(git -C "$dir" ls-remote origin "refs/heads/$branch" 2>> "$log" | cut -f1 || true)
            [ -n "$remote_head" ] || fail "Cannot reach the $name repository."
            if [ "$remote_head" != "$(git -C "$dir" rev-parse HEAD)" ]; then
                run git -C "$dir" pull --ff-only --progress
                updated+=("$name")
            fi
        else
            [ ! -e "$dir" ] || backup "$dir"
            mkdir -p "$(dirname -- "$dir")"
            # The git settings oh-my-zsh's own installer uses, without running it
            # (umask 022 above keeps the clone free of group/other write bits).
            run git clone --progress --depth=1 \
                -c core.eol=lf -c core.autocrlf=false \
                -c fsck.zeroPaddedFilemode=ignore -c fetch.fsck.zeroPaddedFilemode=ignore \
                -c receive.fsck.zeroPaddedFilemode=ignore \
                "$url" "$dir"
            installed+=("$name")
        fi
    done
    result=''
    [ "${#installed[@]}" -eq 0 ] || result="installed ${installed[*]}"
    [ "${#updated[@]}" -eq 0 ] || result="${result:+$result; }updated ${updated[*]}"
    if [ -n "$result" ]; then changes+=("oh-my-zsh: $result"); else result='all up to date'; fi
    passed "$result"
fi

if [ "${answer[shell]}" = yes ] && [ "$skip_shell" = no ]; then
    step Shell 'zsh as login shell'
    zsh_path=$(command -v zsh) || fail 'zsh is not installed.'
    if [ "$login_shell" = "$zsh_path" ]; then
        passed "already $zsh_path"
    else
        sudo_ready
        if [ "$root_mode" = yes ]; then run chsh -s "$zsh_path" root
        else run sudo -n chsh -s "$zsh_path" "$(id -un)"; fi
        changes+=("login shell: $login_shell $arrow $zsh_path")
        passed "$login_shell $arrow $zsh_path"
    fi
fi

if [ "${answer[fonts]}" = yes ] && [ "$skip_fonts" = no ]; then
    step Fonts 'MesloLGS NF'
    [ "${#want_fontconfig[@]}" -eq 0 ] || { apt_install fontconfig; changes+=('apt: fontconfig'); }
    font_dir=$HOME/.local/share/fonts
    mkdir -p "$font_dir"
    new_fonts=0
    for font in "${!font_sha256[@]}"; do
        if [ -f "$font_dir/$font" ] && [ "$(sha256sum < "$font_dir/$font" | cut -d' ' -f1)" = "${font_sha256[$font]}" ]; then
            continue
        fi
        tmp=$(mktemp)
        run curl -fL --progress-bar -o "$tmp" "$fonts_url/${font// /%20}"
        [ "$(sha256sum < "$tmp" | cut -d' ' -f1)" = "${font_sha256[$font]}" ] || { rm -f -- "$tmp"; fail "Checksum mismatch for $font."; }
        [ ! -e "$font_dir/$font" ] || backup "$font_dir/$font"
        mv -- "$tmp" "$font_dir/$font"
        chmod 644 "$font_dir/$font"
        new_fonts=$((new_fonts + 1))
    done
    if [ "$new_fonts" -eq 0 ]; then
        passed 'all 4 installed'
    else
        if command -v fc-cache >/dev/null; then run fc-cache -f "$font_dir"
        else warnings+=('Font files installed; fc-cache is unavailable. Install fontconfig or refresh the font cache later.'); fi
        changes+=("fonts: $new_fonts MesloLGS NF files")
        passed "installed $new_fonts"
    fi
fi

if [ "${answer[links]}" = yes ]; then
    step Links "${#links[@]} dotfiles"
    linked=()
    for rel in "${links[@]}"; do
        source_file=$repo/linux/$rel
        dest=$HOME/$rel
        [ -f "$source_file" ] || fail "Missing in the repo: linux/$rel"
        [ "$(readlink -- "$dest" 2>/dev/null || true)" != "$source_file" ] || continue
        if [ -e "$dest" ] || [ -L "$dest" ]; then
            [ ! -d "$dest" ] || [ -L "$dest" ] || fail "~/$rel is a directory; nothing was replaced."
            bak=$dest.$stamp.bak
            # Never overwrite a backup; cp -P copies a symlink itself, not its target.
            if [ -e "$bak" ] || [ -L "$bak" ]; then fail "$bak already exists; nothing was replaced."; fi
            cp -P -p -- "$dest" "$bak" 2>> "$log" || fail "Backup of ~/$rel failed; nothing was replaced."
            backup "$dest"
            replaced+=("~/$rel -> $bak")
        fi
        mkdir -p "$(dirname -- "$dest")"
        ln -sn -- "$source_file" "$dest"
        printf 'link: %s -> %s\n' "$dest" "$source_file" >> "$log"
        linked+=("~/$rel")
    done
    if [ "${#linked[@]}" -eq 0 ]; then
        passed 'all linked'
    else
        changes+=("links: ${linked[*]}")
        passed "linked ${linked[*]}"
    fi
fi

if [ "${answer[mail]}" = yes ] && [ "$skip_mail" = no ]; then
    step NeoMutt 'mail client, theme and Neovim composer'
    mail_args=(yes)
    if [ "$admin_available" = yes ]; then mail_args+=(with-sudo)
    else mail_args+=(no-packages); fi
    run /usr/bin/python3 -u "$repo/tools/install-mail.py" "${mail_args[@]}"
    if command -v neomutt >/dev/null; then
        changes+=('NeoMutt: package and themed configuration checked; run nmutt')
        passed 'ready; launch nmutt (or neomutt)'
    else
        changes+=('NeoMutt: themed configuration prepared')
        warnings+=('NeoMutt is not installed; ask an administrator to install neomutt before running nmutt.')
        passed 'configuration ready; neomutt package still needed'
    fi
fi

# Remember this run for the next one; rewritten only when something differs.
new_state=$(printf 'commit=%s\n' "$new_commit"; for key in "${keys[@]}"; do printf '%s=%s\n' "$key" "${answer[$key]}"; done)
if [ "$new_state" != "$(cat "$state_file" 2>/dev/null || true)" ]; then
    printf '%s\n' "$new_state" > "$state_file"
fi

# --------------------------------------------------------------- summary ---
printf '\n'
if [ "${#changes[@]}" -eq 0 ]; then
    printf '  Nothing changed; everything was already in place.\n'
else
    printf '  Changed:\n'
    printf '    %s\n' "${changes[@]}"
fi
if [ "${#replaced[@]}" -gt 0 ]; then
    printf '  Replaced configs (originals kept):\n'
    printf '    %s\n' "${replaced[@]}"
fi
if [ "${#replaced[@]}" -gt 0 ] && [ "${#local_notes[@]}" -gt 0 ]; then
    printf '  %sCheck:%s\n' "$bold" "$reset"
    printf '    %s\n' "${local_notes[@]}"
fi
if [ "${#warnings[@]}" -gt 0 ]; then
    printf '  Warnings:\n'
    printf '    %s\n' "${warnings[@]}"
fi
[ -z "$backup_dir" ] || printf '  Backups: %s\n' "$backup_dir"
printf '  Log:     %s\n' "$log"
printf '\n  Done in %s. Open a new shell (exec zsh), then run %shelp-dots%s for the cheat sheet.\n' \
    "$(duration "$(($(date +%s) - started))")" "$bold" "$reset"
