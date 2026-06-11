local tl = require('config.tabline')

local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set()

local eq = MiniTest.expect.equality

T['build'] = MiniTest.new_set()

T['build']['highlights the current buffer'] = function()
  eq(
    tl.build({
      { name = 'a.go', modified = false, current = true },
      { name = 'b.go', modified = true, current = false },
    }),
    '%#TabLineSel# a.go %#TabLine# b.go [+] %#TabLineFill#'
  )
end

T['build']['renders an empty list as just fill'] = function()
  eq(tl.build({}), '%#TabLineFill#')
end

T['in a live instance'] = MiniTest.new_set({
  hooks = {
    pre_case = function()
      child.restart({ '-u', 'init.lua' })
    end,
    post_once = child.stop,
  },
})

T['in a live instance']['hidden with a single buffer (helix "multiple")'] = function()
  eq(child.lua_get([[vim.o.showtabline]]), 0)
end

T['in a live instance']['appears with a second buffer, disappears again'] = function()
  child.lua([[vim.cmd.edit('one.txt') vim.cmd.edit('two.txt') vim.wait(50)]])
  eq(child.lua_get([[vim.o.showtabline]]), 2)
  eq(child.lua_get([[#require('config.tabline').listed_buffers()]]), 2)
  child.lua([[vim.cmd('bdelete one.txt') vim.wait(50)]])
  eq(child.lua_get([[vim.o.showtabline]]), 0)
end

T['in a live instance']['render lists buffer basenames'] = function()
  child.lua([[vim.cmd.edit('one.txt') vim.cmd.edit('two.txt') vim.wait(50)]])
  local rendered = child.lua_get([[require('config.tabline').render()]])
  eq(rendered:find(' one.txt ', 1, true) ~= nil, true)
  eq(rendered:find('%#TabLineSel# two.txt ', 1, true) ~= nil, true)
end

return T
