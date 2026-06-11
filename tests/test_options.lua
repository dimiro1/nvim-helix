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

T['search is smart-case like helix'] = function()
  eq(child.lua_get([[vim.o.ignorecase]]), true)
  eq(child.lua_get([[vim.o.smartcase]]), true)
end

T['splits open right and below'] = function()
  eq(child.lua_get([[vim.o.splitright]]), true)
  eq(child.lua_get([[vim.o.splitbelow]]), true)
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
