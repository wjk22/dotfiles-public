#Set Paths
$Env:PATH += ";C:\Tools\git\usr\bin"
#Aliases

Set-Alias wo Write-Output
Set-Alias ll ls
Set-Alias lld ls
Set-Alias tc 'C:\Program Files (x86)\Total Commander\TCUP64.exe'


# Utilities since windows can not do multiple commands in one alias
#

#function to reload the profile
function repo  {
    @(
            $Profile.AllUsersAllHosts,
            $Profile.AllUsersCurrentHost,
            $Profile.CurrentUserAllHosts,
            $Profile.CurrentUserCurrentHost
      ) | % {
            if(Test-Path $_){
            Write-Verbose "Running $_"
      . $_
       }
   }    
}

#edit aliases, functions
function eal {
 vim $env:USERPROFILE\.config\aliases.ps1 
 Write-Output "Please run . repo to reload the profile"
 $alias_config = Join-Path $env:USERPROFILE .config\aliases.ps1
}

function epro {
 vim $env:USERPROFILE\.config\powershell\user_profile.ps1
 Write-Output "Please run . repo to reload the profile"
}

function which ($command) {
  Get-Command -Name $command -ErrorAction SilentlyContinue |
    Select-Object -ExpandProperty Path -ErrorAction SilentlyContinue
}

function .. {
	cd ..
}
