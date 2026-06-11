local bc = require('config.breadcrumbs')

local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set()

local eq = MiniTest.expect.equality

T['build'] = MiniTest.new_set()

T['build']['joins scopes with the separator'] = function()
  eq(bc.build({}), '')
  eq(bc.build({ 'alpha' }), 'alpha')
  eq(bc.build({ 'config', 'render' }), 'config › render')
end

T['is_scope'] = MiniTest.new_set()

T['is_scope']['accepts declarations, rejects calls'] = function()
  eq(bc.is_scope('function_declaration'), true)
  eq(bc.is_scope('method_declaration'), true)
  eq(bc.is_scope('type_spec'), true)
  eq(bc.is_scope('class_definition'), true)
  eq(bc.is_scope('function_call'), false)
  eq(bc.is_scope('call_expression'), false)
  eq(bc.is_scope('identifier'), false)
end

T['in a live instance'] = MiniTest.new_set({
  hooks = {
    pre_case = function()
      child.restart({ '-u', 'init.lua' })
    end,
    post_once = child.stop,
  },
})

T['in a live instance']['names the enclosing go function'] = function()
  local has_go = child.lua_get(
    [[(function()
      local ok, added = pcall(vim.treesitter.language.add, 'go')
      return ok and added == true
    end)()]]
  )
  if not has_go then
    MiniTest.skip('go parser not installed')
  end
  child.lua([[vim.api.nvim_buf_set_lines(0, 0, -1, false,
    { 'package main', '', 'func alpha(count int) {', '\tprintln(count)', '}' })
    vim.bo.filetype = 'go'
    vim.api.nvim_win_set_cursor(0, { 4, 2 })]])
  eq(child.lua_get([[require('config.breadcrumbs').scope_names()]]), { 'alpha' })
  -- through the real statusline machinery: trail joins the center segment
  local statusline = child.lua_get(
    [[vim.api.nvim_eval_statusline(vim.o.statusline, {}).str]]
  )
  eq(statusline:find('› alpha', 1, true) ~= nil, true)
end

T['in a live instance']['excludes lua calls from the trail'] = function()
  local has_lua = child.lua_get(
    [[(function()
      local ok, added = pcall(vim.treesitter.language.add, 'lua')
      return ok and added == true
    end)()]]
  )
  if not has_lua then
    MiniTest.skip('lua parser not installed')
  end
  child.lua([[vim.cmd.enew()
    vim.api.nvim_buf_set_lines(0, 0, -1, false,
      { 'local function greet(name)', "  print(name)", 'end' })
    vim.bo.filetype = 'lua'
    vim.api.nvim_win_set_cursor(0, { 2, 4 })]])
  eq(child.lua_get([[require('config.breadcrumbs').scope_names()]]), { 'greet' })
end

T['in a live instance']['no winbar is set — the trail lives in the statusline'] = function()
  child.lua([[vim.cmd.enew() vim.bo.filetype = 'go']])
  eq(child.lua_get([[vim.wo.winbar]]), '')
end

return T
