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

T['the everything picker exposes its building blocks'] = function()
  local missing = child.lua_get([[(function()
    local names = {
      'pick', 'everything_opts', 'build_entries', 'record_of',
      'action_for', 'preview_for', 'open', 'list_buffers',
      'normalize_symbols', 'normalize_files',
    }
    local everything, out = require('config.everything'), {}
    for _, name in ipairs(names) do
      if type(everything[name]) ~= 'function' then table.insert(out, name) end
    end
    return out
  end)()]])
  eq(missing, {})
end

T['build_entries orders groups buffers, symbols, files, commands and tags each'] = function()
  local lines = child.lua_get([[require('config.everything').build_entries({
    buffers = { { kind = 'buffer', bufnr = 1, path = '/p/a.lua', name = 'a.lua' } },
    symbols = { { kind = 'symbol', bufnr = 1, name = 'Foo', line = 3, col = 0 } },
    files = { { kind = 'file', path = '/p/b.lua', name = 'b.lua' } },
    commands = { { kind = 'command', cmd_name = 'Z', name = 'Z' } },
  }).lines]])
  eq(lines, { '1\tbuf\ta.lua', '2\tsym\tFoo', '3\tfile\tb.lua', '4\tcmd\tZ' })
end

T['build_entries drops a file already open as a buffer (buffer wins)'] = function()
  local names = child.lua_get([[(function()
    local built = require('config.everything').build_entries({
      buffers = { { kind = 'buffer', bufnr = 1, path = '/p/open.lua', name = 'open.lua' } },
      files = {
        { kind = 'file', path = '/p/open.lua', name = 'open.lua' },
        { kind = 'file', path = '/p/other.lua', name = 'other.lua' },
      },
    })
    local out = {}
    for _, r in ipairs(built.records) do out[#out + 1] = r.kind .. ':' .. r.name end
    return out
  end)()]])
  eq(names, { 'buffer:open.lua', 'file:other.lua' })
end

T['record_of recovers the record an fzf line points at'] = function()
  local name = child.lua_get([[(function()
    local everything = require('config.everything')
    local built = everything.build_entries({ files = {
      { kind = 'file', path = '/p/x.lua', name = 'x.lua' },
      { kind = 'file', path = '/p/y.lua', name = 'y.lua' },
    } })
    everything._records = built.records
    return everything.record_of(built.lines[2]).name
  end)()]])
  eq(name, 'y.lua')
end

T['action_for plans the open verb per kind'] = function()
  local got = child.lua_get([[(function()
    local e = require('config.everything')
    return {
      file = e.action_for({ kind = 'file', path = '/p/a.lua' }),
      buffer = e.action_for({ kind = 'buffer', bufnr = 7 }),
      symbol = e.action_for({ kind = 'symbol', bufnr = 7, line = 3, col = 2 }),
      command = e.action_for({ kind = 'command', cmd_name = 'Z' }),
    }
  end)()]])
  eq(got.file, { 'edit', '/p/a.lua' })
  eq(got.buffer, { 'buffer', 7 })
  eq(got.symbol, { 'symbol', 7, 3, 2 })
  eq(got.command, { 'command', 'Z' })
  eq(child.lua_get([[require('config.everything').action_for(nil) == nil]]), true)
end

T['preview_for builds the previewer entry per kind'] = function()
  local got = child.lua_get([[(function()
    local e = require('config.everything')
    return {
      file = e.preview_for({ kind = 'file', path = '/p/a.lua' }),
      buffer = e.preview_for({ kind = 'buffer', bufnr = 7 }),
      symbol = e.preview_for({ kind = 'symbol', bufnr = 7, line = 3, col = 2 }),
      cmd_def = e.preview_for({ kind = 'command', cmd_name = 'NoHelpTagFooCmd', definition = 'foo body' }),
      cmd_blank = e.preview_for({ kind = 'command', cmd_name = 'NoHelpTagBarCmd' }),
      none = e.preview_for(nil),
    }
  end)()]])
  eq(got.file, { path = '/p/a.lua' })
  eq(got.buffer, { bufnr = 7, line = 1 })
  eq(got.symbol, { bufnr = 7, line = 3, col = 3 })
  eq(got.cmd_def, { title = ' NoHelpTagFooCmd ', filetype = 'help', content = { 'foo body' } })
  eq(got.cmd_blank, { title = ' NoHelpTagBarCmd ', filetype = 'help', content = {} })
  eq(got.none, {})
end

T['normalize_symbols flattens hierarchical and flat results'] = function()
  local got = child.lua_get([[(function()
    local e = require('config.everything')
    return {
      h = e.normalize_symbols({
        { name = 'Outer', selectionRange = { start = { line = 0, character = 2 } },
          children = { { name = 'inner', selectionRange = { start = { line = 5, character = 4 } } } } },
      }, 3),
      f = e.normalize_symbols({
        { name = 'Sym', location = { range = { start = { line = 9, character = 0 } } } },
      }, 3),
    }
  end)()]])
  eq(got.h, {
    { kind = 'symbol', bufnr = 3, name = 'Outer', line = 1, col = 2 },
    { kind = 'symbol', bufnr = 3, name = 'inner', line = 6, col = 4 },
  })
  eq(got.f, { { kind = 'symbol', bufnr = 3, name = 'Sym', line = 10, col = 0 } })
end

T['normalize_files roots relative paths and keeps the relative name'] = function()
  local got = child.lua_get([[require('config.everything').normalize_files('a.lua\nsub/b.lua\n', '/root')]])
  eq(got, {
    { kind = 'file', name = 'a.lua', path = '/root/a.lua' },
    { kind = 'file', name = 'sub/b.lua', path = '/root/sub/b.lua' },
  })
end

T['everything_opts matches only the name field and wires preview and open'] = function()
  local got = child.lua_get([[(function()
    local e = require('config.everything')
    local o = e.everything_opts('/root')
    return {
      delimiter = o.fzf_opts['--delimiter'],
      with_nth = o.fzf_opts['--with-nth'],
      nth = o.fzf_opts['--nth'],
      cwd = o.cwd,
      has_ctor = type(o.previewer._ctor) == 'function',
      open_is_wired = o.actions.default == e.open,
    }
  end)()]])
  eq(got.delimiter, '\t')
  eq(got.with_nth, '2..')
  eq(got.nth, '2')
  eq(got.cwd, '/root')
  eq(got.has_ctor, true)
  eq(got.open_is_wired, true)
end

T['list_buffers records listed buffers with an absolute path'] = function()
  local got = child.lua_get([[(function()
    local tmp = vim.fn.tempname() .. '.lua'
    vim.fn.writefile({ 'return 1' }, tmp)
    vim.cmd.edit(tmp)
    for _, r in ipairs(require('config.everything').list_buffers()) do
      if r.bufnr == vim.api.nvim_get_current_buf() then
        return { kind = r.kind, got = vim.uv.fs_realpath(r.path), want = vim.uv.fs_realpath(tmp) }
      end
    end
    return {}
  end)()]])
  eq(got.kind, 'buffer')
  eq(got.got, got.want)
end

T['open edits a file record'] = function()
  local got = child.lua_get([[(function()
    local tmp = vim.fn.tempname() .. '.txt'
    vim.fn.writefile({ 'hi' }, tmp)
    local e = require('config.everything')
    e._records = { { kind = 'file', path = tmp } }
    e.open({ '1\tfile\t' .. tmp })
    return { got = vim.uv.fs_realpath(vim.api.nvim_buf_get_name(0)), want = vim.uv.fs_realpath(tmp) }
  end)()]])
  eq(got.got, got.want)
end

T['open switches to a buffer record'] = function()
  local same = child.lua_get([[(function()
    local target = vim.api.nvim_create_buf(true, false)
    local e = require('config.everything')
    e._records = { { kind = 'buffer', bufnr = target } }
    e.open({ '1\tbuf\tscratch' })
    return vim.api.nvim_get_current_buf() == target
  end)()]])
  eq(same, true)
end

T['open jumps to a symbol record line'] = function()
  local pos = child.lua_get([[(function()
    local buf = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { 'one', 'two', 'three', 'four' })
    local e = require('config.everything')
    e._records = { { kind = 'symbol', bufnr = buf, line = 3, col = 0 } }
    e.open({ '1\tsym\tthree' })
    return { on_buf = vim.api.nvim_get_current_buf() == buf, row = vim.api.nvim_win_get_cursor(0)[1] }
  end)()]])
  eq(pos.on_buf, true)
  eq(pos.row, 3)
end

return T
