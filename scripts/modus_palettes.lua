-- Generate lua/config/modus_palettes.lua from the upstream Modus and
-- Standard theme sources. The Elisp is read as data and never executed;
-- the Standard palettes' derived entries are recomputed with a
-- transcription of modus-themes-generate-palette and Emacs's color.el.
--
--   nvim --clean -l scripts/modus_palettes.lua <modus-themes> <standard-themes> <output>
--
-- Loaded with dofile() it only returns the module, for the tests.
local M = {}

-- Reader ------------------------------------------------------------------
-- Forms: a symbol is { sym = name }, a string { str = value }, a list a
-- plain array. Only literal palette data needs to read correctly; the rest
-- of a file just has to tokenize without derailing.

local function tokenize(text)
  local tokens, i, n = {}, 1, #text
  while i <= n do
    local c = text:sub(i, i)
    if c:match('%s') then
      i = i + 1
    elseif c == ';' then
      i = (text:find('\n', i, true) or n) + 1
    elseif c == ',' and text:sub(i + 1, i + 1) == '@' then
      tokens[#tokens + 1] = ',@'
      i = i + 2
    elseif c:match("[()'`,]") then
      tokens[#tokens + 1] = c
      i = i + 1
    elseif c == '"' then
      local buf, j = {}, i + 1
      while text:sub(j, j) ~= '"' do
        if text:sub(j, j) == '\\' then
          j = j + 1
        end
        buf[#buf + 1] = text:sub(j, j)
        j = j + 1
      end
      tokens[#tokens + 1] = { str = table.concat(buf) }
      i = j + 1
    elseif c == '?' then
      -- character literal: ?x or ?\x
      local j = i + 1
      if text:sub(j, j) == '\\' then
        j = j + 1
      end
      tokens[#tokens + 1] = { sym = '?char' }
      i = j + 1
    else
      local j = i
      while j <= n and not text:sub(j, j):match('[%s()";\']') do
        if text:sub(j, j) == '\\' then
          j = j + 1
        end
        j = j + 1
      end
      tokens[#tokens + 1] = { sym = text:sub(i, j - 1) }
      i = j
    end
  end
  return tokens
end

local quotes = { ["'"] = true, ['`'] = true, [','] = true, [',@'] = true }

function M.read_all(text)
  local tokens, pos = tokenize(text), 1
  local function read()
    local t = tokens[pos]
    pos = pos + 1
    if t == '(' then
      local list = {}
      while tokens[pos] ~= ')' do
        list[#list + 1] = read()
      end
      pos = pos + 1
      return list
    end
    if quotes[t] then
      return { { sym = 'quote' }, read() }
    end
    return t
  end
  local forms = {}
  while pos <= #tokens do
    forms[#forms + 1] = read()
  end
  return forms
end

-- Symbol name of a read form, or nil for anything else.
local function sym(form)
  return type(form) == 'table' and form.sym or nil
end

-- name -> value form of every (defconst name value) in `text`.
function M.defconsts(text)
  local out = {}
  for _, form in ipairs(M.read_all(text)) do
    if type(form) == 'table' and sym(form[1]) == 'defconst' then
      out[sym(form[2])] = form[3]
    end
  end
  return out
end

-- ((name value) …) -> { { name, { hex = s } | { ref = name } }, … }
function M.entries(list)
  local out = {}
  for _, entry in ipairs(list) do
    local value = entry[2]
    out[#out + 1] = {
      sym(entry[1]),
      value.str and { hex = value.str } or { ref = sym(value) },
    }
  end
  return out
end

-- Color math (color.el, modus-themes.el) -------------------------------------

local function hex_to_rgb(hex)
  hex = hex:gsub('^#', '')
  if #hex == 3 then
    hex = hex:gsub('.', '%0%0')
  end
  local rgb = {}
  for i = 1, 5, 2 do
    rgb[#rgb + 1] = tonumber(hex:sub(i, i + 1), 16) * 257 / 65535
  end
  return rgb
end

local function rgb_to_hsl(r, g, b)
  local max, min = math.max(r, g, b), math.min(r, g, b)
  local delta = max - min
  local l = (max + min) / 2
  if delta == 0 then
    return 0, 0, l
  end
  local s = l <= 0.5 and delta / (max + min) or delta / (2 - max - min)
  local rc, gc, bc = (max - r) / delta, (max - g) / delta, (max - b) / delta
  local h
  if r == max then
    h = bc - gc
  elseif g == max then
    h = 2 + rc - bc
  else
    h = 4 + gc - rc
  end
  return math.fmod(h / 6, 1) % 1, s, l
end

local function hue_to_rgb(v1, v2, h)
  if h < 1 / 6 then
    return v1 + (v2 - v1) * h * 6
  elseif h < 0.5 then
    return v2
  elseif h < 2 / 3 then
    return v1 + (v2 - v1) * (2 / 3 - h) * 6
  end
  return v1
end

local function hsl_to_rgb(h, s, l)
  if s == 0 then
    return l, l, l
  end
  local m2 = l <= 0.5 and l * (1 + s) or (l + s) - (l * s)
  local m1 = 2 * l - m2
  return hue_to_rgb(m1, m2, (h + 1 / 3) % 1),
    hue_to_rgb(m1, m2, h),
    hue_to_rgb(m1, m2, (h - 1 / 3) % 1)
end

-- color-lighten-hsl: positive percentages close the gap to white,
-- negative ones scale toward black.
local function lighten_hsl(h, s, l, percent)
  local p = percent / 100
  if p > 0 then
    l = l * (1 - p)
  else
    p = -(l * math.abs(p))
  end
  return h, s, math.min(1, math.max(0, l + p))
end

-- (format "#%04x…" (* x 65535)) truncates, then upstream keeps the two
-- high digits of each component.
local function rgb_to_hex(r, g, b)
  local out = '#'
  for _, x in ipairs({ r, g, b }) do
    out = out .. ('%02x'):format(math.floor(math.floor(x * 65535) / 256))
  end
  return out
end

-- modus-themes-adjust-value
function M.adjust(color, percent)
  local h, s, l = rgb_to_hsl(unpack(hex_to_rgb(color)))
  return rgb_to_hex(hsl_to_rgb(lighten_hsl(h, s, l, percent)))
end

-- modus-themes-generate-color-blend
function M.blend(color, other, alpha)
  local a, b = hex_to_rgb(color), hex_to_rgb(other)
  local mixed = {}
  for i = 1, 3 do
    mixed[i] = a[i] * alpha + b[i] * (1 - alpha)
  end
  return rgb_to_hex(unpack(mixed))
end

local function warmer(color, alpha)
  return M.blend(color, '#ff0000', alpha)
end

local function cooler(color, alpha)
  return M.blend(color, '#0000ff', alpha)
end

local function luminance(color)
  local total = 0
  for i, weight in ipairs({ 0.2126, 0.7152, 0.0722 }) do
    local v = hex_to_rgb(color)[i]
    v = v <= 0.03928 and v / 12.92 or ((v + 0.055) / 1.055) ^ 2.4
    total = total + weight * v
  end
  return total
end

-- modus-themes-color-dark-p: more contrast against white than black.
function M.dark(color)
  local function contrast(a, b)
    local x = (luminance(a) + 0.05) / (luminance(b) + 0.05)
    return math.max(x, 1 / x)
  end
  return contrast(color, '#ffffff') > contrast(color, '#000000')
end

-- modus-themes-color-warm-p: more red than blue.
function M.warm(color)
  local rgb = hex_to_rgb(color)
  return rgb[1] > rgb[3]
end

-- modus-themes-generate-palette ---------------------------------------------

local hues = { 'red', 'green', 'yellow', 'blue', 'magenta', 'cyan' }

-- `base`/`mappings` are entry lists; `pref` is 'cool', 'warm' or nil;
-- `core` names a palette in `env` or is nil to infer one.
function M.generate(base, pref, core, mappings, env)
  local given, mapped = {}, {}
  for _, e in ipairs(base) do
    given[e[1]] = e[2]
  end
  for _, e in ipairs(mappings) do
    mapped[e[1]] = true
  end
  local bg, fg = given['bg-main'].hex, given['fg-main'].hex
  local dark = M.dark(bg)
  local cool
  if pref then
    cool = pref == 'cool'
  else
    cool = not M.warm(bg)
  end
  local function pick(yes, no) -- by darkness
    if dark then return yes end
    return no
  end
  local function choose(yes, no) -- by coolness
    if cool then return yes end
    return no
  end

  local derived, derived_mappings = {}, {}
  local function value(name, hex)
    if not given[name] then
      derived[#derived + 1] = { name, { hex = hex } }
    end
  end
  local function mapping(name, ref)
    if not mapped[name] then
      derived_mappings[#derived_mappings + 1] = { name, { ref = ref } }
    end
  end

  value('bg-dim', M.adjust(bg, pick(5, -5)))
  value('bg-active', M.adjust(bg, pick(10, -10)))
  value('bg-inactive', M.adjust(bg, pick(8, -8)))
  value('border', M.adjust(bg, pick(20, -20)))
  value('fg-dim', M.adjust(fg, pick(-20, 20)))
  local alt = M.adjust(fg, pick(-10, 10))
  value('fg-alt', cool and cooler(alt, 0.8) or warmer(alt, 0.8))
  for _, e in ipairs(base) do
    local name, hex = e[1], e[2].hex
    if vim.tbl_contains(hues, name) then
      value(name .. '-warmer', M.adjust(warmer(hex, 0.9), pick(20, -20)))
      value(name .. '-cooler', M.adjust(cooler(hex, 0.9), pick(20, -20)))
      value(name .. '-faint', M.adjust(hex, pick(10, -10)))
      value(name .. '-intense', M.adjust(hex, pick(-5, 5)))
      value('bg-' .. name .. '-intense', M.adjust(hex, pick(-40, 40)))
      value('bg-' .. name .. '-subtle', M.adjust(hex, pick(-60, 60)))
      value('bg-' .. name .. '-nuanced', M.adjust(hex, pick(-80, 80)))
    end
  end

  for _, m in ipairs({
    { 'bg-completion', choose('bg-cyan-subtle', 'bg-yellow-subtle') },
    { 'bg-hover', choose('bg-green-intense', 'bg-magenta-intense') },
    { 'bg-hover-secondary', choose('bg-green-subtle', 'bg-magenta-subtle') },
    { 'bg-hl-line', choose('bg-cyan-nuanced', 'bg-yellow-nuanced') },
    { 'bg-paren-match', choose('bg-green-intense', 'bg-yellow-subtle') },
    { 'bg-paren-expression', choose('bg-green-nuanced', 'bg-yellow-nuanced') },
    { 'bg-popup', 'bg-dim' }, { 'bg-region', 'bg-active' }, { 'fg-region', 'fg-main' },
    { 'bg-mode-line-active', 'bg-active' }, { 'fg-mode-line-active', 'fg-main' },
    { 'border-mode-line-active', 'border' }, { 'bg-mode-line-inactive', 'bg-inactive' },
    { 'fg-mode-line-inactive', 'fg-dim' }, { 'border-mode-line-inactive', 'border' },
    { 'modeline-err', 'red-faint' }, { 'modeline-warning', 'yellow-faint' },
    { 'modeline-info', 'blue-faint' },
    { 'bg-search-current', 'bg-yellow-subtle' }, { 'bg-search-lazy', 'bg-magenta-subtle' },
    { 'bg-search-replace', 'bg-red-subtle' }, { 'bg-search-rx-group-0', 'bg-blue-subtle' },
    { 'bg-search-rx-group-1', 'bg-green-subtle' }, { 'bg-search-rx-group-2', 'bg-red-subtle' },
    { 'bg-search-rx-group-3', 'bg-magenta-subtle' },
    { 'fg-search-current', 'yellow-warmer' }, { 'fg-search-lazy', 'magenta-cooler' },
    { 'fg-search-replace', 'red-cooler' }, { 'fg-search-rx-group-0', 'blue-warmer' },
    { 'fg-search-rx-group-1', 'green-warmer' }, { 'fg-search-rx-group-2', 'red-cooler' },
    { 'fg-search-rx-group-3', 'magenta-cooler' },
    { 'bg-prominent-err', 'unspecified' }, { 'bg-prominent-warning', 'unspecified' },
    { 'bg-prominent-note', 'unspecified' }, { 'fg-prominent-err', 'red-intense' },
    { 'fg-prominent-warning', 'yellow-intense' }, { 'fg-prominent-note', 'green-intense' },
    { 'bg-active-argument', choose('bg-cyan-subtle', 'bg-yellow-subtle') },
    { 'fg-active-argument', choose('cyan-cooler', 'yellow-warmer') },
    { 'bg-active-value', choose('bg-magenta-subtle', 'bg-blue-subtle') },
    { 'fg-active-value', choose('magenta-cooler', 'blue-warmer') },
    { 'bg-tab-bar', 'bg-dim' }, { 'bg-tab-current', 'bg-main' },
    { 'bg-tab-other', 'bg-inactive' }, { 'bg-diff-context', 'bg-dim' },
    { 'bg-added', 'bg-green-subtle' }, { 'bg-added-faint', 'bg-green-nuanced' },
    { 'bg-added-refine', 'bg-green-intense' }, { 'bg-added-fringe', 'green' },
    { 'fg-added', 'green-faint' }, { 'fg-added-intense', 'green-intense' },
    { 'bg-changed', 'bg-yellow-subtle' }, { 'bg-changed-faint', 'bg-yellow-nuanced' },
    { 'bg-changed-refine', 'bg-yellow-intense' }, { 'bg-changed-fringe', 'yellow' },
    { 'fg-changed', 'yellow-faint' }, { 'fg-changed-intense', 'yellow-intense' },
    { 'bg-removed', 'bg-red-subtle' }, { 'bg-removed-faint', 'bg-red-nuanced' },
    { 'bg-removed-refine', 'bg-red-intense' }, { 'bg-removed-fringe', 'red' },
    { 'fg-removed', 'red-faint' }, { 'fg-removed-intense', 'red-intense' },
    { 'fg-heading-0', 'fg-alt' }, { 'fg-heading-1', 'fg-main' },
    { 'fg-heading-2', choose('cyan', 'yellow') }, { 'fg-heading-3', choose('green', 'magenta') },
    { 'fg-heading-4', choose('blue', 'red') }, { 'fg-heading-5', choose('yellow', 'cyan') },
    { 'fg-heading-6', choose('magenta', 'green') }, { 'fg-heading-7', choose('red', 'blue') },
    { 'fg-heading-8', 'fg-dim' },
    { 'bg-term-black', pick('bg-main', 'fg-main') },
    { 'bg-term-black-bright', pick('bg-active', 'fg-dim') },
    { 'fg-term-black', pick('bg-main', 'fg-main') },
    { 'fg-term-black-bright', pick('bg-active', 'fg-dim') },
    { 'bg-term-white', pick('fg-dim', 'bg-active') },
    { 'bg-term-white-bright', pick('fg-main', 'bg-main') },
    { 'fg-term-white', pick('fg-dim', 'bg-active') },
    { 'fg-term-white-bright', pick('fg-main', 'bg-main') },
    { 'rust', 'red-faint' }, { 'gold', 'yellow-faint' }, { 'olive', 'green-faint' },
    { 'slate', 'cyan-faint' }, { 'indigo', 'blue-warmer' }, { 'maroon', 'magenta-warmer' },
    { 'pink', 'magenta-faint' },
    { 'bg-clay', 'bg-red-nuanced' }, { 'fg-clay', 'red-cooler' },
    { 'bg-ochre', 'bg-yellow-nuanced' }, { 'fg-ochre', 'yellow-cooler' },
    { 'bg-lavender', 'bg-magenta-nuanced' }, { 'fg-lavender', 'magenta-cooler' },
    { 'bg-sage', 'bg-green-nuanced' }, { 'fg-sage', 'green-cooler' },
  }) do
    mapping(m[1], m[2])
  end
  for _, hue in ipairs(hues) do
    for i, level in ipairs(dark and { 'intense', 'subtle' } or { 'subtle', 'intense' }) do
      mapping(('bg-graph-%s-%d'):format(hue, i - 1), ('bg-%s-%s'):format(hue, level))
    end
  end

  core = core or (dark
    and choose('modus-themes-vivendi-palette', 'modus-themes-vivendi-tinted-palette')
    or choose('modus-themes-operandi-palette', 'modus-themes-operandi-tinted-palette'))

  -- First entry per name wins; named colors precede mappings.
  local seen, colors, refs = {}, {}, {}
  for _, list in ipairs({ base, derived, mappings, derived_mappings, env[core] }) do
    for _, e in ipairs(list) do
      if not seen[e[1]] then
        seen[e[1]] = true
        table.insert(e[2].hex and colors or refs, e)
      end
    end
  end
  return vim.list_extend(colors, refs)
end

-- Evaluation ------------------------------------------------------------------

-- A 'symbol or nil argument -> its name, or nil.
local function symbol_arg(form)
  if form[1] and sym(form[1]) == 'quote' then
    form = form[2]
  end
  local name = sym(form)
  return name ~= 'nil' and name or nil
end

-- A palette-valued form -> entry list.
function M.evaluate(form, env)
  if form.sym then
    return (assert(env[form.sym], 'unknown palette ' .. form.sym))
  end
  local head = sym(form[1])
  if head == 'quote' then
    return M.entries(form[2])
  elseif head == 'append' then
    local out = {}
    for i = 2, #form do
      vim.list_extend(out, M.evaluate(form[i], env))
    end
    return out
  elseif head == 'modus-themes-generate-palette' then
    return M.generate(
      M.evaluate(form[2], env),
      symbol_arg(form[3]),
      form[4] and symbol_arg(form[4]),
      form[5] and M.evaluate(form[5], env) or {},
      env
    )
  end
  error('cannot evaluate ' .. tostring(head))
end

-- Entry list -> name -> lowercase hex, following references; unspecified
-- (or unresolvable) entries map to false.
function M.resolve(palette)
  local first = {}
  for _, e in ipairs(palette) do
    if first[e[1]] == nil then
      first[e[1]] = e[2]
    end
  end
  local function get(name, depth)
    local v = first[name]
    if v == nil or depth > 50 then
      return false
    elseif v.hex then
      return v.hex:lower()
    elseif v.ref == 'unspecified' then
      return false
    end
    return get(v.ref, depth + 1)
  end
  local out = {}
  for name in pairs(first) do
    out[name] = get(name, 0)
  end
  return out
end

-- Output ----------------------------------------------------------------------

-- Every palette entry the highlight builder reads; kebab-case upstream,
-- snake_case in Lua.
M.keys = {
  'bg-main', 'fg-main', 'bg-dim', 'fg-dim', 'bg-inactive',
  'border', 'cursor', 'bg-popup', 'bg-hl-line', 'bg-region', 'fg-region',
  'bg-hover', 'bg-hover-secondary', 'bg-completion', 'fg-completion-match-0',
  'fg-line-number-inactive', 'fg-line-number-active',
  'bg-mode-line-active', 'fg-mode-line-active',
  'bg-mode-line-inactive', 'fg-mode-line-inactive',
  'bg-tab-bar', 'bg-tab-current', 'bg-tab-other',
  'bg-search-current', 'fg-search-current', 'bg-search-lazy', 'fg-search-lazy',
  'bg-search-replace', 'fg-search-replace',
  'bg-paren-match', 'fg-paren-match', 'underline-paren-match',
  'fg-prompt', 'keybind', 'accent-0', 'accent-1', 'fg-space',
  'err', 'warning', 'info', 'underline-err', 'underline-warning', 'underline-note',
  'fg-link', 'underline-link',
  'comment', 'keyword', 'string', 'docstring', 'fnname', 'fnname-call', 'builtin',
  'constant', 'type', 'variable', 'property', 'number', 'operator', 'punctuation',
  'bracket', 'delimiter', 'preprocessor', 'rx-backslash',
  'bg-added', 'bg-added-refine', 'bg-added-fringe', 'fg-added',
  'bg-changed', 'bg-changed-refine', 'bg-changed-fringe', 'fg-changed',
  'bg-removed', 'bg-removed-refine', 'bg-removed-fringe', 'fg-removed',
  'fg-heading-1', 'fg-heading-2', 'fg-heading-3', 'fg-heading-4', 'fg-heading-5',
  'fg-heading-6', 'bg-prose-code', 'fg-prose-code', 'prose-done', 'prose-todo',
}
for _, bright in ipairs({ '', '-bright' }) do
  for _, color in ipairs({ 'black', 'red', 'green', 'yellow', 'blue', 'magenta', 'cyan', 'white' }) do
    M.keys[#M.keys + 1] = 'fg-term-' .. color .. bright
  end
end

M.modus = {
  'operandi', 'operandi-tinted', 'operandi-deuteranopia', 'operandi-tritanopia',
  'vivendi', 'vivendi-tinted', 'vivendi-deuteranopia', 'vivendi-tritanopia',
}
M.standard = { 'light', 'light-tinted', 'dark', 'dark-tinted', 'adwaita', 'wombat' }

local function read_file(path)
  local file = assert(io.open(path, 'r'))
  local text = file:read('*a')
  file:close()
  return text
end

-- Upstream checkouts -> { { theme name, resolved palette }, … } in
-- upstream's order.
function M.palettes(modus_dir, standard_dir)
  local env = {}
  local mt = M.defconsts(read_file(modus_dir .. '/modus-themes.el'))
  env['modus-themes-common-palette-mappings'] =
    M.evaluate(mt['modus-themes-common-palette-mappings'], env)
  for _, variant in ipairs(M.modus) do
    local name = 'modus-themes-' .. variant .. '-palette'
    env[name] = M.evaluate(mt[name], env)
  end
  local st = M.defconsts(read_file(standard_dir .. '/standard-themes.el'))
  env['standard-themes-common-palette-mappings'] =
    M.evaluate(st['standard-themes-common-palette-mappings'], env)

  local out = {}
  for _, variant in ipairs(M.modus) do
    out[#out + 1] = { 'modus-' .. variant, M.resolve(env['modus-themes-' .. variant .. '-palette']) }
  end
  for _, variant in ipairs(M.standard) do
    local consts = M.defconsts(read_file(('%s/standard-%s-theme.el'):format(standard_dir, variant)))
    local form = consts['standard-' .. variant .. '-palette']
    out[#out + 1] = { 'standard-' .. variant, M.resolve(M.evaluate(form, env)) }
  end
  return out
end

-- Palettes -> the Lua source of lua/config/modus_palettes.lua.
function M.render(palettes, modus_rev, standard_rev)
  local lines = {
    ('-- Generated by scripts/modus_palettes.lua from modus-themes %s and'):format(modus_rev),
    ("-- standard-themes %s; regenerate with `make palettes`, don't hand-edit."):format(standard_rev),
    '-- Copyright (C) 2019-2026 Free Software Foundation, Inc.; GPL-3.0-or-later, see',
    "-- docs/modus-LICENSE. 'NONE' marks entries upstream leaves unspecified.",
    'return {',
  }
  for _, theme in ipairs(palettes) do
    local name, palette = theme[1], theme[2]
    lines[#lines + 1] = ("  ['%s'] = {"):format(name)
    lines[#lines + 1] = ("    background = '%s',"):format(M.dark(palette['bg-main']) and 'dark' or 'light')
    for _, key in ipairs(M.keys) do
      local color = palette[key]
      if color == nil then
        error(('%s: no palette entry %s'):format(name, key))
      end
      lines[#lines + 1] = ("    %s = '%s',"):format((key:gsub('-', '_')), color or 'NONE')
    end
    lines[#lines + 1] = '  },'
  end
  lines[#lines + 1] = '}'
  return table.concat(lines, '\n') .. '\n'
end

local function revision(dir)
  local result = vim.system({ 'git', '-C', dir, 'rev-parse', '--short', 'HEAD' }):wait()
  assert(result.code == 0, result.stderr)
  return vim.trim(result.stdout)
end

-- Writes only after every palette rendered, so a failure leaves the
-- committed file intact.
function M.main(args)
  local modus_dir, standard_dir, output = args[1], args[2], args[3]
  assert(output, 'usage: nvim -l scripts/modus_palettes.lua <modus-themes> <standard-themes> <output>')
  local source = M.render(M.palettes(modus_dir, standard_dir), revision(modus_dir), revision(standard_dir))
  local file = assert(io.open(output, 'w'))
  file:write(source)
  file:close()
end

if _G.arg and _G.arg[0] and _G.arg[0]:match('modus_palettes%.lua$') then
  M.main(_G.arg)
end

return M
