-- The Helix keymap as data (ADR 0002): Helix owns Space mode and LSP gotos;
-- Vim owns the grammar. Tree-sitter objects/moves are Vim-idiomatic
-- additions. ]t/[t and ]a/[a deliberately shadow Neovim's tag/arglist
-- defaults: Helix's type/argument navigation is a named project goal.
local M = {}

local function pick(name)
  return function()
    require('config.pickers')[name]()
  end
end

local function textobject(query)
  return function()
    require('nvim-treesitter-textobjects.select').select_textobject(query, 'textobjects')
  end
end

local function move(dir, query)
  return function()
    require('nvim-treesitter-textobjects.move')['goto_' .. dir](query, 'textobjects')
  end
end

-- { modes, lhs, rhs, desc, remap = bool }
M.specs = {
  -- Space mode: pickers
  { 'n', '<Leader><Space>', pick('buffers'), 'Open buffer picker' },
  { 'n', '<Leader>f', pick('files'), 'Open file picker (workspace root)' },
  { 'n', '<Leader>F', pick('files_cwd'), 'Open file picker (current dir)' },
  { 'n', '<Leader>b', pick('buffers'), 'Open buffer picker' },
  { 'n', '<Leader>j', pick('jumps'), 'Open jumplist picker' },
  { 'n', '<Leader>g', pick('changed_files'), 'Open changed file picker' },
  { 'n', '<Leader>s', pick('document_symbols'), 'Open symbol picker' },
  { 'n', '<Leader>S', pick('workspace_symbols'), 'Open workspace symbol picker' },
  { 'n', '<Leader>d', pick('diagnostics_buffer'), 'Open diagnostic picker (buffer)' },
  { 'n', '<Leader>D', pick('diagnostics_workspace'), 'Open diagnostic picker (workspace)' },
  { 'n', '<Leader>/', pick('global_search'), 'Global search in workspace' },
  { 'n', '<Leader>?', pick('command_palette'), 'Open command palette' },
  { 'n', "<Leader>'", pick('resume'), 'Open last picker' },
  { 'n', '<Leader>e', pick('directories'), 'Search directories in workspace' },
  { 'n', '<Leader>z', pick('zoxide'), 'Open recent directory picker (zoxide)' },
  {
    'n',
    '<Leader>W',
    function()
      require('config.worktrees').pick()
    end,
    'Open worktree picker (switch workspace)',
  },
  { 'n', '<Leader>.', pick('explorer_buffer_dir'), "Open file explorer (buffer's directory)" },

  -- Space mode: LSP
  { 'n', '<Leader>k', vim.lsp.buf.hover, 'Show docs under cursor' },
  { 'n', '<Leader>r', vim.lsp.buf.rename, 'Rename symbol' },
  { { 'n', 'x' }, '<Leader>a', vim.lsp.buf.code_action, 'Apply code action' },

  -- Space mode: system clipboard
  { { 'n', 'x' }, '<Leader>y', '"+y', 'Yank to clipboard' },
  { 'n', '<Leader>Y', '"+yy', 'Yank line to clipboard' },
  { { 'n', 'x' }, '<Leader>p', '"+p', 'Paste clipboard after' },
  { 'n', '<Leader>P', '"+P', 'Paste clipboard before' },
  { 'x', '<Leader>R', '"+p', 'Replace selection with clipboard' },

  -- Space mode: misc
  { 'n', '<Leader>c', 'gcc', 'Toggle comment', remap = true },
  { 'x', '<Leader>c', 'gc', 'Toggle comment', remap = true },
  {
    'n',
    '<Leader>G',
    function()
      require('mini.diff').toggle_overlay(0)
    end,
    'Toggle git diff overlay',
  },

  -- Floating terminal
  {
    { 'n', 't' },
    '<C-\\>',
    function()
      require('config.terminal').toggle()
    end,
    'Toggle floating terminal',
  },
  { 't', '<Esc><Esc>', '<C-\\><C-n>', 'Leave terminal mode' },
  -- remap so mini.clue's <C-w> trigger shows the window infobox
  { 'n', '<Leader>w', '<C-w>', 'Window mode', remap = true },

  -- Goto mode: LSP jumps
  { 'n', 'gd', pick('definitions'), 'Goto definition' },
  { 'n', 'gy', pick('type_definitions'), 'Goto type definition' },
  { 'n', 'gi', pick('implementations'), 'Goto implementation' },
  { 'n', 'gr', pick('references'), 'Goto references' },

  -- Goto mode: word jump labels (helix gw; shadows Vim's gw format
  -- operator — documented exception in ADR 0002)
  {
    { 'n', 'x' },
    'gw',
    function()
      local jump2d = require('mini.jump2d')
      jump2d.start(jump2d.builtin_opts.word_start)
    end,
    'Jump to word (labels)',
  },

  -- Tree-sitter text objects
  { { 'x', 'o' }, 'if', textobject('@function.inner'), 'Function (inner)' },
  { { 'x', 'o' }, 'af', textobject('@function.outer'), 'Function (around)' },
  { { 'x', 'o' }, 'ic', textobject('@class.inner'), 'Type (inner)' },
  { { 'x', 'o' }, 'ac', textobject('@class.outer'), 'Type (around)' },
  { { 'x', 'o' }, 'ia', textobject('@parameter.inner'), 'Argument (inner)' },
  { { 'x', 'o' }, 'aa', textobject('@parameter.outer'), 'Argument (around)' },

  -- Unimpaired-style moves between text objects (Helix keys)
  { { 'n', 'x', 'o' }, ']f', move('next_start', '@function.outer'), 'Next function' },
  { { 'n', 'x', 'o' }, '[f', move('previous_start', '@function.outer'), 'Previous function' },
  { { 'n', 'x', 'o' }, ']t', move('next_start', '@class.outer'), 'Next type' },
  { { 'n', 'x', 'o' }, '[t', move('previous_start', '@class.outer'), 'Previous type' },
  { { 'n', 'x', 'o' }, ']a', move('next_start', '@parameter.inner'), 'Next argument' },
  { { 'n', 'x', 'o' }, '[a', move('previous_start', '@parameter.inner'), 'Previous argument' },
}

-- Neovim ships a growing family of gr* LSP defaults (gra gri grn grr grt
-- grx as of 0.12). Any survivor keeps Helix's `gr` ambiguous behind a
-- timeout, so sweep the whole prefix instead of naming versions (ADR 0002).
function M.remove_default_gr_family()
  for _, mode in ipairs({ 'n', 'x' }) do
    for _, map in ipairs(vim.api.nvim_get_keymap(mode)) do
      if vim.startswith(map.lhs, 'gr') and #map.lhs > 2 then
        pcall(vim.keymap.del, mode, map.lhs)
      end
    end
  end
end

function M.setup()
  M.remove_default_gr_family()
  for _, spec in ipairs(M.specs) do
    vim.keymap.set(spec[1], spec[2], spec[3], {
      desc = spec[4],
      remap = spec.remap,
      silent = true,
    })
  end
end

return M
