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
    end,
    post_once = child.stop,
  },
})

local eq = MiniTest.expect.equality

-- Tree-sitter objects need a compiled parser; the pattern-based pair set
-- below must keep running even where parsers are missing, so the skip
-- lives in this nested set, not the file-level hooks.
T['tree-sitter'] = MiniTest.new_set({
  hooks = {
    pre_case = function()
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
  },
})

T['tree-sitter'][']f jumps between function starts like helix'] = function()
  child.type_keys(']f')
  eq(child.lua_get([[vim.api.nvim_win_get_cursor(0)]])[1], 3)
  child.type_keys(']f')
  eq(child.lua_get([[vim.api.nvim_win_get_cursor(0)]])[1], 8)
  child.type_keys('[f')
  eq(child.lua_get([[vim.api.nvim_win_get_cursor(0)]])[1], 3)
end

T['tree-sitter']['vif selects a function body'] = function()
  child.lua([[vim.api.nvim_win_set_cursor(0, { 4, 2 })]])
  child.type_keys('vif', 'y')
  local yanked = child.lua_get([[vim.fn.getreg('"')]])
  eq(yanked:find('x := count', 1, true) ~= nil, true)
  eq(yanked:find('func', 1, true), nil)
end

T['tree-sitter']['vaf selects the whole function'] = function()
  child.lua([[vim.api.nvim_win_set_cursor(0, { 4, 2 })]])
  child.type_keys('vaf', 'y')
  local yanked = child.lua_get([[vim.fn.getreg('"')]])
  eq(yanked:find('func alpha(count int)', 1, true) ~= nil, true)
end

T['tree-sitter']['via selects an argument'] = function()
  child.lua([[vim.api.nvim_win_set_cursor(0, { 3, 12 })]])
  child.type_keys('via', 'y')
  eq(child.lua_get([[vim.fn.getreg('"')]]), 'count int')
end

T['tree-sitter']['vif works in lua buffers too'] = function()
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

-- Pattern-based pair objects (mini.ai): q for quotes, m for the closest
-- surrounding pair. Plain buffers, no parser involved.
T['pairs'] = MiniTest.new_set()

local function set_line(line, col)
  child.lua([[vim.api.nvim_buf_set_lines(0, 0, -1, false, { ... })]], { line })
  child.lua(([[vim.api.nvim_win_set_cursor(0, { 1, %d })]]):format(col))
end

local function yanked()
  return child.lua_get([[vim.fn.getreg('"')]])
end

T['pairs']['viq selects inside double quotes'] = function()
  set_line('local s = "hello world"', 14)
  child.type_keys('viq', 'y')
  eq(yanked(), 'hello world')
end

T['pairs']['vaq includes the quote characters'] = function()
  set_line('local s = "hello world"', 14)
  child.type_keys('vaq', 'y')
  eq(yanked(), '"hello world"')
end

T['pairs']['viq picks the nearest quotes of any kind'] = function()
  set_line([[print("say 'hi' there")]], 12)
  child.type_keys('viq', 'y')
  eq(yanked(), 'hi')
end

T['pairs']['viq matches backticks too'] = function()
  set_line('msg := `raw text`', 8)
  child.type_keys('viq', 'y')
  eq(yanked(), 'raw text')
end

T['pairs']['viq seeks forward when the cursor is before the quotes'] = function()
  set_line('local s = "hello"', 0)
  child.type_keys('viq', 'y')
  eq(yanked(), 'hello')
end

T['pairs']['diq works from operator-pending mode'] = function()
  set_line('local s = "hello world"', 14)
  child.type_keys('diq')
  eq(child.lua_get([[vim.api.nvim_get_current_line()]]), 'local s = ""')
end

T['pairs']['ciq deletes the quote body and enters insert'] = function()
  set_line('local s = "hello world"', 14)
  child.type_keys('ciq')
  eq(child.lua_get([[vim.api.nvim_get_current_line()]]), 'local s = ""')
  eq(child.lua_get([[vim.fn.mode()]]), 'i')
end

T['pairs']['vim selects inside the closest surrounding pair'] = function()
  set_line('foo(bar[baz])', 9)
  child.type_keys('vim', 'y')
  eq(yanked(), 'baz')
end

T['pairs']['vam includes the pair characters'] = function()
  set_line('foo(bar[baz])', 9)
  child.type_keys('vam', 'y')
  eq(yanked(), '[baz]')
end

T['pairs']['m treats quotes as pairs like helix mm-family'] = function()
  set_line('foo("baz")', 6)
  child.type_keys('vim', 'y')
  eq(yanked(), 'baz')
end

T['pairs']['dam works from operator-pending mode'] = function()
  set_line('foo(bar[baz])', 9)
  child.type_keys('dam')
  eq(child.lua_get([[vim.api.nvim_get_current_line()]]), 'foo(bar)')
end

return T
