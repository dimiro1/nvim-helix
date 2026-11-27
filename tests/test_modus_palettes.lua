local eq = MiniTest.expect.equality
local gen = dofile('scripts/modus_palettes.lua')

local T = MiniTest.new_set()

T['reader'] = MiniTest.new_set()

T['reader']['reads lists, symbols, strings, and quotes'] = function()
  eq(gen.read_all([[(a "b \"c\"" '(d e)) `f]]), {
    { { sym = 'a' }, { str = 'b "c"' }, { { sym = 'quote' }, { { sym = 'd' }, { sym = 'e' } } } },
    { { sym = 'quote' }, { sym = 'f' } },
  })
end

T['reader']['skips comments and character literals without derailing'] = function()
  eq(gen.read_all('(a ?\\( ?) ; (not a form\n b) ;; tail'), {
    { { sym = 'a' }, { sym = '?char' }, { sym = '?char' }, { sym = 'b' } },
  })
end

T['reader']['finds defconst values among code it cannot evaluate'] = function()
  local consts = gen.defconsts([[
    (defun f () (mapc #'disable-theme [a b]) ,@x)
    (defconst p '((bg-main "#ffffff") (fg-main bg-main)) "Doc.")
    (defvar q 1)
  ]])
  eq(vim.tbl_keys(consts), { 'p' })
  eq(gen.evaluate(consts.p, {}), {
    { 'bg-main', { hex = '#ffffff' } },
    { 'fg-main', { ref = 'bg-main' } },
  })
end

T['color math'] = MiniTest.new_set()

-- Each pair was computed by Emacs 31's color.el (rgb-to-hsl,
-- lighten-hsl, hsl-to-rgb, rgb-to-hex) and truncated as upstream does.
T['color math']['adjust matches Emacs color.el'] = function()
  for _, case in ipairs({
    { '#ff6f60', -5, '#ff5f4e' },
    { '#44cc44', 10, '#57d157' },
    { '#000000', 5, '#0c0c0c' },
    { '#242424', 20, '#505050' },
    { '#242424', 5, '#2f2f2f' },
    { '#ededed', -8, '#dadada' },
    { '#eedd82', -60, '#827011' },
    { '#8ac6f2', 40, '#b9ddf8' },
  }) do
    eq(gen.adjust(case[1], case[2]), case[3], case[1] .. ' ' .. case[2])
  end
end

T['color math']['blend mixes linearly and truncates like upstream'] = function()
  -- standard-wombat's fg-alt: a dimmed fg-main pulled toward red
  eq(gen.blend(gen.adjust('#f6f3e8', -10), '#ff0000', 0.8), '#eeb49f')
  eq(gen.blend('#ffffff', '#000000', 0.5), '#7f7f7f')
  eq(gen.blend('#123456', '#abcdef', 1), '#123456')
end

T['color math']['dark and warm follow upstream predicates'] = function()
  eq({ gen.dark('#000000'), gen.dark('#182440'), gen.dark('#ffffff'), gen.dark('#eeecd9') },
    { true, true, false, false })
  eq({ gen.warm('#eeecd9'), gen.warm('#182440'), gen.warm('#808080') }, { true, false, false })
end

T['generate'] = MiniTest.new_set()

local function by_name(entries)
  local out = {}
  for _, e in ipairs(entries) do
    out[e[1]] = out[e[1]] or e[2]
  end
  return out
end

local core = {
  ['modus-themes-vivendi-palette'] = {
    { 'bg-main', { hex = '#000000' } },
    { 'only-in-core', { hex = '#010203' } },
    { 'keyword', { ref = 'only-in-core' } },
  },
  ['modus-themes-vivendi-tinted-palette'] = { { 'tinted-core', { hex = '#0d0e1c' } } },
}

T['generate']['keeps given values and derives the rest'] = function()
  local base = {
    { 'bg-main', { hex = '#242424' } },
    { 'fg-main', { hex = '#f6f3e8' } },
    { 'bg-dim', { hex = '#111111' } },
    { 'green', { hex = '#95e454' } },
  }
  local palette = by_name(gen.generate(base, 'warm', 'modus-themes-vivendi-palette', {}, core))
  eq(palette['bg-dim'], { hex = '#111111' })
  eq(palette['fg-alt'], { hex = '#eeb49f' })
  eq(palette['bg-active'], { hex = gen.adjust('#242424', 10) })
  eq(palette['bg-green-subtle'], { hex = gen.adjust('#95e454', -60) })
  -- only the six hues given in the base get variants
  eq(palette['bg-red-subtle'], nil)
  -- warm preference picks the warm mappings
  eq(palette['bg-hl-line'], { ref = 'bg-yellow-nuanced' })
  -- the core fills what the base and derivations leave out
  eq(palette['only-in-core'], { hex = '#010203' })
  eq(palette['keyword'], { ref = 'only-in-core' })
end

T['generate']['explicit mappings win and colors precede mappings'] = function()
  local base = { { 'bg-main', { hex = '#000000' } }, { 'fg-main', { hex = '#ffffff' } } }
  local mappings = { { 'bg-hl-line', { ref = 'fg-main' } } }
  local entries = gen.generate(base, 'cool', 'modus-themes-vivendi-palette', mappings, core)
  eq(by_name(entries)['bg-hl-line'], { ref = 'fg-main' })
  local seen_ref = false
  for _, e in ipairs(entries) do
    if e[2].ref then
      seen_ref = true
    else
      eq(seen_ref, false, e[1] .. ' after a mapping')
    end
  end
end

T['generate']['infers the core from darkness and warmth'] = function()
  local base = { { 'bg-main', { hex = '#182440' } }, { 'fg-main', { hex = '#ffffff' } } }
  eq(by_name(gen.generate(base, nil, nil, {}, core))['tinted-core'], nil)
  -- a warm dark background falls back to the tinted dark core
  local warm = { { 'bg-main', { hex = '#402418' } }, { 'fg-main', { hex = '#ffffff' } } }
  eq(by_name(gen.generate(warm, nil, nil, {}, core))['tinted-core'], { hex = '#0d0e1c' })
end

T['evaluate'] = MiniTest.new_set()

T['evaluate']['handles quote, append, palette references, and generate calls'] = function()
  local env = {
    common = { { 'common', { hex = '#AABBCC' } } },
    ['modus-themes-vivendi-palette'] = {},
  }
  local form = gen.read_all([[
    (modus-themes-generate-palette
     '((bg-main "#000000") (fg-main "#ffffff"))
     'cool
     nil
     (append '((keyword common)) common))
  ]])[1]
  local palette = by_name(gen.evaluate(form, env))
  eq(palette['keyword'], { ref = 'common' })
  eq(palette['common'], { hex = '#AABBCC' })
  eq(palette['bg-hl-line'], { ref = 'bg-cyan-nuanced' })
end

T['resolve'] = MiniTest.new_set()

T['resolve']['follows references to lowercase hex; dead ends are false'] = function()
  eq(gen.resolve({
    { 'a', { hex = '#ABCDEF' } },
    { 'b', { ref = 'a' } },
    { 'c', { ref = 'b' } },
    { 'a', { hex = '#000000' } },
    { 'none', { ref = 'unspecified' } },
    { 'missing', { ref = 'nowhere' } },
    { 'loop', { ref = 'loop' } },
  }), {
    a = '#abcdef', b = '#abcdef', c = '#abcdef',
    none = false, missing = false, loop = false,
  })
end

T['render'] = MiniTest.new_set()

local function full_palette(color)
  local palette = { ['bg-main'] = color }
  for _, key in ipairs(gen.keys) do
    palette[key] = palette[key] or '#123456'
  end
  return palette
end

T['render']['emits a loadable table keyed in snake_case'] = function()
  local light = full_palette('#ffffff')
  light['fg-region'] = false
  local source = gen.render({ { 'x-light', light }, { 'x-dark', full_palette('#000000') } }, 'aaa', 'bbb')
  eq(source:match('^%-%- Generated by scripts/modus_palettes%.lua from modus%-themes aaa') ~= nil, true)
  local loaded = assert(loadstring(source))()
  eq(loaded['x-light'].background, 'light')
  eq(loaded['x-dark'].background, 'dark')
  eq(loaded['x-light'].bg_main, '#ffffff')
  eq(loaded['x-light'].fg_region, 'NONE')
  eq(loaded['x-light'].fg_term_white_bright, '#123456')
  eq(vim.tbl_count(loaded['x-light']), #gen.keys + 1)
end

T['render']['refuses a palette missing a key'] = function()
  local palette = full_palette('#000000')
  palette['keyword'] = nil
  local ok, err = pcall(gen.render, { { 'x', palette } }, 'a', 'b')
  eq(ok, false)
  eq(tostring(err):match('x: no palette entry keyword') ~= nil, true)
end

T['render']['emits exactly the entries the highlight builder reads'] = function()
  local modus = require('config.modus')
  local read = {}
  local proxy = setmetatable({}, {
    __index = function(_, key)
      read[key] = true
      return '#000000'
    end,
  })
  modus.highlights(proxy)
  modus.terminal(proxy)
  local expected = {}
  for _, key in ipairs(gen.keys) do
    expected[#expected + 1] = (key:gsub('-', '_'))
  end
  local got = vim.tbl_keys(read)
  table.sort(expected)
  table.sort(got)
  eq(got, expected)
end

T['main'] = MiniTest.new_set()

T['main']['leaves the output untouched when generation fails'] = function()
  local output = vim.fn.tempname()
  vim.fn.writefile({ 'previous' }, output)
  local ok = pcall(gen.main, { '/nonexistent/modus', '/nonexistent/standard', output })
  eq(ok, false)
  eq(vim.fn.readfile(output), { 'previous' })
end

T['main']['requires an output path'] = function()
  local ok, err = pcall(gen.main, { 'a', 'b' })
  eq(ok, false)
  eq(tostring(err):match('usage:') ~= nil, true)
end

return T
