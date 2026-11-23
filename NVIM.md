# Neovim

My familiar Neovim setup for **Neovim 0.12+**, one `nvim/` folder for Linux, WSL,
macOS and Windows: the original transparent **NeoSolarized** theme, Solarized
lualine, custom powerline tabline and a Powwow `.pow` syntax. It used to live in
dotfiles-nvim; that repo is retired.

The installers link it: `~/.config/nvim` on Linux and macOS, a junction at
`%LOCALAPPDATA%\nvim` on Windows (a copy when the checkout is on a network path).
An existing config is backed up first. Neovim itself stays current: Linux installs
the latest release into `~/.local/opt/nvim` (checksum from GitHub's release data,
Debian's package is too old), macOS upgrades Homebrew's `neovim`, Windows updates
Scoop's. Root setup gets the same config and its own Neovim in `/root/.local`.

Start `nvim`. The first launch downloads plugins into Neovim's data directory.
Later launches do not check for updates. The committed `nvim/nvim-pack-lock.json`
records the tested revisions for other machines. Tests: in an isolated profile,
`nvim --headless '+lua dofile("tests/nvim/smoke.lua")'` from the checkout.

## Personal settings

Keep changes in **`nvim.local.lua` beside the config directory**, not inside the
shared files. It loads last and survives reinstalling the config:

- Linux/WSL: `~/.config/nvim.local.lua` (or `$XDG_CONFIG_HOME/nvim.local.lua`).
- Windows: normally `%LOCALAPPDATA%\nvim.local.lua`.
- Custom app name/path: `:lua print(vim.fn.stdpath('config') .. '.local.lua')`.

```lua
vim.opt.scrolloff = 12
vim.keymap.set('n', '<leader>w', '<Cmd>write<CR>')
-- Disable format-on-save for this filetype; Space f still formats explicitly.
vim.api.nvim_create_autocmd('FileType', {
  pattern = 'python',
  callback = function() vim.b.dotfiles_format_on_save = false end,
})
```

## Language tools

Buffer, path and snippet completion work immediately. Full diagnostics,
navigation and language-aware completion need the corresponding server.
Open **`:Mason`** to install the ones you use. Installed servers enable automatically;
the same servers already available on PATH work too.

| Language | Mason package | Extra runtime/toolchain |
|---|---|---|
| Go | `gopls` | Go |
| Rust | `rust-analyzer` | Rust toolchain and rust-src for standard-library navigation |
| Python | `basedpyright` | Python and pip |
| Lua / Neovim config | `lua-language-server` | Standalone binary |
| Shell | `bash-language-server` | Node.js and npm |
| JavaScript / TypeScript / JSX / TSX | `typescript-language-server` | Node.js and npm |
| ESLint | `eslint-lsp` | Node.js, npm and the project's ESLint config |
| HTML / CSS / JSON | `html-lsp`, `css-lsp`, `json-lsp` | Node.js and npm |
| YAML | `yaml-language-server` | Node.js and npm |
| PHP | `intelephense` | Node.js and npm |

If the runtimes are ready and you want the whole set:

```vim
:MasonInstall gopls rust-analyzer basedpyright lua-language-server bash-language-server typescript-language-server eslint-lsp html-lsp css-lsp json-lsp yaml-language-server intelephense
```

This repo does not install Node, Python, Go or Rust globally or force the web stack
onto people who do not need it. `:checkhealth mason` and `:checkhealth vim.lsp`
show missing tools and attachment problems.

## Syntax parsers

Install a C compiler, `curl`, `tar`, and
[tree-sitter CLI 0.26.1+](https://github.com/tree-sitter/tree-sitter/releases)
through your package manager or its official binary releases. Then run:

```vim
:ParsersInstall
```

It installs web parsers plus Go, Rust, Python, Lua, shell, JSON/YAML/TOML,
Markdown, Vim, PHP, Fish and Swift. `:TSInstall <language>` installs one instead.
The current nvim-treesitter `main` API is used, not the frozen old `master` API.
Highlighting falls back to Vim syntax until a parser is available. Powwow `.pow`
files keep their own syntax in `nvim/syntax/pow.vim`.

## Familiar keys

Space stays the leader. Two-space indentation, unwrapped lines and the old
delete/register behaviour stay too.

| Keys | Action |
|---|---|
| `ss`, `sv`; `sh`, `sj`, `sk`, `sl` | Split horizontally/vertically; move between windows |
| `Tab`, `Shift-Tab` (normal mode); `te` | Next/previous tab; start `:tabedit` |
| `Space d`, `x`; `dw`; `Ctrl-a` | Delete without yanking; backwards-word deletion; select all |
| `Space ff`, `Space fg`, `Space fb` | Find files; search contents; Ivy file browser |
| `\\`, `;;` | Buffers; help tags |
| `Space dff`, `sf`, `fi` | File tree in the current window |
| `gd`, `gD`, `gi` | Definition; declaration; implementation |
| `K`, `Ctrl-k` (insert mode) | Hover; signature help |
| `gh`, `gp`, `gr` | LSP finder; peek definition; rename |
| `Space rn`, `Space ca`, `Space f` | Rename; code action; format |
| `Space e`, `Ctrl-j`, `Space q`, `Space lsp` | Diagnostic float; next; list; LSP status |
| `gcc`, `gc` + motion | Comment line/selection (built into Neovim) |
| `Ctrl-n` | vim-visual-multi selection |

Completion keeps Tab/Shift-Tab, arrows, Ctrl-Space, Ctrl-e, Ctrl-d/Ctrl-f and Enter.
Snippets use Neovim's built-in engine and friendly-snippets; the conflicting
LuaSnip/UltiSnips pair and its Python host are no longer needed.

The tree is now **nvim-tree**, replacing Defx. `c/m/p` copy/cut/paste, `r` rename,
`d` delete, `E` vertical split, `P` preview, `h` parent, `~` home and `q` close stay.
`N`/`K` open the create prompt; end the name with `/` for a directory.
`.` toggles dotfiles, Space marks an item; `g?` lists the complete tree keymap.
Fugitive's `:Git` and `:GBrowse` stay, with `:g` and `:gopen` abbreviations.

## Updates

- Pull this repo; the linked config is current at once. The installer keeps
  Neovim itself on the latest release.
- **`:PluginsRestore`** aligns installed plugins with the checked-in lockfile;
  review its tab, then `:write` to apply or `:quit` to cancel.
- **`:PluginsUpdate`** checks upstream plugins and shows the same review tab.
  The lockfile changes only when you apply; keep that change in Git to use the
  same versions everywhere. Blink stays on its stable 1.x series.
- **`:MasonUpdate`** refreshes the tool catalogue; manage installed tools in `:Mason`.
- **`:TSUpdate`** updates installed parsers. Updating nvim-treesitter through the
  plugin manager also triggers this so its queries and parsers stay together.
- Restart Neovim after plugin/parser updates.
