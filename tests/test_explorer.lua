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

T['the explorer is wired'] = function()
  local missing = child.lua_get([[(function()
    local names = { 'dir_entries', 'explorer', 'directories', 'explorer_root', 'explorer_buffer_dir' }
    local explorer, out = require('config.explorer'), {}
    for _, name in ipairs(names) do
      if type(explorer[name]) ~= 'function' then table.insert(out, name) end
    end
    return out
  end)()]])
  eq(missing, {})
end

T['dir_entries lists parent, then dirs, then files, sorted'] = function()
  local entries = child.lua_get([[(function()
    local tmp = vim.fn.tempname()
    for _, d in ipairs({ 'zeta', 'alpha' }) do
      vim.fn.mkdir(tmp .. '/' .. d, 'p')
    end
    for _, f in ipairs({ 'b.txt', 'a.txt' }) do
      vim.fn.writefile({}, tmp .. '/' .. f)
    end
    return require('config.explorer').dir_entries(tmp)
  end)()]])
  eq(entries, { '../', 'alpha/', 'zeta/', 'a.txt', 'b.txt' })
end

T['dir_entries of an empty directory offers only the parent'] = function()
  local entries = child.lua_get([[(function()
    local tmp = vim.fn.tempname()
    vim.fn.mkdir(tmp, 'p')
    return require('config.explorer').dir_entries(tmp)
  end)()]])
  eq(entries, { '../' })
end

T['dir_entries hides .git and gitignored entries'] = function()
  local entries = child.lua_get([[(function()
    local tmp = vim.fn.tempname()
    vim.fn.mkdir(tmp .. '/node_modules', 'p')
    vim.fn.mkdir(tmp .. '/src', 'p')
    vim.fn.writefile({ 'node_modules' }, tmp .. '/.gitignore')
    vim.fn.system({ 'git', '-C', tmp, 'init', '-q' })
    return require('config.explorer').dir_entries(tmp)
  end)()]])
  eq(entries, { '../', 'src/', '.gitignore' })
end

T['DIRS_CMD finds every directory recursively, minus .git and ignored'] = function()
  local result = child.lua_get([[(function()
    local tmp = vim.fn.tempname()
    vim.fn.mkdir(tmp .. '/a', 'p')
    vim.fn.mkdir(tmp .. '/b/c', 'p')
    vim.fn.mkdir(tmp .. '/vendor', 'p')
    vim.fn.writefile({}, tmp .. '/z.txt')
    vim.fn.writefile({}, tmp .. '/a/x.txt')
    vim.fn.writefile({}, tmp .. '/b/c/y.txt')
    vim.fn.writefile({}, tmp .. '/vendor/v.txt')
    vim.fn.writefile({ 'vendor' }, tmp .. '/.gitignore')
    vim.fn.system({ 'git', '-C', tmp, 'init', '-q' })
    local cmd = require('config.explorer').DIRS_CMD
    local out = vim.fn.system(('cd %s && %s'):format(vim.fn.shellescape(tmp), cmd))
    return vim.split(vim.trim(out), '\n')
  end)()]])
  eq(result, { '.', 'a', 'b/c' })
end

return T
