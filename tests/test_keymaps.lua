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

T['cmdline arrows stay on history while the completion menu is open'] = function()
  for _, lhs in ipairs({ '<Up>', '<Down>' }) do
    eq(child.lua_get(([[vim.fn.maparg('%s', 'c', false, true).expr]]):format(lhs)), 1, lhs)
  end
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
