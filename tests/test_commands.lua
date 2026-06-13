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

T['config.commands is wired'] = function()
  local missing = child.lua_get([[(function()
    local names = { 'extract_help', 'help_text', 'docs', 'normalize', 'list', 'pick' }
    local commands, out = require('config.commands'), {}
    for _, name in ipairs(names) do
      if type(commands[name]) ~= 'function' then table.insert(out, name) end
    end
    return out
  end)()]])
  eq(missing, {})
end

T['the command palette reads its prompt from the shared standard'] = function()
  eq(
    child.lua_get([[(function()
      local last
      require('fzf-lua').fzf_exec = function(_, o) last = o end
      require('config.commands').pick()
      return last and last.prompt
    end)()]]),
    child.lua_get([[require('config.pickers').PROMPTS.command_palette]])
  )
end

T['extract_help takes the prose after an anchor-only line'] = function()
  local got = child.lua_get([[require('config.commands').extract_help({
    '                    *:restart*',
    ':restart [+cmd] [command]',
    'Restarts Nvim. See also |ZR|.',
    '',
    '',
    'A later paragraph that should not appear.',
  }, ':restart')]])
  eq(got, { ':restart [+cmd] [command]', 'Restarts Nvim. See also |ZR|.' })
end

T['extract_help skips stacked tag/error lines before the prose'] = function()
  local got = child.lua_get([[require('config.commands').extract_help({
    '                    *:w* *:write*',
    '                    *E502* *E503*',
    ':w[rite] [++opt]  Write the whole buffer.',
    '',
  }, ':write')]])
  eq(got, { ':w[rite] [++opt]  Write the whole buffer.' })
end

T['extract_help keeps content sharing the anchor line, strips the tags'] = function()
  local got = child.lua_get([[require('config.commands').extract_help({
    ':[N]sp[lit] [++opt]\t\t\t*:sp* *:split*',
    'Split current window in two.',
    '',
  }, ':split')]])
  eq(got, { ':[N]sp[lit] [++opt]', 'Split current window in two.' })
end

T['extract_help returns nil when the tag is absent'] = function()
  eq(child.lua_get([[require('config.commands').extract_help({ 'nothing here' }, ':nope') == nil]]), true)
end

T['extract_help stops at a section rule'] = function()
  local got = child.lua_get([[require('config.commands').extract_help({
    '                    *:restart*',
    ':restart',
    'Restarts Nvim.',
    '',
    '------------------------------------------------------------------------------',
    'A new section heading',
  }, ':restart')]])
  eq(got, { ':restart', 'Restarts Nvim.' })
end

T['docs resolves a real built-in command via :help'] = function()
  local found = child.lua_get([[(function()
    local lines = require('config.commands').docs('split', nil)
    return #lines > 0 and table.concat(lines, '\n'):lower():find('split') ~= nil
  end)()]])
  eq(found, true)
end

T['docs falls back to the definition, then to empty'] = function()
  local got = child.lua_get([[(function()
    local c = require('config.commands')
    return {
      def = c.docs('NoHelpTagCmdXyz', 'my definition'),
      blank = c.docs('NoHelpTagCmdXyz', nil),
    }
  end)()]])
  eq(got.def, { 'my definition' })
  eq(got.blank, {})
end

T['normalize keeps a defined command over a bare built-in of the same name'] = function()
  local got = child.lua_get([[(function()
    local recs = require('config.commands').normalize(
      { { Z = { definition = 'jump to dir' } } },
      { 'Z', 'edit' }
    )
    local out = {}
    for _, r in ipairs(recs) do out[#out + 1] = { r.cmd_name, r.definition or false } end
    return out
  end)()]])
  eq(got, { { 'Z', 'jump to dir' }, { 'edit', false } })
end

T['list picks up registered user commands'] = function()
  local found = child.lua_get([[(function()
    vim.api.nvim_create_user_command('CommandsProbe', function() end, {})
    for _, r in ipairs(require('config.commands').list()) do
      if r.cmd_name == 'CommandsProbe' then return true end
    end
    return false
  end)()]])
  eq(found, true)
end

return T
