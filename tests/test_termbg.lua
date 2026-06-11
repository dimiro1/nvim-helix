local termbg = require('config.termbg')

local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      child.restart({ '-u', 'init.lua' })
    end,
    post_once = child.stop,
  },
})

local eq = MiniTest.expect.equality

-- Pure rendering --------------------------------------------------------

T['osc_set renders an OSC 11 set-background sequence'] = function()
  eq(termbg.osc_set(0x292522), '\27]11;#292522\27\\')
end

T['osc_set zero-pads to six hex digits'] = function()
  eq(termbg.osc_set(0x000001), '\27]11;#000001\27\\')
end

T['osc_set is nil without a color'] = function()
  eq(termbg.osc_set(nil), nil)
end

T['osc_reset is OSC 111'] = function()
  eq(termbg.osc_reset, '\27]111\27\\')
end

-- Config state -----------------------------------------------------------

T['the active colorscheme defines a background to report'] = function()
  eq(child.lua_get([[require('config.termbg').background() ~= nil]]), true)
end

T['background reads Normal guibg'] = function()
  eq(
    child.lua_get([[require('config.termbg').background()]]),
    child.lua_get([[vim.api.nvim_get_hl(0, { name = 'Normal', link = false }).bg]])
  )
end

T['autocmds report on attach/scheme change/resume, reset on leave/suspend'] = function()
  local events = child.lua_get([[(function()
    local out = {}
    for _, au in ipairs(vim.api.nvim_get_autocmds({ group = 'config.termbg' })) do
      out[au.event] = true
    end
    return out
  end)()]])
  eq(events, {
    UIEnter = true,
    ColorScheme = true,
    VimResume = true,
    UILeave = true,
    VimSuspend = true,
  })
end

-- Behavior ---------------------------------------------------------------

T['sync and reset are no-ops without a tty UI'] = function()
  -- The child runs embedded: stdout is this suite's RPC channel, so an
  -- unguarded write would corrupt the very connection asserting this.
  eq(child.lua_get([[require('config.termbg').sync() == nil]]), true)
  eq(child.lua_get([[require('config.termbg').reset() == nil]]), true)
end

T['sync writes the scheme background once a tty UI is attached'] = function()
  local r = child.lua_get([[(function()
    local termbg = require('config.termbg')
    local captured = {}
    local uis, write = vim.api.nvim_list_uis, termbg.write
    vim.api.nvim_list_uis = function() return { { stdout_tty = true } } end
    termbg.write = function(seq) table.insert(captured, seq) end
    local returned = termbg.sync()
    vim.api.nvim_list_uis, termbg.write = uis, write
    return { returned = returned, captured = captured, expected = termbg.osc_set(termbg.background()) }
  end)()]])
  eq(r.returned, r.expected)
  eq(r.captured, { r.expected })
end

T['sync falls back to OSC 111 when the scheme has no background'] = function()
  local r = child.lua_get([[(function()
    local termbg = require('config.termbg')
    vim.api.nvim_set_hl(0, 'Normal', {})
    local captured
    local uis, write = vim.api.nvim_list_uis, termbg.write
    vim.api.nvim_list_uis = function() return { { stdout_tty = true } } end
    termbg.write = function(seq) captured = seq end
    local returned = termbg.sync()
    local owed = termbg.reset()
    vim.api.nvim_list_uis, termbg.write = uis, write
    return { returned = returned, captured = captured, owed_is_nil = owed == nil }
  end)()]])
  eq(r.returned, termbg.osc_reset)
  eq(r.captured, termbg.osc_reset)
  -- the terminal is already at its default: nothing left to undo
  eq(r.owed_is_nil, true)
end

T['reset still writes OSC 111 on exit, after the UI is gone'] = function()
  -- UILeave fires after the UI detaches, so reset must not depend on
  -- nvim_list_uis(); it undoes whatever sync() last wrote.
  local r = child.lua_get([[(function()
    local termbg = require('config.termbg')
    local captured = {}
    local uis, write = vim.api.nvim_list_uis, termbg.write
    vim.api.nvim_list_uis = function() return { { stdout_tty = true } } end
    termbg.write = function(seq) table.insert(captured, seq) end
    termbg.sync()
    vim.api.nvim_list_uis = uis -- the embedded child really has no UIs
    local returned = termbg.reset()
    local again = termbg.reset()
    termbg.write = write
    return { returned = returned, again_is_nil = again == nil, captured = captured }
  end)()]])
  eq(r.returned, termbg.osc_reset)
  eq(r.captured[2], termbg.osc_reset)
  -- one-shot: the second reset has nothing to undo
  eq(r.again_is_nil, true)
end

T['a colorscheme switch re-reports the new background'] = function()
  local r = child.lua_get([[(function()
    local termbg = require('config.termbg')
    local captured = {}
    local uis, write = vim.api.nvim_list_uis, termbg.write
    vim.api.nvim_list_uis = function() return { { stdout_tty = true } } end
    termbg.write = function(seq) table.insert(captured, seq) end
    vim.cmd.colorscheme('rose-pine')
    local expected = termbg.osc_set(termbg.background())
    vim.api.nvim_list_uis, termbg.write = uis, write
    return { captured = captured, expected = expected }
  end)()]])
  eq(#r.captured >= 1, true)
  eq(r.captured[#r.captured], r.expected)
end

return T
