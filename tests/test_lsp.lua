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

T['the five servers are configured as system binaries'] = function()
  local cmds = child.lua_get([[(function()
    return {
      gopls = vim.lsp.config['gopls'].cmd[1],
      ts_ls = vim.lsp.config['ts_ls'].cmd[1],
      pyright = vim.lsp.config['pyright'].cmd[1],
      jdtls = vim.lsp.config['jdtls'].cmd[1],
      lua_ls = vim.lsp.config['lua_ls'].cmd[1],
    }
  end)()]])
  eq(cmds, {
    gopls = 'gopls',
    ts_ls = 'typescript-language-server',
    pyright = 'pyright-langserver',
    jdtls = 'jdtls',
    lua_ls = 'lua-language-server',
  })
end

T['servers are enabled'] = function()
  for _, name in ipairs({ 'gopls', 'ts_ls', 'pyright', 'jdtls', 'lua_ls' }) do
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
  eq(vim.tbl_contains(servers.jdtls.filetypes, 'java'), true)
  eq(vim.tbl_contains(servers.lua_ls.filetypes, 'lua'), true)
end

T['jdtls roots on the gradle and maven build files'] = function()
  local markers = child.lua_get([[require('config.lsp').servers.jdtls.root_markers]])
  for _, marker in ipairs({ 'build.gradle', 'settings.gradle', 'pom.xml' }) do
    eq(vim.tbl_contains(markers, marker), true, marker)
  end
end

T['jdtls advertises class-file contents support for library gotos'] = function()
  eq(
    child.lua_get(
      [[vim.lsp.config['jdtls'].init_options.extendedClientCapabilities.classFileContentsSupport]]
    ),
    true
  )
end

T['jdt:// class files route through the jdtls reader'] = function()
  -- gotos into the JDK / Maven deps open jdt:// URIs; a BufReadCmd is the
  -- only way Neovim can fill a buffer for a scheme it cannot read from disk
  local patterns = child.lua_get([[vim.tbl_map(
    function(a) return a.pattern end,
    vim.api.nvim_get_autocmds({ group = 'config.lsp', event = 'BufReadCmd' })
  )]])
  eq(patterns, { 'jdt://*' })
end

T['the jdt:// reader is a no-op when jdtls is not running'] = function()
  -- the reader must never error on a stray jdt:// buffer with no server;
  -- it returns having left the buffer empty rather than throwing
  local result = child.lua_get([[(function()
    local buf = vim.api.nvim_create_buf(false, true)
    local uri = 'jdt://contents/java.base/java.lang/String.class'
    vim.api.nvim_buf_set_name(buf, uri)
    local ok = pcall(require('config.lsp').open_jdt_class, buf, uri)
    return ok and table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), '')
  end)()]])
  eq(result, '')
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

T['jdtls actually attaches to a java buffer'] = function()
  if child.lua_get([[vim.fn.executable('jdtls')]]) ~= 1 then
    MiniTest.skip('jdtls not on PATH')
  end
  child.lua([[(function()
    local root = vim.fn.tempname()
    vim.fn.mkdir(root, 'p')
    vim.fn.writefile({
      '<project>',
      '  <modelVersion>4.0.0</modelVersion>',
      '  <groupId>com.example</groupId>',
      '  <artifactId>demo</artifactId>',
      '  <version>1.0</version>',
    }, root .. '/pom.xml')
    vim.fn.mkdir(root .. '/src', 'p')
    vim.fn.writefile(
      { 'public class Demo {', '  public static void main(String[] a) {}', '}' },
      root .. '/src/Demo.java'
    )
    vim.cmd.edit(root .. '/src/Demo.java')
  end)()]])
  local attached = child.lua_get([[vim.wait(30000, function()
    return #vim.lsp.get_clients({ bufnr = 0, name = 'jdtls' }) > 0
  end, 100)]])
  eq(attached, true)
end

return T
