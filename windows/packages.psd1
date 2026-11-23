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
    # Kept on purpose: Phone Link, the Store, App Installer (winget), Edge, Photos,
    # and the Xbox sign-in parts that games and the Store use. Copilot, Widgets,
    # Media Player and Quick Assist are in RemoveOptional (step 8).
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
        'Microsoft.MicrosoftOfficeHub'
        'Microsoft.OutlookForWindows'
        'microsoft.windowscommunicationsapps'
        'Microsoft.WindowsMaps'
        'Microsoft.ZuneVideo'
        'Microsoft.People'
        'Microsoft.PowerAutomateDesktop'
        'Microsoft.Todos'
        'MicrosoftCorporationII.MicrosoftFamily'
        'Microsoft.Windows.DevHome'
        'Microsoft.549981C3F5F10'
        '7EE7776C.LinkedInforWindows'
        'OneDrive'
    )
    # Step 8 removes these too, together with the ads, suggested apps and Bing
    # results in Start. Apps someone might still want: keep any by removing it here.
    RemoveOptional = @(
        'Microsoft.Copilot'
        'Microsoft.ZuneMusic'
        'MicrosoftCorporationII.QuickAssist'
        'MicrosoftWindows.Client.WebExperience'
    )
    # Step 9 (with --sudo) disables these services: telemetry (DiagTrack and its WAP
    # push helper), the shop demo mode, offline maps and fax. Their start types are
    # recorded first; install-admin.ps1 -RestoreServices puts them back.
    DisableServices = @(
        'DiagTrack'
        'dmwappushservice'
        'RetailDemo'
        'MapsBroker'
        'Fax'
    )
}
