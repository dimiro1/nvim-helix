-- Report the colorscheme's background to the terminal via OSC 11 — the
-- same escape Helix emits on startup and theme change. Terminals like
-- Ghostty derive their window chrome (tab bar, titlebar) from the
-- reported default background, not from the colors apps paint on cells,
-- so without this the tabs keep the terminal's own background. OSC 111
-- hands the choice back to the terminal (exit, suspend, schemes without
-- a background). Native autocmds, no plugin (ADR 0004).
local M = {}

-- OSC 11 set-default-background for a 24-bit highlight color; nil when
-- the scheme defines no guibg.
function M.osc_set(bg)
  if bg == nil then
    return nil
  end
  return string.format('\027]11;#%06x\027\\', bg)
end

-- OSC 111: reset the default background to the terminal's own.
M.osc_reset = '\027]111\027\\'

-- The color to report: Normal guibg, the canvas every scheme paints.
function M.background()
  return vim.api.nvim_get_hl(0, { name = 'Normal', link = false }).bg
end

-- Escape bytes may only go to a real TUI. Under --embed (tests, GUIs)
-- stdout is the RPC channel, and `make bootstrap`/`make test` run
-- headless inside the user's terminal, where a stray OSC 11 would
-- recolor it with no UILeave to ever reset it.
local function tui_attached()
  for _, ui in ipairs(vim.api.nvim_list_uis()) do
    if ui.stdout_tty then
      return true
    end
  end
  return false
end

-- Whether a sync() reached the terminal and OSC 111 is owed. reset()
-- keys off this, not tui_attached(): UILeave fires after the UI has
-- left nvim_list_uis(), so a UI check would always skip the exit reset
-- and leave the terminal tinted.
local applied = false

-- IO seam for tests. Deliberately bypasses the message pipeline: escape
-- bytes must reach the terminal raw.
function M.write(seq)
  io.stdout:write(seq)
end

-- Report the current background; falls back to OSC 111 so schemes
-- without guibg show the terminal's own background. Returns what was
-- written, nil when skipped.
function M.sync()
  if not tui_attached() then
    return nil
  end
  local seq = M.osc_set(M.background()) or M.osc_reset
  M.write(seq)
  applied = seq ~= M.osc_reset
  return seq
end

-- One-shot: undoes the sync() that was actually written, including on
-- exit when no UI is left to check.
function M.reset()
  if not applied then
    return nil
  end
  applied = false
  M.write(M.osc_reset)
  return M.osc_reset
end

function M.setup()
  local group = vim.api.nvim_create_augroup('config.termbg', {})
  -- UIEnter, not startup, does the first report: init.lua finishes
  -- before the TUI attaches, so the ColorScheme fired during startup
  -- has no terminal to write to yet.
  vim.api.nvim_create_autocmd({ 'UIEnter', 'ColorScheme', 'VimResume' }, {
    group = group,
    callback = function()
      M.sync()
    end,
  })
  vim.api.nvim_create_autocmd({ 'UILeave', 'VimSuspend' }, {
    group = group,
    callback = function()
      M.reset()
    end,
  })
end

return M
