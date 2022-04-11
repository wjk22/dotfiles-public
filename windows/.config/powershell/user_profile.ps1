# set PowerShell to UTF-8
[console]::InputEncoding = [console]::OutputEncoding = New-Object System.Text.UTF8Encoding

#Set some aliases/functions

. $env:USERPROFILE\.config\aliases.ps1

Import-Module posh-git
Import-Module oh-my-posh

$omp_config = Join-Path $env:USERPROFILE .config\powershell\takuya.omp.json

oh-my-posh init pwsh -c $omp_config | Invoke-Expression

Import-Module Terminal-Icons

