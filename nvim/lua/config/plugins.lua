-- Neovim 0.12 manages plugins itself. The checked-in nvim-pack-lock.json
-- reproduces the tested revisions; nothing updates during ordinary startup.
vim.pack.add({
  { src = 'https://github.com/nvim-lua/plenary.nvim' },
  { src = 'https://github.com/nvim-tree/nvim-web-devicons' },
  { src = 'https://github.com/nvim-lualine/lualine.nvim' },
  { src = 'https://github.com/tpope/vim-fugitive' },
  { src = 'https://github.com/tpope/vim-rhubarb' },
  { src = 'https://github.com/nvim-telescope/telescope.nvim' },
  { src = 'https://github.com/nvim-telescope/telescope-file-browser.nvim' },
  { src = 'https://github.com/nvim-tree/nvim-tree.lua' },
  { src = 'https://github.com/neovim/nvim-lspconfig' },
  { src = 'https://github.com/mason-org/mason.nvim' },
  { src = 'https://github.com/mason-org/mason-lspconfig.nvim' },
  { src = 'https://github.com/saghen/blink.cmp', version = vim.version.range('1.*') },
  { src = 'https://github.com/rafamadriz/friendly-snippets' },
  { src = 'https://github.com/nvim-treesitter/nvim-treesitter', version = 'main' },
  { src = 'https://github.com/nvimdev/lspsaga.nvim' },
  { src = 'https://github.com/windwp/nvim-autopairs' },
  { src = 'https://github.com/windwp/nvim-ts-autotag' },
  { src = 'https://github.com/mg979/vim-visual-multi', version = 'master' },
}, { confirm = false, load = true })

vim.api.nvim_create_user_command('PluginsUpdate', function() vim.pack.update() end,
  { desc = 'Review plugin updates; :write to apply, :quit to cancel' })
vim.api.nvim_create_user_command('PluginsRestore', function()
  vim.pack.update(nil, { target = 'lockfile' })
end, { desc = 'Restore the plugin revisions recorded in the lockfile' })

require('nvim-autopairs').setup({ disable_filetype = { 'TelescopePrompt', 'vim' } })
require('nvim-ts-autotag').setup({})
vim.cmd([[cnoreabbrev <expr> g getcmdtype() == ':' && getcmdline() ==# 'g' ? 'Git' : 'g']])
vim.cmd([[cnoreabbrev <expr> gopen getcmdtype() == ':' && getcmdline() ==# 'gopen' ? 'GBrowse' : 'gopen']])
