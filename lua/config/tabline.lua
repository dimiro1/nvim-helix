-- Hand-rolled bufferline (ADR 0004) with helix `bufferline = "multiple"`
-- semantics: visible only when more than one listed buffer (or any real
-- tab pages) exist. build() is pure for testability.
local M = {}

-- bufs: array of { name, modified, current }
function M.build(bufs)
  local out = {}
  for _, b in ipairs(bufs) do
    out[#out + 1] = b.current and '%#TabLineSel#' or '%#TabLine#'
    out[#out + 1] = ' ' .. b.name .. (b.modified and ' [+]' or '') .. ' '
  end
  out[#out + 1] = '%#TabLineFill#'
  return table.concat(out)
end

function M.listed_buffers()
  return vim.tbl_filter(function(buf)
    return vim.bo[buf].buflisted
  end, vim.api.nvim_list_bufs())
end

function M.render()
  local current = vim.api.nvim_get_current_buf()
  local bufs = {}
  for _, buf in ipairs(M.listed_buffers()) do
    local name = vim.api.nvim_buf_get_name(buf)
    bufs[#bufs + 1] = {
      name = name == '' and '[scratch]' or vim.fn.fnamemodify(name, ':t'),
      modified = vim.bo[buf].modified,
      current = buf == current,
    }
  end
  return M.build(bufs)
end

-- helix "multiple": show with 2+ buffers, hide otherwise. Real tab pages
-- always show it.
function M.update_visibility()
  local many = #M.listed_buffers() > 1 or #vim.api.nvim_list_tabpages() > 1
  vim.o.showtabline = many and 2 or 0
end

function M.setup()
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
