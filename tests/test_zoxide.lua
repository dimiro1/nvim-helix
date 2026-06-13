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
    for _, name in ipairs({ 'pick', 'jump', 'setup' }) do
      if type(zoxide[name]) ~= 'function' then table.insert(out, name) end
    end
    return out
  end)()]])
  eq(missing, {})
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

return T
