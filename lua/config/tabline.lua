-- Hand-rolled bufferline with helix `bufferline = "multiple"`
-- semantics: visible only when more than one listed buffer (or any real
-- tab pages) exist. Buffers sharing a file name grow parent directories
-- until they read apart; real tab pages show as numbers on the right; a
-- list wider than the screen scrolls to keep the current buffer in view.
-- build() and its helpers are pure for testability.
local M = {}

-- How far the current buffer's fill moves from the bar toward the text
-- color when the theme draws TabLineSel flat on the bar (see paint()).
M.lift = 0.1

-- Columns reserved for each '‹N'/'N›' overflow marker.
M.marker_width = 5

local function escape(text)
  return (text:gsub('%%', '%%%%'))
end

-- Mix two 0xRRGGBB colors, t = 0 -> from, t = 1 -> to.
function M.blend(from, to, t)
  local out = 0
  for _, shift in ipairs({ 65536, 256, 1 }) do
    local a = math.floor(from / shift) % 256
    local b = math.floor(to / shift) % 256
    out = out + math.floor(a + (b - a) * t + 0.5) * shift
  end
  return out
end

-- The text a buffer occupies, before statusline escaping.
function M.label(b)
  return ' ' .. b.name .. (b.modified and ' [+]' or '') .. ' '
end

-- First/last buffer indices that fit in `budget` columns, grown outward
-- from the current one (right first) so it is never scrolled away. The
-- whole list when it fits, or when there is no current buffer to anchor.
function M.window(widths, current, budget)
  local total = 0
  for _, w in ipairs(widths) do
    total = total + w
  end
  if total <= budget or current == nil then
    return 1, #widths
  end
  local room = budget - 2 * M.marker_width
  local first, last, used = current, current, widths[current]
  local grew = true
  while grew do
    grew = false
    if last < #widths and used + widths[last + 1] <= room then
      last = last + 1
      used = used + widths[last]
      grew = true
    end
    if first > 1 and used + widths[first - 1] <= room then
      first = first - 1
      used = used + widths[first]
      grew = true
    end
  end
  return first, last
end

-- bufs: array of { name, modified, current }
-- opts: { width = screen columns (enables scrolling),
--         tabs = { count, current } (numbers shown when count > 1) }
function M.build(bufs, opts)
  opts = opts or {}
  local tabs = ''
  local tabs_width = 0
  if opts.tabs and opts.tabs.count > 1 then
    local parts = {}
    for i = 1, opts.tabs.count do
      local group = i == opts.tabs.current and 'TablineCurrent' or 'TabLine'
      parts[#parts + 1] = '%#' .. group .. '# ' .. i .. ' '
      tabs_width = tabs_width + #tostring(i) + 2
    end
    tabs = '%=' .. table.concat(parts) .. '%#TabLineFill#'
  end

  local widths, current = {}, nil
  for i, b in ipairs(bufs) do
    widths[i] = vim.fn.strdisplaywidth(M.label(b))
    if b.current then
      current = i
    end
  end
  local first, last = 1, #bufs
  if opts.width then
    first, last = M.window(widths, current, opts.width - tabs_width)
  end

  local out = {}
  if first > 1 then
    out[#out + 1] = '%#TabLine# ‹' .. (first - 1) .. ' '
  end
  for i = first, last do
    local b = bufs[i]
    out[#out + 1] = b.current and '%#TablineCurrent#' or '%#TabLine#'
    out[#out + 1] = escape(M.label(b))
  end
  if last < #bufs then
    out[#out + 1] = '%#TabLine# ' .. (#bufs - last) .. '› '
  end
  out[#out + 1] = '%#TabLineFill#'
  return table.concat(out) .. tabs
end

-- A buffer's path for labelling. LSP URIs (jdtls class files:
-- jdt://…/String.class?=…) carry a query string and a url-encoded path,
-- so the query is stripped and only the trailing segments are ever used.
function M.tab_path(name)
  if name == '' then
    return '[scratch]'
  end
  return (name:gsub('%?.*$', ''))
end

-- Tab label for a lone buffer name: its final path segment.
function M.display_name(name)
  local path = M.tab_path(name)
  return path:match('[^/\\]+$') or path
end

-- Shortest trailing-segment labels that tell the paths apart: a file name
-- alone unless another buffer shares it, then as many parent directories
-- as it takes (config/init.lua vs nvim/init.lua).
function M.unique_names(paths)
  local parts, depth = {}, {}
  for i, path in ipairs(paths) do
    parts[i] = vim.tbl_filter(function(part)
      return part ~= ''
    end, vim.split(path, '[/\\]'))
    if #parts[i] == 0 then
      parts[i] = { path }
    end
    depth[i] = 1
  end
  local function label(i)
    local n = #parts[i]
    return table.concat(parts[i], '/', n - math.min(depth[i], n) + 1, n)
  end
  local changed = true
  while changed do
    changed = false
    local groups = {}
    for i in ipairs(paths) do
      local l = label(i)
      groups[l] = groups[l] or {}
      table.insert(groups[l], i)
    end
    for _, members in pairs(groups) do
      if #members > 1 then
        for _, i in ipairs(members) do
          if depth[i] < #parts[i] then
            depth[i] = depth[i] + 1
            changed = true
          end
        end
      end
    end
  end
  local out = {}
  for i in ipairs(paths) do
    out[i] = label(i)
  end
  return out
end

function M.listed_buffers()
  return vim.tbl_filter(function(buf)
    return vim.bo[buf].buflisted
  end, vim.api.nvim_list_bufs())
end

function M.render()
  local current = vim.api.nvim_get_current_buf()
  local listed = M.listed_buffers()
  local paths = vim.tbl_map(function(buf)
    return M.tab_path(vim.api.nvim_buf_get_name(buf))
  end, listed)
  local names = M.unique_names(paths)
  local bufs = {}
  for i, buf in ipairs(listed) do
    bufs[i] = {
      name = names[i],
      modified = vim.bo[buf].modified,
      current = buf == current,
    }
  end
  return M.build(bufs, {
    width = vim.o.columns,
    tabs = {
      count = #vim.api.nvim_list_tabpages(),
      current = vim.api.nvim_tabpage_get_number(0),
    },
  })
end

-- The current buffer's group follows the active theme: themes that give
-- TabLineSel its own fill keep it; flat ones (selection drawn only by
-- text weight, like anysphere) get a fill lifted off the bar toward the
-- text color, so light and dark themes both read.
function M.paint()
  local function hl(name)
    return vim.api.nvim_get_hl(0, { name = name, link = false })
  end
  local sel, fill, normal = hl('TabLineSel'), hl('TabLineFill'), hl('Normal')
  local base = fill.bg or normal.bg
  if sel.bg and sel.bg ~= base then
    vim.api.nvim_set_hl(0, 'TablineCurrent', { link = 'TabLineSel' })
    return
  end
  local ink = sel.fg or normal.fg
  if base and ink then
    vim.api.nvim_set_hl(0, 'TablineCurrent', {
      fg = ink,
      bg = M.blend(base, ink, M.lift),
      bold = true,
    })
  else
    vim.api.nvim_set_hl(0, 'TablineCurrent', { link = 'TabLineSel' })
  end
end

-- helix "multiple": show with 2+ buffers, hide otherwise. Real tab pages
-- always show it.
function M.update_visibility()
  local many = #M.listed_buffers() > 1 or #vim.api.nvim_list_tabpages() > 1
  vim.o.showtabline = many and 2 or 0
end

function M.setup()
  M.paint()
  vim.api.nvim_create_autocmd('ColorScheme', {
    group = vim.api.nvim_create_augroup('config.tabline.paint', {}),
    callback = M.paint,
  })
  vim.api.nvim_create_autocmd(
    { 'BufAdd', 'BufDelete', 'BufEnter', 'TabEnter', 'TabClosed' },
    {
      group = vim.api.nvim_create_augroup('config.tabline', {}),
      callback = function()
        -- BufDelete fires before the buffer is unlisted
        vim.schedule(M.update_visibility)
      end,
    }
  )
  vim.o.tabline = '%!v:lua.require\'config.tabline\'.render()'
  M.update_visibility()
end

return M
