-- A native Lua tree replaces Defx and its Python host; keep the familiar keys.
local api = require('nvim-tree.api')
require('nvim-tree').setup({
  disable_netrw = true,
  hijack_netrw = false,
  renderer = { icons = { glyphs = { folder = { arrow_closed = '▸', arrow_open = '▾' } } } },
  on_attach = function(buf)
    api.config.mappings.default_on_attach(buf)
    local function map(key, action, desc)
      vim.keymap.set('n', key, action, { buffer = buf, silent = true, nowait = true, desc = desc })
    end
    map('<CR>', api.node.open.edit, 'Open')
    map('l', api.node.open.edit, 'Open')
    map('c', api.fs.copy.node, 'Copy')
    map('m', api.fs.cut, 'Move')
    map('p', api.fs.paste, 'Paste')
    map('E', api.node.open.vertical, 'Vertical split')
    map('P', api.node.open.preview, 'Preview')
    map('o', api.node.open.edit, 'Open or toggle directory')
    map('N', api.fs.create, 'New file (end with / for a directory)')
    map('K', api.fs.create, 'New directory (end the name with /)')
    map('d', api.fs.remove, 'Delete')
    map('r', api.fs.rename, 'Rename')
    map('yy', api.fs.copy.absolute_path, 'Copy path')
    map('.', api.filter.dotfiles.toggle, 'Toggle hidden files')
    map('h', api.tree.change_root_to_parent, 'Parent directory')
    map('~', function() api.tree.change_root(vim.fn.expand('~')) end, 'Home directory')
    map('q', api.tree.close, 'Close tree')
    map('<Space>', function() api.marks.toggle(); vim.cmd.normal({ 'j', bang = true }) end, 'Mark and move down')
    map('<C-l>', api.tree.reload, 'Refresh')
    map('cd', api.tree.change_root_to_node, 'Change root')
  end,
})
local function open()
  api.tree.open({ current_window = true, find_file = true })
end
vim.keymap.set('n', '<leader>dff', open, { desc = 'File tree' })
vim.keymap.set('n', 'sf', open, { desc = 'File tree at current file' })
vim.keymap.set('n', 'fi', open, { desc = 'File tree at current file' })
