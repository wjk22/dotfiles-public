-- Blink replaces nvim-cmp's source plugins and the two conflicting snippet
-- engines. Use the built-in Lua matcher: no binary download or Rust build.
require('blink.cmp').setup({
  keymap = {
    preset = 'none',
    ['<C-Space>'] = { 'show', 'show_documentation', 'hide_documentation' },
    ['<C-e>'] = { 'cancel', 'fallback' },
    ['<C-d>'] = { 'scroll_documentation_up', 'fallback' },
    ['<C-f>'] = { 'scroll_documentation_down', 'fallback' },
    ['<C-h>'] = { 'select_next', 'fallback' },
    ['<Tab>'] = { 'select_next', 'snippet_forward', 'fallback' },
    ['<S-Tab>'] = { 'select_prev', 'snippet_backward', 'fallback' },
    ['<Down>'] = { 'select_next', 'fallback' },
    ['<Up>'] = { 'select_prev', 'fallback' },
    ['<CR>'] = { 'select_and_accept', 'fallback' },
  },
  appearance = { nerd_font_variant = 'normal' },
  completion = {
    list = { selection = { preselect = false, auto_insert = false } },
    menu = { draw = { columns = { { 'kind_icon' }, { 'label', 'label_description', gap = 1 }, { 'kind' } } } },
    documentation = { auto_show = true, window = { border = 'rounded' } },
  },
  sources = { default = { 'lsp', 'path', 'snippets', 'buffer' } },
  snippets = { preset = 'default' }, -- vim.snippet + friendly-snippets
  fuzzy = { implementation = 'lua' },
  cmdline = { enabled = true, keymap = { preset = 'cmdline' } },
})
