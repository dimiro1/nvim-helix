-- Plugin set: each entry covers something Neovim
-- structurally lacks. Managed by native vim.pack; lockfile is committed.
local M = {}

M.specs = {
  { src = 'https://github.com/ibhagwan/fzf-lua' },
  -- 'main' pins are load-bearing: the default branches are frozen legacy.
  { src = 'https://github.com/nvim-treesitter/nvim-treesitter', version = 'main' },
  { src = 'https://github.com/nvim-treesitter/nvim-treesitter-textobjects', version = 'main' },
  -- pinning the enclosing scope while scrolling needs a managed overlay
  -- window Neovim has no primitive for
  { src = 'https://github.com/nvim-treesitter/nvim-treesitter-context' },
  { src = 'https://github.com/tpope/vim-surround' },
  { src = 'https://github.com/tpope/vim-repeat' },
  -- Modules used: mini.clue (infobox), mini.pairs, mini.diff, mini.jump2d,
  -- mini.ai, mini.test. Nothing else.
  { src = 'https://github.com/nvim-mini/mini.nvim' },
  -- colorschemes; the repo is named 'neovim', so pin the plugin name
  { src = 'https://github.com/rose-pine/neovim', name = 'rose-pine' },
  { src = 'https://github.com/savq/melange-nvim' },
}

-- Parsers in priority order. lua is bundled with Neovim, but installing
-- nvim-treesitter's keeps it in lockstep with the plugin's queries.
M.parsers = { 'go', 'gomod', 'javascript', 'typescript', 'tsx', 'python', 'lua' }

M.treesitter_filetypes = {
  'go', 'gomod', 'javascript', 'javascriptreact',
  'typescript', 'typescriptreact', 'python', 'lua',
}

function M.setup()
  vim.pack.add(M.specs)

  require('nvim-treesitter').install(M.parsers)
  vim.api.nvim_create_autocmd('FileType', {
    pattern = M.treesitter_filetypes,
    group = vim.api.nvim_create_augroup('config.treesitter', {}),
    callback = function(args)
      -- Missing parser (e.g. still compiling on first boot) falls back to
      -- legacy syntax instead of erroring.
      pcall(vim.treesitter.start, args.buf)
    end,
  })

  require('nvim-treesitter-textobjects').setup({
    select = { lookahead = true },
    move = { set_jumps = true },
  })

  -- sticky scope headers while scrolling; capped so it never eats the view
  require('treesitter-context').setup({ max_lines = 3 })

  require('fzf-lua').setup({})
  -- vim.ui.select prompts (code actions, …) go through the picker surface
  require('fzf-lua').register_ui_select()

  require('mini.pairs').setup()

  -- Pair textobjects beyond stock Vim: q (nearest quotes of any kind) and
  -- m (helix's "closest surrounding pair"). Only iq/aq/im/am are mapped, in
  -- config.keymaps; the module-wide i/a remap is disabled so stock objects
  -- (ib, i(, iw, …) keep Vim grammar semantics.
  require('mini.ai').setup({
    custom_textobjects = {
      -- nearest of brackets or quotes; <> excluded (comparison-operator
      -- false positives), as in mini.ai's own b builtin
      m = { { '%b()', '%b[]', '%b{}', '%b""', "%b''", '%b``' }, '^.().*().$' },
    },
    mappings = {
      around = '',
      inside = '',
      around_next = '',
      inside_next = '',
      around_last = '',
      inside_last = '',
      goto_left = '',
      goto_right = '',
    },
  })

  -- helix gw word labels; alphabet from the user's helix config (colemak)
  require('mini.jump2d').setup({
    labels = 'arstgmneiodhfuclpwyvk',
    mappings = { start_jumping = '' }, -- gw is mapped in config.keymaps
    silent = true,
  })

  require('mini.diff').setup({
    -- Helix unimpaired keys for changes; apply/reset/textobject keep
    -- mini.diff defaults (gh/gH/gh).
    mappings = {
      goto_first = '[G',
      goto_prev = '[g',
      goto_next = ']g',
      goto_last = ']G',
    },
  })

  local clue = require('mini.clue')
  clue.setup({
    window = {
      delay = 250, -- Helix infobox feel: show promptly
      config = { width = 'auto' }, -- fit the longest clue; default truncates
    },
    triggers = {
      { mode = 'n', keys = '<Leader>' },
      { mode = 'x', keys = '<Leader>' },
      { mode = 'n', keys = '<C-w>' },
      { mode = 'n', keys = 'g' },
      { mode = 'x', keys = 'g' },
      { mode = 'n', keys = 'z' },
      { mode = 'x', keys = 'z' },
      { mode = 'n', keys = ']' },
      { mode = 'n', keys = '[' },
      { mode = 'n', keys = '"' },
      { mode = 'i', keys = '<C-r>' },
    },
    clues = {
      clue.gen_clues.g(),
      clue.gen_clues.windows(),
      clue.gen_clues.z(),
      clue.gen_clues.registers(),
      { mode = 'n', keys = '<Leader>w', desc = '+window' },
    },
  })

  -- plugin colorscheme, so it can only load after pack.add
  vim.cmd.colorscheme('melange')
end

return M
