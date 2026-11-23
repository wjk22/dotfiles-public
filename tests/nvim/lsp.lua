-- Integration check: use an isolated profile with lua-language-server installed.
-- nvim --headless '+lua dofile("tests/nvim/lsp.lua")'
local function run()
  local project = vim.fn.stdpath('state') .. '/lsp-fixture'
  vim.fn.mkdir(project, 'p')
  vim.fn.writefile({ '{}' }, project .. '/.luarc.json')
  vim.fn.writefile({ '---@type string', 'local value = 12', 'print(value)', 'math.' }, project .. '/sample.lua')
  vim.cmd('edit ' .. vim.fn.fnameescape(project .. '/sample.lua'))
  assert(vim.wait(20000, function()
    for _, client in ipairs(vim.lsp.get_clients({ bufnr = 0, name = 'lua_ls' })) do
      if client.initialized then return true end
    end
  end, 50), 'Lua language server did not attach')
  print('PASS real Lua language server attached automatically')
  assert(vim.fn.maparg('gr', 'n') ~= '', 'rename mapping missing')
  local results = vim.lsp.buf_request_sync(0, 'textDocument/hover', {
    textDocument = { uri = vim.uri_from_bufnr(0) }, position = { line = 2, character = 2 },
  }, 5000)
  local hover = false
  for _, result in pairs(results or {}) do hover = hover or result.result ~= nil end
  assert(hover, 'hover request returned no documentation')
  print('PASS real LSP hover response')
  assert(vim.wait(15000, function() return #vim.diagnostic.get(0) > 0 end, 50), 'no diagnostics returned')
  local completion = vim.lsp.buf_request_sync(0, 'textDocument/completion', {
    textDocument = { uri = vim.uri_from_bufnr(0) }, position = { line = 3, character = 5 },
    context = { triggerKind = 2, triggerCharacter = '.' },
  }, 10000)
  local has_items = false
  for _, response in pairs(completion or {}) do
    local result = response.result
    if result then has_items = has_items or #(result.items or result) > 0 end
  end
  assert(has_items, 'completion request returned no suggestions')
  print('PASS real LSP completion response')
  print('PASS real LSP diagnostics')
end
local ok, err = pcall(run)
if not ok then io.stderr:write(tostring(err) .. '\n'); vim.cmd('cquit 1') end
vim.cmd('qa!')
