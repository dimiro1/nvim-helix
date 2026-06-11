-- Plugin set (ADR 0001, 0004): each entry covers something Neovim
-- structurally lacks. Managed by native vim.pack; lockfile is committed.
local M = {}

M.specs = {
  { src = 'https://github.com/ibhagwan/fzf-lua' },
  -- 'main' pins are load-bearing: the default branches are frozen legacy.
  { src = 'https://github.com/nvim-treesitter/nvim-treesitter', version = 'main' },
  { src = 'https://github.com/nvim-treesitter/nvim-treesitter-textobjects', version = 'main' },
  -- passes the ADR 0004 bar: pinning the enclosing scope while scrolling
  -- needs a managed overlay window Neovim has no primitive for
  { src = 'https://github.com/nvim-treesitter/nvim-treesitter-context' },
  { src = 'https://github.com/tpope/vim-surround' },
  { src = 'https://github.com/tpope/vim-repeat' },
  -- Modules used: clue (infobox), pairs, diff, test. Nothing else.
  { src = 'https://github.com/nvim-mini/mini.nvim' },
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

  require('mini.pairs').setup()

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
    window = { delay = 250 }, -- Helix infobox feel: show promptly
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

  -- ships with mini.nvim (mini.hues), so it can only load after pack.add
  vim.cmd.colorscheme('miniwinter')
end

return M
