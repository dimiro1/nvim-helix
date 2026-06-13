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

T['PROMPTS labels every name-driven picker with a uniform Name> standard'] = function()
  local problems = child.lua_get([[(function()
    local P = require('config.pickers').PROMPTS
    local expected = {
      'everything', 'files', 'files_cwd', 'buffers', 'jumps', 'changed_files',
      'document_symbols', 'workspace_symbols', 'diagnostics_buffer',
      'diagnostics_workspace', 'global_search', 'command_palette',
      'definitions', 'type_definitions', 'implementations', 'references',
      'zoxide', 'worktrees',
    }
    local out = {}
    for _, name in ipairs(expected) do
      if not P[name] then out[#out + 1] = name .. ': missing' end
    end
    -- Every label is title-cased and ends with the shared `> ` cap.
    for name, prompt in pairs(P) do
      if type(prompt) ~= 'string' or not prompt:match('^%u.*> $') then
        out[#out + 1] = name .. ': ' .. tostring(prompt)
      end
    end
    table.sort(out)
    return out
  end)()]])
  eq(problems, {})
end

T['each core picker emits its standard prompt'] = function()
  local mismatches = child.lua_get([[(function()
    -- registry name -> the fzf-lua picker it delegates to
    local fns = {
      files = 'files', files_cwd = 'files', buffers = 'buffers', jumps = 'jumps',
      changed_files = 'git_status', document_symbols = 'lsp_document_symbols',
      workspace_symbols = 'lsp_live_workspace_symbols',
      diagnostics_buffer = 'diagnostics_document',
      diagnostics_workspace = 'diagnostics_workspace', global_search = 'live_grep',
      definitions = 'lsp_definitions', type_definitions = 'lsp_typedefs',
      implementations = 'lsp_implementations', references = 'lsp_references',
    }
    local fzf, last = require('fzf-lua'), nil
    for _, fn in pairs(fns) do fzf[fn] = function(o) last = o or {} end end
    local pickers, out = require('config.pickers'), {}
    for picker in pairs(fns) do
      last = nil
      pickers[picker]()
      if not last or last.prompt ~= pickers.PROMPTS[picker] then
        out[#out + 1] = picker .. ': ' .. tostring(last and last.prompt)
      end
    end
    table.sort(out)
    return out
  end)()]])
  eq(mismatches, {})
end

T['fzf-lua provides every picker the wiring calls'] = function()
  local missing = child.lua_get([[(function()
    local fzf, out = require('fzf-lua'), {}
    for _, name in ipairs({
      'files', 'buffers', 'jumps', 'git_status',
      'lsp_document_symbols', 'lsp_live_workspace_symbols',
      'diagnostics_document', 'diagnostics_workspace',
      'live_grep', 'commands', 'resume', 'zoxide',
      'lsp_definitions', 'lsp_typedefs', 'lsp_implementations', 'lsp_references',
    }) do
      if type(fzf[name]) ~= 'function' then table.insert(out, name) end
    end
    return out
  end)()]])
  eq(missing, {})
end

return T
