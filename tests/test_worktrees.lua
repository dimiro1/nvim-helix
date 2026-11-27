local wt = require('config.worktrees')

local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set()

local eq = MiniTest.expect.equality

T['parse'] = MiniTest.new_set()

T['parse']['reads branches, bare and detached worktrees'] = function()
  local parsed = wt.parse({
    'worktree /repos/app',
    'HEAD abc123def4567890abc123def4567890abc123de',
    'branch refs/heads/main',
    '',
    'worktree /repos/app-feat',
    'HEAD def456abc1237890def456abc1237890def456ab',
    'branch refs/heads/feature/login',
    '',
    'worktree /repos/app.bare',
    'bare',
    '',
    'worktree /repos/app-detached',
    'HEAD 0123abc4567890def0123abc4567890def0123ab',
    'detached',
    '',
  })
  eq(#parsed, 4)
  eq(parsed[1], { path = '/repos/app', head = 'abc123d', branch = 'main' })
  eq(parsed[2].branch, 'feature/login')
  eq(parsed[3], { path = '/repos/app.bare', bare = true })
  eq(parsed[4].detached, true)
  eq(parsed[4].branch, nil)
end

T['parse']['handles empty input'] = function()
  eq(wt.parse({}), {})
end

-- Shaped like `wt list --format=json` (schema 2), trimmed to what is read.
local WT_JSON = vim.json.encode({
  schema = 2,
  repo = { default_branch = 'main' },
  items = {
    {
      branch = 'main',
      head = { short_sha = 'abc123d' },
      worktree = { path = '/repos/app', main = true, detached = false,
        changes = { diff = { added = 0, deleted = 0 } } },
    },
    {
      branch = 'feature/login',
      head = { short_sha = 'def456a' },
      worktree = { path = '/repos/app.feat', detached = false,
        changes = { diff = { added = 12, deleted = 3 } } },
      default_branch = { ahead = 2, behind = 5 },
    },
    {
      branch = vim.NIL,
      head = { short_sha = '0123abc' },
      worktree = { path = '/repos/app.review', detached = true,
        changes = { diff = { added = 0, deleted = 0 } } },
      default_branch = { ahead = 0, behind = 0 },
    },
    -- a branch without a worktree (wt list --branches)
    { branch = 'stale', head = { short_sha = '9999999' } },
  },
})

T['parse_wt'] = MiniTest.new_set()

T['parse_wt']['reads worktrees with their status, skipping branch rows'] = function()
  eq(wt.parse_wt(WT_JSON), {
    { path = '/repos/app', branch = 'main', head = 'abc123d', added = 0, deleted = 0 },
    {
      path = '/repos/app.feat', branch = 'feature/login', head = 'def456a',
      added = 12, deleted = 3, ahead = 2, behind = 5, base = 'main',
    },
    {
      path = '/repos/app.review', head = '0123abc', detached = true,
      added = 0, deleted = 0, ahead = 0, behind = 0, base = 'main',
    },
  })
end

T['parse_wt']['rejects output it cannot read'] = function()
  eq(wt.parse_wt(''), nil)
  eq(wt.parse_wt('not json'), nil)
  eq(wt.parse_wt('{"schema": 2}'), nil)
end

T['status'] = MiniTest.new_set()

T['status']['spells out uncommitted lines and commits against the default branch'] = function()
  eq(
    wt.status({ added = 12, deleted = 3, ahead = 2, behind = 5, base = 'main' }),
    '+12 -3 uncommitted · 2 ahead, 5 behind main'
  )
end

T['status']['leaves out zero counts'] = function()
  eq(wt.status({ added = 0, deleted = 4, ahead = 0, behind = 0, base = 'main' }), '-4 uncommitted')
  eq(wt.status({ added = 7, deleted = 0 }), '+7 uncommitted')
  eq(wt.status({ added = 0, deleted = 0, ahead = 3, behind = 0, base = 'main' }), '3 ahead of main')
  eq(wt.status({ added = 0, deleted = 0, ahead = 0, behind = 1, base = 'main' }), '1 behind main')
end

T['status']['is empty for git entries and clean worktrees'] = function()
  eq(wt.status({ path = '/r', branch = 'main' }), '')
  eq(wt.status({ added = 0, deleted = 0, ahead = 0, behind = 0, base = 'main' }), '')
end

T['status']['names the default branch generically when wt did not'] = function()
  eq(wt.status({ ahead = 1 }), '1 ahead of the default branch')
end

T['labels'] = MiniTest.new_set()

T['labels']['line up name and path columns, then marker and status'] = function()
  eq(
    wt.labels({
      { path = '/repos/app', branch = 'main', added = 226, deleted = 10, ahead = 0, behind = 0 },
      { path = '/repos/app.feature', branch = 'feature/login', ahead = 2, behind = 5, base = 'main' },
      { path = '/r', head = 'abc123d', detached = true },
      { path = '/d', detached = true },
    }, '/repos/app'),
    {
      'main           /repos/app          (current)  +226 -10 uncommitted',
      'feature/login  /repos/app.feature  2 ahead, 5 behind main',
      'abc123d        /r',
      'detached       /d',
    }
  )
end

T['labels']['match git entries without a root as plain columns'] = function()
  eq(
    wt.labels({ { path = '/a', branch = 'main' }, { path = '/a.long', branch = 'f' } }),
    { 'main  /a', 'f     /a.long' }
  )
end

T['session_file'] = MiniTest.new_set()

T['session_file']['is stable and distinct per root'] = function()
  local a = wt.session_file('/repos/app')
  local b = wt.session_file('/repos/app-feat')
  eq(a ~= b, true)
  eq(a, wt.session_file('/repos/app'))
  eq(vim.fs.basename(a):find('/', 1, true), nil)
end

T['in a live instance'] = MiniTest.new_set({
  hooks = {
    pre_case = function()
      child.restart({ '-u', 'init.lua' })
    end,
    post_once = child.stop,
  },
})

T['in a live instance']['workspace_root finds the vcs root'] = function()
  local root = child.lua_get([[(function()
    local tmp = vim.fn.tempname()
    vim.fn.mkdir(tmp .. '/proj/.git', 'p')
    vim.fn.mkdir(tmp .. '/proj/sub', 'p')
    vim.cmd.edit(tmp .. '/proj/sub/file.txt')
    local got = require('config.worktrees').workspace_root()
    -- realpath both sides: macOS tempdirs live behind the /var symlink
    return {
      got = vim.uv.fs_realpath(got),
      want = vim.uv.fs_realpath(tmp .. '/proj'),
    }
  end)()]])
  eq(root.got, root.want)
end

T['in a live instance']['workspace_root falls back to cwd without vcs'] = function()
  local root = child.lua_get([[(function()
    local tmp = vim.fn.tempname()
    vim.fn.mkdir(tmp .. '/plain', 'p')
    vim.fn.chdir(tmp .. '/plain')
    vim.cmd.enew()
    return { got = require('config.worktrees').workspace_root(), want = vim.uv.cwd() }
  end)()]])
  eq(root.got, root.want)
end

T['in a live instance']['workspace_root follows the buffer, current_root the cwd'] = function()
  local got = child.lua_get([[(function()
    local tmp = vim.fn.tempname()
    for _, repo in ipairs({ 'a', 'b' }) do
      vim.fn.mkdir(tmp .. '/' .. repo .. '/.git', 'p')
    end
    -- realpath: macOS tempdirs live behind the /var symlink
    tmp = assert(vim.uv.fs_realpath(tmp))
    vim.fn.chdir(tmp .. '/a')
    vim.cmd.edit(tmp .. '/b/file.txt')
    local wt = require('config.worktrees')
    return {
      workspace = vim.uv.fs_realpath(wt.workspace_root()) == tmp .. '/b',
      current = vim.uv.fs_realpath(wt.current_root()) == tmp .. '/a',
    }
  end)()]])
  eq(got, { workspace = true, current = true })
end

T['in a live instance']['buffer_dir is the file directory, else cwd'] = function()
  local got = child.lua_get([[(function()
    local wt = require('config.worktrees')
    local tmp = vim.fn.tempname()
    vim.fn.mkdir(tmp .. '/sub', 'p')
    vim.cmd.edit(tmp .. '/sub/file.txt')
    -- realpath both sides: macOS tempdirs live behind the /var symlink
    local want = vim.uv.fs_realpath(tmp .. '/sub')
    local named = vim.uv.fs_realpath(wt.buffer_dir()) == want
    local by_handle = vim.uv.fs_realpath(wt.buffer_dir(vim.api.nvim_get_current_buf())) == want
    vim.cmd.enew()
    return { named = named, by_handle = by_handle, nameless = wt.buffer_dir() == vim.uv.cwd() }
  end)()]])
  eq(got, { named = true, by_handle = true, nameless = true })
end

-- A repo with a second worktree and a fake `wt` first on PATH. The fake
-- prints `output` and exits with `code`; nil output means no fake at all.
local function setup_repo_with_fake_wt(output, code)
  child.lua(
    [[
    local output, code = ...
    local base = vim.fn.tempname()
    local repo = base .. '/main'
    vim.fn.mkdir(repo, 'p')
    local function git(...)
      local cmd = { 'git', '-C', repo, '-c', 'user.email=t@t', '-c', 'user.name=t' }
      vim.list_extend(cmd, { ... })
      vim.fn.system(cmd)
    end
    git('init', '-q', '-b', 'main')
    git('commit', '-q', '--allow-empty', '-m', 'init')
    git('worktree', 'add', '-q', '-b', 'feat', base .. '/feat')
    _G.repo = repo
    if output then
      local bin = base .. '/bin'
      vim.fn.mkdir(bin, 'p')
      vim.fn.writefile({ output }, bin .. '/out.json')
      vim.fn.writefile({ '#!/bin/sh', 'cat "' .. bin .. '/out.json"', 'exit ' .. code }, bin .. '/wt')
      vim.fn.setfperm(bin .. '/wt', 'rwxr-xr-x')
      vim.env.PATH = bin .. ':' .. vim.env.PATH
    end
  ]],
    { output or false, code or 0 }
  )
end

local function listed()
  return child.lua_get([[vim.tbl_map(function(e)
    return { branch = e.branch, ahead = e.ahead or false }
  end, require('config.worktrees').list(_G.repo))]])
end

T['in a live instance']['list uses Worktrunk when wt is installed'] = function()
  setup_repo_with_fake_wt(WT_JSON, 0)
  eq(child.lua_get([[require('config.worktrees').wt_available()]]), true)
  eq(listed(), {
    { branch = 'main', ahead = false },
    { branch = 'feature/login', ahead = 2 },
    { ahead = 0 },
  })
end

T['in a live instance']['list falls back to git when wt fails'] = function()
  setup_repo_with_fake_wt('boom', 1)
  eq(listed(), { { branch = 'main', ahead = false }, { branch = 'feat', ahead = false } })
end

T['in a live instance']['list falls back to git when wt prints something unreadable'] = function()
  setup_repo_with_fake_wt('not json', 0)
  eq(listed(), { { branch = 'main', ahead = false }, { branch = 'feat', ahead = false } })
end

T['in a live instance']['list uses git when wt is not installed'] = function()
  setup_repo_with_fake_wt(nil)
  child.lua([[require('config.worktrees').wt_available = function() return false end]])
  eq(listed(), { { branch = 'main', ahead = false }, { branch = 'feat', ahead = false } })
end

T['in a live instance']['the real wt lists this repo with status'] = function()
  if vim.fn.executable('wt') == 0 then
    MiniTest.skip('wt not on PATH')
  end
  setup_repo_with_fake_wt(nil)
  local got = child.lua_get([[vim.tbl_map(function(e)
    return { branch = e.branch, counted = type(e.added) == 'number' }
  end, require('config.worktrees').list(_G.repo))]])
  eq(got, { { branch = 'main', counted = true }, { branch = 'feat', counted = true } })
end

T['in a live instance'][':Worktrees command is registered'] = function()
  eq(child.lua_get([[vim.api.nvim_get_commands({})['Worktrees'] ~= nil]]), true)
end

T['in a live instance']['the picker reads its prompt from the shared standard'] = function()
  local got = child.lua_get([[(function()
    local base = vim.fn.tempname()
    local repo = base .. '/main'
    vim.fn.mkdir(repo, 'p')
    local function git(...)
      local cmd = { 'git', '-C', repo, '-c', 'user.email=t@t', '-c', 'user.name=t' }
      vim.list_extend(cmd, { ... })
      vim.fn.system(cmd)
    end
    git('init', '-q', '-b', 'main')
    vim.fn.writefile({ 'alpha' }, repo .. '/a.txt')
    git('add', '.')
    git('commit', '-q', '-m', 'init')
    vim.cmd.cd(repo)

    local last
    require('fzf-lua').fzf_exec = function(_, opts) last = opts end
    require('config.worktrees').pick()
    return last and last.prompt
  end)()]])
  eq(got, child.lua_get([[require('config.pickers').PROMPTS.worktrees]]))
end

T['in a live instance']['switching round-trips workspaces'] = function()
  local result = child.lua_get([[(function()
    local worktrees = require('config.worktrees')
    worktrees.on_first_visit = function() end

    local base = vim.fn.tempname()
    local repo = base .. '/main'
    vim.fn.mkdir(repo, 'p')
    local function git(...)
      local cmd = { 'git', '-C', repo, '-c', 'user.email=t@t', '-c', 'user.name=t' }
      vim.list_extend(cmd, { ... })
      vim.fn.system(cmd)
    end
    git('init', '-q', '-b', 'main')
    vim.fn.writefile({ 'alpha' }, repo .. '/a.txt')
    git('add', '.')
    git('commit', '-q', '-m', 'init')
    git('worktree', 'add', '-q', base .. '/feat', '-b', 'feat')

    vim.cmd.cd(repo)
    vim.cmd.edit(repo .. '/a.txt')

    local ok1 = worktrees.switch(base .. '/feat')
    local cwd_is_feat = vim.uv.fs_realpath(vim.uv.cwd())
      == vim.uv.fs_realpath(base .. '/feat')
    local first_visit_buffer = vim.api.nvim_buf_get_name(0)

    vim.cmd.edit(base .. '/feat/b.txt')
    vim.cmd('silent write')

    local ok2 = worktrees.switch(repo)
    local back_in_main = vim.fs.basename(vim.api.nvim_buf_get_name(0))

    local ok3 = worktrees.switch(base .. '/feat')
    local back_in_feat = vim.fs.basename(vim.api.nvim_buf_get_name(0))

    return {
      ok1 = ok1, ok2 = ok2, ok3 = ok3,
      cwd_is_feat = cwd_is_feat,
      first_visit_buffer = first_visit_buffer,
      back_in_main = back_in_main,
      back_in_feat = back_in_feat,
    }
  end)()]])
  eq(result.ok1, true)
  eq(result.cwd_is_feat, true)
  eq(result.first_visit_buffer, '')
  eq(result.ok2, true)
  eq(result.back_in_main, 'a.txt')
  eq(result.ok3, true)
  eq(result.back_in_feat, 'b.txt')
end

T['in a live instance']['switch is blocked while buffers are modified'] = function()
  local result = child.lua_get([[(function()
    local worktrees = require('config.worktrees')
    worktrees.on_first_visit = function() end

    local base = vim.fn.tempname()
    local repo = base .. '/main'
    vim.fn.mkdir(repo, 'p')
    local function git(...)
      local cmd = { 'git', '-C', repo, '-c', 'user.email=t@t', '-c', 'user.name=t' }
      vim.list_extend(cmd, { ... })
      vim.fn.system(cmd)
    end
    git('init', '-q', '-b', 'main')
    vim.fn.writefile({ 'alpha' }, repo .. '/a.txt')
    git('add', '.')
    git('commit', '-q', '-m', 'init')
    git('worktree', 'add', '-q', base .. '/feat', '-b', 'feat')

    vim.cmd.cd(repo)
    vim.cmd.edit(repo .. '/a.txt')
    vim.api.nvim_buf_set_lines(0, -1, -1, false, { 'dirty' })

    local ok = worktrees.switch(base .. '/feat')
    return {
      ok = ok,
      cwd_unchanged = vim.uv.fs_realpath(vim.uv.cwd()) == vim.uv.fs_realpath(repo),
      still_modified = vim.bo.modified,
    }
  end)()]])
  eq(result.ok, false)
  eq(result.cwd_unchanged, true)
  eq(result.still_modified, true)
end

return T
