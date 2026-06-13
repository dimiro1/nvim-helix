-- zoxide: terminal-style frecent directory jumping, no plugin — zoxide is
-- a system binary and the picker engine already exists. `:Z {query}` jumps
-- like terminal z; `:Z` / Space-z open the picker (Enter = cd, Ctrl-f =
-- cd + file picker). A DirChanged hook mirrors the shell hook: every :cd
-- feeds the db.
local M = {}

local function fzf()
  return require('fzf-lua')
end

M.ZOXIDE_LIST_CMD = 'zoxide query --list'

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

function M.pick()
  if not available() then
    return vim.notify('zoxide not found on PATH', vim.log.levels.ERROR)
  end
  fzf().fzf_exec(M.ZOXIDE_LIST_CMD, {
    prompt = 'z> ',
    actions = {
      default = function(selected)
        if selected[1] then
          cd(selected[1])
        end
      end,
      ['ctrl-f'] = function(selected)
        if selected[1] then
          cd(selected[1])
          require('config.pickers').files_cwd()
        end
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
