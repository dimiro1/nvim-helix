-- Hand-rolled statusline mirroring the user's layout:
-- left = mode + git branch, center = file name + modified/read-only flags,
-- right = search match count, workspace diagnostics, buffer diagnostics,
-- position, encoding, line ending, file type. The mode and position
-- segments are colored badges whose fill is drawn from the active
-- colorscheme. Encoding is shown only when it isn't utf-8; the metadata
-- tail (line ending, encoding, file type) is shed as the window narrows.
-- build()/parse_head()/diag_segment()/encoding_label()/search_segment()
-- are pure for testability.
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

-- The metadata tail drops parts whose key falls below the window width,
-- narrowest-survivor last. Diagnostics, search count, and position never
-- shed. Value = the minimum window columns to keep the part.
M.right_min_width = {
  line_ending = 90,
  encoding = 80,
  filetype = 60,
}

-- A long center path is capped at this many display columns by abbreviating
-- its interior directories, even when the window has room to spare; the
-- window-derived budget shrinks it further when space is tight.
M.path_max_width = 40

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

-- File encoding to display, or nil when it's the unremarkable utf-8.
function M.encoding_label(fenc, fallback)
  local enc = (fenc and fenc ~= '') and fenc or fallback
  return enc ~= 'utf-8' and enc or nil
end

-- '[cur/total]' for the active search; '' when nothing is matched.
function M.search_segment(current, total)
  if (total or 0) == 0 then
    return ''
  end
  return ('[%d/%d]'):format(current or 0, total)
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

-- The center segment's file label. A nameless buffer is '[scratch]'.
-- jdtls class-file buffers carry a jdt:// URI with a `?=…` query and a
-- url-encoded path, so fnamemodify would mangle them — reduce those (and
-- any other scheme:// LSP URI) to the final class/file segment, matching
-- the tabline. Plain files keep their cwd/home-relative path.
function M.file_label(name)
  if name == '' then
    return '[scratch]'
  end
  if name:match('^%a[%w+.-]*://') then
    return (name:gsub('%?.*$', '')):match('[^/\\]+$') or name
  end
  return vim.fn.fnamemodify(name, ':~:.')
end

-- The library a jdt:// class file was decompiled from, shown as a hint
-- that the buffer is dependency code rather than project source; nil for
-- ordinary files. jdtls encodes the maven coordinates in the URI query, so
-- a Maven dependency reads back as a jar-style `artifact-version`; lacking
-- those, fall back to the container segment after contents/ (a jar name, or
-- a JDK module such as java.base).
function M.dependency_hint(name)
  if not name:match('^jdt://') then
    return nil
  end
  local query = name:match('%?(.*)$') or ''
  local artifact = query:match('maven%.artifactId=/([^=/]+)')
  if artifact then
    local version = query:match('maven%.version=/([^=/]+)')
    return version and (artifact .. '-' .. version) or artifact
  end
  return name:match('^jdt://contents/([^/]+)')
end

-- First display character of a path component, preserving a leading dot so
-- dotfiles stay recognizable (src -> s, .config -> .c).
function M.initial(part)
  local dot = part:sub(1, 1) == '.' and '.' or ''
  return dot .. vim.fn.strcharpart(part:sub(#dot + 1), 0, 1)
end

-- Fit a path into `budget` display columns by shortening its interior
-- directories to their initial letter, leftmost first (the least specific
-- end), stopping as soon as it fits. The file name is never abbreviated.
-- Returns the path unchanged when it already fits or the budget is unusable.
function M.fit_path(path, budget)
  if budget < 1 or M.display_width(path) <= budget then
    return path
  end
  local parts = vim.split(path, '/', { plain = true })
  for i = 1, #parts - 1 do
    if M.display_width(table.concat(parts, '/')) <= budget then
      break
    end
    if parts[i] ~= '' then
      parts[i] = M.initial(parts[i])
    end
  end
  return table.concat(parts, '/')
end

-- state: { mode_label, color, branch, worktree, file, dependency, modified,
--          readonly, crumbs, ws_errors, ws_warnings, errors, warnings, line,
--          col, encoding, line_ending, filetype, width }
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

  -- everything the center carries besides the path; measured so the path
  -- can be shortened around it rather than at its expense
  local extras = (s.dependency and (' (' .. s.dependency .. ')') or '')
    .. (s.modified and ' [+]' or '')
    .. (s.readonly and ' [RO]' or '')
  if s.crumbs and s.crumbs ~= '' then
    -- separator matches config.breadcrumbs.separator
    extras = extras .. ' › ' .. s.crumbs
  end

  local segments = {}
  if s.search and s.search ~= '' then
    segments[#segments + 1] = s.search
  end
  local ws = M.diag_segment(s.ws_errors, s.ws_warnings)
  if ws ~= '' then
    segments[#segments + 1] = '[' .. ws .. ']'
  end
  local buf = M.diag_segment(s.errors, s.warnings)
  if buf ~= '' then
    segments[#segments + 1] = buf
  end

  -- Position carries the mode badge's color on the active window, so the
  -- bar is bookended by the mode hue at both ends.
  local position = ('%d:%d'):format(s.line, s.col)
  if s.color and label and M.mode_groups[label] then
    position = '%#' .. M.mode_groups[label] .. '# ' .. position .. ' %#StatusLine#'
  end
  segments[#segments + 1] = position

  -- Metadata tail: drop the parts the window is too narrow to carry.
  local function wide_enough(key)
    return s.width == nil or s.width >= M.right_min_width[key]
  end
  if s.encoding and wide_enough('encoding') then
    segments[#segments + 1] = s.encoding
  end
  if s.line_ending and wide_enough('line_ending') then
    segments[#segments + 1] = s.line_ending
  end
  if s.filetype and s.filetype ~= '' and wide_enough('filetype') then
    segments[#segments + 1] = s.filetype
  end

  local right = table.concat(segments, '  ') .. ' '

  -- Shorten the path's interior directories (leftmost first): always down to
  -- the path cap, and further when the window can't seat the center between
  -- the side segments.
  local file = s.file
  if s.width then
    local budget = s.width - M.display_width(left) - M.display_width(right)
      - M.display_width(extras) - 2
    file = M.fit_path(file, math.min(budget, M.path_max_width))
  end
  local center = file .. extras

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

-- Active-search match position for the focused window; '' when idle.
-- Wrapped in pcall because searchcount errors on a malformed pattern.
function M.search_count()
  if vim.v.hlsearch ~= 1 then
    return ''
  end
  local ok, r = pcall(vim.fn.searchcount, { recompute = true, maxcount = 999 })
  if not ok or type(r) ~= 'table' then
    return ''
  end
  return M.search_segment(r.current, r.total)
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
  -- a global statusline spans all columns; per-window spans the window
  local width = vim.o.laststatus == 3 and vim.o.columns or vim.api.nvim_win_get_width(win)
  return M.build({
    mode_label = active and M.mode_labels[vim.api.nvim_get_mode().mode] or nil,
    color = active,
    branch = active and vim.b[buf].config_branch or nil,
    worktree = active and vim.b[buf].config_worktree or nil,
    file = M.file_label(name),
    dependency = M.dependency_hint(name),
    modified = vim.bo[buf].modified,
    readonly = vim.bo[buf].readonly,
    crumbs = active and require('config.breadcrumbs').trail() or nil,
    ws_errors = ws_counts[vim.diagnostic.severity.ERROR],
    ws_warnings = ws_counts[vim.diagnostic.severity.WARN],
    errors = counts[vim.diagnostic.severity.ERROR],
    warnings = counts[vim.diagnostic.severity.WARN],
    line = pos[1],
    -- virtual (display) column, so tabs and multibyte glyphs read right
    col = vim.fn.virtcol('.', false, win),
    encoding = M.encoding_label(vim.bo[buf].fileencoding, vim.o.encoding),
    line_ending = line_endings[vim.bo[buf].fileformat],
    filetype = vim.bo[buf].filetype,
    search = active and M.search_count() or nil,
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
