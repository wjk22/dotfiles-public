-- Run in an isolated XDG profile after installing plugins:
-- nvim --headless '+lua dofile("tests/nvim/smoke.lua")'
local function check(name, condition)
  assert(condition, name)
  print('PASS ' .. name)
end
local function run()
  check('startup has no errors', vim.v.errmsg == '')
  check('original theme', vim.g.colors_name == 'NeoSolarized')
  check('transparent background', vim.api.nvim_get_hl(0, { name = 'Normal' }).bg == nil)
  check('two-space indentation', vim.o.shiftwidth == 2 and vim.o.tabstop == 2 and vim.o.expandtab)
  check('unwrapped numbered lines', vim.o.number and not vim.o.wrap)
  check('original statusline style', require('lualine').get_config().options.theme == 'solarized_dark')
  check('original tabline', vim.o.tabline == '%!MyTabLine()')
  for _, key in ipairs({ 'ss', 'sv', 'sh', 'sj', 'sk', 'sl', 'te', 'dw', '<Tab>', '<S-Tab>', '<C-a>' }) do
    check('key ' .. key, vim.fn.maparg(key, 'n') ~= '')
  end
  check('18 plugins loaded', #vim.pack.get() == 18)
  check('stable completion with native snippets', require('blink.cmp.config').snippets.preset == 'default')
  check('no Rust matcher dependency', require('blink.cmp.config').fuzzy.implementation == 'lua')
  for _, name in ipairs({ 'ts_ls', 'eslint', 'html', 'cssls', 'jsonls', 'yamlls', 'intelephense', 'gopls', 'rust_analyzer', 'basedpyright', 'lua_ls', 'bashls' }) do
    check('LSP config ' .. name, vim.lsp.config[name] ~= nil)
  end
  vim.cmd('edit ' .. vim.fn.fnameescape(vim.fn.tempname() .. '.pow'))
  check('Powwow file detection', vim.bo.filetype == 'pow')
  check('Powwow syntax loaded', vim.b.current_syntax ~= nil)
  vim.cmd.enew()
  vim.snippet.expand('hello ${1:world}$0')
  check('native snippet expansion', vim.api.nvim_get_current_line() == 'hello world')
  vim.snippet.stop()
  vim.cmd('enew!')
  require('nvim-tree.api').tree.open({ current_window = true })
  check('tree opens', vim.bo.filetype == 'NvimTree')
  for _, key in ipairs({ 'c', 'm', 'p', 'r', 'd', 'E', 'P', 'h', 'K', 'N' }) do
    check('tree key ' .. key, vim.fn.maparg(key, 'n') ~= '')
  end
  require('nvim-tree.api').tree.close()
  require('telescope.builtin').find_files({ cwd = vim.fn.stdpath('config') })
  check('picker opens', vim.bo.filetype == 'TelescopePrompt')
  require('telescope.actions').close(vim.api.nvim_get_current_buf())
  check('no errors after plugins exercised', vim.v.errmsg == '')
end
local ok, err = pcall(run)
if not ok then
  io.stderr:write(tostring(err) .. '\n')
  vim.cmd('cquit 1')
else
  print('ALL SMOKE CHECKS PASSED')
  vim.cmd('qa!')
end
