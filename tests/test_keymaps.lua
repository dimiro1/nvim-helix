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

T['every spec in the keymap data is mapped'] = function()
  local unmapped = child.lua_get([[(function()
    local out = {}
    for _, spec in ipairs(require('config.keymaps').specs) do
      local modes = type(spec[1]) == 'table' and spec[1] or { spec[1] }
      for _, m in ipairs(modes) do
        if vim.tbl_isempty(vim.fn.maparg(spec[2], m, false, true)) then
          table.insert(out, m .. ' ' .. spec[2])
        end
      end
    end
    return out
  end)()]])
  eq(unmapped, {})
end

T['every mapping has a description for the infobox'] = function()
  local missing = child.lua_get([[(function()
    local out = {}
    for _, spec in ipairs(require('config.keymaps').specs) do
      local modes = type(spec[1]) == 'table' and spec[1] or { spec[1] }
      for _, m in ipairs(modes) do
        local info = vim.fn.maparg(spec[2], m, false, true)
        if info.desc == nil or info.desc == '' then
          table.insert(out, m .. ' ' .. spec[2])
        end
      end
    end
    return out
  end)()]])
  eq(missing, {})
end

T['neovim default gr-family is removed so gr fires instantly'] = function()
  for _, lhs in ipairs({ 'grr', 'grn', 'gri', 'grt', 'grx' }) do
    eq(child.lua_get(([[vim.fn.maparg('%s', 'n')]]):format(lhs)), '', lhs)
  end
  eq(child.lua_get([[vim.fn.maparg('gra', 'n')]]), '')
  eq(child.lua_get([[vim.fn.maparg('gra', 'x')]]), '')
end

T['nothing gr-prefixed shadows gr — in any mode, ever'] = function()
  local leftovers = child.lua_get([[(function()
    local out = {}
    for _, mode in ipairs({ 'n', 'x' }) do
      for _, map in ipairs(vim.api.nvim_get_keymap(mode)) do
        if vim.startswith(map.lhs, 'gr') and #map.lhs > 2 then
          table.insert(out, mode .. ' ' .. map.lhs)
        end
      end
    end
    return out
  end)()]])
  eq(leftovers, {})
end

T['helix LSP gotos are mapped'] = function()
  for _, lhs in ipairs({ 'gd', 'gy', 'gi', 'gr' }) do
    eq(
      child.lua_get(([[vim.tbl_isempty(vim.fn.maparg('%s', 'n', false, true))]]):format(lhs)),
      false
    )
  end
end

T['gw jumps with flash labels in normal and visual mode'] = function()
  for _, mode in ipairs({ 'n', 'x' }) do
    eq(child.lua_get(([[vim.fn.maparg('gw', '%s', false, true).desc]]):format(mode)), 'Jump (flash)', mode)
  end
  -- gW is unmapped: flash owns the lowercase gw, no capital sibling
  eq(child.lua_get([[vim.fn.maparg('gW', 'n')]]), '')
end

T['flash leaves the f/t/F/T and / search grammar stock'] = function()
  -- flash's char and search modes would rebind these; both are disabled so
  -- the jump only ever fires from the explicit gw invocation
  for _, mode in ipairs({ 'n', 'x', 'o' }) do
    for _, lhs in ipairs({ 'f', 't', 'F', 'T', ';', ',' }) do
      eq(child.lua_get(([[vim.fn.maparg('%s', '%s')]]):format(lhs, mode)), '', mode .. ' ' .. lhs)
    end
  end
end

T['space-w aliases window mode'] = function()
  eq(child.lua_get([[vim.fn.maparg('<Leader>w', 'n')]]), '<C-W>')
end

T['width resize command follows the key as a separator arrow'] = function()
  local cmd = function(key, has_right, count)
    return child.lua_get(
      ([[require('config.keymaps').width_resize_cmd('%s', %s, %d)]]):format(key, tostring(has_right), count)
    )
  end
  eq(cmd('>', true, 1), 'vertical resize +1')
  eq(cmd('<', true, 1), 'vertical resize -1')
  eq(cmd('>', false, 1), 'vertical resize -1')
  eq(cmd('<', false, 1), 'vertical resize +1')
  eq(cmd('<', false, 7), 'vertical resize +7')
end

T['width resize keys replace the native grow/shrink'] = function()
  eq(child.lua_get([[vim.fn.maparg('<C-w><', 'n', false, true).desc]]), 'Move vertical separator left')
  eq(child.lua_get([[vim.fn.maparg('<C-w>>', 'n', false, true).desc]]), 'Move vertical separator right')
end

local function split_side_by_side()
  child.o.columns = 101
  child.lua([[
    vim.cmd('vsplit')
    vim.cmd('1wincmd w')
    vim.cmd('vertical resize 50')
  ]])
end

local function left_width()
  return child.lua_get([[vim.api.nvim_win_get_width(vim.fn.win_getid(1))]])
end

T['in the left window the separator follows the key'] = function()
  split_side_by_side()
  eq(child.lua_get([[vim.fn.winnr()]]), 1)
  child.type_keys('<C-w>', '>')
  eq(left_width(), 51)
  child.type_keys('<C-w>', '<')
  child.type_keys('<C-w>', '<')
  eq(left_width(), 49)
end

T['in the rightmost window the separator still follows the key'] = function()
  split_side_by_side()
  child.cmd('wincmd l')
  eq(child.lua_get([[vim.fn.winnr()]]), 2)
  child.type_keys('<C-w>', '>')
  eq(left_width(), 51)
  child.type_keys('<C-w>', '<')
  child.type_keys('<C-w>', '<')
  eq(left_width(), 49)
  eq(child.lua_get([[vim.fn.winnr()]]), 2)
end

T['in a middle window the right separator follows the key'] = function()
  child.o.columns = 152
  child.lua([[
    vim.cmd('vsplit | vsplit')
    vim.cmd('wincmd =')
    vim.cmd('2wincmd w')
  ]])
  local right_edge = function()
    return child.lua_get([[vim.fn.win_screenpos(0)[2] + vim.api.nvim_win_get_width(0)]])
  end
  local before = right_edge()
  local left_before = left_width()
  child.type_keys('<C-w>', '>')
  eq(right_edge(), before + 1)
  child.type_keys('<C-w>', '<')
  eq(right_edge(), before)
  eq(left_width(), left_before)
end

T['width resize honors a count'] = function()
  split_side_by_side()
  child.cmd('wincmd l')
  child.type_keys('5', '<C-w>', '<')
  eq(left_width(), 45)
end

T['width resize is a no-op without a vertical split'] = function()
  local cols = child.lua_get([[vim.o.columns]])
  child.type_keys('<C-w>', '<')
  child.type_keys('<C-w>', '>')
  eq(child.lua_get([[vim.api.nvim_win_get_width(0)]]), cols)
end

T['space-w resizes through the same separator-arrow mapping'] = function()
  split_side_by_side()
  child.cmd('wincmd l')
  child.type_keys('<Space>', 'w', '<')
  eq(left_width(), 49)
end

T['cmdline Ctrl-N and Ctrl-P select from the auto-opened menu'] = function()
  child.type_keys(':', 'ech')
  eq(child.lua_get([[vim.fn.wildmenumode()]]), 1)
  eq(child.lua_get([[vim.fn.cmdcomplete_info().selected]]), -1)
  child.type_keys('<C-n>')
  local first = child.lua_get([[vim.fn.cmdcomplete_info().selected]])
  eq(first >= 0, true)
  eq(child.lua_get([[vim.fn.wildmenumode()]]), 1)
  child.type_keys('<C-n>')
  eq(child.lua_get([[vim.fn.cmdcomplete_info().selected]]) ~= first, true)
  child.type_keys('<C-p>')
  eq(child.lua_get([[vim.fn.cmdcomplete_info().selected]]), first)
  child.type_keys('<Esc>')
end

T['cmdline Ctrl-P can select backward from an unselected menu'] = function()
  child.type_keys(':', 'ech')
  eq(child.lua_get([[vim.fn.cmdcomplete_info().selected]]), -1)
  child.type_keys('<C-p>')
  eq(child.lua_get([[vim.fn.cmdcomplete_info().selected >= 0]]), true)
  eq(child.lua_get([[vim.fn.wildmenumode()]]), 1)
  child.type_keys('<Esc>')
end

T['cmdline arrows recall full history past the completion menu'] = function()
  child.type_keys(':', 'echo 42', '<CR>')
  eq(child.lua_get([[vim.fn.histget(':', -1)]]), 'echo 42')
  child.type_keys(':', 'ech')
  eq(child.lua_get([[vim.fn.wildmenumode()]]), 1)
  child.type_keys('<Up>')
  eq(child.lua_get([[vim.fn.getcmdline()]]), 'echo 42')
  child.type_keys('<Down>')
  eq(child.lua_get([[vim.fn.getcmdline()]]), 'ech')
  child.type_keys('<Esc>')
end

T['cmdline Ctrl-K deletes from the cursor through the right edge'] = function()
  child.type_keys(':', 'echo abc', '<C-a>', '<Right><Right><Right><Right>')
  eq(child.lua_get([[vim.fn.getcmdpos()]]), 5)
  child.type_keys('<C-k>')
  eq(child.lua_get([[vim.fn.getcmdline()]]), 'echo')
  child.type_keys('<Esc>')
end

T['cmdline ctrl-a/ctrl-e jump to start and end'] = function()
  -- typing pops the completion menu, so this also covers the
  -- dismiss-menu-first branch of both mappings
  child.type_keys(':', 'echo')
  child.type_keys('<C-a>')
  eq(child.lua_get([[vim.fn.getcmdpos()]]), 1)
  child.type_keys('<C-e>')
  eq(child.lua_get([[vim.fn.getcmdpos()]]), 5)
  eq(child.lua_get([[vim.fn.getcmdline()]]), 'echo')
  child.type_keys('<Esc>')
end

T['double Esc clears search highlights'] = function()
  child.lua([[
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'foo bar foo', 'baz' })
    vim.o.hlsearch = true
  ]])
  child.type_keys('/foo<CR>')
  eq(child.lua_get([[vim.v.hlsearch]]), 1)
  child.type_keys('<Esc><Esc>')
  eq(child.lua_get([[vim.v.hlsearch]]), 0)
end

T['marks survive: m is not remapped'] = function()
  eq(child.lua_get([[vim.fn.maparg('m', 'n')]]), '')
end

T['vim grammar survives: ge and native brackets stay stock'] = function()
  eq(child.lua_get([[vim.fn.maparg('ge', 'n')]]), '')
  -- ]b/[b buffer nav are neovim defaults the config must not clobber
  eq(child.lua_get([[vim.fn.maparg(']b', 'n') ~= '']]), true)
  eq(child.lua_get([[vim.fn.maparg('[b', 'n') ~= '']]), true)
end

T['space-space opens the everything picker, space-b keeps buffers'] = function()
  local desc = child.lua_get([[(function()
    local out = {}
    for _, spec in ipairs(require('config.keymaps').specs) do
      if spec[2] == '<Leader><Space>' then out.space = spec[4] end
      if spec[2] == '<Leader>b' then out.b = spec[4] end
    end
    return out
  end)()]])
  eq(desc.space, 'Open everything picker')
  eq(desc.b, 'Open buffer picker')
end

return T
