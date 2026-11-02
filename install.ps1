<#
  Install or update the dotfiles on Windows. Safe to run again: it asks first,
  changes only what differs and backs up what it replaces.

    powershell -ExecutionPolicy Bypass -File .\install.ps1 [-Yes]

  Run it as your normal user. Chocolatey (system installs) runs once through
  UAC via windows\install-admin.ps1; everything else is per user.
#>
[CmdletBinding()]
param(
    # Accept every suggested answer and apply without asking.
    [switch]$Yes,
    [Alias('h')][switch]$Help
)
Set-StrictMode -Version 2
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$repo = $PSScriptRoot
$started = Get-Date

function Show-Usage {
    Write-Host @'
Usage: .\install.ps1 [-Yes] [-Help]

  Windows 10/11: Chocolatey (one UAC prompt), scoop tools,
  PowerShell modules, fonts and the PowerShell config.
  On Debian or WSL, run ./install.sh instead.

  -Yes      accept every suggested answer and apply without asking
'@
}

if ($Help) { Show-Usage; exit 0 }

# ----------------------------------------------------------------- output ---
# The script stays ASCII (Windows PowerShell reads BOM-less files as ANSI);
# symbols are built from code points, and only in Windows Terminal.
$fancy = [bool]$env:WT_SESSION
if ($fancy) {
    [Console]::OutputEncoding = [Text.Encoding]::UTF8
    $ok = [string][char]0x2713; $failed = [string][char]0x2717; $arrow = [string][char]0x2192
    $title = [char]::ConvertFromUtf32(0x1F407) + ' dotfiles ' + [char]0x00B7 + ' install windows'
} else {
    $ok = 'OK'; $failed = 'FAIL'; $arrow = '->'; $title = 'dotfiles - install windows'
}

function Format-Duration([datetime]$Since) {
    $seconds = [int]((Get-Date) - $Since).TotalSeconds
    if ($seconds -ge 60) { return '{0}m {1}s' -f [int][math]::Floor($seconds / 60), ($seconds % 60) }
    return "${seconds}s"
}
function Stop-Install([string]$Text) {
    Write-Host ('  {0} ' -f $failed) -ForegroundColor Red -NoNewline
    Write-Host $Text
    exit 1
}
function Write-Check([string]$Name, [string]$Detail) {
    Write-Host ('  {0} ' -f $ok) -ForegroundColor Green -NoNewline
    Write-Host ('{0,-12} {1}' -f $Name, $Detail)
}

# ----------------------------------------------------------------- checks ---
# Nothing is written before these pass, not even the log.
Write-Host ''
Write-Host $title
Write-Host ''

if ($env:OS -ne 'Windows_NT') { Stop-Install 'This is not Windows; on Debian or in WSL run ./install.sh.' }
$build = [Environment]::OSVersion.Version.Build
# Per-user fonts and junctions without admin need Windows 10 1809 or newer.
if ($build -lt 17763) { Stop-Install "Windows build $build is too old; this needs Windows 10 1809 (17763) or newer." }
if ($PSVersionTable.PSVersion -lt [version]'5.1') {
    Stop-Install "PowerShell $($PSVersionTable.PSVersion) is too old; this needs Windows PowerShell 5.1 or PowerShell 7."
}
$osName = (Get-CimInstance -ClassName Win32_OperatingSystem).Caption
Write-Check 'System' "$osName (build $build), PowerShell $($PSVersionTable.PSVersion)"

$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if ($principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Stop-Install 'Run this as your normal user, not as administrator; it asks for admin rights (UAC) once, only for Chocolatey.'
}
Write-Check 'User' "$env:USERNAME, not elevated"

$onNetworkPath = $repo.StartsWith('\\')
$newCommit = ''
if (Get-Command git -ErrorAction SilentlyContinue) {
    $dirty = & git -C $repo status --porcelain 2>$null
    if ($LASTEXITCODE -ne 0) { Stop-Install "$repo is not a git checkout; clone the repo and run it from there." }
    if ($dirty) {
        $files = ($dirty | ForEach-Object { $_.Substring(3) }) -join ' '
        Stop-Install "The repo has uncommitted changes; commit or stash them first ($files)."
    }
    $newCommit = (& git -C $repo rev-parse HEAD).Trim()
    $repoDetail = "clean at $($newCommit.Substring(0, 7))"
} else {
    $repoDetail = 'git not installed yet (scoop brings it), clean check skipped'
}
if ($onNetworkPath) { $repoDetail += '; network path, so the config is copied, not linked' }
Write-Check 'Repo' $repoDetail

try { $packageConfig = & (Join-Path $repo 'windows\read-packages.ps1') }
catch { Stop-Install "Could not read package config: $($_.Exception.Message)" }
$systemPackages = @($packageConfig.ChocolateySystem)
$appPackages = @($packageConfig.ChocolateyApps)
$scoopApps = @($packageConfig.Scoop)

$haveChoco = Test-Path (Join-Path $env:ProgramData 'chocolatey\bin\choco.exe')
$scoopRoot = if ($env:SCOOP) { $env:SCOOP } else { Join-Path $env:USERPROFILE 'scoop' }
$haveScoop = Test-Path (Join-Path $scoopRoot 'shims\scoop.ps1')
Write-Check 'Managers' ('Chocolatey {0}, scoop {1}' -f @(
    $(if ($haveChoco) { 'present' } else { 'missing (installed in step 1)' }),
    $(if ($haveScoop) { 'present' } else { 'missing (installed in step 3)' })))

# Old installs (e.g. git, gsudo, wox from the earlier README) also on Chocolatey:
# both work, PATH order decides which one runs. Reported only, never removed.
$overlapIds = @($scoopApps)
if ($scoopApps -contains 'git') { $overlapIds += @('git.install', 'git.portable') }
$chocoOverlap = @()
$chocoLib = Join-Path $env:ProgramData 'chocolatey\lib'
if (Test-Path $chocoLib) {
    $chocoOverlap = @(Get-ChildItem -LiteralPath $chocoLib -Directory | Where-Object { $overlapIds -contains $_.Name } | ForEach-Object { $_.Name })
}
if ($chocoOverlap.Count -gt 0) {
    Write-Host ('  ! {0,-12} Chocolatey also has {1}; scoop installs these too (not removed, see the end)' -f 'Overlap', ($chocoOverlap -join ' ')) -ForegroundColor Yellow
}

$systemDrive = Get-PSDrive -Name $env:SystemDrive.TrimEnd(':')
if ($systemDrive.Free -lt 5GB) {
    Stop-Install ('Only {0:N1} GB free on {1}; the install needs at least 5 GB.' -f ($systemDrive.Free / 1e9), $env:SystemDrive)
}
Write-Check 'Disk' ('{0:N1} GB free on {1}' -f ($systemDrive.Free / 1e9), $env:SystemDrive)

# ------------------------------------------------------------------ state ---
$stateDir = Join-Path $env:LOCALAPPDATA 'dotfiles'
$stateFile = Join-Path $stateDir 'windows.state'
$state = @{}
if (Test-Path $stateFile) {
    foreach ($line in Get-Content -LiteralPath $stateFile) {
        if ($line -match '^([^=]+)=(.*)$') { $state[$Matches[1]] = $Matches[2] }
    }
}

Write-Host ''
$oldCommit = if ($state.ContainsKey('commit')) { $state['commit'] } else { '' }
$newShort = if ($newCommit) { $newCommit.Substring(0, 7) } else { 'this checkout' }
if (-not $oldCommit) {
    Write-Host "  not installed yet $arrow $newShort"
} elseif ($oldCommit -eq $newCommit) {
    Write-Host "  $newShort, nothing new in this checkout"
} else {
    $line = "  $($oldCommit.Substring(0, 7)) $arrow $newShort"
    if ($newCommit) {
        & git -C $repo merge-base --is-ancestor $oldCommit $newCommit 2>$null
        if ($LASTEXITCODE -eq 0) {
            $count = [int](& git -C $repo rev-list --count "$oldCommit..$newCommit")
            $line += $(if ($count -eq 1) { ' - 1 new commit' } else { " - $count new commits" })
        }
    }
    Write-Host $line
}

# -------------------------------------------------------------- questions ---
$modules = @('PSReadLine', 'Terminal-Icons', 'PSFzf')
$fontsUrl = 'https://github.com/romkatv/powerlevel10k-media/raw/145eb9fbc2f42ee408dacd9b22d8e6e0e553f83d'
$fontSha256 = [ordered]@{
    'MesloLGS NF Regular.ttf'     = 'D97946186E97F8D7C0139E8983ABF40A1D2D086924F2C5DBF1C29BD8F2C6E57D'
    'MesloLGS NF Bold.ttf'        = 'B6C0199CF7C7483C8343EA020658925E6DE0AEB318B89908152FCB4D19226003'
    'MesloLGS NF Italic.ttf'      = '6F357BCBE2597704E157A915625928BCA38364A89C22A4AC36E7A116DCD392EF'
    'MesloLGS NF Bold Italic.ttf' = '56B4131ADECEC052C4B324EFB818DD326D586DBC316FC68F98F1CAE2EB8D1220'
}
$pwsh = Join-Path $env:ProgramFiles 'PowerShell\7\pwsh.exe'
$configLink = Join-Path $env:USERPROFILE '.config\powershell'
$configSource = Join-Path $repo 'windows\.config\powershell'

$questions = @(
    @{ Key = 'choco'; Label = 'Use Chocolatey for system apps (one UAC prompt)'; Detail = "$systemPackages, PSWindowsUpdate module; no skips all Chocolatey installs" },
    @{ Key = 'apps'; Label = 'Optional apps via Chocolatey (same UAC prompt)'; Detail = ($appPackages -join ' ') },
    @{ Key = 'scoop'; Label = 'Tools via scoop (per user)'; Detail = ($scoopApps -join ' ') },
    @{ Key = 'modules'; Label = 'PowerShell 7 modules (current user)'; Detail = ($modules -join ' ') },
    @{ Key = 'fonts'; Label = 'MesloLGS NF fonts (per user)'; Detail = 'set them in Windows Terminal afterwards' },
    @{ Key = 'config'; Label = 'PowerShell config (backup first)'; Detail = 'junction ~\.config\powershell, $PROFILE bootstrap, DOTFILES variable' }
)
# ------------------------------------------------------- existing config ---
# Looked at before anything changes: what gets replaced, its .bak, and lines
# that exist only in the user's copy. Links are renamed, never written through.
$stamp = (Get-Date).ToString('yyyyMMdd-HHmmss')
$pwshVersion = $null
$profilePath = $null
if (Test-Path $pwsh) {
    try {
        $pwshVersion = [version]((& $pwsh -NoProfile -NonInteractive -Command '$PSVersionTable.PSVersion.ToString()' | Out-String).Trim() -replace '-.*$', '')
        $profilePath = (& $pwsh -NoProfile -NonInteractive -Command '$PROFILE.CurrentUserCurrentHost' | Out-String).Trim()
    } catch {
        Stop-Install "$pwsh doesn't answer ($($_.Exception.Message)); repair PowerShell 7 or answer no to steps 4 and 6."
    }
}
$bootstrapFile = Join-Path $repo 'windows\Microsoft.PowerShell_profile.ps1'

# Line numbers of the non-blank, non-comment lines of $UserFile that $RepoFile
# doesn't have. Numbers only: the lines can hold paths, tokens or passwords.
function Get-UserOnlyLine([string]$UserFile, [string]$RepoFile) {
    $repoLines = @{}
    if (Test-Path -LiteralPath $RepoFile) { foreach ($l in Get-Content -LiteralPath $RepoFile) { $repoLines[$l.Trim()] = $true } }
    $n = 0
    foreach ($l in Get-Content -LiteralPath $UserFile) {
        $n++
        $t = $l.Trim()
        if ($t -and -not $t.StartsWith('#') -and -not $repoLines.ContainsKey($t)) { $n }
    }
}
function Add-LocalNote([string]$Label, [string]$UserFile, [string]$RepoFile, [string]$Kept) {
    $lines = @(Get-UserOnlyLine $UserFile $RepoFile)
    if ($lines.Count -eq 0) { return }
    $numbers = ($lines | Select-Object -First 12) -join ', '
    if ($lines.Count -gt 12) { $numbers += ', ...' }
    $script:localNotes += "${Label}: $($lines.Count) line(s) not in the new setup (line $numbers). $Kept; move what you still need into ~\.config\powershell.local.ps1."
}
# Check ancestors, not just the item being replaced. A junction at .config or
# above $PROFILE must not redirect writes into another directory's contents.
function Get-ParentProblem([string]$Path) {
    $parent = Split-Path -Parent $Path
    while ($parent) {
        $item = Get-Item -LiteralPath $parent -Force -ErrorAction SilentlyContinue
        if ($item -and ($item.LinkType -or -not $item.PSIsContainer)) {
            return "$parent is a link or not a folder; move it away first."
        }
        $next = Split-Path -Parent $parent
        if ($next -eq $parent) { break }
        $parent = $next
    }
    return ''
}
function Get-ConfigProblem {
    foreach ($path in @($configLink, $profilePath)) {
        if (-not $path) { continue }
        $problem = Get-ParentProblem $path
        if ($problem) { return $problem }
    }
    $item = Get-Item -LiteralPath $configLink -Force -ErrorAction SilentlyContinue
    if ($item -and -not $item.LinkType -and -not $item.PSIsContainer) {
        return '~\.config\powershell is a file; move it away first.'
    }
    if ($profilePath) {
        $item = Get-Item -LiteralPath $profilePath -Force -ErrorAction SilentlyContinue
        if ($item -and $item.PSIsContainer) { return "$profilePath is a folder; move it away first." }
    }
    return ''
}
# Shared by the plan and apply step so an unchanged UNC copy is a no-op in both.
function Test-ConfigCopy {
    if (-not $onNetworkPath) { return $false }
    $item = Get-Item -LiteralPath $configLink -Force -ErrorAction SilentlyContinue
    if (-not $item -or $item.LinkType -or -not $item.PSIsContainer) { return $false }
    foreach ($file in Get-ChildItem -LiteralPath $configSource -File) {
        $copied = Join-Path $configLink $file.Name
        $copy = Get-Item -LiteralPath $copied -Force -ErrorAction SilentlyContinue
        if (-not $copy -or $copy.LinkType -or $copy.PSIsContainer) { return $false }
        if ((Get-FileHash -LiteralPath $copied).Hash -ne (Get-FileHash -LiteralPath $file.FullName).Hash) { return $false }
    }
    return $true
}
function Get-ConfigPlan {
    $script:replacePlan = @(); $script:localNotes = @()
    if (Get-ConfigProblem) { return }
    $item = Get-Item -LiteralPath $configLink -Force -ErrorAction SilentlyContinue
    if ($item) {
        $target = if ($item.LinkType) { @($item.Target)[0] } else { $null }
        if ($item.LinkType -eq 'Junction' -and $target -and $target.TrimEnd('\') -eq $configSource.TrimEnd('\')) {
            # already linked to this repo
        } elseif ($item.LinkType) {
            $script:replacePlan += "~\.config\powershell ($($item.LinkType) to $target) -> renamed to ~\.config\powershell.$stamp.bak, target untouched"
        } elseif (Test-ConfigCopy) {
            # The apply step keeps this identical copy too.
        } elseif ($item.PSIsContainer) {
            $script:replacePlan += "~\.config\powershell (folder) -> backup ~\.config\powershell.$stamp.bak"
            foreach ($name in 'aliases.ps1', 'user_profile.ps1') {
                $userFile = Join-Path $configLink $name
                if (Test-Path -LiteralPath $userFile) {
                    Add-LocalNote -Label "~\.config\powershell\$name" -UserFile $userFile -RepoFile (Join-Path $configSource $name) -Kept "Kept in ~\.config\powershell.$stamp.bak"
                }
            }
        } else {
            $script:replacePlan += "~\.config\powershell is a file; move it away first."
        }
    }
    # The old layout kept the aliases outside the folder; the new profile no longer loads them.
    $oldAliases = Join-Path $env:USERPROFILE '.config\aliases.ps1'
    if (Test-Path -LiteralPath $oldAliases) {
        Add-LocalNote -Label '~\.config\aliases.ps1 (old layout, no longer loaded)' -UserFile $oldAliases -RepoFile (Join-Path $configSource 'aliases.ps1') -Kept 'The file stays where it is'
    }
    if ($profilePath -and (Test-Path -LiteralPath $profilePath)) {
        $profileItem = Get-Item -LiteralPath $profilePath -Force
        if ($profileItem.LinkType) {
            $script:replacePlan += "`$PROFILE ($($profileItem.LinkType) to $(@($profileItem.Target)[0])) -> renamed to $profilePath.$stamp.bak, target untouched"
        } elseif ((Get-Content -LiteralPath $profilePath -Raw) -ne (Get-Content -LiteralPath $bootstrapFile -Raw)) {
            $script:replacePlan += "`$PROFILE $profilePath -> backup $profilePath.$stamp.bak"
            Add-LocalNote -Label '$PROFILE' -UserFile $profilePath -RepoFile $bootstrapFile -Kept "Kept in $profilePath.$stamp.bak"
        }
    }
}
$script:replacePlan = @(); $script:localNotes = @()
Get-ConfigPlan
function Show-ConfigPlan {
    if ($answer['config'] -ne 'yes') { return }
    if ($script:replacePlan.Count -gt 0) {
        Write-Host ''
        Write-Host "  Existing config that step 6 replaces (also kept in ~\.dotfiles-backup\$stamp\):"
        foreach ($entry in $script:replacePlan) { Write-Host "    $entry" }
    }
    if ($script:localNotes.Count -gt 0) {
        Write-Host ''
        Write-Host '  Check: ' -ForegroundColor Yellow -NoNewline
        Write-Host 'machine-local settings are not carried over automatically.'
        foreach ($note in $script:localNotes) { Write-Host "    $note" }
    }
}

$answer = @{}
foreach ($q in $questions) {
    $answer[$q.Key] = 'yes'
    if ($state.ContainsKey($q.Key) -and @('yes', 'no') -contains $state[$q.Key]) { $answer[$q.Key] = $state[$q.Key] }
}

function Read-Answer([string]$Prompt) {
    $reply = Read-Host -Prompt $Prompt
    if ($null -eq $reply) { Stop-Install 'Input ended; nothing was changed.' }
    return $reply.Trim()
}

if (-not $Yes) {
    if ([Console]::IsInputRedirected) { Stop-Install 'No terminal to ask questions on; run it in a terminal or add -Yes.' }
    Write-Host ''
    Write-Host '  Enter accepts the suggestion in brackets, q quits.'
    Write-Host ''
    for ($i = 0; $i -lt $questions.Count; $i++) {
        $q = $questions[$i]
        if ($q.Key -eq 'apps' -and $answer['choco'] -eq 'no') {
            $answer['apps'] = 'no'
            continue
        }
        Write-Host ('  {0}. {1}' -f ($i + 1), $q.Label)
        Write-Host ('     {0}' -f $q.Detail)
        while ($true) {
            $hint = if ($answer[$q.Key] -eq 'yes') { 'Y/n' } else { 'y/N' }
            $reply = Read-Answer "     [$hint]"
            if ($reply -eq '') { break }
            if ($reply -match '^(y|yes)$') { $answer[$q.Key] = 'yes'; break }
            if ($reply -match '^(n|no)$') { $answer[$q.Key] = 'no'; break }
            if ($reply -match '^q$') { Write-Host ''; Write-Host '  Nothing was changed.'; exit 0 }
        }
    }
}

# A plan that would fail half-way is refused before anything changes.
function Test-Plan {
    $needsPwsh = $answer['modules'] -eq 'yes' -or $answer['config'] -eq 'yes'
    $installsPwsh = $answer['choco'] -eq 'yes' -and ($systemPackages -contains 'powershell-core' -or ($answer['apps'] -eq 'yes' -and $appPackages -contains 'powershell-core'))
    if ($needsPwsh -and -not $installsPwsh -and -not (Test-Path $pwsh)) {
        return 'PowerShell 7 is missing; include powershell-core in a selected Chocolatey group, install it first, or disable steps 4 and 6.'
    }
    if ($answer['modules'] -eq 'yes' -and -not $installsPwsh -and $pwshVersion -and $pwshVersion -lt [version]'7.4') {
        return "PowerShell $pwshVersion is too old for the modules step (needs 7.4+); include powershell-core in a selected Chocolatey group, update it first, or disable step 4."
    }
    if ($answer['scoop'] -eq 'yes' -and $scoopApps.Count -gt 0 -and $scoopApps -notcontains 'git' -and -not (Get-Command git -ErrorAction SilentlyContinue)) {
        return 'Scoop bucket updates need Git; add git to the Scoop group or install it first.'
    }
    # Backups never go through a link.
    $backupParent = Get-Item -LiteralPath (Join-Path $env:USERPROFILE '.dotfiles-backup') -Force -ErrorAction SilentlyContinue
    if ($backupParent -and ($backupParent.LinkType -or -not $backupParent.PSIsContainer)) {
        return '~\.dotfiles-backup is a link or not a folder; move it away first, backups never go through a link.'
    }
    if ($answer['config'] -eq 'yes') {
        $problem = Get-ConfigProblem
        if ($problem) { return $problem }
    }
    return ''
}

while ($true) {
    # Declining Chocolatey also disables its optional apps, including saved answers.
    if ($answer['choco'] -eq 'no') { $answer['apps'] = 'no' }
    Write-Host ''
    for ($i = 0; $i -lt $questions.Count; $i++) {
        Write-Host ('  {0}. {1,-52} {2}' -f ($i + 1), $questions[$i].Label, $answer[$questions[$i].Key])
    }
    Show-ConfigPlan
    $problem = Test-Plan
    if ($problem) {
        Write-Host ''
        Write-Host ('  {0} ' -f $failed) -ForegroundColor Red -NoNewline
        Write-Host $problem
        if ($Yes) { exit 1 }
    } elseif ($Yes) {
        break
    }
    Write-Host ''
    $reply = Read-Answer '  Number to change, a to apply, q to quit'
    if ($reply -match '^a$' -and -not $problem) { break }
    if ($reply -match '^q$') { Write-Host ''; Write-Host '  Nothing was changed.'; exit 0 }
    if ($reply -match '^[1-9]$' -and [int]$reply -le $questions.Count) {
        $key = $questions[[int]$reply - 1].Key
        if ($key -eq 'apps' -and $answer['choco'] -eq 'no') {
            Write-Host '  Optional apps are skipped because Chocolatey is disabled.'
            continue
        }
        $answer[$key] = if ($answer[$key] -eq 'yes') { 'no' } else { 'yes' }
    }
}

# -------------------------------------------------------------------- log ---
$logDir = Join-Path $stateDir 'logs'
New-Item -ItemType Directory -Path $logDir -Force | Out-Null
$log = Join-Path $logDir ('install-windows-{0}.log' -f (Get-Date).ToUniversalTime().ToString("yyyyMMdd'T'HHmmss'Z'"))
if (Test-Path $log) { Stop-Install "Another run is writing $log; wait a second and try again." }
"dotfiles install windows, $((Get-Date).ToUniversalTime().ToString('s'))Z, $newCommit" | Out-File -LiteralPath $log -Encoding utf8
Get-ChildItem -LiteralPath $logDir -Filter 'install-windows-*.log' | Sort-Object Name -Descending |
    Select-Object -Skip 10 | Remove-Item -Force

$backupRoot = Join-Path $env:USERPROFILE ".dotfiles-backup\$stamp"
$script:backupDir = ''
# Moves (or copies with -Copy) one path into this run's backup.
function Backup-Item([string]$Path, [switch]$Copy) {
    $home_ = $env:USERPROFILE.TrimEnd('\') + '\'
    $rel = if ($Path.StartsWith($home_, [StringComparison]::OrdinalIgnoreCase)) { $Path.Substring($home_.Length) } else { $Path.Replace(':', '') }
    $script:backupDir = $backupRoot
    $dest = Join-Path $backupRoot $rel
    if (Test-Path -LiteralPath $dest) { Stop-Step "$dest already exists; not overwriting a backup." }
    try {
        New-Item -ItemType Directory -Path (Split-Path -Parent $dest) -Force -ErrorAction Stop | Out-Null
        if ($Copy) { Copy-Item -LiteralPath $Path -Destination $dest -Recurse -ErrorAction Stop }
        else { Move-Item -LiteralPath $Path -Destination $dest -ErrorAction Stop }
    } catch {
        Stop-Step "Backup of $Path failed ($($_.Exception.Message)); nothing was replaced."
    }
    Add-Content -LiteralPath $log -Value "backup: $Path -> $dest" -Encoding UTF8
}
# The original next to itself as <path>.<stamp>.bak, before anything changes.
# A link is renamed (the link itself, never its target); a file or folder is copied.
function Save-Bak([string]$Path) {
    $bak = "$Path.$stamp.bak"
    if (Test-Path -LiteralPath $bak) { Stop-Step "$bak already exists; not overwriting a backup." }
    try {
        $item = Get-Item -LiteralPath $Path -Force -ErrorAction Stop
        # LinkType is evaluated against the old path; save it before renaming.
        $wasLink = [bool]$item.LinkType
        if ($wasLink) { Rename-Item -LiteralPath $Path -NewName (Split-Path -Leaf $bak) -ErrorAction Stop }
        else { Copy-Item -LiteralPath $Path -Destination $bak -Recurse -ErrorAction Stop }
    } catch {
        Stop-Step "Backup of $Path failed ($($_.Exception.Message)); nothing was replaced."
    }
    Add-Content -LiteralPath $log -Value "bak: $Path -> $bak" -Encoding UTF8
    $script:replaced.Add("$Path -> $bak")
    return $wasLink
}

$changes = New-Object System.Collections.Generic.List[string]
$warnings = New-Object System.Collections.Generic.List[string]
$script:replaced = New-Object System.Collections.Generic.List[string]

# ------------------------------------------------------------------ steps ---
$script:stepName = ''
$script:stepStarted = $started
function Start-Step([string]$Name, [string]$Detail) {
    $script:stepName = $Name
    $script:stepStarted = Get-Date
    Add-Content -LiteralPath $log -Value "`r`n--- $Name ---" -Encoding UTF8
    Write-Host ('  .. {0,-12} {1}' -f $Name, $Detail)
}
function Clear-StepLine {
    $width = 120
    try { $width = [Console]::WindowWidth - 1 } catch { $width = 120 }
    # No console window (output redirected): WindowWidth is 0.
    if ($width -lt 1) { $width = 120 }
    Write-Host ("`r" + (' ' * $width) + "`r") -NoNewline
}
function Complete-Step([string]$Result) {
    Clear-StepLine
    Write-Host ('  {0} ' -f $ok) -ForegroundColor Green -NoNewline
    Write-Host ('{0,-12} {1} ({2})' -f $script:stepName, $Result, (Format-Duration $script:stepStarted))
}
function Stop-Step([string]$Text) {
    Add-Content -LiteralPath $log -Value $Text -Encoding UTF8
    Clear-StepLine
    Write-Host ('  {0} ' -f $failed) -ForegroundColor Red -NoNewline
    Write-Host ('{0,-12} {1} ({2})' -f $script:stepName, $Text, (Format-Duration $script:stepStarted))
    Get-Content -LiteralPath $log -Tail 30 | ForEach-Object { Write-Host $_ }
    Write-Host ''
    Write-Host "  Log: $log"
    if ($script:backupDir) { Write-Host "  Backups: $($script:backupDir)" }
    exit 1
}
function Warn-Step([string]$Text) {
    Add-Content -LiteralPath $log -Value $Text -Encoding UTF8
    $warnings.Add("${script:stepName}: $Text")
    Clear-StepLine
    Write-Host ('  {0} {1,-12} {2}' -f $failed, $script:stepName, $Text) -ForegroundColor Yellow
    Get-Content -LiteralPath $log -Tail 30 | ForEach-Object { Write-Host $_ }
}
# Streams a block's output to the console and log and returns its exit code. A
# native command fails by its exit code (its stderr lines are only logged); a
# cmdlet fails by throwing or by writing an error record.
function Invoke-LoggedCode([scriptblock]$Block) {
    $global:LASTEXITCODE = 0
    $script:cmdletFailed = $false
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        & $Block *>&1 | ForEach-Object {
            if ($_ -is [Management.Automation.ErrorRecord] -and $_.FullyQualifiedErrorId -notlike 'NativeCommandError*') {
                $script:cmdletFailed = $true
            }
            $_ | Out-File -LiteralPath $log -Append -Encoding utf8
            $_ | Out-Host
        }
        $code = $LASTEXITCODE
    } catch {
        $_ | Out-String | Out-File -LiteralPath $log -Append -Encoding utf8
        $_ | Out-Host
        $code = 1
    } finally {
        $ErrorActionPreference = $previous
    }
    if ($code -eq 0 -and $script:cmdletFailed) { $code = 1 }
    return $code
}
# Stops the install on failure.
function Invoke-Logged([scriptblock]$Block, [string]$What) {
    $code = Invoke-LoggedCode $Block
    if ($code -ne 0) { Stop-Step "Install stopped: $What failed." }
}

[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
Write-Host ''

$skipModules = $false
$skipConfig = $false
if ($answer['choco'] -eq 'yes') {
    Start-Step 'Chocolatey' 'waiting for the UAC prompt'
    $adminArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$repo\windows\install-admin.ps1`"", '-Log', "`"$log`"")
    if ($answer['apps'] -eq 'yes') { $adminArgs += '-Apps' }
    $chocoError = ''
    try {
        $process = Start-Process -FilePath (Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe') `
            -ArgumentList $adminArgs -Verb RunAs -Wait -PassThru
    } catch {
        $chocoError = 'UAC was cancelled or the Chocolatey step could not be started.'
    }
    if (-not $chocoError -and $process.ExitCode -ne 0) {
        $chocoError = "install-admin.ps1 failed (exit $($process.ExitCode)); some packages may have been installed."
    }
    if ($chocoError) {
        Warn-Step "$chocoError Continuing with the remaining steps."
        # Chocolatey may have failed before installing/upgrading PowerShell.
        # Skip only the dependent steps that cannot run; keep the user's choices.
        $availablePwsh = $null
        if (Test-Path $pwsh) {
            try {
                $availablePwsh = [version]((& $pwsh -NoProfile -NonInteractive -Command '$PSVersionTable.PSVersion.ToString()' | Out-String).Trim() -replace '-.*$', '')
            } catch { $availablePwsh = $null }
        }
        if ($answer['modules'] -eq 'yes' -and (-not $availablePwsh -or $availablePwsh -lt [version]'7.4')) {
            $skipModules = $true
            $warnings.Add('Modules skipped: PowerShell 7.4+ is unavailable after the Chocolatey failure.')
        }
        if ($answer['config'] -eq 'yes' -and -not $availablePwsh) {
            $skipConfig = $true
            $warnings.Add('PowerShell config skipped: PowerShell 7 is unavailable after the Chocolatey failure.')
        }
    } else {
        $result = Select-String -LiteralPath $log -Pattern '^RESULT: (.*)$' | Select-Object -Last 1
        $text = if ($result) { $result.Matches[0].Groups[1].Value } else { 'done' }
        if ($text -ne 'all installed, up to date') { $changes.Add("chocolatey: $text") }
        Complete-Step $text
    }
}

if ($answer['scoop'] -eq 'yes' -and $scoopApps.Count -gt 0) {
    Start-Step 'Scoop' "$($scoopApps.Count) tools"
    $scoopDone = @()
    if (-not (Test-Path (Join-Path $scoopRoot 'shims\scoop.ps1'))) {
        # scoop's own installer, saved to a file and run from there.
        $installer = Join-Path $env:TEMP "scoop-install-$PID.ps1"
        Invoke-Logged { Invoke-WebRequest -Uri 'https://get.scoop.sh' -OutFile $installer -UseBasicParsing -ErrorAction Stop } 'downloading the scoop installer'
        Invoke-Logged { & $installer } 'the scoop installer'
        Remove-Item -LiteralPath $installer -ErrorAction SilentlyContinue
        $scoopDone += 'scoop'
    }
    $shims = Join-Path $scoopRoot 'shims'
    if (($env:PATH -split ';') -notcontains $shims) { $env:PATH = "$shims;$env:PATH" }
    $missing = @($scoopApps | Where-Object { -not (Test-Path (Join-Path $scoopRoot "apps\$_\current")) })
    # extras needs git, so git comes first.
    if ($missing -contains 'git') { Invoke-Logged { scoop install git } 'scoop install git' }
    if (-not (Test-Path (Join-Path $scoopRoot 'buckets\extras'))) {
        Invoke-Logged { scoop bucket add extras } 'scoop bucket add extras'
    }
    $rest = @($missing | Where-Object { $_ -ne 'git' })
    if ($rest.Count -gt 0) { Invoke-Logged { scoop install @rest } "scoop install $($rest -join ' ')" }
    # scoop can report success while one app failed, so check each one landed.
    $stillMissing = @($scoopApps | Where-Object { -not (Test-Path (Join-Path $scoopRoot "apps\$_\current")) })
    if ($stillMissing.Count -gt 0) { Stop-Step "scoop did not install $($stillMissing -join ' ')." }
    $scoopDone += $missing
    # Updates: refresh the buckets, then update only this set.
    $before = (Get-Item -LiteralPath $log).Length
    Invoke-Logged { scoop update } 'scoop update'
    Invoke-Logged { scoop update @scoopApps } 'scoop update (apps)'
    $stream = [IO.File]::Open($log, 'Open', 'Read', 'ReadWrite')
    try {
        $null = $stream.Seek($before, 'Begin')
        $tail = (New-Object IO.StreamReader($stream)).ReadToEnd()
    } finally { $stream.Dispose() }
    $updatedApps = @([regex]::Matches($tail, "Updating '([^']+)'") | ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique)
    if ($updatedApps.Count -gt 0) { $scoopDone += ($updatedApps | ForEach-Object { "$_ (updated)" }) }
    # tealdeer needs its page cache once; later updates are tldr --update.
    if ($missing -contains 'tealdeer') {
        if ((Invoke-LoggedCode { tldr --update }) -eq 0) { $scoopDone += 'tldr pages' }
        else { $warnings.Add('tldr --update failed (network?); run it later, tldr works without pages until then.') }
    }
    if ($scoopDone.Count -eq 0) {
        Complete-Step "all $($scoopApps.Count) installed, up to date"
    } else {
        $changes.Add("scoop: $($scoopDone -join ' ')")
        Complete-Step "installed $($scoopDone -join ' ')"
    }
}

if ($answer['modules'] -eq 'yes' -and -not $skipModules) {
    Start-Step 'Modules' ($modules -join ' ')
    if (-not (Test-Path $pwsh)) { Stop-Step "PowerShell 7 not found at $pwsh." }
    $pwshNow = [version]((& $pwsh -NoProfile -NonInteractive -Command '$PSVersionTable.PSVersion.ToString()' | Out-String).Trim() -replace '-.*$', '')
    if ($pwshNow -lt [version]'7.4') { Stop-Step "PowerShell $pwshNow is too old for PSResourceGet (needs 7.4+); update it with step 1." }
    # Runs in pwsh: modules installed from Windows PowerShell land where pwsh doesn't look.
    $moduleScript = @"
`$ErrorActionPreference = 'Stop'
foreach (`$name in '$($modules -join "','")') {
    `$latest = Find-PSResource -Name `$name -Repository PSGallery
    `$have = Get-InstalledPSResource -Name `$name -Scope CurrentUser -ErrorAction SilentlyContinue | Sort-Object Version -Descending | Select-Object -First 1
    if (-not `$have) {
        Install-PSResource -Name `$name -Scope CurrentUser -TrustRepository -Quiet
        "CHANGED: `$name `$(`$latest.Version)"
    } elseif (`$latest.Version -gt `$have.Version) {
        Update-PSResource -Name `$name -Scope CurrentUser -TrustRepository -Quiet
        "CHANGED: `$name `$(`$have.Version) -> `$(`$latest.Version)"
    }
}
foreach (`$old in 'oh-my-posh', 'posh-git', 'z') {
    if (Get-Module -ListAvailable -Name `$old) { "UNUSED: `$old" }
}
"@
    $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($moduleScript))
    $before = (Get-Item -LiteralPath $log).Length
    Invoke-Logged { & $pwsh -NoProfile -NonInteractive -EncodedCommand $encoded } 'installing the PowerShell modules'
    $stream = [IO.File]::Open($log, 'Open', 'Read', 'ReadWrite')
    try {
        $null = $stream.Seek($before, 'Begin')
        $tail = (New-Object IO.StreamReader($stream)).ReadToEnd()
    } finally { $stream.Dispose() }
    $moduleChanges = @([regex]::Matches($tail, '(?m)^CHANGED: (.+?)\s*$') | ForEach-Object { $_.Groups[1].Value })
    $unusedModules = @([regex]::Matches($tail, '(?m)^UNUSED: (.+?)\s*$') | ForEach-Object { $_.Groups[1].Value })
    if ($moduleChanges.Count -eq 0) {
        Complete-Step 'all installed, up to date'
    } else {
        $changes.Add("modules: $($moduleChanges -join ', ')")
        Complete-Step ($moduleChanges -join ', ')
    }
}

if ($answer['fonts'] -eq 'yes') {
    Start-Step 'Fonts' 'MesloLGS NF'
    $fontDir = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts'
    $fontKey = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts'
    New-Item -ItemType Directory -Path $fontDir -Force | Out-Null
    if (-not (Test-Path $fontKey)) { New-Item -Path $fontKey -Force | Out-Null }
    $newFonts = 0
    foreach ($font in $fontSha256.Keys) {
        $dest = Join-Path $fontDir $font
        $valueName = ($font -replace '\.ttf$', '') + ' (TrueType)'
        $fileOk = (Test-Path $dest) -and ((Get-FileHash -LiteralPath $dest -Algorithm SHA256).Hash -eq $fontSha256[$font])
        if (-not $fileOk) {
            $tmp = Join-Path $env:TEMP "dotfiles-font-$PID.ttf"
            $url = "$fontsUrl/$($font -replace ' ', '%20')"
            Invoke-Logged { Invoke-WebRequest -Uri $url -OutFile $tmp -UseBasicParsing -ErrorAction Stop } "downloading $font"
            if ((Get-FileHash -LiteralPath $tmp -Algorithm SHA256).Hash -ne $fontSha256[$font]) {
                Remove-Item -LiteralPath $tmp -Force
                Stop-Step "Checksum mismatch for $font."
            }
            if (Test-Path $dest) { Backup-Item $dest }
            Move-Item -LiteralPath $tmp -Destination $dest
            $newFonts++
        }
        $registered = (Get-ItemProperty -Path $fontKey -Name $valueName -ErrorAction SilentlyContinue)
        if (-not $registered -or $registered.$valueName -ne $dest) {
            New-ItemProperty -Path $fontKey -Name $valueName -Value $dest -PropertyType String -Force | Out-Null
            if ($fileOk) { $newFonts++ }
        }
    }
    if ($newFonts -eq 0) {
        Complete-Step 'all 4 installed'
    } else {
        $changes.Add("fonts: $newFonts MesloLGS NF files (set the font in Windows Terminal)")
        Complete-Step "installed $newFonts"
    }
}

if ($answer['config'] -eq 'yes' -and -not $skipConfig) {
    Start-Step 'Config' 'junction, $PROFILE, DOTFILES'
    if (-not (Test-Path $pwsh)) { Stop-Step "PowerShell 7 not found at $pwsh." }
    # Query again after Chocolatey may have installed pwsh. Check every
    # destination before the first config write, including redirected Documents.
    $profilePath = (& $pwsh -NoProfile -NonInteractive -Command '$PROFILE.CurrentUserCurrentHost' | Out-String).Trim()
    if (-not $profilePath) { Stop-Step 'Could not read $PROFILE from pwsh.' }
    $problem = Get-ConfigProblem
    if ($problem) { Stop-Step $problem }
    $configDone = @()

    # 1. %USERPROFILE%\.config\powershell -> repo: a junction, a copy only as fallback.
    $item = Get-Item -LiteralPath $configLink -Force -ErrorAction SilentlyContinue
    $linked = $false
    if ($item -and $item.LinkType -eq 'Junction') {
        $linked = (@($item.Target)[0].TrimEnd('\')) -eq $configSource.TrimEnd('\')
    }
    if (-not $linked) {
        if (-not (Test-ConfigCopy)) {
            if ($item) {
                # A link is renamed to its .bak; a folder is copied there, then moved to the backup folder.
                $wasLink = Save-Bak $configLink
                if (-not $wasLink) { Backup-Item $configLink }
            }
            New-Item -ItemType Directory -Path (Split-Path -Parent $configLink) -Force | Out-Null
            $junctionMade = $false
            if (-not $onNetworkPath) {
                try {
                    New-Item -ItemType Junction -Path $configLink -Target $configSource -ErrorAction Stop | Out-Null
                    $junctionMade = $true
                } catch {
                    Add-Content -LiteralPath $log -Value "junction failed: $_" -Encoding UTF8
                }
            }
            if ($junctionMade) {
                $configDone += "junction $configLink"
            } else {
                Copy-Item -LiteralPath $configSource -Destination $configLink -Recurse
                $configDone += "copied $configLink (no junction possible; run again after changes)"
            }
        }
    }

    # 2. $PROFILE as pwsh sees it (it may be redirected to OneDrive).
    $bootstrap = Get-Content -LiteralPath (Join-Path $repo 'windows\Microsoft.PowerShell_profile.ps1') -Raw
    $profileItem = Get-Item -LiteralPath $profilePath -Force -ErrorAction SilentlyContinue
    $current = if ($profileItem -and -not $profileItem.LinkType) { Get-Content -LiteralPath $profilePath -Raw } else { $null }
    # A linked $PROFILE is replaced too, so nothing is ever written through the link.
    if (($profileItem -and $profileItem.LinkType) -or $current -ne $bootstrap) {
        if ($profileItem) {
            $wasLink = Save-Bak $profilePath
            if (-not $wasLink) { Backup-Item $profilePath -Copy }
        }
        New-Item -ItemType Directory -Path (Split-Path -Parent $profilePath) -Force | Out-Null
        [IO.File]::WriteAllText($profilePath, $bootstrap)
        $configDone += "`$PROFILE $profilePath"
    }

    # 3. DOTFILES points help-dots at HELP.md.
    if ([Environment]::GetEnvironmentVariable('DOTFILES', 'User') -ne $repo) {
        [Environment]::SetEnvironmentVariable('DOTFILES', $repo, 'User')
        $configDone += "DOTFILES=$repo"
    }
    $env:DOTFILES = $repo

    if ($configDone.Count -eq 0) {
        Complete-Step 'all in place'
    } else {
        $changes.Add("config: $($configDone -join '; ')")
        Complete-Step ($configDone -join '; ')
    }
}

# Remember this run for the next one; rewritten only when something differs.
$newState = @("commit=$newCommit") + @($questions | ForEach-Object { "$($_.Key)=$($answer[$_.Key])" })
$oldState = if (Test-Path $stateFile) { @(Get-Content -LiteralPath $stateFile) } else { @() }
if (($newState -join "`n") -ne ($oldState -join "`n")) {
    [IO.File]::WriteAllText($stateFile, (($newState -join "`n") + "`n"))
}

# ---------------------------------------------------------------- summary ---
Write-Host ''
if ($changes.Count -eq 0 -and $warnings.Count -gt 0) {
    Write-Host '  No completed changes were recorded; see warnings below.'
} elseif ($changes.Count -eq 0) {
    Write-Host '  Nothing changed; everything was already in place.'
} else {
    Write-Host '  Changed:'
    foreach ($change in $changes) { Write-Host "    $change" }
}
if ($script:replaced.Count -gt 0) {
    Write-Host '  Replaced config (originals kept):'
    foreach ($entry in $script:replaced) { Write-Host "    $entry" }
}
if ($answer['config'] -eq 'yes' -and $script:localNotes.Count -gt 0) {
    Write-Host '  Check: ' -ForegroundColor Yellow -NoNewline
    Write-Host 'machine-local settings are not carried over automatically.'
    foreach ($note in $script:localNotes) { Write-Host "    $note" }
}
if ($chocoOverlap.Count -gt 0) {
    Write-Host "  Also on Chocolatey: $($chocoOverlap -join ' '). Windows puts the system PATH first, so those copies win over scoop's."
    Write-Host "    Nothing was removed; if you want scoop's: gsudo choco uninstall $($chocoOverlap -join ' ')"
}
if ($warnings.Count -gt 0) {
    Write-Host '  Warnings:'
    foreach ($warning in $warnings) { Write-Host "    $warning" }
}
if ((Get-Variable -Name unusedModules -ErrorAction SilentlyContinue) -and $unusedModules.Count -gt 0) {
    Write-Host "  No longer used: $($unusedModules -join ', ') (pwsh: Uninstall-Module $($unusedModules -join ', '))"
}
if ($script:backupDir) { Write-Host "  Backups: $($script:backupDir)" }
Write-Host "  Log:     $log"
Write-Host ''
$outcome = if ($warnings.Count -gt 0) { 'Finished with warnings' } else { 'Done' }
Write-Host "  $outcome in $(Format-Duration $started). Open a new PowerShell 7 window (pwsh), then run " -NoNewline
Write-Host 'help-dots' -ForegroundColor Cyan -NoNewline
Write-Host ' for the cheat sheet.'
