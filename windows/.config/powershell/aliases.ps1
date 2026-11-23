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
# arguments; "nssh" picks from the list, "nssh list" shows it numbered with a
# name and when it was last used (most recent first, then the hosts in
# ~\.ssh\config). "nssh 3" or "nssh name" connects, "nssh r 3 name" names an
# entry, "nssh d 3" deletes one. A failed connection (ssh exits 255) is not
# remembered. List: %LOCALAPPDATA%\nssh\hosts, one "time<TAB>name<TAB>args".
function Get-NsshEntry {
    $file = Join-Path $env:LOCALAPPDATA 'nssh\hosts'
    $entries = New-Object System.Collections.Generic.List[object]
    if (Test-Path -LiteralPath $file) {
        foreach ($l in Get-Content -LiteralPath $file) {
            if (-not $l) { continue }
            $p = $l -split "`t", 3
            if ($p.Count -eq 3) { $entries.Add([pscustomobject]@{ When = [long]$p[0]; Name = $p[1]; Args = $p[2] }) }
            else { $entries.Add([pscustomobject]@{ When = 0L; Name = ''; Args = $l }) }
        }
    }
    $config = Join-Path $HOME '.ssh\config'
    if (Test-Path -LiteralPath $config) {
        foreach ($l in Get-Content -LiteralPath $config) {
            if ($l -notmatch '^\s*Host\s+(.+)$') { continue }
            foreach ($h in ($Matches[1].Trim() -split '\s+')) {
                if ($h -match '[*?!]' -or ($entries | Where-Object { $_.Args -eq $h -or $_.Name -eq $h })) { continue }
                $entries.Add([pscustomobject]@{ When = -1L; Name = $h; Args = $h })
            }
        }
    }
    return , $entries
}
function Save-NsshEntry($Entries) {
    $file = Join-Path $env:LOCALAPPDATA 'nssh\hosts'
    New-Item -ItemType Directory -Force -Path (Split-Path $file) | Out-Null
    $lines = @($Entries | Where-Object { $_.When -ge 0 } | Sort-Object -Property When -Descending -Stable |
        ForEach-Object { "$($_.When)`t$($_.Name)`t$($_.Args)" })
    Set-Content -LiteralPath $file -Value $lines
}
function Format-NsshAgo([long]$When) {
    if ($When -lt 0) { return 'ssh config' }
    if ($When -eq 0) { return '-' }
    $d = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds() - $When
    if ($d -lt 60) { return 'just now' }
    if ($d -lt 3600) { return "$([math]::Floor($d / 60))m ago" }
    if ($d -lt 86400) { return "$([math]::Floor($d / 3600))h ago" }
    if ($d -lt 7 * 86400) { return "$([math]::Floor($d / 86400))d ago" }
    return [DateTimeOffset]::FromUnixTimeSeconds($When).LocalDateTime.ToString('yyyy-MM-dd')
}
function Show-Nssh($Entries) {
    $w = [math]::Max(4, (@($Entries | ForEach-Object { $_.Name.Length }) + 0 | Measure-Object -Maximum).Maximum)
    for ($i = 0; $i -lt $Entries.Count; $i++) {
        $e = $Entries[$i]
        '{0,3}  {1}  {2,-10}  {3}' -f ($i + 1), $e.Name.PadRight($w), (Format-NsshAgo $e.When), $e.Args
    }
}
function Get-NsshIndex($Entries, [string]$Key) {
    if ($Key -match '^\d+$' -and [int]$Key -ge 1 -and [int]$Key -le $Entries.Count) { return [int]$Key - 1 }
    if ($Key -notmatch '^\d+$') {
        for ($i = 0; $i -lt $Entries.Count; $i++) { if ($Entries[$i].Name -eq $Key) { return $i } }
    }
    Write-Host "nssh: no entry $Key (see nssh list)"
    return -1
}
function nssh {
    $entries = Get-NsshEntry
    if ($args.Count -eq 1 -and $args[0] -eq 'list') { Show-Nssh $entries; return }
    if ($args.Count -eq 3 -and $args[0] -eq 'r') {
        $i = Get-NsshIndex $entries $args[1]; if ($i -lt 0) { return }
        $name = [string]$args[2]
        if ($name -match '\s' -or $name -match '^\d+$' -or $name -in 'list', 'r', 'd') { Write-Host 'nssh: a name is one word, not a number or list/r/d'; return }
        if ($entries | Where-Object { $_.Name -eq $name -and $_ -ne $entries[$i] }) { Write-Host "nssh: $name is taken"; return }
        $entries[$i].Name = $name
        if ($entries[$i].When -lt 0) { $entries[$i].When = 0L }
        Save-NsshEntry $entries; Show-Nssh (Get-NsshEntry); return
    }
    if ($args.Count -eq 2 -and $args[0] -eq 'd') {
        $i = Get-NsshIndex $entries $args[1]; if ($i -lt 0) { return }
        if ($entries[$i].When -lt 0) { Write-Host "nssh: $($entries[$i].Args) comes from ~\.ssh\config; remove it there"; return }
        $entries.RemoveAt($i)
        Save-NsshEntry $entries; Show-Nssh (Get-NsshEntry); return
    }
    $sshArgs = @($args)
    $i = -1
    if ($args.Count -eq 0) {
        if ($entries.Count -eq 0) { Write-Host 'nssh: nothing remembered yet; "nssh user@host" connects and remembers it.'; return }
        if (Get-Command fzf -ErrorAction SilentlyContinue) {
            $pick = Show-Nssh $entries | fzf --no-sort --reverse --height=40% --prompt='nssh> '
            if (-not $pick) { return }
            $key = ($pick.Trim() -split '\s+')[0]
        } else {
            Show-Nssh $entries | Write-Host
            $key = Read-Host 'Number'
        }
        $i = Get-NsshIndex $entries $key; if ($i -lt 0) { return }
    } elseif ($args.Count -eq 1) {
        $first = [string]$args[0]  # $args inside a script block is the block's own
        if ($first -match '^\d+$' -or ($entries | Where-Object { $_.Name -eq $first })) {
            $i = Get-NsshIndex $entries $first; if ($i -lt 0) { return }
        }
    }
    if ($i -ge 0) { $sshArgs = @($entries[$i].Args -split '\s+' | Where-Object { $_ }) }
    & ssh @sshArgs
    if ($LASTEXITCODE -ne 255) {
        $line = $sshArgs -join ' '
        $name = ''
        $old = $entries | Where-Object { $_.Args -eq $line } | Select-Object -First 1
        if ($old) { $name = $old.Name; [void]$entries.Remove($old) }
        $entries.Insert(0, [pscustomobject]@{ When = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds(); Name = $name; Args = $line })
        Save-NsshEntry $entries
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
