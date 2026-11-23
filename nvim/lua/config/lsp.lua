require('mason').setup({ ui = { border = 'rounded' } })
-- Install the tools you need with :Mason; installed servers are enabled by the
-- current vim.lsp.config/enable API. No global Node/Python/toolchain installs.
require('mason-lspconfig').setup({ automatic_enable = true })
vim.lsp.config('*', { capabilities = require('blink.cmp').get_lsp_capabilities() })
vim.lsp.config('lua_ls', { settings = { Lua = { diagnostics = { globals = { 'vim' } } } } })

local servers = {
  'ts_ls', 'eslint', 'html', 'cssls', 'jsonls', 'yamlls', 'intelephense',
  'gopls', 'rust_analyzer', 'basedpyright', 'lua_ls', 'bashls',
}
-- Also use language servers already installed by the OS or a toolchain.
for _, name in ipairs(servers) do
  local config = vim.lsp.config[name]
  if config and type(config.cmd) == 'table' and vim.fn.executable(config.cmd[1]) == 1 then
    vim.lsp.enable(name)
  end
end

vim.diagnostic.config({
  underline = true,
  severity_sort = true,
  virtual_text = { spacing = 4, prefix = '' },
  float = { border = 'rounded' },
})
require('lspsaga').setup({
  ui = { border = 'rounded' },
  lightbulb = { enable = false },
  symbol_in_winbar = { enable = false },
})
vim.keymap.set('n', '<leader>lsp', '<Cmd>checkhealth vim.lsp<CR>', { desc = 'Language server status' })
local group = vim.api.nvim_create_augroup('DotfilesLsp', { clear = true })
vim.api.nvim_create_autocmd('LspAttach', {
  group = group,
  callback = function(event)
    local function map(mode, key, action, desc)
      vim.keymap.set(mode, key, action, { buffer = event.buf, silent = true, desc = desc })
    end
    map('n', 'gD', vim.lsp.buf.declaration, 'Declaration')
    map('n', 'gd', vim.lsp.buf.definition, 'Definition')
    map('n', 'gi', vim.lsp.buf.implementation, 'Implementation')
    map('n', 'K', '<Cmd>Lspsaga hover_doc<CR>', 'Hover documentation')
    map('i', '<C-k>', function() vim.lsp.buf.signature_help({ border = 'rounded' }) end, 'Signature help')
    map('n', 'gh', '<Cmd>Lspsaga finder<CR>', 'Find references and implementations')
    map('n', 'gp', '<Cmd>Lspsaga peek_definition<CR>', 'Preview definition')
    map('n', 'gr', '<Cmd>Lspsaga rename<CR>', 'Rename symbol')
    map('n', '<leader>rn', vim.lsp.buf.rename, 'Rename symbol')
    map('n', '<leader>ca', vim.lsp.buf.code_action, 'Code action')
    map('n', '<leader>D', vim.lsp.buf.type_definition, 'Type definition')
    map('n', '<leader>wa', vim.lsp.buf.add_workspace_folder, 'Add workspace folder')
    map('n', '<leader>wr', vim.lsp.buf.remove_workspace_folder, 'Remove workspace folder')
    map('n', '<leader>wl', function() vim.print(vim.lsp.buf.list_workspace_folders()) end, 'Workspace folders')
    map('n', '<leader>e', vim.diagnostic.open_float, 'Line diagnostics')
    map('n', '<leader>q', vim.diagnostic.setloclist, 'Diagnostics list')
    map('n', '<C-j>', '<Cmd>Lspsaga diagnostic_jump_next<CR>', 'Next diagnostic')
    map('n', '<S-C-j>', function() vim.diagnostic.jump({ count = 1, float = true }) end, 'Next diagnostic')
    map('n', '<leader>f', function() vim.lsp.buf.format({ bufnr = event.buf }) end, 'Format buffer')

    local client = vim.lsp.get_client_by_id(event.data.client_id)
    -- Retain format-on-save where the server supports it; TypeScript leaves
    -- formatting to the chosen formatter, as in the old setup.
    if client and client.name == 'ts_ls' then
      client.server_capabilities.documentFormattingProvider = false
    elseif client and client:supports_method('textDocument/formatting', event.buf) then
      vim.api.nvim_clear_autocmds({ group = group, event = 'BufWritePre', buffer = event.buf })
      vim.api.nvim_create_autocmd('BufWritePre', {
        group = group, buffer = event.buf,
        callback = function()
          if vim.b.dotfiles_format_on_save ~= false then
            vim.lsp.buf.format({ bufnr = event.buf, timeout_ms = 2000 })
          end
        end,
      })
    end
  end,
})
