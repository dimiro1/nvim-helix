-- Floating terminal toggle: one reusable :terminal
-- buffer in a centered float. Ctrl-\ toggles from normal and terminal
-- mode; Esc Esc leaves terminal-mode.
local M = {}

M.state = { buf = nil, win = nil }

local function win_open()
  return M.state.win ~= nil and vim.api.nvim_win_is_valid(M.state.win)
end

function M.toggle()
  if win_open() then
    vim.api.nvim_win_close(M.state.win, true)
    M.state.win = nil
    return
  end

  if M.state.buf == nil or not vim.api.nvim_buf_is_valid(M.state.buf) then
    M.state.buf = vim.api.nvim_create_buf(false, true)
  end

  local height = math.floor(vim.o.lines * 0.8)
  local width = math.floor(vim.o.columns * 0.8)
  M.state.win = vim.api.nvim_open_win(M.state.buf, true, {
    relative = 'editor',
    row = math.max(math.floor((vim.o.lines - height) / 2) - 1, 0),
    col = math.floor((vim.o.columns - width) / 2),
    width = width,
    height = height,
    border = 'single',
  })

  if vim.bo[M.state.buf].buftype ~= 'terminal' then
    vim.fn.jobstart(vim.o.shell, { term = true })
  end
  vim.cmd.startinsert()
end

return M
