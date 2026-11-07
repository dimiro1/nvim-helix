-- Persistent project tree, separate from the fzf-lua directory pickers.
-- Only tree buffers override / and the width keys; editing grammar stays native.
local M = {}

function M.toggle()
  local api = require('nvim-tree.api')
  if api.tree.is_visible() then
    api.tree.close()
  else
    api.tree.open({ path = require('config.pickers').workspace_root(), find_file = true })
  end
end

function M.start_filter()
  local api = require('nvim-tree.api')
  -- Live filtering only sees loaded nodes. Discover nested files before
  -- filtering so a collapsed directory does not conceal a matching file.
  api.tree.expand_all()
  api.filter.live.start()
end

function M.on_attach(buf)
  local api = require('nvim-tree.api')
  api.map.on_attach.default(buf)
  local function map(key, callback, desc)
    vim.keymap.set('n', key, callback, {
      buffer = buf, silent = true, nowait = true, desc = desc,
    })
  end
  map('/', M.start_filter, 'Filter tree by filename')
  map('>', function() api.tree.resize({ relative = 5 * vim.v.count1 }) end, 'Widen tree')
  map('<', function() api.tree.resize({ relative = -5 * vim.v.count1 }) end, 'Narrow tree')
end

function M.setup()
  require('nvim-tree').setup({
    on_attach = M.on_attach,
    view = { width = 40 },
    sync_root_with_cwd = true,
    update_focused_file = { enable = true },
    actions = { change_dir = { enable = false } },
    renderer = { group_empty = true, icons = { show = { file = false } } },
    filters = { git_ignored = true, dotfiles = false, custom = { '^\\.git$' } },
    live_filter = { always_show_folders = false },
  })
end

return M
