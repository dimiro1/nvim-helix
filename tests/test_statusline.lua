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

T['build']['paints the mode badge when active'] = function()
  eq(
    sl.build({ mode_label = 'INS', color = true, file = 'x', line = 1, col = 1 }),
    ' %#StatuslineModeInsert# INS %#StatusLine# %=x%=1:1 '
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

return T
