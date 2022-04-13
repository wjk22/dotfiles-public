# set PowerShell to UTF-8

#Set some aliases/functions
. $env:USERPROFILE\.config\aliases.ps1

[console]::InputEncoding = [console]::OutputEncoding = New-Object System.Text.UTF8Encoding

Import-Module posh-git
Import-Module oh-my-posh
Import-Module Terminal-Icons

# PSReadLine
Set-PSReadLineOption -EditMode Vi
Set-PSReadLineOption -BellStyle None
Set-PSReadLineKeyHandler -Chord 'Ctrl+d' -Function DeleteChar
Set-PSReadLineOption -PredictionSource History
#Set-PSReadLineOption -PredictionViewStyle ListView 
Set-PSReadLineOption -PredictionViewStyle InlineView

# Fzf
Import-Module PSFzf
Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+f' -PSReadlineChordReverseHistory 'Ctrl+r'


$omp_config = Join-Path $env:USERPROFILE .config\powershell\takuya.omp.json

oh-my-posh init pwsh -c $omp_config | Invoke-Expression


