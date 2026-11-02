<#
  The Chocolatey part of the dotfiles install: system-wide installs that need
  admin rights. install.ps1 windows runs it once through UAC (it works with a
  separate admin account). It also runs on its own from an elevated PowerShell:

    powershell -ExecutionPolicy Bypass -File .\windows\install-admin.ps1 [-Apps]

  Installs Chocolatey if missing, then installs or upgrades the packages, and
  the PSWindowsUpdate module for all users. Safe to run again.
#>
[CmdletBinding()]
param(
    # Also install the optional apps.
    [switch]$Apps,
    # Append all output to this log (install.ps1 passes its own); console otherwise.
    [string]$Log
)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$packageConfig = & (Join-Path $PSScriptRoot 'read-packages.ps1')
$systemPackages = @($packageConfig.ChocolateySystem)
$appPackages = @($packageConfig.ChocolateyApps)

function Add-LogLine([string]$Text) {
    if ($Log) { Add-Content -LiteralPath $Log -Value $Text -Encoding UTF8 } else { Write-Output $Text }
}

# Streams a block's output to the console and log; returns the exit code. A native
# command fails by its exit code (its stderr lines are only logged); a cmdlet
# fails by throwing or by writing an error record.
function Invoke-Logged([scriptblock]$Block) {
    $global:LASTEXITCODE = 0
    $script:cmdletFailed = $false
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        & $Block *>&1 | ForEach-Object {
            if ($_ -is [Management.Automation.ErrorRecord] -and $_.FullyQualifiedErrorId -notlike 'NativeCommandError*') {
                $script:cmdletFailed = $true
            }
            if ($Log) { $_ | Out-File -LiteralPath $Log -Append -Encoding utf8 }
            $_ | Out-Host
        }
        $code = $LASTEXITCODE
    } catch {
        Add-LogLine ($_ | Out-String)
        if ($Log) { $_ | Out-Host }
        $code = 1
    } finally {
        $ErrorActionPreference = $previous
    }
    if ($code -eq 0 -and $script:cmdletFailed) { $code = 1 }
    return $code
}

function Stop-Admin([string]$Text) {
    Add-LogLine "ERROR: $Text"
    exit 1
}

Add-LogLine ''
Add-LogLine "--- install-admin.ps1 as $env:USERDOMAIN\$env:USERNAME ---"

$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Stop-Admin 'install-admin.ps1 needs an elevated PowerShell (Run as administrator).'
}

[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
$done = @()

$choco = Join-Path $env:ProgramData 'chocolatey\bin\choco.exe'
if (-not (Test-Path $choco)) {
    # Chocolatey's own installer, saved to a file and run from there.
    $installer = Join-Path $env:TEMP "chocolatey-install-$PID.ps1"
    $code = Invoke-Logged { Invoke-WebRequest -Uri 'https://community.chocolatey.org/install.ps1' -OutFile $installer -UseBasicParsing -ErrorAction Stop }
    if ($code -ne 0) { Stop-Admin 'Could not download the Chocolatey installer.' }
    $code = Invoke-Logged { & $installer }
    Remove-Item -LiteralPath $installer -ErrorAction SilentlyContinue
    if ($code -ne 0 -or -not (Test-Path $choco)) { Stop-Admin 'The Chocolatey installer failed.' }
    $done += 'Chocolatey'
}

$packages = $systemPackages
if ($Apps) { $packages += $appPackages }
# upgrade installs what's missing and updates what's outdated.
$code = 0
if ($packages.Count -gt 0) { $code = Invoke-Logged { & $choco upgrade $packages -y } }
# 1641 and 3010: done, a reboot is needed.
if (@(0, 1641, 3010) -notcontains $code) { Stop-Admin "choco upgrade failed (exit $code)." }
if ($Log) {
    $counted = Select-String -LiteralPath $Log -Pattern 'Chocolatey upgraded (\d+)/(\d+) packages' | Select-Object -Last 1
    if ($counted -and $counted.Matches[0].Groups[1].Value -ne '0') {
        $done += "$($counted.Matches[0].Groups[1].Value) of $($counted.Matches[0].Groups[2].Value) packages installed or upgraded"
    }
}
if ($code -ne 0) { $done += 'reboot needed' }

if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {
    $code = Invoke-Logged {
        Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Scope AllUsers -Force -ErrorAction Stop | Out-Null
        Install-Module -Name PSWindowsUpdate -Scope AllUsers -Force -ErrorAction Stop
    }
    if ($code -ne 0) { Stop-Admin 'Installing the PSWindowsUpdate module failed.' }
    $done += 'PSWindowsUpdate'
}

if ($done.Count -eq 0) { Add-LogLine 'RESULT: all installed, up to date' } else { Add-LogLine "RESULT: $($done -join ', ')" }
exit 0
