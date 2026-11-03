# Tests installer control flow with mocked processes; installs nothing.
Set-StrictMode -Version 2
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$tokens = $null; $errors = $null
$ast = [Management.Automation.Language.Parser]::ParseFile((Join-Path $repo 'install.ps1'), [ref]$tokens, [ref]$errors)
if ($errors.Count) { throw ($errors | Out-String) }
function Assert([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}
$choco = $ast.EndBlock.Statements | Where-Object { $_.Extent.Text.StartsWith("if (`$Sudo -and `$answer['choco'] -eq 'yes') {") }
Assert (@($choco).Count -eq 1) 'Could not locate the guarded Chocolatey step'
$extraOptions = $ast.EndBlock.Statements | Where-Object { $_.Extent.Text.StartsWith('foreach ($argument in $ExtraArguments)') }
$switchProbe = [scriptblock]::Create('[CmdletBinding()]' + "`n" + $ast.ParamBlock.Extent.Text + "`n" + $extraOptions.Extent.Text + "`n[bool]`$Sudo")
Assert (-not (& $switchProbe)) 'Default invocation enables administrator commands'
Assert (-not (& $switchProbe -Yes)) '-Yes must not enable administrator commands'
Assert (& $switchProbe --sudo) '--sudo does not bind to the elevation switch'
Assert (& $switchProbe -Sudo) '-Sudo does not bind to the elevation switch'
$warn = $ast.Find({ param($node)
    $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Warn-Step'
}, $true)
$log = [IO.Path]::GetTempFileName()
try {
    foreach ($scenario in @(
        @{ Name='default user'; Sudo=$false; Exit=0; Cancel=$false; Version='7.5.0'; Enabled='yes'; Warn=0; Modules=$true; Config=$true },
        @{ Name='package failure'; Sudo=$true; Exit=1; Cancel=$false; Version='7.5.0'; Enabled='yes'; Warn=1; Modules=$true; Config=$true },
        @{ Name='UAC cancellation'; Sudo=$true; Exit=0; Cancel=$true; Version='7.5.0'; Enabled='yes'; Warn=1; Modules=$true; Config=$true },
        @{ Name='missing PowerShell'; Sudo=$true; Exit=1; Cancel=$false; Version=''; Enabled='yes'; Warn=3; Modules=$false; Config=$false },
        @{ Name='Scoop recovers missing PowerShell'; Sudo=$true; Exit=1; Cancel=$false; Version=''; Enabled='yes'; Warn=1; Modules=$true; Config=$true; ScoopPwsh=$true },
        @{ Name='old PowerShell'; Sudo=$true; Exit=1; Cancel=$false; Version='7.3.0'; Enabled='yes'; Warn=2; Modules=$false; Config=$true },
        @{ Name='success'; Sudo=$true; Exit=0; Cancel=$false; Version='7.5.0'; Enabled='yes'; Warn=0; Modules=$true; Config=$true },
        @{ Name='disabled'; Sudo=$true; Exit=0; Cancel=$false; Version='7.5.0'; Enabled='no'; Warn=0; Modules=$true; Config=$true }
    )) {
        & {
            $answer = @{ choco=$scenario.Enabled; apps='yes'; scoop='yes'; modules='yes'; fonts='yes'; config='yes' }
            $Sudo = $scenario.Sudo
            $warnings = New-Object 'System.Collections.Generic.List[string]'
            $changes = New-Object 'System.Collections.Generic.List[string]'
            $skipModules = $false; $skipConfig = $false
            $scoopApps = @('git'); $pwsh = 'Test-Pwsh'; $failed = 'FAIL'
            if ($scenario.ContainsKey('ScoopPwsh')) { $scoopApps += 'pwsh' }
            $script:completed = $false; $script:launched = $false
            function Start-Step { $script:stepName = 'Chocolatey' }
            function Clear-StepLine {}
            function Write-Host {}
            function Complete-Step { $script:completed = $true }
            function Stop-Step { throw 'Installer aborted instead of continuing' }
            function Test-Path { return [bool]$scenario.Version }
            function Test-Pwsh { return $scenario.Version }
            function Start-Process {
                $script:launched = $true
                if ($scenario.Cancel) { throw 'User cancelled elevation' }
                return [pscustomobject]@{ ExitCode=$scenario.Exit }
            }
            . ([scriptblock]::Create($warn.Extent.Text))
            'RESULT: all installed, up to date' | Set-Content -LiteralPath $log
            . ([scriptblock]::Create($choco.Extent.Text))
            Assert ($warnings.Count -eq $scenario.Warn) "$($scenario.Name): wrong warnings"
            Assert ($script:launched -eq ($scenario.Sudo -and $scenario.Enabled -eq 'yes')) "$($scenario.Name): wrong launch decision"
            Assert ($script:completed -eq ($scenario.Name -eq 'success')) "$($scenario.Name): failed step reported as successful"
            foreach ($key in @('scoop', 'modules', 'fonts', 'config')) {
                $step = $ast.EndBlock.Statements | Where-Object { $_.Extent.Text.StartsWith("if (`$answer['$key'] -eq 'yes'") }
                $runs = & ([scriptblock]::Create($step.Clauses[0].Item1.Extent.Text))
                $expected = if ($key -eq 'modules') { $scenario.Modules } elseif ($key -eq 'config') { $scenario.Config } else { $true }
                Assert ($runs -eq $expected) "$($scenario.Name): wrong continuation for $key"
                Assert ($answer[$key] -eq 'yes') "$($scenario.Name): saved choice was changed"
            }
            "PASS: $($scenario.Name)"
        }
    }
} finally { Remove-Item -LiteralPath $log }
