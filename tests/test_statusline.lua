local sl = require('config.statusline')

local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set()

local eq = MiniTest.expect.equality

T['build'] = MiniTest.new_set()

T['build']['renders the segment layout'] = function()
  eq(
    sl.build({
      mode_label = 'NOR', file = 'main.go', line = 12, col = 4,
      encoding = 'utf-8', line_ending = 'LF', filetype = 'go',
    }),
    ' NOR %=main.go%=12:4  utf-8  LF  go '
  )
end

T['build']['shows the git branch next to the mode'] = function()
  eq(
    sl.build({ mode_label = 'NOR', branch = 'main', file = 'x', line = 1, col = 1 }),
    ' NOR  main %=x%=1:1 '
  )
end

T['build']['shows the worktree alongside the branch'] = function()
  eq(
    sl.build({
      mode_label = 'NOR', branch = 'main', worktree = 'kelowna',
      file = 'x', line = 1, col = 1,
    }),
    ' NOR  main (kelowna) %=x%=1:1 '
  )
  -- worktree without a branch renders nothing vcs-ish
  eq(
    sl.build({ mode_label = 'NOR', worktree = 'kelowna', file = 'x', line = 1, col = 1 }),
    ' NOR %=x%=1:1 '
  )
end

T['build']['paints the mode and position badges when active'] = function()
  eq(
    sl.build({ mode_label = 'INS', color = true, file = 'x', line = 1, col = 1 }),
    ' %#StatuslineModeInsert# INS %#StatusLine# %=x%=%#StatuslineModeInsert# 1:1 %#StatusLine# '
  )
end

T['build']['leaves the position uncolored without an active mode'] = function()
  -- color set but no mode label (no badge to borrow the hue from)
  eq(
    sl.build({ color = true, file = 'x', line = 4, col = 9 }),
    '       %=x%=4:9 '
  )
end

T['build']['appends the breadcrumb trail to the center segment'] = function()
  eq(
    sl.build({
      mode_label = 'NOR', file = 'a.go', crumbs = 'Type › method',
      line = 1, col = 1,
    }),
    ' NOR %=a.go › Type › method%=1:1 '
  )
  -- empty trail adds nothing
  eq(
    sl.build({ mode_label = 'NOR', file = 'a.go', crumbs = '', line = 1, col = 1 }),
    ' NOR %=a.go%=1:1 '
  )
end

T['build']['marks modified and read-only buffers'] = function()
  eq(
    sl.build({ mode_label = 'NOR', file = 'a', modified = true, readonly = true, line = 1, col = 1 }),
    ' NOR %=a [+] [RO]%=1:1 '
  )
end

T['build']['separates workspace and buffer diagnostics'] = function()
  eq(
    sl.build({
      mode_label = 'NOR', file = 'a', line = 3, col = 7,
      ws_errors = 3, ws_warnings = 4, errors = 1, warnings = 2,
    }),
    ' NOR %=a%=[E:3 W:4]  E:1 W:2  3:7 '
  )
end

T['build']['blanks the mode for inactive windows'] = function()
  eq(sl.build({ file = 'x', line = 1, col = 1 }), '       %=x%=1:1 ')
end

T['build']['centers the file on the window midpoint when width is known'] = function()
  -- left ' NOR' (4), center 'mid' (3), right '1:1 ' (4) in a width of 40:
  -- center starts at floor((40-3)/2)=18, so 14 spaces left, 15 right
  eq(
    sl.build({ mode_label = 'NOR', file = 'mid', line = 1, col = 1, width = 40 }),
    ' NOR' .. string.rep(' ', 14) .. 'mid' .. string.rep(' ', 15) .. '1:1 '
  )
end

T['build']['keeps the center fixed when the left segment grows'] = function()
  -- a wider left (mode + branch) must not push the center off the midpoint
  eq(
    sl.build({ mode_label = 'NOR', branch = 'main', file = 'X', line = 1, col = 1, width = 40 }),
    ' NOR  main' .. string.rep(' ', 9) .. 'X' .. string.rep(' ', 16) .. '1:1 '
  )
end

T['build']['falls back to %= balancing when too narrow to center'] = function()
  local out = sl.build({
    mode_label = 'NOR', branch = 'averylongbranchname',
    file = 'filename', line = 1, col = 1, width = 20,
  })
  eq(out:find('%=', 1, true) ~= nil, true)
end

T['build']['sheds the metadata tail as the window narrows'] = function()
  local th = sl.right_min_width
  local function at(width)
    return sl.build({
      mode_label = 'NOR', file = 'x', line = 12, col = 3,
      encoding = 'latin1', line_ending = 'LF', filetype = 'lua', width = width,
    })
  end
  local function has(out, part)
    return out:find(part, 1, true) ~= nil
  end

  -- wide: the whole tail is present
  local wide = at(200)
  eq(has(wide, 'latin1'), true)
  eq(has(wide, 'LF'), true)
  eq(has(wide, 'lua'), true)

  -- below the line-ending threshold: LF goes first, the rest stays
  local narrow = at(th.line_ending - 1)
  eq(has(narrow, 'LF'), false)
  eq(has(narrow, 'latin1'), true)
  eq(has(narrow, 'lua'), true)

  -- below the encoding threshold: encoding goes too, file type stays
  local narrower = at(th.encoding - 1)
  eq(has(narrower, 'LF'), false)
  eq(has(narrower, 'latin1'), false)
  eq(has(narrower, 'lua'), true)

  -- below the file-type threshold: the tail is gone, position survives
  local tiny = at(th.filetype - 1)
  eq(has(tiny, 'lua'), false)
  eq(has(tiny, '12:3'), true)
end

T['display_width'] = MiniTest.new_set()

T['display_width']['ignores highlight-group escapes'] = function()
  eq(sl.display_width('%#StatuslineModeInsert# INS %#StatusLine#'), 5)
  eq(sl.display_width(' NOR  main'), 10)
end

T['display_width']['counts multibyte glyphs by display cells'] = function()
  eq(sl.display_width('a › b'), 5)
end

T['diag_segment'] = MiniTest.new_set()

T['diag_segment']['omits zero counts'] = function()
  eq(sl.diag_segment(0, 0), '')
  eq(sl.diag_segment(nil, nil), '')
  eq(sl.diag_segment(2, 0), 'E:2')
  eq(sl.diag_segment(nil, 3), 'W:3')
  eq(sl.diag_segment(1, 2), 'E:1 W:2')
end

T['encoding_label'] = MiniTest.new_set()

T['encoding_label']['hides the unremarkable utf-8'] = function()
  eq(sl.encoding_label('utf-8', 'utf-8'), nil)
  eq(sl.encoding_label('', 'utf-8'), nil)
end

T['encoding_label']['shows other encodings'] = function()
  eq(sl.encoding_label('latin1', 'utf-8'), 'latin1')
  -- empty file encoding falls back to the global one, still shown when not utf-8
  eq(sl.encoding_label('', 'latin1'), 'latin1')
end

T['search_segment'] = MiniTest.new_set()

T['search_segment']['formats the active match position'] = function()
  eq(sl.search_segment(3, 12), '[3/12]')
  eq(sl.search_segment(0, 5), '[0/5]')
end

T['search_segment']['is empty without matches'] = function()
  eq(sl.search_segment(0, 0), '')
  eq(sl.search_segment(nil, nil), '')
  eq(sl.search_segment(1, 0), '')
end

T['parse_head'] = MiniTest.new_set()

T['parse_head']['extracts branch names'] = function()
  eq(sl.parse_head('ref: refs/heads/main'), 'main')
  eq(sl.parse_head('ref: refs/heads/feature/picker-polish'), 'feature/picker-polish')
end

T['parse_head']['short-hashes detached heads'] = function()
  eq(sl.parse_head('abc123def4567890abc123def4567890abc123de'), 'abc123d')
end

T['parse_head']['handles missing content'] = function()
  eq(sl.parse_head(nil), nil)
  eq(sl.parse_head(''), nil)
end

T['mode labels'] = MiniTest.new_set()

T['mode labels']['map vim modes to three-letter abbreviations'] = function()
  eq(sl.mode_labels.n, 'NOR')
  eq(sl.mode_labels.i, 'INS')
  eq(sl.mode_labels.v, 'VIS')
  eq(sl.mode_labels.V, 'VIS')
  eq(sl.mode_labels['\22'], 'VIS')
  eq(sl.mode_labels.R, 'REP')
  eq(sl.mode_labels.c, 'CMD')
  eq(sl.mode_labels.r, 'PMT')
  eq(sl.mode_labels['!'], 'SHL')
  eq(sl.mode_labels.t, 'TRM')
end

T['mode labels']['every label has a highlight group'] = function()
  local seen = {}
  for _, label in pairs(sl.mode_labels) do
    seen[label] = true
  end
  for label in pairs(seen) do
    eq(sl.mode_groups[label] ~= nil, true, 'missing group for ' .. label)
  end
end

T['mode labels']['every group has a fill source'] = function()
  for _, group in pairs(sl.mode_groups) do
    eq(sl.mode_sources[group] ~= nil, true, 'missing source for ' .. group)
  end
end

T['ink'] = MiniTest.new_set()

T['ink']['picks black on light fills, white on dark'] = function()
  eq(sl.ink(0xffffff), 0x000000)
  eq(sl.ink(0x000000), 0xffffff)
  -- a bright green fill is light enough for black ink
  eq(sl.ink(0x00ff00), 0x000000)
  -- a deep blue fill is dark enough for white ink
  eq(sl.ink(0x0000ff), 0xffffff)
end

T['in a live instance'] = MiniTest.new_set({
  hooks = {
    pre_case = function()
      child.restart({ '-u', 'init.lua' })
    end,
    post_once = child.stop,
  },
})

T['in a live instance']['the statusline option points at render'] = function()
  eq(child.lua_get([[vim.o.statusline]]), "%{%v:lua.require'config.statusline'.render()%}")
end

T['in a live instance']['render produces the expected look'] = function()
  -- wide enough that the metadata tail (incl. the line ending) is not shed
  child.lua([[vim.o.columns = 200]])
  child.lua([[vim.cmd.edit('demo.txt')]])
  local rendered = child.lua_get([[require('config.statusline').render()]])
  eq(rendered:find('NOR', 1, true) ~= nil, true)
  eq(rendered:find('demo.txt', 1, true) ~= nil, true)
  eq(rendered:find('1:1', 1, true) ~= nil, true)
  eq(rendered:find('LF', 1, true) ~= nil, true)
end

T['in a live instance']['the branch is cached for repo buffers'] = function()
  child.lua([[vim.cmd.edit('demo.txt')]])
  local branch = child.lua_get([[vim.b.config_branch]])
  -- this repo is a git checkout, so some branch (or short hash) must appear
  eq(type(branch), 'string')
  eq(#branch > 0, true)
end

T['in a live instance']['the worktree name is cached alongside the branch'] = function()
  child.lua([[vim.cmd.edit('demo.txt')]])
  local result = child.lua_get([[(function()
    local root = vim.fs.root(assert(vim.uv.cwd()), '.git')
    return { got = vim.b.config_worktree, want = vim.fs.basename(root) }
  end)()]])
  eq(result.got, result.want)
  eq(#result.got > 0, true)
end

T['in a live instance']['mode highlight groups are defined'] = function()
  for _, group in pairs(sl.mode_groups) do
    eq(
      child.lua_get(([[vim.fn.hlexists('%s')]]):format(group)),
      1
    )
  end
end

T['in a live instance']['centers the file name on the window'] = function()
  -- wide enough that left + center + right leave room to truly center
  child.lua([[vim.o.columns = 200]])
  child.lua([[vim.cmd.edit('centerme.txt')]])
  local m = child.lua_get([[(function()
    local line = require('config.statusline').render()
    local ev = vim.api.nvim_eval_statusline(line, { winid = 0, maxwidth = vim.o.columns })
    local s, e = ev.str:find('centerme.txt', 1, true)
    return { mid = (s + e) / 2, half = ev.width / 2, balanced = line:find('%=', 1, true) ~= nil }
  end)()]])
  -- the centered branch ran (no %= fallback) ...
  eq(m.balanced, false)
  -- ... and the file name's midpoint sits within a column or two of center
  eq(math.abs(m.mid - m.half) <= 2, true)
end

T['in a live instance']['mode badges carry a resolved fill'] = function()
  -- the active theme styles Function, so the normal badge must paint a
  -- concrete fg/bg pair rather than fall back to a plain link
  local hl = child.lua_get(
    [[vim.api.nvim_get_hl(0, { name = 'StatuslineModeNormal', link = false })]]
  )
  eq(type(hl.bg), 'number')
  eq(type(hl.fg), 'number')
end

T['in a live instance']['hides utf-8 but shows other encodings'] = function()
  child.lua([[vim.o.columns = 200]])
  child.lua([[vim.cmd.edit('utf8.txt')]])
  local utf = child.lua_get([[require('config.statusline').render()]])
  eq(utf:find('utf-8', 1, true), nil)
  child.lua([[vim.bo.fileencoding = 'latin1']])
  local latin = child.lua_get([[require('config.statusline').render()]])
  eq(latin:find('latin1', 1, true) ~= nil, true)
end

T['in a live instance']['reports the virtual column, not the byte column'] = function()
  child.lua([[
    vim.cmd.edit('tabs.txt')
    vim.bo.expandtab = false
    vim.bo.tabstop = 8
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { '\tX' })
    vim.api.nvim_win_set_cursor(0, { 1, 1 })
  ]])
  local rendered = child.lua_get([[require('config.statusline').render()]])
  -- 'X' sits at virtual column 9 (past an 8-cell tab); its byte column is 2
  eq(rendered:find('1:9', 1, true) ~= nil, true)
  eq(rendered:find('1:2', 1, true), nil)
end

T['in a live instance']['shows the search match count while searching'] = function()
  child.lua([[
    vim.cmd.edit('search.txt')
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'foo', 'foo', 'foo' })
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    vim.o.hlsearch = true
    vim.fn.setreg('/', 'foo')
    vim.v.hlsearch = 1
  ]])
  local rendered = child.lua_get([[require('config.statusline').render()]])
  eq(rendered:find('[1/3]', 1, true) ~= nil, true)
end

return T
