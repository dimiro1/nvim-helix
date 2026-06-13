-- Worktree workspaces: each git worktree owns a saved editing
-- state — buffers, windows, tabs (a Workspace, see CONTEXT.md). Switching
-- saves the current workspace via :mksession and restores the target's;
-- first visit opens the file picker. Switch-only by design: creating and
-- deleting worktrees stays in the terminal, like the rest of git.
local M = {}

-- Parse `git worktree list --porcelain` output: blocks separated by blank
-- lines with fields `worktree <path>`, `branch refs/heads/<name>`,
-- `HEAD <sha>`, `bare`, `detached`.
function M.parse(lines)
  local out, current = {}, nil
  for _, line in ipairs(lines) do
    if line == '' then
      current = nil
    elseif vim.startswith(line, 'worktree ') then
      current = { path = line:sub(#'worktree ' + 1) }
      out[#out + 1] = current
    elseif current then
      local branch = line:match('^branch refs/heads/(.+)$')
      if branch then
        current.branch = branch
      elseif line == 'bare' then
        current.bare = true
      elseif line == 'detached' then
        current.detached = true
      else
        local head = line:match('^HEAD (%x+)')
        if head then
          current.head = head:sub(1, 7)
        end
      end
    end
  end
  return out
end

function M.list(dir)
  local lines = vim.fn.systemlist({
    'git', '-C', dir or assert(vim.uv.cwd()), 'worktree', 'list', '--porcelain',
  })
  if vim.v.shell_error ~= 0 then
    return {}
  end
  return M.parse(lines)
end

function M.current_root()
  local cwd = assert(vim.uv.cwd())
  return vim.fs.root(cwd, '.git') or cwd
end

-- One root, one identity: resolve symlinks (macOS reports /private/var for
-- a /var cwd; symlinked project dirs are common) so the same worktree never
-- forks into two workspace keys.
function M.canonical(path)
  local normalized = vim.fs.normalize(path)
  return vim.uv.fs_realpath(normalized) or normalized
end

-- One session file per worktree root, same %-encoding scheme as undofiles.
function M.session_file(root)
  local dir = vim.fn.stdpath('state') .. '/worktrees'
  vim.fn.mkdir(dir, 'p')
  return dir .. '/' .. M.canonical(root):gsub('[/\\:]', '%%') .. '.vim'
end

function M.modified_buffers()
  return vim.tbl_filter(function(buf)
    return vim.bo[buf].buflisted and vim.bo[buf].modified
  end, vim.api.nvim_list_bufs())
end

-- Overridable for tests; default lands in the file picker at the new root.
function M.on_first_visit()
  require('config.pickers').files()
end

---@return boolean switched
function M.switch(target)
  target = M.canonical(target)
  local current = M.canonical(M.current_root())
  if target == current then
    return true
  end
  if #M.modified_buffers() > 0 then
    vim.notify(
      'unsaved buffers — write or discard them before switching worktrees',
      vim.log.levels.ERROR
    )
    return false
  end

  vim.cmd('mksession! ' .. vim.fn.fnameescape(M.session_file(current)))
  vim.cmd('silent! %bdelete')
  vim.cmd.cd(vim.fn.fnameescape(target)) -- feeds zoxide, refreshes branch

  local session = M.session_file(target)
  if vim.fn.filereadable(session) == 1 then
    vim.cmd('silent! source ' .. vim.fn.fnameescape(session))
  else
    M.on_first_visit()
  end
  return true
end

function M.pick()
  local entries = vim.tbl_filter(function(wt)
    return not wt.bare
  end, M.list())
  if #entries == 0 then
    return vim.notify('no git worktrees here', vim.log.levels.WARN)
  end
  local root = M.canonical(M.current_root())
  local lines, by_line = {}, {}
  for _, wt in ipairs(entries) do
    local label = (wt.branch or wt.head or 'detached')
      .. '  '
      .. vim.fn.fnamemodify(wt.path, ':~')
    if M.canonical(wt.path) == root then
      label = label .. '  (current)'
    end
    lines[#lines + 1] = label
    by_line[label] = wt.path
  end
  require('fzf-lua').fzf_exec(lines, {
    prompt = require('config.pickers').PROMPTS.worktrees,
    actions = {
      default = function(selected)
        if selected[1] then
          M.switch(by_line[selected[1]])
        end
      end,
    },
  })
end

function M.setup()
  vim.api.nvim_create_user_command('Worktrees', M.pick, {
    desc = 'Switch git worktree (swaps workspaces)',
  })
end

return M
