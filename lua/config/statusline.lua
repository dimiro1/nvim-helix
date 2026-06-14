-- Hand-rolled statusline mirroring the user's Helix statusline:
-- left = mode + git branch, center = file name + modified/read-only flags,
-- right = workspace diagnostics, buffer diagnostics, position, encoding,
-- line ending, file type. The mode segment is a colored badge whose
-- fill is drawn from the active colorscheme.
-- build()/parse_head()/diag_segment() are pure for testability.
local M = {}

M.mode_labels = {
  n = 'NOR', no = 'NOR', nov = 'NOR', noV = 'NOR', ['no\22'] = 'NOR',
  niI = 'NOR', niR = 'NOR', niV = 'NOR', nt = 'NOR', ntT = 'NOR',
  i = 'INS', ic = 'INS', ix = 'INS',
  v = 'VIS', vs = 'VIS', V = 'VIS', Vs = 'VIS',
  ['\22'] = 'VIS', ['\22s'] = 'VIS', s = 'VIS', S = 'VIS', ['\19'] = 'VIS',
  R = 'REP', Rc = 'REP', Rx = 'REP', Rv = 'REP', Rvc = 'REP', Rvx = 'REP',
  c = 'CMD', cv = 'CMD', r = 'PMT', rm = 'PMT', ['r?'] = 'PMT',
  ['!'] = 'SHL', t = 'TRM',
}

-- Label -> highlight group; build() wraps the badge in '%#group#…'.
M.mode_groups = {
  NOR = 'StatuslineModeNormal',
  INS = 'StatuslineModeInsert',
  VIS = 'StatuslineModeVisual',
  REP = 'StatuslineModeReplace',
  CMD = 'StatuslineModeCommand',
  PMT = 'StatuslineModePrompt',
  SHL = 'StatuslineModeShell',
  TRM = 'StatuslineModeTerm',
}

-- Each badge fills with a builtin group's foreground, resolved live in
-- setup() so the palette follows whatever colorscheme is set. Sources
-- are chosen to land on distinct hues (themes that leave one unstyled
-- fall back to the plain bar — see setup()).
M.mode_sources = {
  StatuslineModeNormal = 'Function',
  StatuslineModeInsert = 'PreProc',
  StatuslineModeVisual = 'Statement',
  StatuslineModeReplace = 'DiagnosticError',
  StatuslineModeCommand = 'Constant',
  StatuslineModePrompt = 'DiagnosticInfo',
  StatuslineModeShell = 'Operator',
  StatuslineModeTerm = 'Type',
}

-- Readable ink for a 0xRRGGBB fill: light fills get black text, dark
-- fills get white, by Rec. 601 luma. Keeps badges legible on any theme.
function M.ink(fill)
  local r = math.floor(fill / 65536) % 256
  local g = math.floor(fill / 256) % 256
  local b = fill % 256
  local luma = (r * 299 + g * 587 + b * 114) / 1000
  return luma >= 128 and 0x000000 or 0xffffff
end

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

-- Display columns a built segment occupies, ignoring %#hl# group escapes
-- (which take no screen space).
function M.display_width(segment)
  return vim.fn.strdisplaywidth((segment:gsub('%%#[^#]*#', '')))
end

-- state: { mode_label, color, branch, worktree, file, modified, readonly,
--          crumbs, ws_errors, ws_warnings, errors, warnings, line, col,
--          encoding, line_ending, filetype, width }
-- width (the window's columns) opts the center segment into true
-- window-centering; without it the center balances in the leftover space.
function M.build(s)
  local label = s.mode_label
  local mode
  if label == nil then
    mode = '     ' -- inactive window: reserve the badge's width
  elseif s.color and M.mode_groups[label] then
    mode = '%#' .. M.mode_groups[label] .. '# ' .. label .. ' %#StatusLine#'
  else
    mode = label -- active but uncolored (unit tests); no badge to pad
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

  local right = table.concat(segments, '  ') .. ' '

  -- True-center the center segment on the window midpoint: position it
  -- by hand from the segment widths instead of letting %= balance it in
  -- the leftover space (which drifts when left and right differ in size).
  if s.width then
    local lw = M.display_width(left)
    local cw = M.display_width(center)
    local rw = M.display_width(right)
    local left_gap = math.floor((s.width - cw) / 2) - lw
    local right_gap = s.width - lw - left_gap - cw - rw
    if left_gap >= 1 and right_gap >= 1 then
      return left .. (' '):rep(left_gap) .. center .. (' '):rep(right_gap) .. right
    end
  end

  -- No width, or the segments are too wide to center without overlap:
  -- fall back to %= balancing, which degrades gracefully.
  return left .. ' %=' .. center .. '%=' .. right
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
  -- a global statusline spans all columns; per-window spans the window
  local width = vim.o.laststatus == 3 and vim.o.columns or vim.api.nvim_win_get_width(win)
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
    width = width,
  })
end

function M.setup()
  -- Fill each badge from its source group's foreground and ink it for
  -- contrast; repaint on theme switch so the colors keep up. Resolving
  -- live (rather than linking) lets a single group carry both fg and bg.
  local function paint()
    for group, source in pairs(M.mode_sources) do
      local fill = vim.api.nvim_get_hl(0, { name = source, link = false }).fg
      if fill then
        vim.api.nvim_set_hl(0, group, { fg = M.ink(fill), bg = fill, bold = true })
      else
        -- theme leaves the source unstyled: degrade to the plain bar
        vim.api.nvim_set_hl(0, group, { link = 'StatusLine' })
      end
    end
  end
  paint()
  vim.api.nvim_create_autocmd('ColorScheme', {
    group = vim.api.nvim_create_augroup('config.statusline.modes', {}),
    callback = paint,
  })

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
