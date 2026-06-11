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
end

return M
