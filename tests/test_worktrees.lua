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
