
#Basic Admin Windows Install script
#

Write-Output "Installing Chocolatey"
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))

Write-Output "ADMIN install .... installing basic programs with choco"
choco install git totalcommander vim wox powershell-core everyting gsudo
Install-Module -Name PSWindowsUpdate -Force
