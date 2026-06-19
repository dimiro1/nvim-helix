-- zoxide: terminal-style frecent directory jumping. `:Z {query}` jumps like
-- terminal z; `:Z` / Space-z open fzf-lua's zoxide picker (Enter = cd, Ctrl-f =
-- cd + file picker). A DirChanged hook mirrors the shell hook: every :cd feeds
-- the db, so in-editor jumps count, not just picker selections.
local M = {}

local function fzf()
  return require('fzf-lua')
end

local function available()
  return vim.fn.executable('zoxide') == 1
end

local function cd(dir)
  vim.cmd.cd(vim.fn.fnameescape(dir))
  vim.notify(vim.fn.fnamemodify(dir, ':~'))
end

function M.jump(words)
  if not available() then
    return vim.notify('zoxide not found on PATH', vim.log.levels.ERROR)
  end
  local out = vim.fn.systemlist(vim.list_extend({ 'zoxide', 'query' }, words))
  if vim.v.shell_error ~= 0 or out[1] == nil then
    return vim.notify('zoxide: no match for ' .. table.concat(words, ' '), vim.log.levels.WARN)
  end
  cd(out[1])
end

-- The single most frecent directory in the db, or nil when zoxide is absent
-- or the db is empty. `zoxide query` with no keywords ranks the whole db and
-- returns its top entry — the same one the picker floats first.
function M.top()
  if not available() then
    return nil
  end
  local out = vim.fn.systemlist({ 'zoxide', 'query' })
  if vim.v.shell_error ~= 0 or out[1] == nil or out[1] == '' then
    return nil
  end
  return out[1]
end

-- Neovide launched from the dock or an app launcher starts in $HOME with no
-- file to edit, so its cwd is incidental. Land in the top frecent directory
-- instead, where the pickers then open something useful. A file or directory
-- argument (`neovide foo.lua`) means the cwd was chosen on purpose — leave it.
function M.start_in_top()
  if not vim.g.neovide or vim.fn.argc() ~= 0 then
    return false
  end
  local dir = M.top()
  if dir == nil then
    return false
  end
  cd(dir)
  return true
end

-- The built-in picker lists with scores, previews the directory, and its Enter
-- action cd's and feeds the db. We only layer Ctrl-f on top: cd, then open the
-- file picker in the chosen directory.
function M.pick()
  local zoxide_cd = require('fzf-lua.actions').zoxide_cd
  fzf().zoxide({
    prompt = require('config.pickers').PROMPTS.zoxide,
    actions = {
      enter = zoxide_cd,
      ['ctrl-f'] = function(selected, opts)
        zoxide_cd(selected, opts)
        require('config.pickers').files_cwd()
      end,
    },
  })
end

function M.setup()
  vim.api.nvim_create_user_command('Z', function(cmd)
    if #cmd.fargs == 0 then
      M.pick()
    else
      M.jump(cmd.fargs)
    end
  end, { nargs = '*', desc = 'Jump to a recent directory (zoxide)' })

  local group = vim.api.nvim_create_augroup('config.zoxide', {})

  -- VimEnter, not setup time: under Neovide the UI attaches and sets
  -- g:neovide around when init runs, and argv is only fully known once
  -- startup completes.
  vim.api.nvim_create_autocmd('VimEnter', {
    group = group,
    callback = function()
      M.start_in_top()
    end,
  })

  if available() then
    vim.api.nvim_create_autocmd('DirChanged', {
      group = group,
      callback = function()
        vim.fn.system({ 'zoxide', 'add', vim.v.event.cwd })
      end,
    })
  end
end

return M
