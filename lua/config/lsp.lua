-- Hand-rolled server configs: servers are system binaries on PATH;
-- no lspconfig, no Mason.
local M = {}

M.servers = {
  gopls = {
    cmd = { 'gopls' },
    filetypes = { 'go', 'gomod', 'gowork', 'gotmpl' },
    root_markers = { 'go.work', 'go.mod', '.git' },
  },
  ts_ls = {
    cmd = { 'typescript-language-server', '--stdio' },
    filetypes = { 'javascript', 'javascriptreact', 'typescript', 'typescriptreact' },
    root_markers = { 'tsconfig.json', 'jsconfig.json', 'package.json', '.git' },
  },
  pyright = {
    cmd = { 'pyright-langserver', '--stdio' },
    filetypes = { 'python' },
    root_markers = { 'pyproject.toml', 'pyrightconfig.json', 'setup.py', 'requirements.txt', '.git' },
  },
  -- the jdtls launcher is a real PATH binary that derives a per-project
  -- workspace data dir from the cwd, so it slots in like the stdio servers
  -- with no extra wiring (no -data, no bootstrap classpath to assemble).
  jdtls = {
    cmd = { 'jdtls' },
    filetypes = { 'java' },
    root_markers = {
      'settings.gradle', 'settings.gradle.kts',
      'build.gradle', 'build.gradle.kts',
      'pom.xml', 'mvnw', 'gradlew', '.git',
    },
    init_options = {
      -- without this, gotos into the JDK and Maven/Gradle dependencies
      -- resolve to nothing: the server only emits jdt:// class-file URIs
      -- for symbols inside jars when the client advertises support for them.
      extendedClientCapabilities = { classFileContentsSupport = true },
    },
  },
  -- tuned for editing this config: LuaJIT, the `vim` global and runtime
  -- type stubs. A project's own .luarc.json takes precedence, so non-nvim
  -- lua projects self-correct.
  lua_ls = {
    cmd = { 'lua-language-server' },
    filetypes = { 'lua' },
    root_markers = { '.luarc.json', '.luarc.jsonc', '.git' },
    settings = {
      Lua = {
        runtime = { version = 'LuaJIT' },
        workspace = {
          checkThirdParty = false,
          library = { vim.env.VIMRUNTIME, '${3rd}/luv/library' },
        },
        -- mini.test injects MiniTest into the test runtime
        diagnostics = { globals = { 'MiniTest' } },
      },
    },
  },
}

-- Helix auto-formats on save when the server supports it. For Go that
-- means gopls' organize-imports code action followed by formatting.
function M.go_format(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  for _, client in ipairs(vim.lsp.get_clients({ bufnr = bufnr, name = 'gopls' })) do
    local params = vim.lsp.util.make_range_params(0, client.offset_encoding) --[[@as lsp.CodeActionParams]]
    params.context = { only = { 'source.organizeImports' }, diagnostics = {} }
    local result = client:request_sync('textDocument/codeAction', params, 2000, bufnr)
    for _, action in ipairs(result and result.result or {}) do
      if action.edit then
        vim.lsp.util.apply_workspace_edit(action.edit, client.offset_encoding)
      end
    end
  end
  vim.lsp.buf.format({ bufnr = bufnr, timeout_ms = 2000 })
end

-- jdtls hands back jdt:// URIs for class files that live inside jars (the
-- JDK stdlib, Maven/Gradle dependencies). Neovim has no reader for that
-- scheme, so a goto into library code lands on an empty buffer. Ask the
-- server for the source/decompiled text through its java/classFileContents
-- extension and fill the buffer read-only, then attach jdtls so gotos from
-- within the opened class keep working.
function M.open_jdt_class(bufnr, uri)
  local client = vim.lsp.get_clients({ name = 'jdtls' })[1]
  if not client then
    return
  end
  -- java/classFileContents is a jdtls server extension, outside the standard
  -- method enum the bundled type stubs know about
  ---@type any
  local method = 'java/classFileContents'
  local response = client:request_sync(method, { uri = uri }, 5000, bufnr)
  local content = response and response.result or ''
  vim.bo[bufnr].modifiable = true
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, vim.split(content, '\n', { plain = true }))
  vim.bo[bufnr].filetype = 'java'
  vim.bo[bufnr].modifiable = false
  vim.bo[bufnr].modified = false
  vim.lsp.buf_attach_client(bufnr, client.id)
end

function M.setup()
  for name, cfg in pairs(M.servers) do
    vim.lsp.config(name, cfg)
  end
  vim.lsp.enable(vim.tbl_keys(M.servers))

  local group = vim.api.nvim_create_augroup('config.lsp', {})

  -- 'autocomplete' + the 'o' source drive as-you-type candidates; enabling
  -- vim.lsp.completion adds resolve popups, snippet expansion and
  -- additionalTextEdits on accept.
  vim.api.nvim_create_autocmd('LspAttach', {
    group = group,
    callback = function(args)
      local client = assert(vim.lsp.get_client_by_id(args.data.client_id))
      if client:supports_method('textDocument/completion') then
        vim.lsp.completion.enable(true, client.id, args.buf)
      end
      -- resting the cursor on a symbol lights up its other uses
      if client:supports_method('textDocument/documentHighlight') then
        local highlight = vim.api.nvim_create_augroup(
          'config.lsp.highlight.' .. args.buf,
          {}
        )
        vim.api.nvim_create_autocmd({ 'CursorHold', 'CursorHoldI' }, {
          group = highlight,
          buffer = args.buf,
          callback = vim.lsp.buf.document_highlight,
        })
        vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI', 'BufLeave' }, {
          group = highlight,
          buffer = args.buf,
          callback = vim.lsp.buf.clear_references,
        })
      end
    end,
  })

  vim.api.nvim_create_autocmd('BufWritePre', {
    group = group,
    pattern = '*.go',
    callback = function(args)
      M.go_format(args.buf)
    end,
  })

  vim.api.nvim_create_autocmd('BufReadCmd', {
    group = group,
    pattern = 'jdt://*',
    callback = function(args)
      M.open_jdt_class(args.buf, args.match)
    end,
  })
end

return M
