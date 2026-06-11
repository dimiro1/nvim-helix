-- Git permalinks: commit-pinned, line-anchored URLs to the current file on
-- its hosting platform — copy to the system clipboard or open in the
-- browser (native vim.ui.open). Host specs are data and URL assembly is pure, so
-- everything up to the git calls tests without a repository.
local M = {}

-- One entry per supported host. `match` is a Lua pattern against the
-- remote's hostname; `path_format` receives (base_url, commit, path);
-- `range_format` receives (first, last) — single lines always anchor as
-- '#L%d'. Support a new host by appending an entry.
M.hosts = {
  {
    name = 'GitHub',
    match = 'github%.com',
    path_format = '%s/blob/%s/%s',
    range_format = '#L%d-L%d',
  },
  {
    name = 'GitLab',
    match = 'gitlab%.com',
    path_format = '%s/-/blob/%s/%s',
    range_format = '#L%d-%d',
  },
  {
    name = 'Codeberg',
    match = 'codeberg%.org',
    path_format = '%s/src/commit/%s/%s',
    range_format = '#L%d-L%d',
  },
}

function M.find_host(host)
  for _, spec in ipairs(M.hosts) do
    if host:find(spec.match) then
      return spec
    end
  end
end

-- 'git@host:user/repo.git', 'ssh://git@host:port/user/repo' and
-- 'https://host/user/repo' all parse to { host = host, path = 'user/repo' };
-- anything else is nil.
function M.parse_remote(url)
  url = vim.trim(url):gsub('%.git$', '')
  local host, path = url:match('^[^@/]+@([^:/]+):(.+)$')
  if not host then
    local authority
    authority, path = url:match('^%w+://([^/]+)/(.+)$')
    if authority then
      host = authority:gsub('^.*@', ''):gsub(':%d+$', '')
    end
  end
  if host and path then
    return { host = host, path = path }
  end
end

-- Percent-encode bytes a host could misread (spaces, '#', '?'), keeping
-- '/' as the segment separator.
local function encode_path(path)
  return (path:gsub('[^%w%-_./]', function(c)
    return ('%%%02X'):format(c:byte())
  end))
end

-- range is a {first, last} pair in either order, or nil for no anchor.
function M.anchor(spec, range)
  if not range then
    return ''
  end
  local first = math.min(range[1], range[2])
  local last = math.max(range[1], range[2])
  if first == last then
    return ('#L%d'):format(first)
  end
  return spec.range_format:format(first, last)
end

-- Pure assembly: remote URL + relative path + commit + line range → web
-- URL. Without a path the repository root URL is returned; a path needs
-- the commit, or the link would not be permanent.
---@return string? url, string? err
function M.build(remote_url, opts)
  opts = opts or {}
  local remote = M.parse_remote(remote_url)
  if not remote then
    return nil, 'cannot parse git remote: ' .. remote_url
  end
  local spec = M.find_host(remote.host)
  if not spec then
    return nil, 'unsupported git host: ' .. remote.host
  end
  local base = ('https://%s/%s'):format(remote.host, remote.path)
  if not opts.path then
    return base
  end
  if not opts.commit then
    return nil, 'no commit to pin the link to'
  end
  return spec.path_format:format(base, opts.commit, encode_path(opts.path))
    .. M.anchor(spec, opts.range)
end

local function git(root, ...)
  local out = vim.fn.systemlist({ 'git', '-C', root, ... })
  if vim.v.shell_error ~= 0 then
    return nil
  end
  return out
end

function M.remote_url(root)
  local out = git(root, 'remote', 'get-url', 'origin')
  if out and out[1] and out[1] ~= '' then
    return vim.trim(out[1])
  end
end

function M.head_commit(root)
  local out = git(root, 'rev-parse', 'HEAD')
  if out and out[1] and out[1] ~= '' then
    return vim.trim(out[1])
  end
end

-- Any difference from HEAD — including untracked — means the link's line
-- numbers may not match what the site shows.
function M.dirty(root, path)
  local out = git(root, 'status', '--porcelain', '--', path)
  return out ~= nil and out[1] ~= nil
end

-- Visual selection → line range; otherwise the cursor line.
function M.current_range()
  if vim.fn.mode():match('^[vV\22]') then
    return { vim.fn.line('v'), vim.fn.line('.') }
  end
  return { vim.fn.line('.'), vim.fn.line('.') }
end

-- Read the range before leaving visual mode: copying a link is a completed
-- action on the selection, like Space-y.
local function take_range()
  local range = M.current_range()
  if vim.fn.mode():match('^[vV\22]') then
    vim.api.nvim_feedkeys(vim.keycode('<Esc>'), 'n', false)
  end
  return range
end

-- Permalink for the current buffer at `range`. nil + message when the
-- buffer has no file, is outside a repository, or the remote is unusable.
---@return { url: string, dirty: boolean }? link, string? err
function M.get(range)
  local file = vim.api.nvim_buf_get_name(0)
  if file == '' then
    return nil, 'buffer has no file'
  end
  local root = vim.fs.root(file, '.git')
  if not root then
    return nil, 'not in a git repository'
  end
  local remote = M.remote_url(root)
  if not remote then
    return nil, "no 'origin' remote"
  end
  local path = vim.fs.relpath(root, file)
  local url, err = M.build(remote, {
    path = path,
    commit = M.head_commit(root),
    range = range,
  })
  if not url then
    return nil, err
  end
  return { url = url, dirty = path ~= nil and M.dirty(root, path) }
end

local function report(verb, link)
  if link.dirty then
    vim.notify(
      verb .. ' permalink to the last commit — file has uncommitted changes: ' .. link.url,
      vim.log.levels.WARN
    )
  else
    vim.notify(verb .. ' permalink: ' .. link.url)
  end
end

function M.copy(range)
  local link, err = M.get(range or take_range())
  if not link then
    return vim.notify(err or 'no permalink', vim.log.levels.ERROR)
  end
  vim.fn.setreg('+', link.url)
  report('copied', link)
end

function M.open(range)
  local link, err = M.get(range or take_range())
  if not link then
    return vim.notify(err or 'no permalink', vim.log.levels.ERROR)
  end
  local _, open_err = vim.ui.open(link.url)
  if open_err then
    return vim.notify(open_err, vim.log.levels.ERROR)
  end
  report('opening', link)
end

function M.setup()
  vim.api.nvim_create_user_command('Permalink', function(opts)
    local action = opts.args == 'open' and M.open or M.copy
    action({ opts.line1, opts.line2 })
  end, {
    range = true,
    nargs = '?',
    complete = function()
      return { 'copy', 'open' }
    end,
    desc = 'Copy (or open) a commit-pinned link to the current file lines',
  })
end

return M
