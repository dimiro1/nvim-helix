-- Hand-rolled statusline (ADR 0004) mirroring the user's Helix statusline:
-- left = mode + git branch, center = file name + modified/read-only flags,
-- right = workspace diagnostics, buffer diagnostics, position, encoding,
-- line ending, file type. Mode segment is colored (helix color-modes).
-- build()/parse_head()/diag_segment() are pure for testability.
local M = {}

M.mode_labels = {
  n = '❮N❯', no = '❮N❯', nov = '❮N❯', noV = '❮N❯', ['no\22'] = '❮N❯',
  niI = '❮N❯', niR = '❮N❯', niV = '❮N❯', nt = '❮N❯', ntT = '❮N❯',
  i = '❮I❯', ic = '❮I❯', ix = '❮I❯',
  v = '❮V❯', vs = '❮V❯', V = '❮V❯', Vs = '❮V❯',
  ['\22'] = '❮V❯', ['\22s'] = '❮V❯', s = '❮V❯', S = '❮V❯', ['\19'] = '❮V❯',
  R = '❮R❯', Rc = '❮R❯', Rx = '❮R❯', Rv = '❮R❯', Rvc = '❮R❯', Rvx = '❮R❯',
  c = '❮C❯', cv = '❮C❯', r = '❮P❯', rm = '❮P❯', ['r?'] = '❮P❯',
  ['!'] = '❮$❯', t = '❮T❯',
}

M.mode_groups = {
  ['❮N❯'] = 'StatuslineModeNormal',
  ['❮I❯'] = 'StatuslineModeInsert',
  ['❮V❯'] = 'StatuslineModeVisual',
  ['❮R❯'] = 'StatuslineModeReplace',
  ['❮C❯'] = 'StatuslineModeCommand',
  ['❮T❯'] = 'StatuslineModeTerm',
}

-- 'E:1 W:2' with zero-count parts omitted; '' when clean.
function M.diag_segment(errors, warnings)
  local parts = {}
  if (errors or 0) > 0 then
    parts[#parts + 1] = ('E:%d'):format(errors)
  end
  if (warnings or 0) > 0 then
    parts[#parts + 1] = ('W:%d'):format(warnings)
  end
  return table.concat(parts, ' ')
end

-- .git/HEAD content -> branch name, or short hash when detached.
function M.parse_head(content)
  if content == nil or content == '' then
    return nil
  end
  local branch = content:match('^ref: refs/heads/(%S+)')
  if branch then
    return branch
  end
  return content:match('^(%x+)') and content:sub(1, 7) or nil
end

-- state: { mode_label, color, branch, worktree, file, modified, readonly,
--          crumbs, ws_errors, ws_warnings, errors, warnings, line, col,
--          encoding, line_ending, filetype }
function M.build(s)
  local mode = s.mode_label or '   '
  if s.mode_label and s.color then
    local group = M.mode_groups[s.mode_label]
    if group then
      mode = '%#' .. group .. '#' .. s.mode_label .. '%#StatusLine#'
    end
  end
  local vcs = s.branch
  if vcs and s.worktree then
    vcs = vcs .. ' (' .. s.worktree .. ')'
  end
  local left = ' ' .. mode .. (vcs and ('  ' .. vcs) or '')

  local center = s.file
    .. (s.modified and ' [+]' or '')
    .. (s.readonly and ' [RO]' or '')
  if s.crumbs and s.crumbs ~= '' then
    -- separator matches config.breadcrumbs.separator
    center = center .. ' › ' .. s.crumbs
  end

  local segments = {}
  local ws = M.diag_segment(s.ws_errors, s.ws_warnings)
  if ws ~= '' then
    segments[#segments + 1] = '[' .. ws .. ']'
  end
  local buf = M.diag_segment(s.errors, s.warnings)
  if buf ~= '' then
    segments[#segments + 1] = buf
  end
  segments[#segments + 1] = ('%d:%d'):format(s.line, s.col)
  if s.encoding then
    segments[#segments + 1] = s.encoding
  end
  if s.line_ending then
    segments[#segments + 1] = s.line_ending
  end
  if s.filetype and s.filetype ~= '' then
    segments[#segments + 1] = s.filetype
  end

  return left .. ' %=' .. center .. '%=' .. table.concat(segments, '  ') .. ' '
end

local line_endings = { unix = 'LF', dos = 'CRLF', mac = 'CR' }

-- Branch is cached per buffer by autocmd (render must not do IO).
function M.detect_branch(path)
  local root = vim.fs.root(path, '.git')
  if root == nil then
    return nil
  end
  local gitdir = root .. '/.git'
  if vim.fn.isdirectory(gitdir) == 0 then
    -- worktree: .git is a file with `gitdir: <path>`
    local indirection = (vim.fn.readfile(gitdir, '', 1)[1] or ''):match('^gitdir: (.+)$')
    if indirection == nil then
      return nil
    end
    gitdir = indirection
  end
  local head = vim.fn.filereadable(gitdir .. '/HEAD') == 1
      and vim.fn.readfile(gitdir .. '/HEAD', '', 1)[1]
    or nil
  return M.parse_head(head)
end

-- Runs inside a %{%…%} block: current window is the one being drawn,
-- g:actual_curwin is the focused one.
function M.render()
  local win = vim.api.nvim_get_current_win()
  local buf = vim.api.nvim_win_get_buf(win)
  local active = win == (tonumber(vim.g.actual_curwin) or win)
  local name = vim.api.nvim_buf_get_name(buf)
  local counts = vim.diagnostic.count(buf)
  local ws_counts = vim.diagnostic.count(nil)
  local pos = vim.api.nvim_win_get_cursor(win)
  local fenc = vim.bo[buf].fileencoding
  return M.build({
    mode_label = active and M.mode_labels[vim.api.nvim_get_mode().mode] or nil,
    color = active,
    branch = active and vim.b[buf].config_branch or nil,
    worktree = active and vim.b[buf].config_worktree or nil,
    file = name == '' and '[scratch]' or vim.fn.fnamemodify(name, ':~:.'),
    modified = vim.bo[buf].modified,
    readonly = vim.bo[buf].readonly,
    crumbs = active and require('config.breadcrumbs').trail() or nil,
    ws_errors = ws_counts[vim.diagnostic.severity.ERROR],
    ws_warnings = ws_counts[vim.diagnostic.severity.WARN],
    errors = counts[vim.diagnostic.severity.ERROR],
    warnings = counts[vim.diagnostic.severity.WARN],
    line = pos[1],
    col = pos[2] + 1,
    encoding = fenc ~= '' and fenc or vim.o.encoding,
    line_ending = line_endings[vim.bo[buf].fileformat],
    filetype = vim.bo[buf].filetype,
  })
end

function M.setup()
  -- helix color-modes on the stock theme: link to distinct builtin groups
  for group, link in pairs({
    StatuslineModeNormal = 'Function',
    StatuslineModeInsert = 'String',
    StatuslineModeVisual = 'Statement',
    StatuslineModeReplace = 'Error',
    StatuslineModeCommand = 'Constant',
    StatuslineModeTerm = 'Special',
  }) do
    vim.api.nvim_set_hl(0, group, { link = link, default = true })
  end

  vim.api.nvim_create_autocmd({ 'BufEnter', 'FocusGained', 'DirChanged' }, {
    group = vim.api.nvim_create_augroup('config.statusline', {}),
    callback = function(args)
      local name = vim.api.nvim_buf_get_name(args.buf)
      local dir = name ~= '' and vim.fs.dirname(name) or assert(vim.uv.cwd())
      local root = vim.fs.root(dir, '.git')
      vim.b[args.buf].config_branch = M.detect_branch(dir)
      -- which worktree this buffer lives in, shown beside the branch
      vim.b[args.buf].config_worktree = root and vim.fs.basename(root) or nil
    end,
  })

  vim.o.statusline = "%{%v:lua.require'config.statusline'.render()%}"
end

return M
