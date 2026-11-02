# Shared by the normal-user installer and the elevated Chocolatey step.
$path = Join-Path $PSScriptRoot 'packages.local.psd1'
if (-not (Test-Path -LiteralPath $path)) { $path = Join-Path $PSScriptRoot 'packages.psd1' }
$packages = Import-PowerShellDataFile -LiteralPath $path -ErrorAction Stop
$groups = @('ChocolateySystem', 'ChocolateyApps', 'Scoop')
foreach ($key in $packages.Keys) {
    if ($groups -notcontains $key) { throw "Unknown package group '$key' in $path." }
}
foreach ($key in $groups) {
    if (-not $packages.ContainsKey($key) -or $packages[$key] -isnot [array]) {
        throw "Package group '$key' must be an array in $path (use @() for none)."
    }
    foreach ($id in $packages[$key]) {
        if ($id -isnot [string] -or $id -notmatch '^[a-zA-Z0-9][a-zA-Z0-9._-]*$') {
            throw "Invalid package ID in group '$key' in $path. Use package names, without flags or paths."
        }
    }
    $packages[$key] = @($packages[$key] | Select-Object -Unique)
}
$packages
