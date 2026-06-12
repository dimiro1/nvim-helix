-- Editor options mirroring the user's Helix config where Neovim differs.
local M = {}

-- listchars value rendering indent guides ("┊") for space indentation at
-- the given shiftwidth. Tab indentation is covered by the tab: item.
function M.indent_listchars(shiftwidth)
  return 'tab:┊ ,leadmultispace:┊' .. string.rep(' ', math.max(shiftwidth - 1, 1))
end

local o = vim.o

-- helix: line-number = "relative" (hybrid: absolute on cursor line)
o.number = true
o.relativenumber = true
o.signcolumn = 'yes'
o.updatetime = 250 -- CursorHold latency: document-highlight responsiveness
o.ignorecase = true
o.smartcase = true
o.splitright = true
o.splitbelow = true

-- helix: popup-border = "all"
o.winborder = 'single'

-- helix: tab-width = 4 (display and indent width; expandtab stays with
-- the ftplugins so Go keeps real tabs)
o.tabstop = 4
o.shiftwidth = 4

-- helix: soft-wrap.enable = true
o.wrap = true
o.linebreak = true
o.breakindent = true

-- helix: indent-guides.render = true, character = "┊"
-- (skip-levels = 1 is not expressible with listchars; guides start at col 1)
o.list = true
o.listchars = M.indent_listchars(vim.o.shiftwidth)
vim.api.nvim_create_autocmd('OptionSet', {
  pattern = 'shiftwidth',
  group = vim.api.nvim_create_augroup('config.indentguides', {}),
  callback = function()
    -- vim.fn.shiftwidth() resolves sw=0 ("follow tabstop"), which e.g.
    -- the bundled Go ftplugin uses
    vim.opt_local.listchars = M.indent_listchars(vim.fn.shiftwidth())
  end,
})

-- What a workspace session captures; 'terminal' deliberately
-- excluded for clean restores.
o.sessionoptions = 'blank,buffers,curdir,folds,help,tabpages,winsize'

-- Native as-you-type completion. Sources, in order: 'o' = LSP (omnifunc),
-- '.' = current buffer, 'w' = other windows, 'b' = other loaded buffers;
-- ^N caps how many matches each source may contribute.
o.autocomplete = true
o.complete = 'o^10,.^5,w^5,b^5'
o.completeopt = 'menuone,noselect,fuzzy,popup'
-- silence the "match 1 of N" messages while completing
o.shortmess = o.shortmess .. 'c'

-- Cmdline autocompletion (:h cmdline-autocompletion): popup menu as you
-- type, nothing preselected so the typed text is never clobbered, fuzzy
-- filtering to match the pickers.
o.wildmode = 'noselect:lastused,full'
vim.opt.wildoptions:append('fuzzy')
vim.api.nvim_create_autocmd('CmdlineChanged', {
  pattern = { ':', '/', '\\?' },
  group = vim.api.nvim_create_augroup('config.cmdlinecomplete', {}),
  callback = function()
    vim.fn.wildtrigger()
  end,
})

-- helix: end-of-line-diagnostics everywhere except the cursor line, which
-- gets the expanded inline rendering (inline-diagnostics.cursor-line)
vim.diagnostic.config({
  severity_sort = true,
  signs = true,
  virtual_text = { current_line = false },
  virtual_lines = { current_line = true },
})

-- The experimental ui2 message/cmdline layer (:h ui2) drops hit-enter
-- prompts: long messages collapse behind a [+x] spill indicator (g<
-- expands) and :messages gets a real pager buffer. enable() no-ops unless
-- a UI is attached, so it is exposed here for callers that attach one
-- first (the TUI attaches before init).
function M.enable_ui2()
  require('vim._core.ui2').enable()
end
M.enable_ui2()

return M
