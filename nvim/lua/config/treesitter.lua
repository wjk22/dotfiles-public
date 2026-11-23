-- Current nvim-treesitter API; syntax/pow.vim remains the Powwow highlighter.
require('nvim-treesitter').setup({})
local group = vim.api.nvim_create_augroup('DotfilesTreesitter', { clear = true })
vim.api.nvim_create_autocmd('FileType', {
  group = group,
  callback = function(event)
    if vim.bo[event.buf].filetype == 'pow' then return end
    -- Plain Vim syntax stays available when a parser has not been installed.
    pcall(vim.treesitter.start, event.buf)
  end,
})
vim.api.nvim_create_user_command('ParsersInstall', function()
  require('nvim-treesitter').install({
    'bash', 'css', 'go', 'gomod', 'html', 'javascript', 'json', 'lua',
    'markdown', 'markdown_inline', 'php', 'python', 'rust', 'scss',
    'toml', 'tsx', 'typescript', 'vim', 'vimdoc', 'yaml', 'fish', 'swift',
  })
end, { desc = 'Install parsers for the configured languages (requires a compiler and tree-sitter CLI)' })
vim.api.nvim_create_autocmd('PackChanged', {
  group = group,
  callback = function(event)
    if event.data.spec.name == 'nvim-treesitter' and event.data.kind == 'update' then
      require('nvim-treesitter').update()
    end
  end,
})
