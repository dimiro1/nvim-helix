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

-- Native as-you-type completion: LSP first via the 'o' source
-- ('omnifunc' is vim.lsp.omnifunc on attached buffers), then buffer words.
-- ^N caps candidates per source.
o.autocomplete = true
o.complete = 'o^10,.^5,w^5,b^5'
o.completeopt = 'menuone,noselect,fuzzy,popup'
o.shortmess = o.shortmess .. 'c'

-- helix: end-of-line-diagnostics everywhere except the cursor line, which
-- gets the expanded inline rendering (inline-diagnostics.cursor-line)
vim.diagnostic.config({
  severity_sort = true,
  signs = true,
  virtual_text = { current_line = false },
  virtual_lines = { current_line = true },
})

return M
