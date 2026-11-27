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

T['Ctrl-o in a terminal goes to the program, not the jumplist'] = function()
  local got = child.lua_get([[(function()
    vim.cmd.edit(vim.fn.tempname())
    local file = vim.api.nvim_get_current_buf()
    vim.cmd.enew()
    vim.fn.jobstart({ 'cat' }, { term = true })
    local term = vim.api.nvim_get_current_buf()
    vim.cmd.stopinsert()
    vim.api.nvim_feedkeys(vim.keycode('<C-o>'), 'x', false)
    -- the tty echoes the control byte cat received as ^O
    local echoed = vim.wait(2000, function()
      return table.concat(vim.api.nvim_buf_get_lines(term, 0, -1, false), '\n'):find('^O', 1, true) ~= nil
    end)
    return {
      echoed = echoed,
      stayed = vim.api.nvim_get_current_buf() == term,
      left_file = vim.api.nvim_get_current_buf() ~= file,
    }
  end)()]])
  eq(got, { echoed = true, stayed = true, left_file = true })
  -- startinsert applies once the main loop resumes, after the call above
  eq(child.api.nvim_get_mode().mode, 't')
end

T['every terminal gets the Ctrl-o mapping, other buffers keep the jumplist'] = function()
  local got = child.lua_get([[(function()
    local function mapped()
      return vim.fn.maparg('<C-o>', 'n', false, true).buffer == 1
    end
    local out = {}
    vim.cmd.terminal()
    out.terminal = mapped()
    require('config.terminal').toggle()
    out.float = mapped()
    require('config.terminal').toggle()
    vim.cmd.enew()
    out.file = mapped()
    out.global = vim.fn.maparg('<C-o>', 'n') == ''
    return out
  end)()]])
  eq(got, { terminal = true, float = true, file = false, global = true })
end

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
