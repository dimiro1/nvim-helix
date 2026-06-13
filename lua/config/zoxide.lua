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

  if available() then
    vim.api.nvim_create_autocmd('DirChanged', {
      group = vim.api.nvim_create_augroup('config.zoxide', {}),
      callback = function()
        vim.fn.system({ 'zoxide', 'add', vim.v.event.cwd })
      end,
    })
  end
end

return M
