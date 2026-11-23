# Run with Windows PowerShell 5.1 or PowerShell 7. Does not install anything.
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
function Assert([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}
function Read-Ast([string]$Path) {
    $tokens = $null; $errors = $null
    $ast = [Management.Automation.Language.Parser]::ParseFile($Path, [ref]$tokens, [ref]$errors)
    Assert ($errors.Count -eq 0) "Syntax errors in $Path"
    return $ast
}
$main = Read-Ast (Join-Path $repo 'install.ps1')
$admin = Read-Ast (Join-Path $PSScriptRoot 'install-admin.ps1')
$null = Read-Ast (Join-Path $PSScriptRoot 'read-packages.ps1')
$fixture = Join-Path ([IO.Path]::GetTempPath()) ('dotfiles-packages-' + [guid]::NewGuid())
$null = New-Item -ItemType Directory -Path $fixture
try {
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'read-packages.ps1') -Destination $fixture
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'packages.psd1') -Destination $fixture
    $loader = Join-Path $fixture 'read-packages.ps1'
    $local = Join-Path $fixture 'packages.local.psd1'
    $defaults = & $loader
    Assert ($defaults.Scoop -contains 'git') 'Default Scoop list was not loaded'
    Assert ($defaults.ChocolateySystem -contains 'powershell-core') 'PowerShell 7 must be installed for all users through Chocolatey'
    Assert ($defaults.Scoop -notcontains 'pwsh') 'Default PowerShell must not be installed twice'
    Assert ($defaults.Remove -contains 'Microsoft.MicrosoftSolitaireCollection' -and $defaults.Remove -contains 'OneDrive') 'Default Remove list was not loaded'
    Assert ($defaults.Remove -notcontains 'Microsoft.XboxIdentityProvider' -and $defaults.Remove -notcontains 'Microsoft.Xbox.TCUI') 'Xbox sign-in parts must stay; games and Store depend on them'
    Assert ($defaults.Remove -notcontains 'Microsoft.YourPhone' -and $defaults.Remove -notcontains 'Microsoft.WindowsStore' -and $defaults.Remove -notcontains 'Microsoft.DesktopAppInstaller') 'Phone Link, the Store and winget must stay'
    Assert ($defaults.ChocolateySystem -notcontains 'openvpn' -and $defaults.ChocolateySystem -notcontains 'netlimiter') 'Removed packages reappeared'
    "@{ ChocolateySystem=@('custom-system'); ChocolateyApps=@('custom-app'); Scoop=@('custom-tool','custom-tool') }" | Set-Content -LiteralPath $local
    $custom = & $loader
    Assert ($custom.ChocolateySystem.Count -eq 1 -and $custom.ChocolateySystem[0] -eq 'custom-system') 'Local list did not replace defaults'
    Assert ($custom.Scoop.Count -eq 1 -and $custom.Scoop[0] -eq 'custom-tool') 'Duplicates were not removed'
    Assert ($custom.Remove.Count -eq $defaults.Remove.Count) 'A local file without Remove must keep the default Remove list'
    "@{ ChocolateySystem=@(); ChocolateyApps=@(); Scoop=@(); Remove=@() }" | Set-Content -LiteralPath $local
    Assert ((& $loader).Remove.Count -eq 0) 'An empty local Remove list must remove nothing'
    foreach ($bad in @(
        "@{ ChocolateySystem=@(); ChocolateyApps=@() }",
        "@{ ChocolateySystem=@(); ChocolateyApps=@(); Scoop='git' }",
        "@{ ChocolateySystem=@('--force'); ChocolateyApps=@(); Scoop=@() }",
        "@{ ChocolateySystem=@(); ChocolateyApps=@(); Scoop=@('extras/git') }",
        "@{ ChocolateySystem=@(); ChocolateyApps=@(); Scoop=@(); Typo=@() }",
        "@{ ChocolateySystem=@(); ChocolateyApps=@(); Scoop=@(Get-Date) }",
        "@{ ChocolateySystem=@(); ChocolateyApps=@(); Scoop=@(); Remove='OneDrive' }"
    )) {
        $bad | Set-Content -LiteralPath $local
        $rejected = $false
        try { $null = & $loader } catch { $rejected = $true }
        Assert $rejected "Invalid configuration was accepted: $bad"
    }
    '@{ ChocolateySystem=@(); ChocolateyApps=@(); Scoop=@() }' | Set-Content -LiteralPath $local
    $empty = & $loader
    Assert ($empty.Scoop.Count -eq 0 -and $empty.ChocolateySystem.Count -eq 0) 'Empty lists were not preserved'

    # The all-users install (what Windows Terminal lists as "PowerShell") wins;
    # without it, a per-user Scoop runtime wins over one on PATH.
    $resolver = $main.Find({ param($node)
        $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Resolve-Pwsh'
    }, $true)
    & {
        $scoopRoot = Join-Path $fixture 'scoop'
        $runtimeDir = Join-Path $scoopRoot 'apps\pwsh\current'
        $candidate = Join-Path $runtimeDir 'pwsh.exe'
        New-Item -ItemType Directory -Path $runtimeDir -Force | Out-Null
        [IO.File]::WriteAllText($candidate, 'fixture, never executed')
        try {
            . ([scriptblock]::Create($resolver.Extent.Text))
            $programFiles = $env:ProgramFiles
            $env:ProgramFiles = Join-Path $fixture 'pf'
            try {
                Assert ((Resolve-Pwsh) -eq $candidate) 'Scoop PowerShell was not preferred over PATH'
                $machine = Join-Path $env:ProgramFiles 'PowerShell\7\pwsh.exe'
                New-Item -ItemType Directory -Path (Split-Path -Parent $machine) -Force | Out-Null
                [IO.File]::WriteAllText($machine, 'fixture, never executed')
                Assert ((Resolve-Pwsh) -eq $machine) 'All-users PowerShell 7 was not preferred'
            } finally {
                $env:ProgramFiles = $programFiles
                Remove-Item -LiteralPath (Join-Path $fixture 'pf') -Recurse -ErrorAction SilentlyContinue
            }
        } finally {
            Remove-Item -LiteralPath $candidate
            foreach ($directory in @($runtimeDir, (Split-Path -Parent $runtimeDir), (Join-Path $scoopRoot 'apps'), $scoopRoot)) {
                Remove-Item -LiteralPath $directory
            }
        }
    }

    # Exercise the actual admin package selection and guarded invocation.
    $selection = $admin.EndBlock.Statements | Where-Object {
        $_.Extent.Text -eq '$packages = $systemPackages' -or
        $_.Extent.Text -eq 'if ($Apps) { $packages += $appPackages }' -or
        $_.Extent.Text.StartsWith('if ($packages.Count -gt 0)')
    }
    Assert (@($selection).Count -eq 3) 'Could not locate admin selection statements'
    $selectionCode = [scriptblock]::Create(($selection.Extent.Text -join "`n"))
    function Invoke-Logged([scriptblock]$Block) { & $Block; return 0 }
    function Test-Choco { $script:chocoArgs = @($args | ForEach-Object { $_ }) }
    $choco = 'Test-Choco'
    foreach ($Apps in @($false, $true)) {
        $systemPackages = $custom.ChocolateySystem; $appPackages = $custom.ChocolateyApps
        $script:chocoArgs = @()
        & $selectionCode
        Assert ($script:chocoArgs -contains 'custom-system') 'System package not passed to Chocolatey'
        Assert (($script:chocoArgs -contains 'custom-app') -eq $Apps) 'Optional selection not respected'
        $systemPackages = $empty.ChocolateySystem; $appPackages = $empty.ChocolateyApps
        $script:chocoArgs = @()
        & $selectionCode
        Assert ($script:chocoArgs.Count -eq 0) 'Chocolatey invoked with no packages'
    }
    $scoopStep = $main.Find({ param($node)
        $node -is [Management.Automation.Language.IfStatementAst] -and
        $node.Extent.Text.StartsWith("if (`$answer['scoop'] -eq 'yes' -and `$scoopApps.Count -gt 0) {")
    }, $true)
    $answer = @{ scoop = 'yes' }
    foreach ($scoopApps in @($empty.Scoop, $custom.Scoop)) {
        $runs = & ([scriptblock]::Create($scoopStep.Clauses[0].Item1.Extent.Text))
        Assert ($runs -eq ($scoopApps.Count -gt 0)) 'Empty Scoop list must skip the entire step'
    }
    $plan = $main.Find({ param($node)
        $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Test-Plan'
    }, $true)
    . ([scriptblock]::Create($plan.Extent.Text))
    function Test-Path { return $false }
    function Get-Item { return $null }
    function Get-Command { return $null }
    $pwsh = 'missing-pwsh'; $pwshVersion = $null
    $Sudo = $true
    $answer = @{ choco = 'yes'; apps = 'no'; modules = 'yes'; config = 'no'; scoop = 'no' }
    $systemPackages = @(); $appPackages = @('powershell-core')
    Assert ((Test-Plan) -like 'PowerShell 7 is missing*') 'Removing PowerShell must not bypass dependency checks'
    $answer.apps = 'yes'
    Assert ((Test-Plan) -eq '') 'PowerShell in selected optional apps should satisfy the plan'
    $Sudo = $false
    Assert ((Test-Plan) -like 'PowerShell 7 is missing*') 'Chocolatey must not satisfy dependencies without --sudo'
    $answer.scoop = 'yes'; $scoopApps = @('git', 'pwsh')
    Assert ((Test-Plan) -eq '') 'Per-user Scoop PowerShell should satisfy the plan without --sudo'
    $answer.modules = 'no'; $answer.scoop = 'yes'; $scoopApps = @('custom-tool')
    Assert ((Test-Plan) -like 'Scoop bucket updates need Git*') 'Missing Git dependency not detected'
    $scoopApps = @()
    Assert ((Test-Plan) -eq '') 'Empty Scoop list must not require Git'
    Write-Output 'PASS: package config, overrides, validation, selection, empty groups, PowerShell 7 dependencies, and script syntax'
} finally {
    foreach ($name in @('read-packages.ps1', 'packages.psd1', 'packages.local.psd1')) {
        Remove-Item -LiteralPath (Join-Path $fixture $name) -ErrorAction SilentlyContinue
    }
    Remove-Item -LiteralPath $fixture
}
