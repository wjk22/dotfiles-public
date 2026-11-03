# Native Windows regression: real Git and config writes, temporary homes only.
# Run with Windows PowerShell 5.1 or PowerShell 7. No packages or UAC.
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2
function Assert([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}
function Stop-Install([string]$Text) { throw $Text }
function Stop-Step([string]$Text) { throw $Text }
function Write-Check([string]$Name, [string]$Detail) { }
function Start-Step([string]$Name, [string]$Detail) { }
$sourceRepo = Split-Path -Parent $PSScriptRoot
$scriptText = Get-Content -LiteralPath (Join-Path $sourceRepo 'install.ps1') -Raw
$tokens = $null; $errors = $null
$ast = [Management.Automation.Language.Parser]::ParseInput($scriptText, [ref]$tokens, [ref]$errors)
Assert ($errors.Count -eq 0) 'Installer syntax errors'
foreach ($function in $ast.FindAll({ param($node)
    $node -is [Management.Automation.Language.FunctionDefinitionAst]
}, $true)) {
    if ($function.Name -in @('Save-Bak', 'Backup-Item', 'Test-ConfigCopy', 'Get-ConfigProblem', 'Get-ParentProblem')) {
        . ([scriptblock]::Create($function.Extent.Text))
    }
}
$start = $scriptText.IndexOf('$onNetworkPath =')
$end = $scriptText.IndexOf('try { $packageConfig')
Assert ($start -ge 0 -and $end -gt $start) 'Missing checkout check'
$check = [scriptblock]::Create($scriptText.Substring($start, $end - $start))
$start = $scriptText.IndexOf("    Start-Step 'Config'")
$end = $scriptText.IndexOf('    # 3. DOTFILES')
Assert ($start -ge 0 -and $end -gt $start) 'Missing config apply block'
$apply = [scriptblock]::Create($scriptText.Substring($start, $end - $start))
$fixture = Join-Path ([IO.Path]::GetTempPath()) ('dotfiles-local-edits-' + [guid]::NewGuid())
$null = New-Item -ItemType Directory -Path $fixture
$originalHome = $env:USERPROFILE
try {
    foreach ($copy in @($false, $true)) {
        $mode = if ($copy) { 'copy' } else { 'junction' }
        $repo = Join-Path $fixture $mode
        $null = New-Item -ItemType Directory -Path (Join-Path $repo 'windows') -Force
        Copy-Item -LiteralPath (Join-Path $sourceRepo 'windows\.config') -Destination (Join-Path $repo 'windows\.config') -Recurse
        Copy-Item -LiteralPath (Join-Path $sourceRepo 'windows\Microsoft.PowerShell_profile.ps1') -Destination (Join-Path $repo 'windows')
        & git -C $repo init -q
        & git -C $repo add .
        & git -C $repo -c user.name=Fixture -c user.email=fixture@example.invalid -c commit.gpgsign=false commit -qm fixture
        Assert ($LASTEXITCODE -eq 0) 'Fixture Git commit failed'
        . $check
        Assert ($repoDetail -like 'clean at *') 'Clean checkout not recognized'
        $configSource = Join-Path $repo 'windows\.config\powershell'
        $alias = Join-Path $configSource 'aliases.ps1'
        Add-Content -LiteralPath $alias -Value '# staged customization'
        & git -C $repo add .
        Add-Content -LiteralPath $alias -Value '# unstaged customization'
        $untracked = Join-Path $configSource 'extra.txt'
        Set-Content -LiteralPath $untracked -Value 'untracked customization'
        $beforeStatus = (& git -C $repo status --porcelain | Out-String)
        $beforeIndex = (& git -C $repo diff --cached | Out-String)
        $beforeDiff = (& git -C $repo diff | Out-String)
        . $check
        Assert ($repoDetail -like '*with local changes*') 'Local edits blocked or misreported'
        $env:USERPROFILE = Join-Path $fixture ($mode + '-home')
        $null = New-Item -ItemType Directory -Path $env:USERPROFILE
        $configLink = Join-Path $env:USERPROFILE '.config\powershell'
        $profilePath = Join-Path $env:USERPROFILE 'Documents\PowerShell\Microsoft.PowerShell_profile.ps1'
        $pwsh = Join-Path $fixture ($mode + '-pwsh.ps1')
        Set-Content -LiteralPath $pwsh -Value ("'" + $profilePath.Replace("'", "''") + "'")
        $onNetworkPath = $copy
        $stamp = 'fixture'
        $backupRoot = Join-Path $env:USERPROFILE '.dotfiles-backup\fixture'
        $backupDir = ''
        $replaced = New-Object 'System.Collections.Generic.List[string]'
        $log = Join-Path $fixture ($mode + '.log')
        . $apply
        Assert ((Get-Content -LiteralPath (Join-Path $configLink 'aliases.ps1') -Raw) -eq (Get-Content -LiteralPath $alias -Raw)) 'Edited bytes not installed'
        Assert ((Get-Content -LiteralPath (Join-Path $configLink 'extra.txt')) -eq 'untracked customization') 'Untracked config not installed'
        Assert ((& git -C $repo status --porcelain | Out-String) -eq $beforeStatus) 'Git status changed'
        Assert ((& git -C $repo diff --cached | Out-String) -eq $beforeIndex) 'Git index changed'
        Assert ((& git -C $repo diff | Out-String) -eq $beforeDiff) 'Working edits changed'
        . $apply
        Assert ($configDone.Count -eq 0) 'Unchanged rerun should not replace config'
        Write-Output "PASS: $mode installs staged, unstaged and untracked files; Git state preserved; rerun unchanged"
    }
} finally {
    $env:USERPROFILE = $originalHome
}
Write-Output "Fixtures: $fixture"
