
#Aliases

Set-Alias wo Write-Output
Set-Alias ll ls

# Utilities since windows can not do multiple commands in one alias

function eal {
 vim $env:USERPROFILE\.config\aliases.ps1 ; . $env:USERPROFILE\.config\aliases.ps1
}

function which ($command) {
  Get-Command -Name $command -ErrorAction SilentlyContinue |
    Select-Object -ExpandProperty Path -ErrorAction SilentlyContinue
}
