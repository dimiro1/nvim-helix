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
    '%#TablineCurrent# a.go %#TabLine# b.go [+] %#TabLineFill#'
  )
end

T['build']['escapes percent signs in file names'] = function()
  eq(
    tl.build({ { name = '100%.txt', current = true } }),
    '%#TablineCurrent# 100%%.txt %#TabLineFill#'
  )
end

T['build']['numbers real tab pages on the right, current highlighted'] = function()
  eq(
    tl.build({ { name = 'a', current = true } }, { tabs = { count = 3, current = 2 } }),
    '%#TablineCurrent# a %#TabLineFill#'
      .. '%=%#TabLine# 1 %#TablineCurrent# 2 %#TabLine# 3 %#TabLineFill#'
  )
end

T['build']['omits the tab numbers with a single tab page'] = function()
  eq(
    tl.build({ { name = 'a', current = true } }, { tabs = { count = 1, current = 1 } }),
    '%#TablineCurrent# a %#TabLineFill#'
  )
end

T['build']['scrolls a list wider than the screen around the current buffer'] = function()
  local bufs = {}
  for i = 1, 20 do
    bufs[i] = { name = ('file%02d.go'):format(i), current = i == 15 }
  end
  local out = tl.build(bufs, { width = 60 })
  -- the current buffer survives, with overflow markers on both sides
  eq(out:find('%#TablineCurrent# file15.go ', 1, true) ~= nil, true)
  eq(out:find(' ‹', 1, true) ~= nil, true)
  eq(out:find('› ', 1, true) ~= nil, true)
  eq(out:find('file01.go', 1, true), nil)
  -- and the drawn text fits the screen
  local visible = out:gsub('%%#[^#]*#', '')
  eq(vim.fn.strdisplaywidth(visible) <= 60, true)
end

T['build']['leaves a list that fits unmarked'] = function()
  local out = tl.build({ { name = 'a', current = true }, { name = 'b' } }, { width = 80 })
  eq(out:find('‹', 1, true), nil)
  eq(out:find('›', 1, true), nil)
end

T['window'] = MiniTest.new_set()

T['window']['returns the whole list when it fits'] = function()
  eq({ tl.window({ 10, 10, 10 }, 2, 30) }, { 1, 3 })
end

T['window']['grows outward from the current buffer, right first'] = function()
  -- 10 columns of room after reserving both markers: current + one neighbour
  local budget = 20 + 2 * tl.marker_width
  eq({ tl.window({ 10, 10, 10, 10, 10 }, 3, budget) }, { 3, 4 })
end

T['window']['falls back to the left edge at the end of the list'] = function()
  local budget = 20 + 2 * tl.marker_width
  eq({ tl.window({ 10, 10, 10, 10, 10 }, 5, budget) }, { 4, 5 })
end

T['window']['keeps the current buffer even when it alone overflows'] = function()
  eq({ tl.window({ 10, 99, 10 }, 2, 30) }, { 2, 2 })
end

T['window']['shows the whole list with no current buffer to anchor on'] = function()
  eq({ tl.window({ 50, 50 }, nil, 30) }, { 1, 2 })
end

T['unique_names'] = MiniTest.new_set()

T['unique_names']['keeps bare file names when they differ'] = function()
  eq(tl.unique_names({ '/p/a/x.lua', '/p/b/y.lua' }), { 'x.lua', 'y.lua' })
end

T['unique_names']['adds parents to colliding names only'] = function()
  eq(
    tl.unique_names({ '/p/config/init.lua', '/p/nvim/init.lua', '/p/z.lua' }),
    { 'config/init.lua', 'nvim/init.lua', 'z.lua' }
  )
end

T['unique_names']['goes as deep as it takes'] = function()
  eq(
    tl.unique_names({ '/a/src/main.go', '/b/src/main.go' }),
    { 'a/src/main.go', 'b/src/main.go' }
  )
end

T['unique_names']['stops at the root when paths are identical'] = function()
  eq(tl.unique_names({ '[scratch]', '[scratch]' }), { '[scratch]', '[scratch]' })
end

T['blend'] = MiniTest.new_set()

T['blend']['interpolates each channel'] = function()
  eq(tl.blend(0x000000, 0xffffff, 0), 0x000000)
  eq(tl.blend(0x000000, 0xffffff, 1), 0xffffff)
  eq(tl.blend(0x000000, 0xc8c8c8, 0.5), 0x646464)
  eq(tl.blend(0x102030, 0x102030, 0.3), 0x102030)
end

T['build']['renders an empty list as just fill'] = function()
  eq(tl.build({}), '%#TabLineFill#')
end

T['display_name'] = MiniTest.new_set()

T['display_name']['takes the basename of a plain path'] = function()
  eq(tl.display_name('/home/u/proj/two.txt'), 'two.txt')
end

T['display_name']['labels a nameless buffer as scratch'] = function()
  eq(tl.display_name(''), '[scratch]')
end

T['display_name']['reduces a jdtls class-file uri to the class name'] = function()
  -- jdt:// names carry a ?=… query and url-encoded path; the raw basename
  -- would be mangled, so only the final class segment should show
  eq(
    tl.display_name('jdt://contents/java.base/java.lang/String.class?=demo/\\/modules'),
    'String.class'
  )
  eq(
    tl.display_name(
      'jdt://contents/jackson-databind.jar/com.fasterxml.jackson.databind/ObjectMapper.class?=x'
    ),
    'ObjectMapper.class'
  )
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
  eq(rendered:find('%#TablineCurrent# two.txt ', 1, true) ~= nil, true)
end

T['in a live instance']['render tells same-named buffers apart'] = function()
  child.lua([[vim.cmd.edit('init.lua') vim.cmd.edit('lua/config/init.lua') vim.wait(50)]])
  local rendered = child.lua_get([[require('config.tabline').render()]])
  -- the repo checkout's own directory name labels the top-level init.lua
  local top = child.lua_get([[vim.fs.basename(assert(vim.uv.cwd()))]]) .. '/init.lua'
  eq(rendered:find(' ' .. top .. ' ', 1, true) ~= nil, true)
  eq(rendered:find(' config/init.lua ', 1, true) ~= nil, true)
end

T['in a live instance']['render numbers real tab pages'] = function()
  child.lua([[vim.cmd.edit('one.txt') vim.cmd.tabnew('two.txt') vim.wait(50)]])
  local rendered = child.lua_get([[require('config.tabline').render()]])
  eq(rendered:find('%=%#TabLine# 1 %#TablineCurrent# 2 ', 1, true) ~= nil, true)
end

T['in a live instance']['the current buffer gets a lifted fill under a flat theme'] = function()
  -- anysphere draws TabLineSel on the bar's own background
  local hl = child.lua_get([[(function()
    local function get(name) return vim.api.nvim_get_hl(0, { name = name, link = false }) end
    return { cur = get('TablineCurrent'), fill = get('TabLineFill'), sel = get('TabLineSel') }
  end)()]])
  eq(hl.sel.bg, hl.fill.bg)
  eq(hl.cur.bg, tl.blend(hl.fill.bg, hl.sel.fg, tl.lift))
  eq(hl.cur.fg, hl.sel.fg)
  eq(hl.cur.bold, true)
end

T['in a live instance']['the current buffer keeps the theme fill when it has one'] = function()
  child.lua([[
    vim.api.nvim_set_hl(0, 'TabLineSel', { fg = 0xffffff, bg = 0x334455 })
    require('config.tabline').paint()
  ]])
  eq(
    child.lua_get([[vim.api.nvim_get_hl(0, { name = 'TablineCurrent' })]]),
    { link = 'TabLineSel' }
  )
end

T['in a live instance']['repaints the current buffer on colorscheme change'] = function()
  child.lua([[vim.cmd.colorscheme('rose-pine')]])
  local hl = child.lua_get([[(function()
    local function get(name) return vim.api.nvim_get_hl(0, { name = name, link = false }) end
    return { cur = get('TablineCurrent'), fill = get('TabLineFill'), normal = get('Normal') }
  end)()]])
  -- whichever path paint() took, the current buffer stands off the bar
  eq(type(hl.cur.bg), 'number')
  eq(hl.cur.bg ~= (hl.fill.bg or hl.normal.bg), true)
end

return T
