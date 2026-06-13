-- File explorer (Space-e / Space-.): a picker over one directory's entries —
-- `../` first, then directories, then files; Enter descends into directories
-- or opens files. No file operations: those belong to the terminal, like git.
local M = {}

local function fzf()
  return require('fzf-lua')
end

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
  local root = require('config.pickers').workspace_root()
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
  M.explorer(require('config.pickers').workspace_root())
end

function M.explorer_buffer_dir()
  local name = vim.api.nvim_buf_get_name(0)
  M.explorer(name ~= '' and vim.fs.dirname(name) or assert(vim.uv.cwd()))
end

return M
