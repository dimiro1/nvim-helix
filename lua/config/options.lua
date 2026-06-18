-- Editor options mirroring the user's Helix config where Neovim differs.
local M = {}

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

-- The statusline shows the mode as a colored badge, so the built-in
-- '-- INSERT --' line on the command area is redundant.
o.showmode = false

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

-- Indent guides are drawn by mini.indentscope (config.plugins), which marks
-- only the scope at the cursor rather than every level.

-- What a workspace session captures; 'terminal' deliberately
-- excluded for clean restores.
o.sessionoptions = 'blank,buffers,curdir,folds,help,tabpages,winsize'

-- Native as-you-type completion. Sources, in order: 'o' = LSP (omnifunc),
-- '.' = current buffer, 'w' = other windows, 'b' = other loaded buffers;
-- ^N caps how many matches each source may contribute.
o.autocomplete = true
o.complete = 'o^10,.^5,w^5,b^5'
o.completeopt = 'menuone,noselect,fuzzy,popup'
-- 'c' silences "match 1 of N" while completing; 'S' drops the built-in
-- '[1/5]' search-count message, which the statusline now renders itself.
o.shortmess = o.shortmess .. 'cS'

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
