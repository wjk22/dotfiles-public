# set PowerShell to UTF-8
[console]::InputEncoding = [console]::OutputEncoding = New-Object System.Text.UTF8Encoding

#Set some aliases/functions

. $env:USERPROFILE\.config\aliases.ps1

oh-my-posh init pwsh | Invoke-Expression
Set-PoshPrompt paradox

Import-Module Terminal-Icons

