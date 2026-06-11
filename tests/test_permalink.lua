local permalink = require('config.permalink')

local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set()

local eq = MiniTest.expect.equality

T['parse_remote'] = MiniTest.new_set()

T['parse_remote']['reads scp-like ssh remotes and strips .git'] = function()
  eq(
    permalink.parse_remote('git@github.com:dimiro1/demo.git'),
    { host = 'github.com', path = 'dimiro1/demo' }
  )
end

T['parse_remote']['reads https remotes with nested groups'] = function()
  eq(
    permalink.parse_remote('https://gitlab.com/group/sub/repo'),
    { host = 'gitlab.com', path = 'group/sub/repo' }
  )
end

T['parse_remote']['reads ssh:// remotes, dropping user and port'] = function()
  eq(
    permalink.parse_remote('ssh://git@codeberg.org:2222/dimiro1/dotfiles.git'),
    { host = 'codeberg.org', path = 'dimiro1/dotfiles' }
  )
end

T['parse_remote']['rejects what it cannot parse'] = function()
  eq(permalink.parse_remote('/local/bare/repo.git'), nil)
  eq(permalink.parse_remote(''), nil)
end

T['anchor'] = MiniTest.new_set()

T['anchor']['is empty without a range'] = function()
  eq(permalink.anchor(permalink.hosts[1], nil), '')
end

T['anchor']['uses the shared single-line form on every host'] = function()
  for _, spec in ipairs(permalink.hosts) do
    eq(permalink.anchor(spec, { 7, 7 }), '#L7', spec.name)
  end
end

T['anchor']['formats ranges per host and normalizes order'] = function()
  local by_name = {}
  for _, spec in ipairs(permalink.hosts) do
    by_name[spec.name] = spec
  end
  eq(permalink.anchor(by_name['GitHub'], { 3, 9 }), '#L3-L9')
  eq(permalink.anchor(by_name['Codeberg'], { 3, 9 }), '#L3-L9')
  eq(permalink.anchor(by_name['GitLab'], { 3, 9 }), '#L3-9')
  eq(permalink.anchor(by_name['GitHub'], { 9, 3 }), '#L3-L9')
end

T['build'] = MiniTest.new_set()

T['build']['assembles a github blob url'] = function()
  eq(
    permalink.build('git@github.com:dimiro1/demo.git', {
      path = 'lua/config/permalink.lua',
      commit = 'abc123',
      range = { 3, 3 },
    }),
    'https://github.com/dimiro1/demo/blob/abc123/lua/config/permalink.lua#L3'
  )
end

T['build']['assembles a gitlab url with /-/blob and its range style'] = function()
  eq(
    permalink.build('https://gitlab.com/group/repo.git', {
      path = 'src/a.lua',
      commit = 'abc123',
      range = { 10, 20 },
    }),
    'https://gitlab.com/group/repo/-/blob/abc123/src/a.lua#L10-20'
  )
end

T['build']['assembles a codeberg src/commit url'] = function()
  eq(
    permalink.build('git@codeberg.org:dimiro1/.emacs.d.git', {
      path = 'user-lisp/d1-git-permalink.el',
      commit = 'abc123',
      range = { 10, 20 },
    }),
    'https://codeberg.org/dimiro1/.emacs.d/src/commit/abc123/user-lisp/d1-git-permalink.el#L10-L20'
  )
end

T['build']['percent-encodes path bytes that hosts misread'] = function()
  eq(
    permalink.build('git@github.com:u/r.git', {
      path = 'dir with space/file#1.lua',
      commit = 'abc',
    }),
    'https://github.com/u/r/blob/abc/dir%20with%20space/file%231.lua'
  )
end

T['build']['returns the repository root url without a path'] = function()
  eq(permalink.build('git@github.com:u/r.git', {}), 'https://github.com/u/r')
end

T['build']['fails on unsupported hosts, unparseable remotes, missing commit'] = function()
  local url, err = permalink.build('git@bitbucket.org:u/r.git', {})
  eq(url, nil)
  eq(err, 'unsupported git host: bitbucket.org')

  url, err = permalink.build('not a remote', {})
  eq(url, nil)
  eq(err, 'cannot parse git remote: not a remote')

  url, err = permalink.build('git@github.com:u/r.git', { path = 'a.txt' })
  eq(url, nil)
  eq(err, 'no commit to pin the link to')
end

-- Boots the real init.lua; cases needing a repository build one in a temp
-- dir with an `origin` pointing at github, plus a fake clipboard provider
-- (headless instances have none) and a notify recorder.
T['in a live instance'] = MiniTest.new_set({
  hooks = {
    pre_case = function()
      child.restart({ '-u', 'init.lua' })
    end,
    post_once = child.stop,
  },
})

local make_repo = [[
  vim.g.clipboard = {
    name = 'fake',
    copy = {
      ['+'] = function(lines) _G.clip = lines end,
      ['*'] = function(lines) _G.clip = lines end,
    },
    paste = {
      ['+'] = function() return _G.clip or {} end,
      ['*'] = function() return _G.clip or {} end,
    },
  }
  _G.messages = {}
  vim.notify = function(msg, level)
    table.insert(_G.messages, { msg = msg, level = level })
  end

  local repo = vim.fn.tempname()
  vim.fn.mkdir(repo, 'p')
  local function git(...)
    local cmd = { 'git', '-C', repo, '-c', 'user.email=t@t', '-c', 'user.name=t' }
    vim.list_extend(cmd, { ... })
    return vim.fn.systemlist(cmd)
  end
  git('init', '-q', '-b', 'main')
  vim.fn.writefile({ 'one', 'two', 'three', 'four', 'five' }, repo .. '/a.txt')
  git('add', '.')
  git('commit', '-q', '-m', 'init')
  git('remote', 'add', 'origin', 'git@github.com:dimiro1/demo.git')
  _G.repo = repo
  _G.sha = git('rev-parse', 'HEAD')[1]
  vim.cmd.edit(repo .. '/a.txt')
]]

T['in a live instance'][':Permalink command is registered'] = function()
  eq(child.lua_get([[vim.api.nvim_get_commands({})['Permalink'] ~= nil]]), true)
end

T['in a live instance']['space-l and space-L are mapped in normal and visual mode'] = function()
  for _, lhs in ipairs({ '<Leader>l', '<Leader>L' }) do
    for _, mode in ipairs({ 'n', 'x' }) do
      eq(
        child.lua_get(
          ([[vim.tbl_isempty(vim.fn.maparg('%s', '%s', false, true))]]):format(lhs, mode)
        ),
        false,
        mode .. ' ' .. lhs
      )
    end
  end
end

T['in a live instance']['copy pins the cursor line to the head commit'] = function()
  child.lua(make_repo)
  child.lua([[
    vim.api.nvim_win_set_cursor(0, { 3, 0 })
    require('config.permalink').copy()
  ]])
  local expected = 'https://github.com/dimiro1/demo/blob/'
    .. child.lua_get('_G.sha')
    .. '/a.txt#L3'
  eq(child.lua_get([[vim.fn.getreg('+')]]), expected)
  eq(child.lua_get([[_G.messages[#_G.messages].msg]]), 'copied permalink: ' .. expected)
  eq(child.lua_get([[_G.messages[#_G.messages].level == nil]]), true)
end

T['in a live instance']['visual space-l copies the line range and leaves visual mode'] = function()
  child.lua(make_repo)
  child.type_keys('2gg', 'V', '2j', ' l')
  local expected = 'https://github.com/dimiro1/demo/blob/'
    .. child.lua_get('_G.sha')
    .. '/a.txt#L2-L4'
  eq(child.lua_get([[vim.fn.getreg('+')]]), expected)
  eq(child.lua_get([[vim.fn.mode()]]), 'n')
end

T['in a live instance'][':Permalink takes a command range'] = function()
  child.lua(make_repo)
  child.lua([[vim.cmd('2,4Permalink')]])
  eq(
    child.lua_get([[vim.fn.getreg('+')]]),
    'https://github.com/dimiro1/demo/blob/' .. child.lua_get('_G.sha') .. '/a.txt#L2-L4'
  )
end

T['in a live instance']['open routes through vim.ui.open'] = function()
  child.lua(make_repo)
  child.lua([[
    vim.ui.open = function(url)
      _G.opened = url
    end
    vim.api.nvim_win_set_cursor(0, { 5, 0 })
    require('config.permalink').open()
  ]])
  eq(
    child.lua_get('_G.opened'),
    'https://github.com/dimiro1/demo/blob/' .. child.lua_get('_G.sha') .. '/a.txt#L5'
  )
end

T['in a live instance']['uncommitted changes downgrade the link with a warning'] = function()
  child.lua(make_repo)
  child.lua([[
    vim.fn.writefile({ 'six' }, _G.repo .. '/a.txt', 'a')
    require('config.permalink').copy()
  ]])
  eq(child.lua_get([[_G.messages[#_G.messages].level]]), vim.log.levels.WARN)
  eq(
    child.lua_get([[_G.messages[#_G.messages].msg:find('uncommitted changes') ~= nil]]),
    true
  )
  -- the link itself still pins the last commit
  eq(
    child.lua_get([[vim.fn.getreg('+')]]),
    'https://github.com/dimiro1/demo/blob/' .. child.lua_get('_G.sha') .. '/a.txt#L1'
  )
end

T['in a live instance']['errors are reported, not thrown'] = function()
  child.lua([[
    _G.messages = {}
    vim.notify = function(msg, level)
      table.insert(_G.messages, { msg = msg, level = level })
    end
  ]])

  -- no file
  child.lua([[require('config.permalink').copy()]])
  eq(child.lua_get([[_G.messages[#_G.messages].msg]]), 'buffer has no file')
  eq(child.lua_get([[_G.messages[#_G.messages].level]]), vim.log.levels.ERROR)

  -- file outside any repository
  child.lua([[
    local dir = vim.fn.tempname()
    vim.fn.mkdir(dir, 'p')
    vim.fn.writefile({ 'x' }, dir .. '/plain.txt')
    vim.cmd.edit(dir .. '/plain.txt')
    require('config.permalink').copy()
  ]])
  eq(child.lua_get([[_G.messages[#_G.messages].msg]]), 'not in a git repository')

  -- repository without an origin remote
  child.lua([[
    local repo = vim.fn.tempname()
    vim.fn.mkdir(repo, 'p')
    vim.fn.systemlist({ 'git', '-C', repo, 'init', '-q' })
    vim.fn.writefile({ 'x' }, repo .. '/a.txt')
    vim.cmd.edit(repo .. '/a.txt')
    require('config.permalink').copy()
  ]])
  eq(child.lua_get([[_G.messages[#_G.messages].msg]]), "no 'origin' remote")
end

return T
