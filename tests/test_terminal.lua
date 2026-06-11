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

T['toggle opens a floating terminal'] = function()
  child.lua([[require('config.terminal').toggle()]])
  local state = child.lua_get([[(function()
    local term = require('config.terminal')
    return {
      win_valid = vim.api.nvim_win_is_valid(term.state.win),
      floating = vim.api.nvim_win_get_config(term.state.win).relative == 'editor',
      buftype = vim.bo[term.state.buf].buftype,
    }
  end)()]])
  eq(state.win_valid, true)
  eq(state.floating, true)
  eq(state.buftype, 'terminal')
end

T['toggle closes and reopens the same terminal'] = function()
  local result = child.lua_get([[(function()
    local term = require('config.terminal')
    term.toggle()
    local first_buf = term.state.buf
    term.toggle()
    local closed = term.state.win == nil
    term.toggle()
    return { closed = closed, same_buf = term.state.buf == first_buf }
  end)()]])
  eq(result.closed, true)
  eq(result.same_buf, true)
end

return T
