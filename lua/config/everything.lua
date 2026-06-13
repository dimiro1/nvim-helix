-- Everything picker: one fuzzy list spanning files, buffers, document symbols,
-- and commands, matched by name. Each row is `index\ttag\tname`; the previewer
-- and the open action recover the record by index and branch on its kind.
-- Content search and workspace symbols are query-driven and stay separate.
local M = {}

local function fzf()
  return require('fzf-lua')
end

local TAGS = { buffer = 'buf', symbol = 'sym', file = 'file', command = 'cmd' }

-- Concatenation order: sets the pre-query view and the order of fzf score ties.
local GROUP_ORDER = { 'buffers', 'symbols', 'files', 'commands' }

-- Flatten an LSP documentSymbol result — hierarchical DocumentSymbol[] or flat
-- SymbolInformation[] — into symbol records for `bufnr`. line is 1-based and
-- col 0-based, matching nvim_win_set_cursor.
function M.normalize_symbols(result, bufnr)
  local out = {}
  local function walk(items)
    for _, sym in ipairs(items or {}) do
      local range = sym.selectionRange or sym.range or (sym.location and sym.location.range)
      if range then
        out[#out + 1] = {
          kind = 'symbol',
          bufnr = bufnr,
          name = sym.name,
          line = range.start.line + 1,
          col = range.start.character,
        }
      end
      walk(sym.children)
    end
  end
  walk(result)
  return out
end

-- Split `rg --files` output into file records rooted at `root`: name is the
-- relative path shown in the list, path is absolute for opening and previewing.
function M.normalize_files(stdout, root)
  local out = {}
  for _, rel in ipairs(vim.split(stdout or '', '\n', { trimempty = true })) do
    out[#out + 1] = { kind = 'file', name = rel, path = vim.fs.normalize(root .. '/' .. rel) }
  end
  return out
end

-- Open buffers as records: listed buffers, named ones carrying an absolute path
-- so build_entries can drop the duplicate file row.
function M.list_buffers()
  local out = {}
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.fn.buflisted(bufnr) == 1 then
      local name = vim.api.nvim_buf_get_name(bufnr)
      out[#out + 1] = {
        kind = 'buffer',
        bufnr = bufnr,
        path = name ~= '' and vim.fs.normalize(name) or nil,
        name = name ~= '' and vim.fn.fnamemodify(name, ':~:.') or ('[No Name ' .. bufnr .. ']'),
      }
    end
  end
  return out
end

-- Merge the per-kind source lists into ordered records plus the fzf input
-- lines. A file already open as a named buffer is dropped — the buffer row
-- opens it preserving cursor and fold state.
function M.build_entries(sources)
  local open = {}
  for _, buf in ipairs(sources.buffers or {}) do
    if buf.path then
      open[buf.path] = true
    end
  end
  local records, lines = {}, {}
  for _, group in ipairs(GROUP_ORDER) do
    for _, rec in ipairs(sources[group] or {}) do
      if not (rec.kind == 'file' and open[rec.path]) then
        records[#records + 1] = rec
        lines[#lines + 1] = string.format('%d\t%s\t%s', #records, TAGS[rec.kind], rec.name)
      end
    end
  end
  return { records = records, lines = lines }
end

-- The record an fzf line points at: its index is the first tab-separated field.
function M.record_of(line)
  local idx = line and tonumber(tostring(line):match('^(%d+)'))
  return idx and M._records and M._records[idx] or nil
end

-- What opening a record does, as data: { verb, args… }. Commands prefill the
-- cmdline instead of executing, so an argument-taking command can be finished
-- by hand.
function M.action_for(rec)
  if not rec then
    return nil
  elseif rec.kind == 'file' then
    return { 'edit', rec.path }
  elseif rec.kind == 'buffer' then
    return { 'buffer', rec.bufnr }
  elseif rec.kind == 'symbol' then
    return { 'symbol', rec.bufnr, rec.line, rec.col }
  elseif rec.kind == 'command' then
    return { 'command', rec.cmd_name }
  end
end

-- The previewer entry for a record (fzf-lua builtin previewer shape). file,
-- buffer, and symbol resolve to a file/buffer at a line; a command renders its
-- documentation (its :help entry or definition) via config.commands.
function M.preview_for(rec)
  if not rec then
    return {}
  elseif rec.kind == 'command' then
    return {
      title = ' ' .. rec.cmd_name .. ' ',
      filetype = 'help',
      content = require('config.commands').docs(rec.cmd_name, rec.definition),
    }
  elseif rec.kind == 'buffer' then
    return { bufnr = rec.bufnr, path = rec.path, line = rec.line or 1 }
  elseif rec.kind == 'symbol' then
    return { bufnr = rec.bufnr, line = rec.line, col = rec.col + 1 }
  else
    return { path = rec.path }
  end
end

function M.open(selected)
  local action = M.action_for(M.record_of(selected and selected[1]))
  if not action then
    return
  end
  local verb = action[1]
  if verb == 'edit' then
    vim.cmd.edit(vim.fn.fnameescape(action[2]))
  elseif verb == 'buffer' then
    vim.cmd.buffer(action[2])
  elseif verb == 'symbol' then
    vim.cmd.buffer(action[2])
    pcall(vim.api.nvim_win_set_cursor, 0, { action[3], action[4] })
    vim.cmd('normal! zvzz')
  elseif verb == 'command' then
    vim.cmd('stopinsert')
    vim.fn.feedkeys(':' .. action[2], 'nt')
  end
end

-- A buffer_or_file previewer that resolves the record by line index and defers
-- to M.preview_for; built lazily so opts can be assembled without fzf-lua.
local everything_previewer
do
  local class
  everything_previewer = function()
    if not class then
      class = require('fzf-lua.previewer.builtin').buffer_or_file:extend()
      class.parse_entry = function(_, line)
        return M.preview_for(M.record_of(line))
      end
    end
    return class
  end
end

-- fzf options as data: rows are `index<TAB>tag<TAB>name`. --with-nth hides the
-- index column (showing tag + name); --nth limits matching to the name so the
-- tag never filters. --nth counts fields within the --with-nth view, where the
-- name is field 2, not field 3. fzf ranks matches by fuzzy score, so an exact
-- match wins; GROUP_ORDER sets only the pre-query view and the order of ties.
function M.everything_opts(root)
  return {
    prompt = require('config.pickers').PROMPTS.everything,
    cwd = root,
    fzf_opts = { ['--delimiter'] = '\t', ['--with-nth'] = '2..', ['--nth'] = '2' },
    previewer = { _ctor = everything_previewer },
    actions = { default = M.open },
  }
end

function M.pick()
  local root = require('config.pickers').workspace_root()
  local bufnr = vim.api.nvim_get_current_buf()
  local symbols = {}
  if next(vim.lsp.get_clients({ bufnr = bufnr })) then
    local params = { textDocument = vim.lsp.util.make_text_document_params(bufnr) }
    local responses = vim.lsp.buf_request_sync(bufnr, 'textDocument/documentSymbol', params, 1000) or {}
    for _, response in pairs(responses) do
      vim.list_extend(symbols, M.normalize_symbols(response.result, bufnr))
    end
  end
  local files = {}
  local rg = vim.system({ 'rg', '--files', '--hidden', '-g', '!.git' }, { cwd = root, text = true }):wait()
  if rg.code == 0 then
    files = M.normalize_files(rg.stdout, root)
  end
  local built = M.build_entries({
    buffers = M.list_buffers(),
    symbols = symbols,
    files = files,
    commands = require('config.commands').list(),
  })
  M._records = built.records
  fzf().fzf_exec(built.lines, M.everything_opts(root))
end

return M
