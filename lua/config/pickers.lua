-- fzf-lua wiring for the Helix picker set (ADR 0001).
local M = {}

local function fzf()
  return require('fzf-lua')
end

-- Helix "workspace root": VCS root of the current buffer, else cwd.
function M.workspace_root()
  local name = vim.api.nvim_buf_get_name(0)
  local dir = name ~= '' and vim.fs.dirname(name) or assert(vim.uv.cwd())
  return vim.fs.root(dir, '.git') or assert(vim.uv.cwd())
end

-- Space mode pickers; hidden = true mirrors the user's helix
-- file-picker.hidden = false (dotfiles shown, .gitignore still respected)
function M.files() fzf().files({ cwd = M.workspace_root(), hidden = true }) end
function M.files_cwd() fzf().files({ cwd = vim.uv.cwd(), hidden = true }) end
function M.buffers() fzf().buffers() end
function M.jumps() fzf().jumps() end
function M.changed_files() fzf().git_status({ cwd = M.workspace_root() }) end
function M.document_symbols() fzf().lsp_document_symbols() end
function M.workspace_symbols() fzf().lsp_live_workspace_symbols() end
function M.diagnostics_buffer() fzf().diagnostics_document() end
function M.diagnostics_workspace() fzf().diagnostics_workspace() end
function M.global_search() fzf().live_grep({ cwd = M.workspace_root() }) end
function M.command_palette() fzf().commands() end
function M.resume() fzf().resume() end

-- File explorer (helix master: Space-e / Space-.): a picker over one
-- directory's entries — `../` first, then directories, then files; Enter
-- descends into directories or opens files. No file operations: those
-- belong to the terminal, like git.

-- Names in `dir` that .gitignore rules ignore (empty outside git repos;
-- check-ignore's "not a repository" stderr never matches real names).
local function gitignored(dir, names)
  if #names == 0 then
    return {}
  end
  local out = vim.fn.systemlist({ 'git', '-C', dir, 'check-ignore', '--stdin' }, names)
  local ignored = {}
  for _, name in ipairs(out) do
    ignored[name] = true
  end
  return ignored
end

-- Listing: { '../', dirs…/, files… }, each group alphabetical. `.git` and
-- anything .gitignore ignores is hidden, like the pickers.
function M.dir_entries(dir)
  local names = {}
  for name in vim.fs.dir(dir) do
    if name ~= '.git' then
      names[#names + 1] = name
    end
  end
  local ignored = gitignored(dir, names)
  local dirs, files = {}, {}
  for _, name in ipairs(names) do
    if not ignored[name] then
      if vim.fn.isdirectory(dir .. '/' .. name) == 1 then
        dirs[#dirs + 1] = name .. '/'
      else
        files[#files + 1] = name
      end
    end
  end
  table.sort(dirs)
  table.sort(files)
  local out = { '../' }
  vim.list_extend(out, dirs)
  return vim.list_extend(out, files)
end

function M.explorer(dir)
  dir = vim.fs.normalize(dir)
  fzf().fzf_exec(M.dir_entries(dir), {
    prompt = vim.fn.fnamemodify(dir, ':~') .. '/',
    cwd = dir, -- relative entries resolve for the previewer
    previewer = 'builtin',
    actions = {
      default = function(selected)
        if selected[1] == nil then
          return
        end
        local path = vim.fs.normalize(dir .. '/' .. selected[1])
        if selected[1]:sub(-1) == '/' then
          M.explorer(path)
        else
          vim.cmd.edit(path)
        end
      end,
    },
  })
end

-- Recursive directory list for the whole workspace, derived from rg's
-- gitignore-respecting file walk ('.' = the root itself; empty dirs and
-- dirs with only ignored files don't appear). --hidden alone would descend
-- into .git — gitignore never lists it — hence the explicit glob. awk
-- strips the filename; field separator '/' keeps paths with spaces intact.
M.DIRS_CMD = [[rg --files --hidden -g '!.git' | awk -F/ -v OFS=/ 'NF > 1 { NF--; print; next } { print "." }' | sort -u]]

-- Space-e: fuzzy search over every directory under the workspace root;
-- Enter lands in the level explorer at the chosen directory.
function M.directories()
  local root = M.workspace_root()
  fzf().fzf_exec(M.DIRS_CMD, {
    prompt = vim.fn.fnamemodify(root, ':~') .. '/**/',
    cwd = root,
    actions = {
      default = function(selected)
        if selected[1] then
          M.explorer(root .. '/' .. selected[1])
        end
      end,
    },
  })
end

function M.explorer_root()
  M.explorer(M.workspace_root())
end

function M.explorer_buffer_dir()
  local name = vim.api.nvim_buf_get_name(0)
  M.explorer(name ~= '' and vim.fs.dirname(name) or assert(vim.uv.cwd()))
end

-- zoxide: terminal-style frecent directory jumping, no plugin — zoxide is
-- a system binary and the picker engine already exists. `:Z {query}` jumps
-- like terminal z; `:Z` / Space-z open the picker (Enter = cd, Ctrl-f =
-- cd + file picker). A DirChanged hook mirrors the shell hook: every :cd
-- feeds the db.
M.ZOXIDE_LIST_CMD = 'zoxide query --list'

local function zoxide_available()
  return vim.fn.executable('zoxide') == 1
end

local function cd(dir)
  vim.cmd.cd(vim.fn.fnameescape(dir))
  vim.notify(vim.fn.fnamemodify(dir, ':~'))
end

function M.zoxide_jump(words)
  if not zoxide_available() then
    return vim.notify('zoxide not found on PATH', vim.log.levels.ERROR)
  end
  local out = vim.fn.systemlist(vim.list_extend({ 'zoxide', 'query' }, words))
  if vim.v.shell_error ~= 0 or out[1] == nil then
    return vim.notify('zoxide: no match for ' .. table.concat(words, ' '), vim.log.levels.WARN)
  end
  cd(out[1])
end

function M.zoxide()
  if not zoxide_available() then
    return vim.notify('zoxide not found on PATH', vim.log.levels.ERROR)
  end
  fzf().fzf_exec(M.ZOXIDE_LIST_CMD, {
    prompt = 'z> ',
    actions = {
      default = function(selected)
        if selected[1] then
          cd(selected[1])
        end
      end,
      ['ctrl-f'] = function(selected)
        if selected[1] then
          cd(selected[1])
          M.files_cwd()
        end
      end,
    },
  })
end

function M.setup()
  vim.api.nvim_create_user_command('Z', function(cmd)
    if #cmd.fargs == 0 then
      M.zoxide()
    else
      M.zoxide_jump(cmd.fargs)
    end
  end, { nargs = '*', desc = 'Jump to a recent directory (zoxide)' })

  if zoxide_available() then
    vim.api.nvim_create_autocmd('DirChanged', {
      group = vim.api.nvim_create_augroup('config.zoxide', {}),
      callback = function()
        vim.fn.system({ 'zoxide', 'add', vim.v.event.cwd })
      end,
    })
  end
end

-- Goto-mode LSP jumps: like Helix, jump straight to a single result and
-- open the picker only when there are several.
function M.definitions() fzf().lsp_definitions({ jump1 = true }) end
function M.type_definitions() fzf().lsp_typedefs({ jump1 = true }) end
function M.implementations() fzf().lsp_implementations({ jump1 = true }) end
function M.references() fzf().lsp_references({ jump1 = false }) end

return M
