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

local themes = {
  'modus-operandi', 'modus-operandi-tinted', 'modus-operandi-deuteranopia',
  'modus-operandi-tritanopia', 'modus-vivendi', 'modus-vivendi-tinted',
  'modus-vivendi-deuteranopia', 'modus-vivendi-tritanopia',
  'standard-light', 'standard-light-tinted', 'standard-dark',
  'standard-dark-tinted', 'standard-adwaita', 'standard-wombat',
}

local function hex(color)
  return tonumber(color:sub(2), 16)
end

T['every upstream variant is a colorscheme with its palette'] = function()
  eq(child.lua_get([[require('config.modus').themes]]), themes)
  local names = child.lua_get([[(function()
    local names = vim.tbl_keys(require('config.modus').palettes)
    table.sort(names)
    return names
  end)()]])
  local sorted = vim.deepcopy(themes)
  table.sort(sorted)
  eq(names, sorted)
  for _, theme in ipairs(themes) do
    eq(#child.api.nvim_get_runtime_file('colors/' .. theme .. '.lua', false), 1, theme)
  end
end

T['each colorscheme paints its own canvas, background, and a flat gutter'] = function()
  for _, theme in ipairs(themes) do
    child.cmd('colorscheme ' .. theme)
    local result = child.lua_get([[(function()
      local p = require('config.modus').palettes[vim.g.colors_name]
      local normal = vim.api.nvim_get_hl(0, { name = 'Normal' })
      return {
        name = vim.g.colors_name,
        background = vim.o.background,
        expected_background = p.background,
        fg = normal.fg, bg = normal.bg,
        expected_fg = tonumber(p.fg_main:sub(2), 16),
        expected_bg = tonumber(p.bg_main:sub(2), 16),
        rgb = vim.o.termguicolors,
        flat_gutter = vim.api.nvim_get_hl(0, { name = 'SignColumn' }).bg == nil
          and vim.api.nvim_get_hl(0, { name = 'LineNr' }).bg == nil
          and vim.api.nvim_get_hl(0, { name = 'CursorLineNr' }).bg == nil,
      }
    end)()]])
    eq(result.name, theme)
    eq(result.background, result.expected_background, theme)
    eq({ result.fg, result.bg }, { result.expected_fg, result.expected_bg }, theme)
    eq(result.rgb, true)
    eq(result.flat_gutter, true, theme)
  end
end

T['palettes carry upstream values'] = function()
  local function pick(theme, keys)
    return child.lua_get(([[(function()
      local p = require('config.modus').palettes['%s']
      local out = {}
      for _, key in ipairs(%s) do out[key] = p[key] end
      return out
    end)()]]):format(theme, vim.inspect(keys)))
  end
  local keys = { 'bg_main', 'fg_main', 'keyword', 'string', 'comment', 'fnname' }
  eq(pick('modus-operandi', keys), {
    bg_main = '#ffffff', fg_main = '#000000', keyword = '#531ab6',
    string = '#3548cf', comment = '#595959', fnname = '#721045',
  })
  eq(pick('modus-vivendi', keys), {
    bg_main = '#000000', fg_main = '#ffffff', keyword = '#b6a0ff',
    string = '#79a8ff', comment = '#989898', fnname = '#feacd0',
  })
  -- the Standard themes keep Emacs's own default font-lock colors
  eq(pick('standard-light', keys), {
    bg_main = '#ffffff', fg_main = '#000000', keyword = '#800080',
    string = '#8b2252', comment = '#b22222', fnname = '#0000ff',
  })
  -- derived by modus-themes-generate-palette: bg-dim lightens bg-main
  -- (checked against Emacs's color.el); bg-completion darkens yellow
  eq(pick('standard-wombat', { 'bg_dim', 'bg_completion' }), {
    bg_dim = '#2f2f2f', bg_completion = '#6b4519',
  })
  -- entries upstream leaves unspecified stay transparent
  eq(pick('standard-light', { 'fg_region', 'bg_prose_code' }), {
    fg_region = 'NONE', bg_prose_code = 'NONE',
  })
end

T['the builder reads only palette entries every theme defines'] = function()
  local problems = child.lua_get([[(function()
    local modus = require('config.modus')
    local problems = {}
    for name, palette in pairs(modus.palettes) do
      local strict = setmetatable({}, {
        __index = function(_, key)
          local value = palette[key]
          if value == nil then
            table.insert(problems, name .. ': missing ' .. key)
          elseif not (value == 'NONE' or value:match('^#%x%x%x%x%x%x$')) then
            table.insert(problems, name .. ': bad ' .. key .. ' ' .. value)
          end
          return value
        end,
      })
      modus.highlights(strict)
      modus.terminal(strict)
    end
    return problems
  end)()]])
  eq(problems, {})
end

T['palette semantics land on the matching groups'] = function()
  child.cmd('colorscheme modus-operandi-tinted')
  local result = child.lua_get([[(function()
    local p = require('config.modus').palettes['modus-operandi-tinted']
    local function hl(name)
      return vim.api.nvim_get_hl(0, { name = name, link = false })
    end
    local function n(color) return tonumber(color:sub(2), 16) end
    return {
      comment = { hl('Comment').fg == n(p.comment), hl('Comment').italic },
      keyword = { hl('Keyword').fg == n(p.keyword), hl('Keyword').bold },
      visual = hl('Visual').bg == n(p.bg_region),
      search = hl('Search').bg == n(p.bg_search_lazy),
      current = hl('CurSearch').bg == n(p.bg_search_current),
      popup = hl('Pmenu').bg == n(p.bg_popup),
      selected = hl('PmenuSel').bg == n(p.bg_completion),
      bar = hl('StatusLine').bg == n(p.bg_mode_line_active),
      bar_inactive = hl('StatusLineNC').bg == n(p.bg_mode_line_inactive),
      current_number = { hl('CursorLineNr').fg == n(p.fg_line_number_active), hl('CursorLineNr').bold },
      add_sign = hl('MiniDiffSignAdd').fg == n(p.bg_added_fringe),
      diff_line = { hl('diffAdded').fg == n(p.fg_added), hl('diffAdded').bg == n(p.bg_added) },
      error = hl('DiagnosticError').fg == n(p.err),
      undercurl = hl('DiagnosticUnderlineWarn').sp == n(p.underline_warning),
      hint = hl('DiagnosticHint').fg == n(p.info),
      reference = { hl('LspReferenceText').underline, hl('LspReferenceText').sp == n(p.border) },
      key = hl('MiniClueNextKey').fg == n(p.keybind),
      heading = hl('@markup.heading.2').fg == n(p.fg_heading_2),
    }
  end)()]])
  eq(result, {
    -- upstream defaults: no italic or bold constructs
    comment = { true, nil },
    keyword = { true, nil },
    visual = true,
    search = true,
    current = true,
    popup = true,
    selected = true,
    bar = true,
    bar_inactive = true,
    current_number = { true, true },
    add_sign = true,
    diff_line = { true, true },
    error = true,
    undercurl = true,
    hint = true,
    reference = { true, true },
    key = true,
    heading = true,
  })
end

T['selections keep syntax colors and the gutter sits on the canvas'] = function()
  child.cmd('colorscheme standard-light')
  local p = child.lua_get([[require('config.modus').palettes['standard-light'] ]])
  local result = child.lua_get([[(function()
    local function hl(name)
      return vim.api.nvim_get_hl(0, { name = name, link = false })
    end
    return {
      visual_fg = hl('Visual').fg == nil,
      visual_bg = hl('Visual').bg,
      number_fg = hl('LineNr').fg,
      number_bg = hl('LineNr').bg == nil,
      current_bg = hl('CursorLineNr').bg == nil,
      signs_bg = hl('SignColumn').bg == nil,
      folds_bg = hl('FoldColumn').bg == nil,
    }
  end)()]])
  eq(result, {
    visual_fg = true,
    visual_bg = hex(p.bg_region),
    number_fg = hex(p.fg_line_number_inactive),
    number_bg = true,
    current_bg = true,
    signs_bg = true,
    folds_bg = true,
  })
end

T['real Lua captures follow the Modus code mappings'] = function()
  child.cmd('colorscheme modus-vivendi')
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
  local p = child.lua_get([[require('config.modus').palettes['modus-vivendi'] ]])
  local samples = {
    { 0, 0, 'keyword', p.keyword },
    { 0, 15, 'function', p.fnname },
    { 0, 21, 'variable.parameter', p.fg_main },
    { 1, 10, 'string', p.string },
    { 1, 25, 'variable.member', p.property },
    { 1, 33, 'number', p.number },
    { 3, 0, 'function.call', p.fnname_call },
    { 3, 6, 'constructor', p.bracket },
    { 4, 0, 'function.builtin', p.builtin },
    { 5, 3, 'comment', p.comment },
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
    )), hex(sample[4]), sample[3])
  end
end

T['semantic modifiers keep declarations distinct from uses'] = function()
  child.cmd('colorscheme modus-vivendi')
  local p = child.lua_get([[require('config.modus').palettes['modus-vivendi'] ]])
  local colors = child.lua_get([[vim.tbl_map(function(name)
    return vim.api.nvim_get_hl(0, { name = name, link = false }).fg
  end, {
    '@lsp.type.function',
    '@lsp.typemod.function.declaration',
    '@lsp.typemod.method.definition',
    '@lsp.typemod.function.defaultLibrary',
    '@lsp.type.variable',
    '@lsp.typemod.variable.declaration',
  })]])
  eq(colors, {
    hex(p.fnname_call), hex(p.fnname), hex(p.fnname), hex(p.builtin),
    hex(p.fg_main), hex(p.variable),
  })
end

T['switching between light and dark variants keeps the requested one'] = function()
  -- each step flips 'background', which would reload the previous scheme
  -- if it were still the active one
  for _, step in ipairs({
    { 'modus-vivendi', 'dark', 0x000000 },
    { 'modus-operandi', 'light', 0xffffff },
    { 'standard-dark-tinted', 'dark', 0x182440 },
    { 'standard-light-tinted', 'light', 0xeeecd9 },
    { 'anysphere', 'dark', 0x181818 },
    { 'modus-operandi-tinted', 'light', 0xfbf7f0 },
  }) do
    child.cmd('colorscheme ' .. step[1])
    eq(child.lua_get([[{
      vim.g.colors_name,
      vim.o.background,
      vim.api.nvim_get_hl(0, { name = 'Normal' }).bg,
    }]]), step, step[1])
  end
end

T['integrations repaint from the active variant'] = function()
  child.cmd('colorscheme standard-dark-tinted')
  local p = child.lua_get([[require('config.modus').palettes['standard-dark-tinted'] ]])
  local result = child.lua_get([[(function()
    local function hl(name)
      return vim.api.nvim_get_hl(0, { name = name, link = false })
    end
    return {
      terminal_background = require('config.termbg').background(),
      picker = hl('FzfLuaFzfNormal').bg,
      tree = hl('NvimTreeNormal').bg,
      mode_badge = hl('StatuslineModeNormal').bg,
      ansi = { vim.g.terminal_color_1, vim.g.terminal_color_15 },
    }
  end)()]])
  eq(result, {
    terminal_background = hex(p.bg_main),
    picker = hex(p.bg_popup),
    tree = hex(p.bg_main),
    mode_badge = hex(p.fnname),
    ansi = { p.fg_term_red, p.fg_term_white_bright },
  })
end

T['statusline diff counts stay legible on every Modus bar'] = function()
  -- WCAG AA for normal text; the gutter sign colors fell to 1.1:1 here
  local low = child.lua_get([[(function()
    local function luminance(color)
      local total = 0
      for i, weight in ipairs({ 0.2126, 0.7152, 0.0722 }) do
        local v = bit.band(bit.rshift(color, 8 * (3 - i)), 0xff) / 255
        v = v <= 0.03928 and v / 12.92 or ((v + 0.055) / 1.055) ^ 2.4
        total = total + weight * v
      end
      return total
    end
    local low = {}
    for _, theme in ipairs(require('config.modus').themes) do
      if theme:match('^modus') then
        vim.cmd.colorscheme(theme)
        for _, group in ipairs({ 'StatuslineDiffAdd', 'StatuslineDiffChange', 'StatuslineDiffDelete' }) do
          local hl = vim.api.nvim_get_hl(0, { name = group, link = false })
          local a, b = luminance(hl.fg), luminance(hl.bg)
          local ratio = (math.max(a, b) + 0.05) / (math.min(a, b) + 0.05)
          if ratio < 4.5 then
            table.insert(low, ('%s %s %.1f'):format(theme, group, ratio))
          end
        end
      end
    end
    return low
  end)()]])
  eq(low, {})
end

T['colorschemes load on their own without plugin setup'] = function()
  child.restart({ '-u', 'NONE' })
  child.lua([[
    vim.opt.runtimepath:prepend(vim.fn.getcwd())
    vim.o.background = 'dark'
    vim.cmd.colorscheme('modus-operandi')
  ]])
  eq(child.lua_get([[{ vim.g.colors_name, vim.o.background }]]), { 'modus-operandi', 'light' })
  eq(child.lua_get([[vim.api.nvim_get_hl(0, { name = 'Normal' }).bg]]), 0xffffff)
end

return T
