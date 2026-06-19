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

T['zoxide is wired'] = function()
  local missing = child.lua_get([[(function()
    local zoxide, out = require('config.zoxide'), {}
    for _, name in ipairs({ 'pick', 'jump', 'setup', 'top', 'start_in_top' }) do
      if type(zoxide[name]) ~= 'function' then table.insert(out, name) end
    end
    return out
  end)()]])
  eq(missing, {})
end

T['a VimEnter hook in the config.zoxide group lands the start directory'] = function()
  eq(
    child.lua_get([[(function()
      for _, au in ipairs(vim.api.nvim_get_autocmds({
        group = 'config.zoxide',
        event = 'VimEnter',
      })) do
        return true
      end
      return false
    end)()]]),
    true
  )
end

T['pick delegates to the built-in zoxide picker, layering ctrl-f'] = function()
  local got = child.lua_get([[(function()
    local seen = {}
    require('fzf-lua').zoxide = function(opts) seen.opts = opts or false end
    require('config.zoxide').pick()
    local actions = type(seen.opts) == 'table' and seen.opts.actions or {}
    return {
      called = seen.opts ~= nil,
      enter = type(actions.enter) == 'function',
      ctrl_f = type(actions['ctrl-f']) == 'function',
      prompt = type(seen.opts) == 'table' and seen.opts.prompt or nil,
    }
  end)()]])
  eq(got, {
    called = true,
    enter = true,
    ctrl_f = true,
    prompt = child.lua_get([[require('config.pickers').PROMPTS.zoxide]]),
  })
end

T[':Z command is registered'] = function()
  eq(child.lua_get([[vim.api.nvim_get_commands({})['Z'] ~= nil]]), true)
end

T[':Z jumps to the best frecent match'] = function()
  if child.lua_get([[vim.fn.executable('zoxide')]]) ~= 1 then
    MiniTest.skip('zoxide not on PATH')
  end
  local result = child.lua_get([[(function()
    local data = vim.fn.tempname()
    vim.fn.mkdir(data, 'p')
    vim.env._ZO_DATA_DIR = data -- hermetic db for this test only
    local target = vim.fn.tempname() .. '/proj' .. vim.fn.rand()
    vim.fn.mkdir(target, 'p')
    vim.fn.system({ 'zoxide', 'add', target })
    vim.cmd.Z(vim.fs.basename(target))
    return {
      got = vim.uv.fs_realpath(vim.fn.getcwd()),
      want = vim.uv.fs_realpath(target),
    }
  end)()]])
  eq(result.got, result.want)
end

T['every :cd feeds the zoxide db (shell-hook parity)'] = function()
  if child.lua_get([[vim.fn.executable('zoxide')]]) ~= 1 then
    MiniTest.skip('zoxide not on PATH')
  end
  local found = child.lua_get([[(function()
    local data = vim.fn.tempname()
    vim.fn.mkdir(data, 'p')
    vim.env._ZO_DATA_DIR = data
    local target = vim.fn.tempname() .. '/visited' .. vim.fn.rand()
    vim.fn.mkdir(target, 'p')
    vim.cmd.cd(target)
    local want = vim.uv.fs_realpath(target)
    for _, line in ipairs(vim.fn.systemlist({ 'zoxide', 'query', '--list' })) do
      if vim.uv.fs_realpath(line) == want then
        return true
      end
    end
    return false
  end)()]])
  eq(found, true)
end

T['top returns the highest-scored directory'] = function()
  if child.lua_get([[vim.fn.executable('zoxide')]]) ~= 1 then
    MiniTest.skip('zoxide not on PATH')
  end
  local result = child.lua_get([[(function()
    local data = vim.fn.tempname()
    vim.fn.mkdir(data, 'p')
    vim.env._ZO_DATA_DIR = data -- hermetic db for this test only
    local target = vim.fn.tempname() .. '/top' .. vim.fn.rand()
    vim.fn.mkdir(target, 'p')
    -- Repeated adds raise the frecency score, so this lone entry tops it.
    vim.fn.system({ 'zoxide', 'add', target })
    vim.fn.system({ 'zoxide', 'add', target })
    return {
      got = vim.uv.fs_realpath(require('config.zoxide').top()),
      want = vim.uv.fs_realpath(target),
    }
  end)()]])
  eq(result.got, result.want)
end

T['top is nil on an empty database'] = function()
  if child.lua_get([[vim.fn.executable('zoxide')]]) ~= 1 then
    MiniTest.skip('zoxide not on PATH')
  end
  eq(
    child.lua_get([[(function()
      local data = vim.fn.tempname()
      vim.fn.mkdir(data, 'p')
      vim.env._ZO_DATA_DIR = data -- empty db, nothing added
      return require('config.zoxide').top()
    end)()]]),
    vim.NIL
  )
end

T['start_in_top lands in the top directory under Neovide with no args'] = function()
  if child.lua_get([[vim.fn.executable('zoxide')]]) ~= 1 then
    MiniTest.skip('zoxide not on PATH')
  end
  local result = child.lua_get([[(function()
    local data = vim.fn.tempname()
    vim.fn.mkdir(data, 'p')
    vim.env._ZO_DATA_DIR = data
    local target = vim.fn.tempname() .. '/proj' .. vim.fn.rand()
    vim.fn.mkdir(target, 'p')
    vim.fn.system({ 'zoxide', 'add', target })
    vim.g.neovide = true -- the booted child is headless; fake the GUI flag
    local applied = require('config.zoxide').start_in_top()
    return {
      applied = applied,
      argc = vim.fn.argc(), -- guard: this child really did start bare
      got = vim.uv.fs_realpath(vim.fn.getcwd()),
      want = vim.uv.fs_realpath(target),
    }
  end)()]])
  eq(result.argc, 0)
  eq(result.applied, true)
  eq(result.got, result.want)
end

T['start_in_top leaves the cwd alone outside Neovide'] = function()
  if child.lua_get([[vim.fn.executable('zoxide')]]) ~= 1 then
    MiniTest.skip('zoxide not on PATH')
  end
  local result = child.lua_get([[(function()
    local data = vim.fn.tempname()
    vim.fn.mkdir(data, 'p')
    vim.env._ZO_DATA_DIR = data
    local target = vim.fn.tempname() .. '/proj' .. vim.fn.rand()
    vim.fn.mkdir(target, 'p')
    vim.fn.system({ 'zoxide', 'add', target })
    local before = vim.fn.getcwd()
    vim.g.neovide = nil -- a terminal Neovim: leave its cwd untouched
    return {
      applied = require('config.zoxide').start_in_top(),
      moved = vim.fn.getcwd() ~= before,
    }
  end)()]])
  eq(result, { applied = false, moved = false })
end

T['start_in_top leaves the cwd alone when a file argument was given'] = function()
  child.restart({ '-u', 'init.lua', 'README.md' }) -- argc() == 1
  local result = child.lua_get([[(function()
    vim.g.neovide = true
    local before = vim.fn.getcwd()
    return {
      argc = vim.fn.argc(),
      applied = require('config.zoxide').start_in_top(),
      moved = vim.fn.getcwd() ~= before,
    }
  end)()]])
  eq(result, { argc = 1, applied = false, moved = false })
end

return T
