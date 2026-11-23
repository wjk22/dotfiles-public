-- One config for Linux, WSL and Windows. Personal changes go in nvim.local.lua
-- next to this config directory, so installing/updating never replaces them.
if vim.fn.has('nvim-0.12') == 0 then
  error('These dotfiles need Neovim 0.12 or newer; see the repository README.')
end

vim.g.mapleader = ' '
vim.g.maplocalleader = ' '
require('config.options')
vim.cmd.source(vim.fn.stdpath('config') .. '/maps.vim')
vim.g.neosolarized_termtrans = 1
vim.cmd.colorscheme('NeoSolarized')

require('config.plugins')
require('config.ui')
require('config.completion')
require('config.lsp')
require('config.treesitter')
require('config.explorer')
require('config.pickers')

local local_config = vim.fn.stdpath('config') .. '.local.lua'
if vim.fn.filereadable(local_config) == 1 then
  dofile(local_config)
end
