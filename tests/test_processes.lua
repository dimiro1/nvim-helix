local processes = require('config.processes')

local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set()

local eq = MiniTest.expect.equality

T['parse_pids'] = MiniTest.new_set()

T['parse_pids']['reads pids, skipping blanks and noise'] = function()
  eq(
    processes.parse_pids({ '123', '', '  456 ', 'lsof: warning', '78a' }),
    { 123, 456 }
  )
end

T['parse_pids']['dedups a process listening on several sockets'] = function()
  eq(processes.parse_pids({ '321', '321', '99' }), { 321, 99 })
end

T['parse_pids']['handles empty input'] = function()
  eq(processes.parse_pids({}), {})
end

T['format'] = MiniTest.new_set()

T['format']['labels a process by name and pid'] = function()
  eq(processes.format({ pid = 4242, name = 'node' }), 'node (PID 4242)')
end

-- Child-side snippets composed into lua_get blocks. A throwaway bind to
-- port 0 reserves a free port; the listener is a second headless nvim
-- (`--listen` opens a TCP server) — the one binary the suite can rely on.
local FREE_PORT = [[
  local processes = require('config.processes')
  local port
  do
    local probe = assert(vim.uv.new_tcp())
    probe:bind('127.0.0.1', 0)
    port = probe:getsockname().port
    probe:close()
  end
]]

local LISTENER = FREE_PORT
  .. [[
  local job = vim.fn.jobstart({
    vim.v.progpath, '--clean', '--headless', '--listen', '127.0.0.1:' .. port,
  })
  local appeared = vim.wait(10000, function()
    return #processes.processes_on_port(port) > 0
  end, 100)
  if not appeared then
    vim.fn.jobstop(job)
    return { appeared = false }
  end
]]

local function in_child(body)
  return child.lua_get('(function()\n' .. body .. '\nend)()')
end

T['in a live instance'] = MiniTest.new_set({
  hooks = {
    pre_case = function()
      child.restart({ '-u', 'init.lua' })
    end,
    post_once = child.stop,
  },
})

T['in a live instance'][':KillPort command is registered'] = function()
  eq(child.lua_get("vim.api.nvim_get_commands({})['KillPort'] ~= nil"), true)
  eq(child.lua_get("vim.api.nvim_get_commands({})['KillPort'].nargs"), '?')
end

T['in a live instance']['kills the listener after confirmation'] = function()
  local result = in_child(LISTENER .. [[
    local proc = processes.processes_on_port(port)[1]
    local confirmed = {}
    processes.confirm = function(label)
      confirmed[#confirmed + 1] = label
      return true
    end
    local notices = {}
    vim.notify = function(msg)
      notices[#notices + 1] = msg
    end

    processes.kill(port)
    local gone = vim.wait(10000, function()
      return #processes.processes_on_port(port) == 0
    end, 100)
    vim.fn.jobstop(job)
    return {
      appeared = appeared,
      proc = proc,
      port = port,
      confirmed = confirmed,
      notices = notices,
      gone = gone,
    }]])
  eq(result.appeared, true)
  eq(result.proc.name, 'nvim')
  local label = ('nvim (PID %d)'):format(result.proc.pid)
  eq(result.confirmed, { label })
  eq(result.gone, true)
  eq(result.notices, { ('killed %s on port %d'):format(label, result.port) })
end

T['in a live instance']['declining the confirmation leaves it running'] = function()
  local result = in_child(LISTENER .. [[
    processes.confirm = function()
      return false
    end
    local notice_count = 0
    vim.notify = function()
      notice_count = notice_count + 1
    end

    processes.kill(port)
    local still_listening = #processes.processes_on_port(port) == 1
    local job_running = vim.fn.jobwait({ job }, 0)[1] == -1
    vim.fn.jobstop(job)
    return {
      appeared = appeared,
      still_listening = still_listening,
      job_running = job_running,
      notice_count = notice_count,
    }]])
  eq(result.appeared, true)
  eq(result.still_listening, true)
  eq(result.job_running, true)
  eq(result.notice_count, 0)
end

T['in a live instance']['several listeners go through vim.ui.select'] = function()
  local result = in_child(LISTENER .. [[
    local proc = processes.processes_on_port(port)[1]
    local lookup = processes.processes_on_port
    processes.processes_on_port = function()
      return {
        { pid = proc.pid, name = 'first' },
        { pid = proc.pid, name = 'second' },
      }
    end
    local offered, prompt
    vim.ui.select = function(items, opts, on_choice)
      offered = vim.tbl_map(opts.format_item, items)
      prompt = opts.prompt
      on_choice(items[2])
    end
    processes.confirm = function()
      return true
    end
    local notices = {}
    vim.notify = function(msg)
      notices[#notices + 1] = msg
    end

    processes.kill(port)
    local gone = vim.wait(10000, function()
      return #lookup(port) == 0
    end, 100)
    vim.fn.jobstop(job)
    return {
      appeared = appeared,
      pid = proc.pid,
      port = port,
      offered = offered,
      prompt = prompt,
      gone = gone,
      notices = notices,
    }]])
  eq(result.appeared, true)
  eq(result.offered, {
    ('first (PID %d)'):format(result.pid),
    ('second (PID %d)'):format(result.pid),
  })
  eq(result.prompt, ('port %d> '):format(result.port))
  eq(result.gone, true)
  eq(
    result.notices,
    { ('killed second (PID %d) on port %d'):format(result.pid, result.port) }
  )
end

T['in a live instance']['reports when nothing listens on the port'] = function()
  local result = in_child(FREE_PORT .. [[
    local notices = {}
    vim.notify = function(msg, level)
      notices[#notices + 1] = { msg = msg, level = level }
    end
    processes.kill(port)
    return { port = port, notices = notices }]])
  eq(result.notices, {
    {
      msg = ('no process listening on port %d'):format(result.port),
      level = vim.log.levels.WARN,
    },
  })
end

T['in a live instance']['rejects invalid ports'] = function()
  local result = in_child([[
    local processes = require('config.processes')
    local notices = {}
    vim.notify = function(msg, level)
      notices[#notices + 1] = { msg = msg, level = level }
    end
    processes.kill('teapot')
    processes.kill('0')
    processes.kill('70000')
    processes.kill('30.5')
    return notices]])
  local function invalid(arg)
    return { msg = 'invalid port: ' .. arg, level = vim.log.levels.ERROR }
  end
  eq(result, {
    invalid('teapot'),
    invalid('0'),
    invalid('70000'),
    invalid('30.5'),
  })
end

T['in a live instance'][':KillPort takes the port as argument or prompts'] = function()
  local result = in_child(FREE_PORT .. [[
    local notices = {}
    vim.notify = function(msg)
      notices[#notices + 1] = msg
    end

    vim.cmd('KillPort ' .. port)

    local prompt
    vim.ui.input = function(opts, on_confirm)
      prompt = opts.prompt
      on_confirm(tostring(port))
    end
    vim.cmd('KillPort')

    vim.ui.input = function(_, on_confirm)
      on_confirm(nil)
    end
    vim.cmd('KillPort') -- cancelled prompt: no lookup, no notice

    return { port = port, prompt = prompt, notices = notices }]])
  local expected = ('no process listening on port %d'):format(result.port)
  eq(result.notices, { expected, expected })
  eq(result.prompt, 'Kill port: ')
end

return T
