local opts = require('config.options')

local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      child.restart({ '-u', 'init.lua' })
    end,
    post_once = child.stop,
  },
})

local eq = MiniTest.expect.equality

T['leader is space'] = function()
  eq(child.lua_get([[vim.g.mapleader]]), ' ')
end

T['line numbers are relative with absolute cursor line'] = function()
  eq(child.lua_get([[vim.o.number]]), true)
  eq(child.lua_get([[vim.o.relativenumber]]), true)
end

T['soft wrap is on'] = function()
  eq(child.lua_get([[vim.o.wrap]]), true)
  eq(child.lua_get([[vim.o.linebreak]]), true)
  eq(child.lua_get([[vim.o.breakindent]]), true)
end

T['floats get borders (helix popup-border)'] = function()
  eq(child.lua_get([[vim.o.winborder]]), 'single')
end

T['tabs are four wide (helix tab-width)'] = function()
  eq(child.lua_get([[vim.o.tabstop]]), 4)
  eq(child.lua_get([[vim.o.shiftwidth]]), 4)
  -- expandtab is left to ftplugins so Go keeps real tabs
  eq(child.lua_get([[vim.o.expandtab]]), false)
end

T['indent guides render via listchars'] = function()
  eq(child.lua_get([[vim.o.list]]), true)
  eq(child.lua_get([[vim.o.listchars]]):find('┊', 1, true) ~= nil, true)
end

T['indent_listchars sizes guides to shiftwidth'] = function()
  eq(opts.indent_listchars(2), 'tab:┊ ,leadmultispace:┊ ')
  eq(opts.indent_listchars(4), 'tab:┊ ,leadmultispace:┊   ')
end

T['native as-you-type completion is on'] = function()
  eq(child.lua_get([[vim.o.autocomplete]]), true)
  eq(child.lua_get([[vim.o.complete]]), 'o^10,.^5,w^5,b^5')
end

T['completeopt matches the helix-style menu'] = function()
  local completeopt = child.lua_get([[vim.o.completeopt]])
  for _, flag in ipairs({ 'menuone', 'noselect', 'fuzzy', 'popup' }) do
    eq(completeopt:find(flag, 1, true) ~= nil, true)
  end
end

T['cmdline completes as you type (cmdline autocompletion)'] = function()
  eq(child.lua_get([[vim.o.wildmode]]), 'noselect:lastused,full')
  eq(child.lua_get([[vim.o.wildoptions]]):find('fuzzy', 1, true) ~= nil, true)
  local autocmds = child.lua_get(
    [[#vim.api.nvim_get_autocmds({ group = 'config.cmdlinecomplete', event = 'CmdlineChanged' })]]
  )
  eq(autocmds > 0, true)
end

T['typing a command pops the completion menu unselected'] = function()
  child.type_keys(':', 'ech')
  eq(child.lua_get([[vim.fn.wildmenumode()]]), 1)
  -- noselect: the typed text is untouched until the user picks a match
  eq(child.lua_get([[vim.fn.getcmdline()]]), 'ech')
  child.type_keys('<Esc>')
end

T['typing a search pattern pops buffer-word completion'] = function()
  child.lua([[vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'alpha', 'alpine' })]])
  child.type_keys('/', 'alp')
  eq(child.lua_get([[vim.fn.wildmenumode()]]), 1)
  child.type_keys('<Esc>')
end

T['experimental ui2 message layer activates with a UI'] = function()
  -- ui2's enable() no-ops headless (as test children boot), so attach a
  -- UI over RPC and rerun the config's enable step; activation is
  -- observable through the autocmds the upstream module installs.
  eq(child.lua_get([[#vim.api.nvim_get_autocmds({ group = 'nvim.ui2' })]]), 0)
  child.api.nvim_ui_attach(80, 24, {})
  child.lua([[require('config.options').enable_ui2()]])
  eq(child.lua_get([[#vim.api.nvim_get_autocmds({ group = 'nvim.ui2' }) > 0]]), true)
end

T['search is smart-case like helix'] = function()
  eq(child.lua_get([[vim.o.ignorecase]]), true)
  eq(child.lua_get([[vim.o.smartcase]]), true)
end

T['splits open right and below'] = function()
  eq(child.lua_get([[vim.o.splitright]]), true)
  eq(child.lua_get([[vim.o.splitbelow]]), true)
end

T['the built-in mode message is off (the statusline badge replaces it)'] = function()
  eq(child.lua_get([[vim.o.showmode]]), false)
end

T['diagnostics: eol text off the cursor line, expanded on it'] = function()
  eq(child.lua_get([[vim.diagnostic.config().severity_sort]]), true)
  eq(child.lua_get([[vim.diagnostic.config().signs]]), true)
  eq(child.lua_get([[vim.diagnostic.config().virtual_text.current_line]]), false)
  eq(child.lua_get([[vim.diagnostic.config().virtual_lines.current_line]]), true)
end

T['gutter is always visible'] = function()
  eq(child.lua_get([[vim.o.signcolumn]]), 'yes')
end

T['cursorhold is snappy for document highlight'] = function()
  eq(child.lua_get([[vim.o.updatetime]]), 250)
end

return T
