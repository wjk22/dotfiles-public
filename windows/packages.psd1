# Package IDs, one per line. Remove an entry to stop managing it; this does
# not uninstall it. Use @() for an empty group.
# For machine-local choices, copy this file to packages.local.psd1 (Git ignores it).
@{
    ChocolateySystem = @(
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
        'pwsh'
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
}
