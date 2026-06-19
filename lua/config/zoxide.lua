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

-- The filename_first formatter (set globally) lays each entry out as three
-- tab fields — score, leaf, parent — instead of the whole path the built-in
-- picker's preview and Enter action both assume. The two helpers below put
-- the directory back together: the preview lists the reconstructed `{3}/{2}`
-- (parent/leaf), and the action rejoins parent/leaf before cd'ing.

-- The lsd/eza/ls cascade mirrors the built-in picker's, keeping the preview's
-- look unchanged. fzf strips the field highlights and quotes each field, so
-- `{3}/{2}` stays correct for directory names containing spaces.
local function preview_cmd()
  local dir = '{3}/{2}'
  if vim.fn.executable('lsd') == 1 then
    return 'lsd -la --color=always --icon=always --group-directories-first --literal ' .. dir
  elseif vim.fn.executable('eza') == 1 then
    return 'eza -la --color=always --icons -g --group-directories-first ' .. dir
  end
  return 'ls -la ' .. dir
end

-- Rebuild the full directory from a selected entry. zoxide_cd would otherwise
-- cd to the entry's last tab field, which filename_first makes the parent.
-- fzf-lua's own entry reversers (_fmt.from, path.entry_to_file) assume a file
-- entry and mis-parse zoxide's leading score field, so we split the fields
-- ourselves but lean on its helpers to drop the highlights and rejoin the path.
local function selected_dir(entry)
  local utils = require('fzf-lua.utils')
  local fields = vim.split(utils.strip_ansi_coloring(entry), '\t', { plain = true })
  if #fields < 3 then
    return fields[#fields] -- score⇥path, nothing to rejoin
  end
  return require('fzf-lua.path').join({ fields[#fields], fields[2] }) -- parent/leaf
end

-- cd to the chosen directory by handing zoxide_cd a single-field path, so its
-- cd, db-feed, and scope/git-root handling all carry over unchanged.
local function cd_selected(selected, opts)
  if not selected[1] then
    return
  end
  require('fzf-lua.actions').zoxide_cd({ selected_dir(selected[1]) }, opts)
end

-- The built-in picker lists with scores, previews the directory, and its Enter
-- action cd's and feeds the db. We only layer Ctrl-f on top: cd, then open the
-- file picker in the chosen directory.
function M.pick()
  fzf().zoxide({
    prompt = require('config.pickers').PROMPTS.zoxide,
    preview = preview_cmd(),
    actions = {
      enter = cd_selected,
      ['ctrl-f'] = function(selected, opts)
        cd_selected(selected, opts)
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
