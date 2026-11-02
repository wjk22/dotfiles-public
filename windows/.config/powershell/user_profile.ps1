# PowerShell 7 profile, loaded by the small bootstrap in $PROFILE.
# This folder is %USERPROFILE%\.config\powershell, a junction to the repo.

[console]::InputEncoding = [console]::OutputEncoding = New-Object System.Text.UTF8Encoding

. "$PSScriptRoot\aliases.ps1"

# Prompt: the oh-my-posh binary (scoop), not the old PowerShell module
if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
    oh-my-posh init pwsh --config "$PSScriptRoot\takuya.omp.json" | Invoke-Expression
}

if (Get-Module -ListAvailable Terminal-Icons) { Import-Module Terminal-Icons }

# PSReadLine
Set-PSReadLineOption -EditMode Vi
Set-PSReadLineOption -BellStyle None
Set-PSReadLineKeyHandler -Chord 'Ctrl+d' -Function DeleteChar
Set-PSReadLineOption -PredictionSource History
Set-PSReadLineOption -PredictionViewStyle InlineView

# fzf: Ctrl+f files, Ctrl+r history
if (Get-Module -ListAvailable PSFzf) {
    Import-Module PSFzf
    Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+f' -PSReadlineChordReverseHistory 'Ctrl+r'
}

# zoxide: z and zi, as on Linux
if (Get-Command zoxide -ErrorAction SilentlyContinue) {
    Invoke-Expression (& { (zoxide init powershell | Out-String) })
}

# Machine-local settings: never in the repo.
$localProfile = Join-Path $env:USERPROFILE '.config\powershell.local.ps1'
if (Test-Path $localProfile) { . $localProfile }
