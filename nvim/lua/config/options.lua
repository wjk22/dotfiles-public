local opt = vim.opt
opt.number = true
opt.title = true
opt.autoindent = true
opt.smartindent = true
opt.expandtab = true
opt.shiftwidth = 2
opt.tabstop = 2
opt.scrolloff = 10
opt.wrap = false
opt.ignorecase = true
opt.smartcase = true
opt.hlsearch = true
opt.inccommand = 'split'
opt.laststatus = 2
opt.cmdheight = 1
opt.showcmd = false
opt.ruler = false
opt.showmode = false
opt.cursorline = true
opt.termguicolors = true
opt.background = 'dark'
opt.winblend = 0
opt.pumblend = 5
opt.fileencodings = { 'utf-8', 'sjis', 'euc-jp', 'latin1' }
opt.backup = false
opt.path:append('**')
opt.wildignore:append('*/node_modules/*')
opt.suffixesadd:append({ '.js', '.es', '.jsx', '.json', '.css', '.less', '.sass', '.styl', '.php', '.py', '.md' })
opt.exrc = true -- Neovim's trust database asks before loading project code.

-- Never force zsh on Windows. Keep its native default shell.
if vim.fn.has('win32') == 0 and vim.fn.executable('zsh') == 1 then
  opt.shell = vim.fn.exepath('zsh')
end

vim.filetype.add({ extension = { pow = 'pow', es6 = 'javascript', flow = 'javascript', mdx = 'markdown' } })
local group = vim.api.nvim_create_augroup('DotfilesOptions', { clear = true })
vim.api.nvim_create_autocmd('WinEnter', { group = group, callback = function() vim.wo.cursorline = true end })
vim.api.nvim_create_autocmd('WinLeave', { group = group, callback = function() vim.wo.cursorline = false end })
vim.api.nvim_create_autocmd('FileType', {
  group = group,
  callback = function() vim.opt_local.formatoptions:append('r') end,
})
