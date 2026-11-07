local child = MiniTest.new_child_neovim()
local eq = MiniTest.expect.equality

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      child.restart({ '-u', 'init.lua' })
    end,
    post_once = child.stop,
  },
})

T['editor surfaces match the Emacs palette after a real boot'] = function()
  local result = child.lua_get([[(function()
    local function hl(name)
      return vim.api.nvim_get_hl(0, { name = name, link = false })
    end
    return {
      rgb = vim.o.termguicolors,
      normal = hl('Normal'),
      comment = { fg = hl('Comment').fg, italic = hl('Comment').italic },
      selection = hl('Visual').bg,
      current_search = hl('CurSearch').bg,
      popup = hl('Pmenu').bg,
      line = hl('CursorLine').bg,
    }
  end)()]])
  eq(result, {
    rgb = true,
    normal = { fg = 0xd6d6dd, bg = 0x181818 },
    comment = { fg = 0x6d6d6d, italic = true },
    selection = 0x163761,
    current_search = 0x163764,
    popup = 0x1d1d1d,
    line = 0x181818,
  })
end

T['real Lua captures distinguish declarations, calls, properties and literals'] = function()
  child.lua([[
    vim.api.nvim_buf_set_lines(0, 0, -1, false, {
      'local function greet(person)',
      '  return "hi " .. person.name .. 42',
      'end',
      'greet({ name = "Ada" })',
      'print("done")',
      '-- a comment',
    })
    vim.bo.filetype = 'lua'
    vim.treesitter.start()
    vim.treesitter.get_parser():parse()
  ]])
  local samples = {
    { 0, 0, 'keyword', 0x83d6c5 },
    { 0, 15, 'function', 0xefb080 },
    { 1, 10, 'string', 0xe394dc },
    { 1, 25, 'variable.member', 0xaa9bf5 },
    { 1, 33, 'number', 0xebc88d },
    { 3, 0, 'function.call', 0xebc88d },
    { 4, 0, 'function.builtin', 0x82d2ce },
    { 5, 3, 'comment', 0x6d6d6d },
  }
  for _, sample in ipairs(samples) do
    local captures = child.lua_get(([[vim.treesitter.get_captures_at_pos(0, %d, %d)]]):format(
      sample[1], sample[2]
    ))
    local found = false
    for _, capture in ipairs(captures) do
      if capture.capture == sample[3] then found = true end
    end
    eq(found, true, sample[3] .. ' capture missing')
    eq(child.lua_get(([[vim.api.nvim_get_hl(0, { name = '@%s.lua', link = false }).fg]]):format(
      sample[3]
    )), sample[4], sample[3])
  end
end

T['semantic function modifiers retain the declaration and call distinction'] = function()
  for _, kind in ipairs({ 'function', 'method' }) do
    local colors = child.lua_get(([[vim.tbl_map(function(name)
      return vim.api.nvim_get_hl(0, { name = name, link = false }).fg
    end, {
      '@lsp.type.%s',
      '@lsp.typemod.%s.declaration',
      '@lsp.typemod.%s.definition',
      '@lsp.typemod.%s.defaultLibrary',
    })]]):format(kind, kind, kind, kind))
    eq(colors, { 0xebc88d, 0xefb080, 0xefb080, 0x82d2ce })
  end
end

T['switching away and back restores integrations and terminal background'] = function()
  child.lua([[
    vim.cmd.colorscheme('oshen-day')
    vim.cmd.colorscheme('anysphere')
  ]])
  local result = child.lua_get([[(function()
    local function hl(name)
      return vim.api.nvim_get_hl(0, { name = name, link = false })
    end
    return {
      name = vim.g.colors_name,
      background = vim.o.background,
      terminal_background = require('config.termbg').background(),
      ansi_background = vim.g.terminal_color_0,
      picker = hl('FzfLuaFzfNormal').bg,
      tree = hl('NvimTreeNormal').bg,
      tree_changed = hl('NvimTreeGitDirtyIcon').fg,
      mode_badge = hl('StatuslineModeNormal').bg,
      add = hl('MiniDiffOverAdd').bg,
      delete = hl('MiniDiffOverDelete').bg,
      diagnostic = hl('DiagnosticVirtualTextError').fg,
      underline = hl('DiagnosticUnderlineError').sp,
    }
  end)()]])
  eq(result, {
    name = 'anysphere',
    background = 'dark',
    terminal_background = 0x181818,
    ansi_background = '#181818',
    picker = 0x1d1d1d,
    tree = 0x181818,
    tree_changed = 0xe5b95c,
    mode_badge = 0xefb080,
    add = 0x25302e,
    delete = 0x331f1f,
    diagnostic = 0xf14c4c,
    underline = 0xf14c4c,
  })
end

T['colorscheme loads on its own without plugin setup'] = function()
  child.restart({ '-u', 'NONE' })
  child.lua([[
    vim.opt.runtimepath:prepend(vim.fn.getcwd())
    vim.o.background = 'light'
    vim.cmd.colorscheme('anysphere')
  ]])
  eq(child.lua_get([[vim.g.colors_name]]), 'anysphere')
  eq(child.lua_get([[vim.o.background]]), 'dark')
  eq(child.lua_get([[vim.api.nvim_get_hl(0, { name = 'Normal' }).bg]]), 0x181818)
end

return T
