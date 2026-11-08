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

T['exactly the configured plugins are active'] = function()
  local names = child.lua_get([[(function()
    local out = {}
    for _, p in ipairs(vim.pack.get()) do
      if p.active then table.insert(out, p.spec.name) end
    end
    table.sort(out)
    return out
  end)()]])
  eq(names, {
    'Oshen.nvim', 'flash.nvim', 'fzf-lua', 'melange-nvim', 'mini.nvim',
    'nvim-tree.lua',
    'nvim-treesitter', 'nvim-treesitter-context',
    'nvim-treesitter-textobjects', 'rose-pine', 'vim-fugitive', 'vim-repeat', 'vim-surround',
  })
end

T['treesitter-context is set up'] = function()
  local commands = child.lua_get([[(function()
    local out = {}
    for name in pairs(vim.api.nvim_get_commands({})) do
      if vim.startswith(name, 'TSContext') then table.insert(out, name) end
    end
    return out
  end)()]])
  eq(#commands > 0, true)
end

T['treesitter branches are pinned to main'] = function()
  local versions = child.lua_get([[(function()
    local out = {}
    for _, p in ipairs(vim.pack.get()) do
      out[p.spec.name] = p.spec.version
    end
    return { ts = out['nvim-treesitter'], txo = out['nvim-treesitter-textobjects'] }
  end)()]])
  eq(versions, { ts = 'main', txo = 'main' })
end

T['installed parsers are discoverable in a clean child'] = function()
  -- regression: children boot --clean, which drops data/site from rtp;
  -- init.lua must re-add it or no parser (and no highlighting) loads
  eq(child.lua_get([[vim.treesitter.language.add('go') == true]]), true)
end

T['treesitter highlighting starts for configured filetypes'] = function()
  local patterns = child.lua_get([[vim.tbl_map(
    function(a) return a.pattern end,
    vim.api.nvim_get_autocmds({ group = 'config.treesitter', event = 'FileType' })
  )]])
  eq(#patterns > 0, true)
  eq(vim.tbl_contains(patterns, 'go'), true)
  eq(vim.tbl_contains(patterns, 'java'), true)
  eq(vim.tbl_contains(patterns, 'typescript'), true)
  eq(vim.tbl_contains(patterns, 'python'), true)
  eq(vim.tbl_contains(patterns, 'lua'), true)
end

T['every highlighted filetype has a parser queued for install'] = function()
  -- a filetype in the start autocmd but missing from the install list would
  -- silently fall back to legacy syntax; pin both lists name java together
  local parsers = child.lua_get([[require('config.plugins').parsers]])
  local filetypes = child.lua_get([[require('config.plugins').treesitter_filetypes]])
  for _, lang in ipairs({ 'go', 'java', 'typescript', 'python', 'lua' }) do
    eq(vim.tbl_contains(parsers, lang), true, lang)
    eq(vim.tbl_contains(filetypes, lang), true, lang)
  end
end

T['mini.clue, mini.pairs, mini.diff, mini.ai, mini.indentscope are set up'] = function()
  eq(child.lua_get([[type(_G.MiniClue)]]), 'table')
  eq(child.lua_get([[type(_G.MiniPairs)]]), 'table')
  eq(child.lua_get([[type(_G.MiniDiff)]]), 'table')
  eq(child.lua_get([[type(_G.MiniAi)]]), 'table')
  eq(child.lua_get([[type(_G.MiniIndentscope)]]), 'table')
  -- jumping moved to flash.nvim, so mini.jump2d is deliberately not set up
  eq(child.lua_get([[_G.MiniJump2d == nil]]), true)
end

T['flash.nvim is set up with the colemak labels and grammar modes off'] = function()
  eq(child.lua_get([[type(require('flash').jump)]]), 'function')
  -- colemak home row plus a few easy neighbours
  eq(child.lua_get([[require('flash.config').labels]]), 'arstneiodhgm')
  -- no uppercase labels: excess matches must not spill into shift-typed letters
  eq(child.lua_get([[require('flash.config').label.uppercase]]), false)
  -- char (f/t/F/T) and search (/) integrations stay off: Vim owns that grammar
  eq(child.lua_get([[require('flash.config').modes.char.enabled]]), false)
  eq(child.lua_get([[require('flash.config').modes.search.enabled]]), false)
end

T['the indent scope guide is the dotted vertical, drawn without animation'] = function()
  eq(child.lua_get([[MiniIndentscope.config.symbol]]), '┊')
  -- gen_animation.none yields a function that always returns 0ms wait, so
  -- the scope line appears instantly rather than easing into view
  eq(child.lua_get([[type(MiniIndentscope.config.draw.animation)]]), 'function')
  eq(child.lua_get([[MiniIndentscope.config.draw.animation(1, 10)]]), 0)
end

T['mini.indentscope is visualization only: no scope mappings'] = function()
  -- the textobjects/motions stay disabled so native [i/]i keep their
  -- meaning and ii/ai never shadow the i/a grammar
  local shadowed = child.lua_get([[(function()
    local out = {}
    for _, lhs in ipairs({ '[i', ']i' }) do
      if vim.fn.maparg(lhs, 'n') ~= '' then table.insert(out, 'n ' .. lhs) end
    end
    for _, mode in ipairs({ 'x', 'o' }) do
      for _, lhs in ipairs({ 'ii', 'ai' }) do
        if vim.fn.maparg(lhs, mode) ~= '' then
          table.insert(out, mode .. ' ' .. lhs)
        end
      end
    end
    return out
  end)()]])
  eq(shadowed, {})
end

T['mini.ai leaves the i/a grammar unshadowed'] = function()
  -- module-wide remaps must stay disabled: only the explicit iq/aq/im/am
  -- keymaps go through mini.ai; everything else stays stock Vim
  local shadowed = child.lua_get([[(function()
    local out = {}
    for _, mode in ipairs({ 'x', 'o' }) do
      for _, lhs in ipairs({ 'i', 'a', 'il', 'al' }) do
        if vim.fn.maparg(lhs, mode) ~= '' then
          table.insert(out, mode .. ' ' .. lhs)
        end
      end
    end
    for _, lhs in ipairs({ 'g[', 'g]' }) do
      if vim.fn.maparg(lhs, 'n') ~= '' then table.insert(out, 'n ' .. lhs) end
    end
    return out
  end)()]])
  eq(shadowed, {})
end

T['neovim 0.12 node objects in/an survive: not replaced by mini.ai'] = function()
  -- in/an are core defaults (select child/parent node); mini.ai's
  -- inside_next/around_next would sit on the same keys if ever re-enabled
  for _, mode in ipairs({ 'x', 'o' }) do
    eq(
      child.lua_get(([[vim.fn.maparg('in', '%s', false, true).desc]]):format(mode)),
      'Select child (inner) node'
    )
    eq(
      child.lua_get(([[vim.fn.maparg('an', '%s', false, true).desc]]):format(mode)),
      'Select parent (outer) node'
    )
  end
end

T['the m textobject is the closest-surrounding-pair alternation'] = function()
  eq(child.lua_get([[MiniAi.config.custom_textobjects.m]]), {
    { '%b()', '%b[]', '%b{}', '%b""', "%b''", '%b``' },
    '^.().*().$',
  })
end

T['fzf-lua backs vim.ui.select (code actions et al.)'] = function()
  eq(
    child.lua_get([[require('fzf-lua.providers.ui_select').is_registered()]]),
    true
  )
end

T['fzf-lua pickers lead with the path tail (filename_first)'] = function()
  -- the global default must reach zoxide too: zoxide ships its own
  -- dirname_first default, which left-anchors and so truncates the leaf
  -- directory — the identifying part — on long paths
  local resolved = child.lua_get([[(function()
    local config = require('fzf-lua.config')
    local files = config.normalize_opts({}, 'files')
    local zoxide = config.normalize_opts({}, 'zoxide')
    return {
      files = files.formatter,
      zoxide = zoxide.formatter,
      files_fmt = files._fmt and type(files._fmt.to) == 'function',
      zoxide_fmt = zoxide._fmt and type(zoxide._fmt.to) == 'function',
    }
  end)()]])
  eq(resolved, {
    files = 'path.filename_first',
    zoxide = 'path.filename_first',
    files_fmt = true,
    zoxide_fmt = true,
  })
end

T['the path tail is rendered ahead of its parent'] = function()
  -- behavioral: the formatter must actually reorder so the long parent
  -- prefix (not the leaf) is what overflows and truncates
  local rendered = child.lua_get([[(function()
    local config = require('fzf-lua.config')
    local zoxide = config.normalize_opts({}, 'zoxide')
    local out = zoxide._fmt.to('/Users/me/DevPersonal/Saldo/competition', zoxide, {
      path = require('fzf-lua.path'),
      utils = require('fzf-lua.utils'),
    })
    -- strip the dir-part highlight's ansi escapes for a stable assertion
    return (out:gsub('\27%[[0-9;]*m', ''))
  end)()]])
  eq(rendered, 'competition\t/Users/me/DevPersonal/Saldo')
end

T['the infobox window fits clue descriptions'] = function()
  eq(child.lua_get([[MiniClue.config.window.config.width]]), 'auto')
  eq(child.lua_get([[MiniClue.config.window.delay]]), 250)
end

T['hunk navigation uses helix keys'] = function()
  eq(child.lua_get([[vim.fn.maparg(']g', 'n') ~= '']]), true)
  eq(child.lua_get([[vim.fn.maparg('[g', 'n') ~= '']]), true)
end

T['the colorscheme is anysphere (dark)'] = function()
  eq(child.lua_get([[vim.g.colors_name]]), 'anysphere')
  eq(child.lua_get([[vim.o.background]]), 'dark')
end

T['local and plugin themes provide loadable colorschemes'] = function()
  -- Oshen's night/day schemes only resolve once its setup has run at boot
  for _, name in ipairs({ 'anysphere', 'rose-pine', 'melange', 'oshen-night', 'oshen-day' }) do
    eq(
      child.lua_get(([[pcall(vim.cmd.colorscheme, '%s')]]):format(name)),
      true
    )
  end
end

T['surround is the tpope flavor'] = function()
  eq(child.lua_get([[vim.fn.maparg('ys', 'n') ~= '']]), true)
  eq(child.lua_get([[vim.fn.maparg('cs', 'n') ~= '']]), true)
  eq(child.lua_get([[vim.fn.maparg('ds', 'n') ~= '']]), true)
end

return T
