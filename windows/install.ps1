
#Basic Windows Use Install script
#
#
Write-Output "Installing scoop"

Invoke-Expression (New-Object System.Net.WebClient).DownloadString('https://get.scoop.sh')
scoop install curl fzf

Write-Output "Installing some windows modules .."

Install-Module -Name Terminal-Icons -Repository PSGallery
Install-Module oh-my-posh -Scope CurrentUser -Force -Verbose
Install-Module posh-git -Scope CurrentUser -Force -Verbose
Install-Module -Name PSReadLine -AllowPrerelease -Scope CurrentuSer -Force -SkipPublisherCheck -Verbose
Install-Module -Name PSFzf -Scope CurrentUser -Force -Verbose
Install-Module -Name z -Scope CurrentUser -Force -Verbose
