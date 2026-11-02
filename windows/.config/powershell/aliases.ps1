# Aliases and small functions, dot-sourced by user_profile.ps1.

# Unix tools that ship with Git (less, grep, ...), scoop's Git first.
# Added once, so reloading the profile (. repo) doesn't grow PATH.
foreach ($gitBin in "$env:USERPROFILE\scoop\apps\git\current\usr\bin", "$env:ProgramFiles\Git\usr\bin") {
    if (Test-Path $gitBin) {
        if (($env:PATH -split ';') -notcontains $gitBin) { $env:PATH += ";$gitBin" }
        break
    }
}

Set-Alias -Name vim -Value nvim
Set-Alias -Name v -Value nvim
Set-Alias wo Write-Output
Set-Alias ll ls
Set-Alias lld ls

# Same file viewer as Linux (batcat on Debian).
if (Get-Command bat -CommandType Application -ErrorAction SilentlyContinue) {
    Set-Alias -Name bcat -Value bat
    Set-Alias -Name cat -Value bat
}

# Same listings as on Linux
function el { eza -l @args }
function es { eza @args }
function esa { eza -la @args }

# Total Commander: TC Ultima Prime if installed, otherwise Chocolatey's
foreach ($tcExe in "${env:ProgramFiles(x86)}\Total Commander\TCUP64.exe",
                   "$env:COMMANDER_PATH\TOTALCMD64.EXE",
                   "$env:ProgramFiles\totalcmd\TOTALCMD64.EXE") {
    if ($tcExe -and (Test-Path $tcExe)) { Set-Alias tc $tcExe; break }
}

# Reload the profile: . repo
function repo {
    @(
        $Profile.AllUsersAllHosts,
        $Profile.AllUsersCurrentHost,
        $Profile.CurrentUserAllHosts,
        $Profile.CurrentUserCurrentHost
    ) | ForEach-Object {
        if (Test-Path $_) {
            Write-Verbose "Running $_"
            . $_
        }
    }
}

# Edit aliases / profile
function eal {
    nvim "$env:USERPROFILE\.config\powershell\aliases.ps1"
    Write-Output 'Please run . repo to reload the profile'
}

function epro {
    nvim "$env:USERPROFILE\.config\powershell\user_profile.ps1"
    Write-Output 'Please run . repo to reload the profile'
}

function which ($command) {
    Get-Command -Name $command -ErrorAction SilentlyContinue |
        Select-Object -ExpandProperty Path -ErrorAction SilentlyContinue
}

function .. { Set-Location .. }

# Cheat sheet for this setup; install.ps1 sets DOTFILES to the repo
function help-dots {
    if (-not $env:DOTFILES) { Write-Warning 'DOTFILES is not set; run install.ps1 again.'; return }
    $helpFile = Join-Path $env:DOTFILES 'HELP.md'
    if (Get-Command bat -ErrorAction SilentlyContinue) {
        bat --theme=ansi --style=plain --language=markdown --paging=always $helpFile
    } else {
        Get-Content $helpFile | more
    }
}
