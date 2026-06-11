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

T['the four servers are configured as system binaries'] = function()
  local cmds = child.lua_get([[(function()
    return {
      gopls = vim.lsp.config['gopls'].cmd[1],
      ts_ls = vim.lsp.config['ts_ls'].cmd[1],
      pyright = vim.lsp.config['pyright'].cmd[1],
      lua_ls = vim.lsp.config['lua_ls'].cmd[1],
    }
  end)()]])
  eq(cmds, {
    gopls = 'gopls',
    ts_ls = 'typescript-language-server',
    pyright = 'pyright-langserver',
    lua_ls = 'lua-language-server',
  })
end

T['servers are enabled'] = function()
  for _, name in ipairs({ 'gopls', 'ts_ls', 'pyright', 'lua_ls' }) do
    eq(child.lua_get(([[vim.lsp.is_enabled('%s')]]):format(name)), true)
  end
end

T['lua_ls knows the neovim runtime'] = function()
  local lua_settings = child.lua_get([[vim.lsp.config['lua_ls'].settings.Lua]])
  eq(lua_settings.runtime.version, 'LuaJIT')
  eq(lua_settings.workspace.checkThirdParty, false)
  eq(lua_settings.diagnostics.globals, { 'MiniTest' })
  local has_vimruntime = child.lua_get(
    [[vim.tbl_contains(vim.lsp.config['lua_ls'].settings.Lua.workspace.library, vim.env.VIMRUNTIME)]]
  )
  eq(has_vimruntime, true)
end

T['every server roots on project markers plus .git'] = function()
  local servers = child.lua_get([[require('config.lsp').servers]])
  for name, cfg in pairs(servers) do
    eq(cfg.root_markers[#cfg.root_markers], '.git')
    eq(#cfg.filetypes > 0, true, name)
  end
  eq(vim.tbl_contains(servers.gopls.filetypes, 'go'), true)
  eq(vim.tbl_contains(servers.ts_ls.filetypes, 'typescriptreact'), true)
  eq(vim.tbl_contains(servers.pyright.filetypes, 'python'), true)
  eq(vim.tbl_contains(servers.lua_ls.filetypes, 'lua'), true)
end

T['completion hooks into LspAttach'] = function()
  local count = child.lua_get(
    [[#vim.api.nvim_get_autocmds({ group = 'config.lsp', event = 'LspAttach' })]]
  )
  eq(count, 1)
end

T['go buffers format on save, others do not'] = function()
  local patterns = child.lua_get([[vim.tbl_map(
    function(a) return a.pattern end,
    vim.api.nvim_get_autocmds({ group = 'config.lsp', event = 'BufWritePre' })
  )]])
  eq(patterns, { '*.go' })
end

T['lua_ls actually attaches to a lua buffer'] = function()
  if child.lua_get([[vim.fn.executable('lua-language-server')]]) ~= 1 then
    MiniTest.skip('lua-language-server not on PATH')
  end
  child.lua([[vim.cmd.edit('init.lua')]])
  local attached = child.lua_get([[vim.wait(15000, function()
    return #vim.lsp.get_clients({ bufnr = 0, name = 'lua_ls' }) > 0
  end, 100)]])
  eq(attached, true)
end

T['gopls actually attaches to a go buffer'] = function()
  if child.lua_get([[vim.fn.executable('gopls')]]) ~= 1 then
    MiniTest.skip('gopls not on PATH')
  end
  child.lua([[(function()
    local root = vim.fn.tempname()
    vim.fn.mkdir(root, 'p')
    vim.fn.writefile({ 'module example.com/demo', '', 'go 1.22' }, root .. '/go.mod')
    vim.fn.writefile(
      { 'package main', '', 'func main() {}' },
      root .. '/main.go'
    )
    vim.cmd.edit(root .. '/main.go')
  end)()]])
  local attached = child.lua_get([[vim.wait(15000, function()
    return #vim.lsp.get_clients({ bufnr = 0, name = 'gopls' }) > 0
  end, 100)]])
  eq(attached, true)
  -- attach wires document highlight on cursor hold
  local highlight_hooks = child.lua_get(
    [[#vim.api.nvim_get_autocmds({ event = 'CursorHold', buffer = 0 })]]
  )
  eq(highlight_hooks > 0, true)
end

return T
