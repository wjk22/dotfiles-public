# Package IDs, one per line. Remove an entry to stop managing it; this does
# not uninstall it. Use @() for an empty group.
# For machine-local choices, copy this file to packages.local.psd1 (Git ignores it).
@{
    # powershell-core is PowerShell 7 for all users, in Program Files: Windows
    # Terminal lists it as "PowerShell", and the config step makes it the default.
    ChocolateySystem = @(
        'powershell-core'
        'everything'
        'totalcommander'
    )
    ChocolateyApps = @(
        'ditto'
        'imageglass'
        'googlechrome'
        'firefox'
        'potplayer'
        'systeminformer'
        'vscode'
        'vlc'
        'python3'
        'seafile-client'
    )
    # Package IDs from Scoop's main and extras buckets.
    Scoop = @(
        'git'
        'neovim'
        'gsudo'
        'oh-my-posh'
        'wox'
        'lazygit'
        'lazydocker'
        'ripgrep'
        'fzf'
        'fd'
        'bat'
        'eza'
        'zoxide'
        'btop'
        'dust'
        'gdu'
        'duf'
        'tealdeer'
        'tinta'
    )

    # Windows extras that step 7 removes for the current user; with --sudo they are
    # also no longer provisioned for new users. AppX package names, plus OneDrive,
    # which is only uninstalled when no folder of yours syncs to it. Remove an
    # entry to keep that app; anything removed can come back from the Store.
    Remove = @(
        'Microsoft.MicrosoftSolitaireCollection'
        'Microsoft.GamingApp'
        'Microsoft.XboxGamingOverlay'
        'Microsoft.XboxGameOverlay'
        'Microsoft.XboxSpeechToTextOverlay'
        'MSTeams'
        'MicrosoftTeams'
        'Clipchamp.Clipchamp'
        'Microsoft.BingNews'
        'Microsoft.BingWeather'
        'Microsoft.BingSearch'
        'Microsoft.GetHelp'
        'Microsoft.Getstarted'
        'Microsoft.WindowsFeedbackHub'
        'OneDrive'
    )
}
