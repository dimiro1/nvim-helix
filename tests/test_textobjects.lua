local child = MiniTest.new_child_neovim()

local go_sample = {
  'package main',
  '',
  'func alpha(count int) {',
  '\tx := count',
  '\t_ = x',
  '}',
  '',
  'func beta() {',
  '}',
}

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      child.restart({ '-u', 'init.lua' })
      -- language.add returns nil (no error) when the parser is missing,
      -- so check the return value, not just pcall success
      local has_go_parser = child.lua_get(
        [[(function()
          local ok, added = pcall(vim.treesitter.language.add, 'go')
          return ok and added == true
        end)()]]
      )
      if not has_go_parser then
        MiniTest.skip('go parser not installed')
      end
      child.lua(
        [[vim.api.nvim_buf_set_lines(0, 0, -1, false, ...) vim.bo.filetype = 'go']],
        { go_sample }
      )
      child.lua([[vim.api.nvim_win_set_cursor(0, { 1, 0 })]])
    end,
    post_once = child.stop,
  },
})

local eq = MiniTest.expect.equality

T[']f jumps between function starts like helix'] = function()
  child.type_keys(']f')
  eq(child.lua_get([[vim.api.nvim_win_get_cursor(0)]])[1], 3)
  child.type_keys(']f')
  eq(child.lua_get([[vim.api.nvim_win_get_cursor(0)]])[1], 8)
  child.type_keys('[f')
  eq(child.lua_get([[vim.api.nvim_win_get_cursor(0)]])[1], 3)
end

T['vif selects a function body'] = function()
  child.lua([[vim.api.nvim_win_set_cursor(0, { 4, 2 })]])
  child.type_keys('vif', 'y')
  local yanked = child.lua_get([[vim.fn.getreg('"')]])
  eq(yanked:find('x := count', 1, true) ~= nil, true)
  eq(yanked:find('func', 1, true), nil)
end

T['vaf selects the whole function'] = function()
  child.lua([[vim.api.nvim_win_set_cursor(0, { 4, 2 })]])
  child.type_keys('vaf', 'y')
  local yanked = child.lua_get([[vim.fn.getreg('"')]])
  eq(yanked:find('func alpha(count int)', 1, true) ~= nil, true)
end

T['via selects an argument'] = function()
  child.lua([[vim.api.nvim_win_set_cursor(0, { 3, 12 })]])
  child.type_keys('via', 'y')
  eq(child.lua_get([[vim.fn.getreg('"')]]), 'count int')
end

T['vif works in lua buffers too'] = function()
  local has_lua_parser = child.lua_get(
    [[(function()
      local ok, added = pcall(vim.treesitter.language.add, 'lua')
      return ok and added == true
    end)()]]
  )
  if not has_lua_parser then
    MiniTest.skip('lua parser not installed')
  end
  child.lua([[vim.cmd.enew()
    vim.api.nvim_buf_set_lines(0, 0, -1, false,
      { 'local function greet(name)', '  return name', 'end' })
    vim.bo.filetype = 'lua']])
  child.lua([[vim.api.nvim_win_set_cursor(0, { 2, 4 })]])
  child.type_keys('vif', 'y')
  local yanked = child.lua_get([[vim.fn.getreg('"')]])
  eq(yanked:find('return name', 1, true) ~= nil, true)
  eq(yanked:find('function', 1, true), nil)
end

return T
