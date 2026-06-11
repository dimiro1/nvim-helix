-- :KillPort — kill the process listening on a TCP port (ADR 0004, native:
-- lsof + ps for lookup, vim.uv.kill to terminate, vim.ui.select when
-- several listen). Only LISTEN-state sockets match, so a process merely
-- connected to the port (a browser on :3000) is never offered as a target.
local M = {}

-- Parse `lsof -t` terse output into pids. lsof prints one line per
-- matching socket — a server listening on IPv4 and IPv6 appears twice —
-- so dedup while parsing.
function M.parse_pids(lines)
  local seen, pids = {}, {}
  for _, line in ipairs(lines) do
    local pid = tonumber(line:match('^%s*(%d+)%s*$'))
    if pid and not seen[pid] then
      seen[pid] = true
      pids[#pids + 1] = pid
    end
  end
  return pids
end

function M.format(proc)
  return ('%s (PID %d)'):format(proc.name, proc.pid)
end

---@return { pid: integer, name: string }[]
function M.processes_on_port(port)
  local lines = vim.fn.systemlist({
    'lsof', '-nP', '-iTCP:' .. port, '-sTCP:LISTEN', '-t',
  })
  if vim.v.shell_error ~= 0 then -- lsof exits non-zero when nothing matches
    return {}
  end
  local procs = {}
  for _, pid in ipairs(M.parse_pids(lines)) do
    -- macOS comm is the binary's full path, Linux just the name — basename
    -- both; '?' when the process vanished between lsof and ps.
    local name = (vim.fn.systemlist({ 'ps', '-p', tostring(pid), '-o', 'comm=' })[1] or '')
      :gsub('%s+$', '')
    procs[#procs + 1] = {
      pid = pid,
      name = name ~= '' and vim.fs.basename(name) or '?',
    }
  end
  return procs
end

-- Overridable for tests; plain Enter means No.
function M.confirm(label)
  return vim.fn.confirm(('Kill %s?'):format(label), '&Yes\n&No', 2) == 1
end

-- SIGKILL, not SIGTERM: the target is a stuck dev server holding its port.
local function confirm_and_kill(proc, port)
  if not M.confirm(M.format(proc)) then
    return
  end
  if vim.uv.kill(proc.pid, 'sigkill') then
    vim.notify(('killed %s on port %d'):format(M.format(proc), port))
  else
    vim.notify(('failed to kill %s'):format(M.format(proc)), vim.log.levels.ERROR)
  end
end

function M.kill(port)
  local n = tonumber(port)
  if not n or n % 1 ~= 0 or n < 1 or n > 65535 then
    return vim.notify('invalid port: ' .. tostring(port), vim.log.levels.ERROR)
  end
  local procs = M.processes_on_port(n)
  if #procs == 0 then
    return vim.notify(('no process listening on port %d'):format(n), vim.log.levels.WARN)
  end
  if #procs == 1 then
    return confirm_and_kill(procs[1], n)
  end
  vim.ui.select(procs, {
    prompt = ('port %d> '):format(n),
    format_item = M.format,
  }, function(choice)
    if choice then
      confirm_and_kill(choice, n)
    end
  end)
end

function M.setup()
  vim.api.nvim_create_user_command('KillPort', function(opts)
    if opts.args ~= '' then
      M.kill(opts.args)
      return
    end
    vim.ui.input({ prompt = 'Kill port: ' }, function(input)
      if input and input ~= '' then
        M.kill(input)
      end
    end)
  end, { nargs = '?', desc = 'Kill the process listening on a TCP port' })
end

return M
