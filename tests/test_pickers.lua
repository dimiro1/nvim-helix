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

T['the core picker set is wired'] = function()
  local missing = child.lua_get([[(function()
    local names = {
      'files', 'files_cwd', 'buffers', 'jumps', 'changed_files',
      'document_symbols', 'workspace_symbols',
      'diagnostics_buffer', 'diagnostics_workspace',
      'global_search', 'command_palette', 'resume',
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

T['the module-backed pickers are re-exported through the registry'] = function()
  local missing = child.lua_get([[(function()
    local names = { 'everything', 'directories', 'explorer_buffer_dir', 'zoxide', 'worktrees' }
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
