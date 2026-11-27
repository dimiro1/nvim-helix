-- Worktree workspaces: each git worktree owns a saved editing
-- state — buffers, windows, tabs (a Workspace, see CONTEXT.md). Switching
-- saves the current workspace via :mksession and restores the target's;
-- first visit opens the file picker. Switch-only by design: creating and
-- deleting worktrees stays in the terminal, like the rest of git. With
-- Worktrunk (`wt`) installed, the list also shows each worktree's status.
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

-- Parse `wt list --format=json` into parse()'s shape plus status: the
-- uncommitted diff (`added`/`deleted` lines) and commits `ahead`/`behind`
-- the default branch, named in `base`. Entries without a worktree (branch
-- rows) are skipped.
function M.parse_wt(text)
  local ok, data = pcall(vim.json.decode, text, { luanil = { object = true, array = true } })
  if not ok or type(data) ~= 'table' or type(data.items) ~= 'table' then
    return nil
  end
  local out = {}
  local default = data.repo and data.repo.default_branch
  for _, item in ipairs(data.items) do
    local tree = item.worktree
    if tree and tree.path then
      local diff = tree.changes and tree.changes.diff or {}
      local base = item.default_branch or {}
      out[#out + 1] = {
        path = tree.path,
        branch = item.branch,
        head = item.head and item.head.short_sha,
        detached = tree.detached or nil,
        added = diff.added,
        deleted = diff.deleted,
        ahead = base.ahead,
        behind = base.behind,
        base = item.default_branch and default or nil,
      }
    end
  end
  return out
end

-- Overridable for tests.
function M.wt_available()
  return vim.fn.executable('wt') == 1
end

-- Worktrees of the repository at `dir` (cwd by default): Worktrunk's list
-- when `wt` is installed and succeeds, else git's.
function M.list(dir)
  dir = dir or assert(vim.uv.cwd())
  if M.wt_available() then
    -- vim.system raises when the binary vanished from PATH after the check
    local ok, proc = pcall(vim.system, { 'wt', '-C', dir, 'list', '--format=json' }, { text = true })
    local out = ok and proc:wait()
    local entries = out and out.code == 0 and M.parse_wt(out.stdout or '')
    if entries then
      return entries
    end
  end
  local lines = vim.fn.systemlist({ 'git', '-C', dir, 'worktree', 'list', '--porcelain' })
  if vim.v.shell_error ~= 0 then
    return {}
  end
  return M.parse(lines)
end

-- The status a list entry carries, in words: uncommitted lines
-- (`+12 -3 uncommitted`) and commits against the default branch (`2 ahead,
-- 5 behind main`). Zero counts are left out; '' when there is nothing.
function M.status(wt)
  local parts = {}
  local diff = {}
  if (wt.added or 0) > 0 then
    diff[#diff + 1] = '+' .. wt.added
  end
  if (wt.deleted or 0) > 0 then
    diff[#diff + 1] = '-' .. wt.deleted
  end
  if #diff > 0 then
    parts[#parts + 1] = table.concat(diff, ' ') .. ' uncommitted'
  end
  local ahead, behind = wt.ahead or 0, wt.behind or 0
  local base = wt.base or 'the default branch'
  if ahead > 0 and behind > 0 then
    parts[#parts + 1] = ('%d ahead, %d behind %s'):format(ahead, behind, base)
  elseif ahead > 0 then
    parts[#parts + 1] = ('%d ahead of %s'):format(ahead, base)
  elseif behind > 0 then
    parts[#parts + 1] = ('%d behind %s'):format(behind, base)
  end
  return table.concat(parts, ' · ')
end

-- Picker rows: name (branch, else short sha), path, then current marker and
-- status, with the name and path columns padded to line up.
function M.labels(entries, root)
  local rows, widths = {}, { 0, 0 }
  for i, wt in ipairs(entries) do
    rows[i] = { wt.branch or wt.head or 'detached', vim.fn.fnamemodify(wt.path, ':~') }
    for col = 1, 2 do
      widths[col] = math.max(widths[col], vim.fn.strdisplaywidth(rows[i][col]))
    end
  end
  local out = {}
  for i, wt in ipairs(entries) do
    local cells = {}
    for col = 1, 2 do
      cells[col] = rows[i][col] .. (' '):rep(widths[col] - vim.fn.strdisplaywidth(rows[i][col]))
    end
    if root and M.canonical(wt.path) == root then
      cells[#cells + 1] = '(current)'
    end
    local status = M.status(wt)
    if status ~= '' then
      cells[#cells + 1] = status
    end
    out[i] = vim.trim(table.concat(cells, '  '))
  end
  return out
end

-- The directory a buffer's file lives in; cwd for a nameless buffer.
function M.buffer_dir(buf)
  local name = vim.api.nvim_buf_get_name(buf or 0)
  return name ~= '' and vim.fs.dirname(name) or assert(vim.uv.cwd())
end

-- The workspace the current buffer belongs to: VCS root of its file, else
-- cwd. Pickers, the explorer, and the tree anchor here, so a buffer from
-- another repository searches that repository.
function M.workspace_root()
  -- A tree buffer's name is synthetic. Its actual root still anchors
  -- pickers when the sidebar is focused and cwd belongs somewhere else.
  if vim.bo.filetype == 'NvimTree' then
    local node = require('nvim-tree.api').tree.get_nodes()
    if node then
      return vim.fs.root(node.absolute_path, '.git') or node.absolute_path
    end
  end
  return vim.fs.root(M.buffer_dir(), '.git') or assert(vim.uv.cwd())
end

-- The workspace cwd is in: what a switch saves and leaves. Differs from
-- workspace_root() while the focused buffer belongs to another repository.
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

  -- On Neovim 0.12, sessions cannot restore nvim-tree's scratch buffers.
  -- Save the editing windows, then reopen the sidebar at the new root.
  local tree = require('nvim-tree.api').tree
  local tree_visible = tree.is_visible({ any_tabpage = true })
  tree.close_in_all_tabs()
  vim.cmd('mksession! ' .. vim.fn.fnameescape(M.session_file(current)))
  vim.cmd('silent! %bdelete')
  vim.cmd.cd(vim.fn.fnameescape(target)) -- feeds zoxide, refreshes branch

  local session = M.session_file(target)
  if vim.fn.filereadable(session) == 1 then
    vim.cmd('silent! source ' .. vim.fn.fnameescape(session))
  else
    M.on_first_visit()
  end
  if tree_visible then
    tree.toggle({ path = target, find_file = true, focus = false })
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
  local lines, by_line = M.labels(entries, root), {}
  for i, wt in ipairs(entries) do
    by_line[lines[i]] = wt.path
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
