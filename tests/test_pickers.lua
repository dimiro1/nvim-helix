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

T['workspace_root finds the vcs root'] = function()
  local root = child.lua_get([[(function()
    local tmp = vim.fn.tempname()
    vim.fn.mkdir(tmp .. '/proj/.git', 'p')
    vim.fn.mkdir(tmp .. '/proj/sub', 'p')
    vim.cmd.edit(tmp .. '/proj/sub/file.txt')
    local got = require('config.pickers').workspace_root()
    -- realpath both sides: macOS tempdirs live behind the /var symlink
    return {
      got = vim.uv.fs_realpath(got),
      want = vim.uv.fs_realpath(tmp .. '/proj'),
    }
  end)()]])
  eq(root.got, root.want)
end

T['workspace_root falls back to cwd without vcs'] = function()
  local root = child.lua_get([[(function()
    local tmp = vim.fn.tempname()
    vim.fn.mkdir(tmp .. '/plain', 'p')
    vim.fn.chdir(tmp .. '/plain')
    vim.cmd.enew()
    return { got = require('config.pickers').workspace_root(), want = vim.uv.cwd() }
  end)()]])
  eq(root.got, root.want)
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
    return require('config.pickers').dir_entries(tmp)
  end)()]])
  eq(entries, { '../', 'alpha/', 'zeta/', 'a.txt', 'b.txt' })
end

T['dir_entries of an empty directory offers only the parent'] = function()
  local entries = child.lua_get([[(function()
    local tmp = vim.fn.tempname()
    vim.fn.mkdir(tmp, 'p')
    return require('config.pickers').dir_entries(tmp)
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
    return require('config.pickers').dir_entries(tmp)
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
    local cmd = require('config.pickers').DIRS_CMD
    local out = vim.fn.system(('cd %s && %s'):format(vim.fn.shellescape(tmp), cmd))
    return vim.split(vim.trim(out), '\n')
  end)()]])
  eq(result, { '.', 'a', 'b/c' })
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

T['the full helix picker set is wired'] = function()
  local missing = child.lua_get([[(function()
    local names = {
      'files', 'files_cwd', 'buffers', 'jumps', 'changed_files',
      'document_symbols', 'workspace_symbols',
      'diagnostics_buffer', 'diagnostics_workspace',
      'global_search', 'command_palette', 'resume',
      'directories', 'explorer', 'explorer_root', 'explorer_buffer_dir',
      'zoxide', 'zoxide_jump',
      'definitions', 'type_definitions', 'implementations', 'references',
    }
    local pickers, out = require('config.pickers'), {}
    for _, name in ipairs(names) do
      if type(pickers[name]) ~= 'function' then table.insert(out, name) end
    end
    return out
  end)()]])
  eq(missing, {})
end

T['fzf-lua provides every picker the wiring calls'] = function()
  local missing = child.lua_get([[(function()
    local fzf, out = require('fzf-lua'), {}
    for _, name in ipairs({
      'files', 'buffers', 'jumps', 'git_status',
      'lsp_document_symbols', 'lsp_live_workspace_symbols',
      'diagnostics_document', 'diagnostics_workspace',
      'live_grep', 'commands', 'resume',
      'lsp_definitions', 'lsp_typedefs', 'lsp_implementations', 'lsp_references',
    }) do
      if type(fzf[name]) ~= 'function' then table.insert(out, name) end
    end
    return out
  end)()]])
  eq(missing, {})
end

return T
