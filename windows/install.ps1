
#Basic Windows Use Install script
#
#
Invoke-Expression (New-Object System.Net.WebClient).DownloadString('https://get.scoop.sh')
scoop install curl fzf
Install-Module oh-my-posh -Scope CurrentUser -Force
Install-Module posh-git -Scope CurrentUser -Force
Install-Module -Name PSReadLine -AllowPrerelease -Scope CurrentuSer -Force -SkipPublisherCheck
Install-Module -Name PSFzf -Scope CurrentUser -Force
Install-Module -Name PSWindowsUpdate -Force

