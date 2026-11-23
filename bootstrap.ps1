<#
  One line for a fresh Windows, where git isn't installed yet:

    irm https://raw.githubusercontent.com/wjk22/dotfiles-public/master/bootstrap.ps1 | iex

  Run it as your normal user, in Windows PowerShell or PowerShell 7. It gets git
  through Scoop (per user, no UAC), clones the repo to C:\Dev\Workspace\dotfiles-public
  (or updates the checkout already there) and starts install.ps1.
#>
# Everything runs inside this block: under `iex`, an `exit` would close the window.
& {
    Set-StrictMode -Version 2
    $ErrorActionPreference = 'Stop'
    $ProgressPreference = 'SilentlyContinue'
    $repoUrl = 'https://github.com/wjk22/dotfiles-public.git'
    $target = 'C:\Dev\Workspace\dotfiles-public'

    function Say([string]$Text) { Write-Host "  $Text" }
    function Fail([string]$Text) { Write-Host "  $Text" -ForegroundColor Red }

    $principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    if ($principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Fail 'Run this as your normal user, not as administrator. The installer asks for UAC itself when it needs it.'
        return
    }
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    # This window only: lets Scoop's installer and its shims run. Later sessions keep their policy.
    Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force

    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        $scoopRoot = if ($env:SCOOP) { $env:SCOOP } else { Join-Path $env:USERPROFILE 'scoop' }
        $shims = Join-Path $scoopRoot 'shims'
        if (-not (Test-Path -LiteralPath (Join-Path $shims 'scoop.ps1'))) {
            Say 'Installing Scoop for your account (no UAC) ...'
            Invoke-RestMethod -Uri 'https://get.scoop.sh' | Invoke-Expression
        }
        if (($env:PATH -split ';') -notcontains $shims) { $env:PATH = "$shims;$env:PATH" }
        Say 'Installing git through Scoop ...'
        scoop install git
        if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
            Fail 'git is still not available; see the Scoop output above.'
            return
        }
    }

    if (Test-Path -LiteralPath (Join-Path $target '.git')) {
        $origin = git -C $target remote get-url origin
        if ($origin -notmatch 'wjk22/dotfiles-public') {
            Fail "$target holds another repository ($origin); move it away first."
            return
        }
        Say "Updating $target ..."
        git -C $target pull --ff-only
        if ($LASTEXITCODE -ne 0) {
            Fail "git pull failed in $target (local changes?). Sort them out, then run this line again."
            return
        }
    } elseif ((Test-Path -LiteralPath $target) -and (Get-ChildItem -LiteralPath $target -Force | Select-Object -First 1)) {
        Fail "$target exists and isn't a git checkout; move it away first."
        return
    } else {
        New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force | Out-Null
        Say "Cloning to $target ..."
        git clone $repoUrl $target
        if ($LASTEXITCODE -ne 0) {
            Fail 'git clone failed; see the output above.'
            return
        }
    }

    Write-Host ''
    # PowerShell 7 itself comes through Chocolatey, so the admin step is the default.
    $reply = Read-Host '  Allow the admin step (PowerShell 7 and Chocolatey apps, one UAC prompt)? [Y/n]'
    $installArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', (Join-Path $target 'install.ps1'))
    if ($reply -notmatch '^(n|no)$') { $installArgs += '--sudo' }
    & (Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe') @installArgs
}
