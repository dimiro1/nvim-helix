local sl = require('config.statusline')

local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set()

local eq = MiniTest.expect.equality

T['build'] = MiniTest.new_set()

T['build']['renders the helix segment layout'] = function()
  eq(
    sl.build({
      mode_label = '❮N❯', file = 'main.go', line = 12, col = 4,
      encoding = 'utf-8', line_ending = 'LF', filetype = 'go',
    }),
    ' ❮N❯ %=main.go%=12:4  utf-8  LF  go '
  )
end

T['build']['shows the git branch next to the mode'] = function()
  eq(
    sl.build({ mode_label = '❮N❯', branch = 'main', file = 'x', line = 1, col = 1 }),
    ' ❮N❯  main %=x%=1:1 '
  )
end

T['build']['shows the worktree alongside the branch'] = function()
  eq(
    sl.build({
      mode_label = '❮N❯', branch = 'main', worktree = 'kelowna',
      file = 'x', line = 1, col = 1,
    }),
    ' ❮N❯  main (kelowna) %=x%=1:1 '
  )
  -- worktree without a branch renders nothing vcs-ish
  eq(
    sl.build({ mode_label = '❮N❯', worktree = 'kelowna', file = 'x', line = 1, col = 1 }),
    ' ❮N❯ %=x%=1:1 '
  )
end

T['build']['colors the mode segment when active (color-modes)'] = function()
  eq(
    sl.build({ mode_label = '❮I❯', color = true, file = 'x', line = 1, col = 1 }),
    ' %#StatuslineModeInsert#❮I❯%#StatusLine# %=x%=1:1 '
  )
end

T['build']['appends the breadcrumb trail to the center segment'] = function()
  eq(
    sl.build({
      mode_label = '❮N❯', file = 'a.go', crumbs = 'Type › method',
      line = 1, col = 1,
    }),
    ' ❮N❯ %=a.go › Type › method%=1:1 '
  )
  -- empty trail adds nothing
  eq(
    sl.build({ mode_label = '❮N❯', file = 'a.go', crumbs = '', line = 1, col = 1 }),
    ' ❮N❯ %=a.go%=1:1 '
  )
end

T['build']['marks modified and read-only buffers'] = function()
  eq(
    sl.build({ mode_label = '❮N❯', file = 'a', modified = true, readonly = true, line = 1, col = 1 }),
    ' ❮N❯ %=a [+] [RO]%=1:1 '
  )
end

T['build']['separates workspace and buffer diagnostics'] = function()
  eq(
    sl.build({
      mode_label = '❮N❯', file = 'a', line = 3, col = 7,
      ws_errors = 3, ws_warnings = 4, errors = 1, warnings = 2,
    }),
    ' ❮N❯ %=a%=[E:3 W:4]  E:1 W:2  3:7 '
  )
end

T['build']['blanks the mode for inactive windows'] = function()
  eq(sl.build({ file = 'x', line = 1, col = 1 }), '     %=x%=1:1 ')
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

T['mode labels']['use the personal helix glyphs'] = function()
  eq(sl.mode_labels.n, '❮N❯')
  eq(sl.mode_labels.i, '❮I❯')
  eq(sl.mode_labels.v, '❮V❯')
  eq(sl.mode_labels.V, '❮V❯')
  eq(sl.mode_labels['\22'], '❮V❯')
  eq(sl.mode_labels.c, '❮C❯')
end

T['mode labels']['every label has a highlight group'] = function()
  local seen = {}
  for _, label in pairs(sl.mode_labels) do
    seen[label] = true
  end
  for label in pairs(seen) do
    if label ~= '❮P❯' and label ~= '❮$❯' then
      eq(sl.mode_groups[label] ~= nil, true, 'missing group for ' .. label)
    end
  end
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

T['in a live instance']['render produces the helix look'] = function()
  child.lua([[vim.cmd.edit('demo.txt')]])
  local rendered = child.lua_get([[require('config.statusline').render()]])
  eq(rendered:find('❮N❯', 1, true) ~= nil, true)
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

return T
