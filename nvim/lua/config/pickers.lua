local telescope = require('telescope')
telescope.setup({
  defaults = { mappings = { n = { q = require('telescope.actions').close } } },
  extensions = { file_browser = { theme = 'ivy' } },
})
telescope.load_extension('file_browser')
local builtin = require('telescope.builtin')
local function map(key, action, desc) vim.keymap.set('n', key, action, { silent = true, desc = desc }) end
map('<leader>tff', '<Cmd>Telescope<CR>', 'Telescope pickers')
map('<leader>ff', builtin.find_files, 'Find files')
map('<leader>fg', builtin.live_grep, 'Search file contents')
map('<leader>fb', telescope.extensions.file_browser.file_browser, 'File browser')
map('\\\\', builtin.buffers, 'Buffers')
map(';;', builtin.help_tags, 'Help tags')
