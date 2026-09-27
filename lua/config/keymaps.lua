-- The Helix keymap as data: Helix owns Space mode and LSP gotos;
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

-- mini.ai textobject with its module-wide i/a remap disabled, so
-- the operator-pending plumbing its own mappings would do is replicated
-- here: pass the forced-motion mode (v/V/<C-v> typed after an operator) and
-- the count through to select_textobject.
local function pair_textobject(ai_type, id)
  return function()
    local opts = { n_times = vim.v.count1 }
    local mode = vim.fn.mode(1)
    if mode:sub(1, 2) == 'no' then
      local forced = mode:sub(3)
      opts.operator_pending = true
      opts.vis_mode = forced == '' and 'v' or forced
    end
    require('mini.ai').select_textobject(ai_type, id, opts)
  end
end

-- { modes, lhs, rhs, desc, remap = bool, expr = bool }
M.specs = {
  -- Space mode: pickers
  { 'n', '<Leader><Space>', pick('everything'), 'Open everything picker' },
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
  { 'n', '<Leader>W', pick('worktrees'), 'Open worktree picker (switch workspace)' },
  { 'n', '<Leader>.', pick('explorer_buffer_dir'), "Open file explorer (buffer's directory)" },

  -- Space mode: LSP
  {
    'n',
    '<Leader>k',
    function()
      require('config.lsp').hover()
    end,
    'Show docs under cursor',
  },
  { 'n', '<Leader>r', vim.lsp.buf.rename, 'Rename symbol' },
  { { 'n', 'x' }, '<Leader>a', vim.lsp.buf.code_action, 'Apply code action' },

  -- Space mode: system clipboard
  { { 'n', 'x' }, '<Leader>y', '"+y', 'Yank to clipboard' },
  { 'n', '<Leader>Y', '"+yy', 'Yank line to clipboard' },
  { { 'n', 'x' }, '<Leader>p', '"+p', 'Paste clipboard after' },
  { 'n', '<Leader>P', '"+P', 'Paste clipboard before' },
  { 'x', '<Leader>R', '"+p', 'Replace selection with clipboard' },

  -- Clear search highlights
  { 'n', '<Esc><Esc>', '<Cmd>nohlsearch<CR>', 'Clear search highlights' },

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
  {
    { 'n', 'x' },
    '<Leader>l',
    function()
      require('config.permalink').copy()
    end,
    'Copy git permalink',
  },
  {
    { 'n', 'x' },
    '<Leader>L',
    function()
      require('config.permalink').open()
    end,
    'Open git permalink in browser',
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

  -- Goto mode: incremental jump — type to narrow, labels appear live, press
  -- one to jump. Deliberately shadows Vim's gw format operator (gq remains).
  {
    { 'n', 'x' },
    'gw',
    function()
      require('flash').jump()
    end,
    'Jump (flash)',
  },

  -- Tree-sitter text objects
  { { 'x', 'o' }, 'if', textobject('@function.inner'), 'Function (inner)' },
  { { 'x', 'o' }, 'af', textobject('@function.outer'), 'Function (around)' },
  { { 'x', 'o' }, 'ic', textobject('@class.inner'), 'Type (inner)' },
  { { 'x', 'o' }, 'ac', textobject('@class.outer'), 'Type (around)' },
  { { 'x', 'o' }, 'ia', textobject('@parameter.inner'), 'Argument (inner)' },
  { { 'x', 'o' }, 'aa', textobject('@parameter.outer'), 'Argument (around)' },

  -- Pattern-based pair text objects (mini.ai): new keys, no stock object
  -- shadowed — quotes q has no Vim counterpart, m mirrors helix's
  -- "closest surrounding pair"
  { { 'x', 'o' }, 'iq', pair_textobject('i', 'q'), 'Quotes (inner)' },
  { { 'x', 'o' }, 'aq', pair_textobject('a', 'q'), 'Quotes (around)' },
  { { 'x', 'o' }, 'im', pair_textobject('i', 'm'), 'Surrounding pair (inner)' },
  { { 'x', 'o' }, 'am', pair_textobject('a', 'm'), 'Surrounding pair (around)' },

  -- Cmdline autocompletion pops a menu while typing. Ctrl-Z is wildcharm:
  -- unlike Tab, it triggers completion from a mapping. Ctrl-N needs it to
  -- select the first item; native Ctrl-P already navigates backward.
  {
    'c',
    '<C-n>',
    function()
      return vim.fn.wildmenumode() == 1 and '<C-z>' or '<C-n>'
    end,
    'Next cmdline completion, else newer history',
    expr = true,
  },
  -- Arrows always recall history, even when the typed prefix matches no past
  -- command. Ctrl-E first dismisses the popup without changing the input.
  {
    'c',
    '<Up>',
    function()
      return vim.fn.wildmenumode() == 1 and '<C-e><S-Up>' or '<S-Up>'
    end,
    'Older cmdline history',
    expr = true,
  },
  {
    'c',
    '<Down>',
    function()
      return vim.fn.wildmenumode() == 1 and '<C-e><S-Down>' or '<S-Down>'
    end,
    'Newer cmdline history',
    expr = true,
  },
  {
    'c',
    '<C-k>',
    function()
      vim.fn.setcmdline(vim.fn.getcmdline():sub(1, vim.fn.getcmdpos() - 1))
      return ''
    end,
    'Delete cmdline from cursor to end',
    expr = true,
  },
  -- Readline-style cursor jumps; <C-a> shadows the native insert-all-matches
  {
    'c',
    '<C-a>',
    function()
      return vim.fn.wildmenumode() == 1 and '<C-e><Home>' or '<Home>'
    end,
    'Cursor to start of cmdline',
    expr = true,
  },
  {
    'c',
    '<C-e>',
    function()
      return vim.fn.wildmenumode() == 1 and '<C-e><End>' or '<End>'
    end,
    'Cursor to end of cmdline',
    expr = true,
  },

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
-- timeout, so sweep the whole prefix instead of naming versions.
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
      expr = spec.expr,
      silent = true,
    })
  end
end

return M
