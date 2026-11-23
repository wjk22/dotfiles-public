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

# nssh: ssh that remembers. "nssh [ssh options] host" connects and keeps the
# arguments at the top of its list; "nssh" alone picks from that list (most
# recent first, then the hosts in ~\.ssh\config); "nssh list" prints it.
# A connection that fails (ssh exits 255) is not remembered.
function Get-NsshList {
    $file = Join-Path $env:LOCALAPPDATA 'nssh\hosts'
    $seen = @{}
    $out = New-Object System.Collections.Generic.List[string]
    if (Test-Path -LiteralPath $file) {
        foreach ($l in Get-Content -LiteralPath $file) { if ($l -and -not $seen[$l]) { $seen[$l] = 1; $out.Add($l) } }
    }
    $config = Join-Path $HOME '.ssh\config'
    if (Test-Path -LiteralPath $config) {
        foreach ($l in Get-Content -LiteralPath $config) {
            if ($l -match '^\s*Host\s+(.+)$') {
                foreach ($h in ($Matches[1].Trim() -split '\s+')) {
                    if ($h -notmatch '[*?!]' -and -not $seen[$h]) { $seen[$h] = 1; $out.Add($h) }
                }
            }
        }
    }
    $out
}
function nssh {
    $file = Join-Path $env:LOCALAPPDATA 'nssh\hosts'
    if ($args.Count -eq 1 -and $args[0] -eq 'list') { Get-NsshList; return }
    $sshArgs = @($args)
    if ($sshArgs.Count -eq 0) {
        $list = @(Get-NsshList)
        if ($list.Count -eq 0) { Write-Host 'nssh: nothing remembered yet; "nssh user@host" connects and remembers it.'; return }
        if (Get-Command fzf -ErrorAction SilentlyContinue) {
            $pick = $list | fzf --no-sort --reverse --height=40% --prompt='nssh> '
        } else {
            for ($i = 0; $i -lt $list.Count; $i++) { Write-Host ('{0,3}  {1}' -f ($i + 1), $list[$i]) }
            $n = Read-Host 'Number'
            $pick = if ($n -match '^\d+$' -and [int]$n -ge 1 -and [int]$n -le $list.Count) { $list[[int]$n - 1] } else { '' }
        }
        if (-not $pick) { return }
        $sshArgs = @($pick -split '\s+' | Where-Object { $_ })
    }
    & ssh @sshArgs
    if ($LASTEXITCODE -ne 255) {
        $line = $sshArgs -join ' '
        New-Item -ItemType Directory -Force -Path (Split-Path $file) | Out-Null
        $old = if (Test-Path -LiteralPath $file) { @(Get-Content -LiteralPath $file | Where-Object { $_ -and $_ -ne $line }) } else { @() }
        Set-Content -LiteralPath $file -Value (@($line) + $old)
    }
}

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
