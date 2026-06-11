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

T['exactly the nine agreed plugins are active'] = function()
  local names = child.lua_get([[(function()
    local out = {}
    for _, p in ipairs(vim.pack.get()) do
      if p.active then table.insert(out, p.spec.name) end
    end
    table.sort(out)
    return out
  end)()]])
  eq(names, {
    'fzf-lua', 'melange-nvim', 'mini.nvim', 'nvim-treesitter',
    'nvim-treesitter-context', 'nvim-treesitter-textobjects', 'rose-pine',
    'vim-repeat', 'vim-surround',
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
  eq(vim.tbl_contains(patterns, 'typescript'), true)
  eq(vim.tbl_contains(patterns, 'python'), true)
  eq(vim.tbl_contains(patterns, 'lua'), true)
end

T['mini modules are set up: clue, pairs, diff, jump2d'] = function()
  eq(child.lua_get([[type(_G.MiniClue)]]), 'table')
  eq(child.lua_get([[type(_G.MiniPairs)]]), 'table')
  eq(child.lua_get([[type(_G.MiniDiff)]]), 'table')
  eq(child.lua_get([[type(_G.MiniJump2d)]]), 'table')
end

T['fzf-lua backs vim.ui.select (code actions et al.)'] = function()
  eq(
    child.lua_get([[require('fzf-lua.providers.ui_select').is_registered()]]),
    true
  )
end

T['the infobox window fits clue descriptions'] = function()
  eq(child.lua_get([[MiniClue.config.window.config.width]]), 'auto')
  eq(child.lua_get([[MiniClue.config.window.delay]]), 250)
end

T['jump labels use the colemak alphabet'] = function()
  eq(
    child.lua_get([[MiniJump2d.config.labels]]),
    'arstgmneiodhfuclpwyvk'
  )
end

T['hunk navigation uses helix keys'] = function()
  eq(child.lua_get([[vim.fn.maparg(']g', 'n') ~= '']]), true)
  eq(child.lua_get([[vim.fn.maparg('[g', 'n') ~= '']]), true)
end

T['the colorscheme is melange'] = function()
  eq(child.lua_get([[vim.g.colors_name]]), 'melange')
end

T['theme plugins provide loadable colorschemes'] = function()
  for _, name in ipairs({ 'rose-pine', 'melange' }) do
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
