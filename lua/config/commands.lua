-- Command documentation and the command palette (Space ?). Shared by the
-- palette and the Everything picker's command rows so both surface the same
-- docs: a command's :help entry when it has one, else its definition. Help is
-- resolved lazily (only for the previewed command) and cached.
local M = {}

local function fzf()
  return require('fzf-lua')
end

M._help_cache = {} -- { [name] = lines | false }
M._defs = {} -- palette name -> definition, for the previewer lookup
-- M._tag_index is built once on first help lookup: { [':cmd'] = doc file }

-- Drop *tag* anchors and trailing whitespace; |links| stay as readable text.
local function strip_tags(line)
  return (line:gsub('%*[^*%s]-%*', ''):gsub('%s+$', ''))
end

-- The help block documenting `tag` (e.g. ':restart') from a doc file's `lines`:
-- start at the *tag* anchor, skip the leading anchor/error-tag lines, then take
-- prose until a double blank or a line cap so a sprawling entry can't flood the
-- pane.
function M.extract_help(lines, tag)
  local anchor = '*' .. tag .. '*'
  local start
  for i, line in ipairs(lines) do
    if line:find(anchor, 1, true) then
      start = i
      break
    end
  end
  if not start then
    return nil
  end
  local out, blanks, seen = {}, 0, false
  for i = start, #lines do
    local stripped = strip_tags(lines[i])
    if stripped:match('^%s*$') then
      if seen then
        blanks = blanks + 1
        if blanks >= 2 then
          break
        end
        out[#out + 1] = ''
      end
    elseif seen and stripped:match('^[%-=][%-=][%-=]') then
      -- a section rule (---- or ====) ends the entry
      break
    else
      seen = true
      blanks = 0
      out[#out + 1] = stripped
      if #out >= 25 then
        break
      end
    end
  end
  while #out > 0 and out[#out] == '' do
    out[#out] = nil
  end
  return #out > 0 and out or nil
end

-- Map every help tag to its doc file, once. doc/tags lines are `tag\tfile\tcmd`.
local function tag_index()
  if M._tag_index then
    return M._tag_index
  end
  local index = {}
  for _, tagsfile in ipairs(vim.api.nvim_get_runtime_file('doc/tags', true)) do
    local dir = vim.fn.fnamemodify(tagsfile, ':h')
    for _, line in ipairs(vim.fn.readfile(tagsfile)) do
      local tag, file = line:match('^([^\t]+)\t([^\t]+)\t')
      if tag and not index[tag] then
        index[tag] = dir .. '/' .. file
      end
    end
  end
  M._tag_index = index
  return index
end

-- The :help text for a command name, or nil when it isn't documented. Cached.
function M.help_text(name)
  local cached = M._help_cache[name]
  if cached ~= nil then
    return cached or nil
  end
  local lines
  local docfile = tag_index()[':' .. name]
  if docfile then
    local ok, content = pcall(vim.fn.readfile, docfile)
    if ok then
      lines = M.extract_help(content, ':' .. name)
    end
  end
  M._help_cache[name] = lines or false
  return lines
end

-- Documentation lines for a command: its :help entry, else its definition
-- (the desc for Lua user commands), else empty.
function M.docs(name, definition)
  return M.help_text(name) or (definition and vim.split(definition, '\n')) or {}
end

-- Command records from command dictionaries (nvim_get_commands shape) followed
-- by bare command names (completion output). First occurrence wins, so a
-- defined command keeps its definition over a bare built-in of the same name.
function M.normalize(dicts, names)
  local out, seen = {}, {}
  local function add(name, definition)
    if name == '' or seen[name] then
      return
    end
    seen[name] = true
    out[#out + 1] = { kind = 'command', name = name, cmd_name = name, definition = definition }
  end
  for _, dict in ipairs(dicts or {}) do
    for name, def in pairs(dict) do
      if type(def) == 'table' then
        add(name, def.definition)
      end
    end
  end
  for _, name in ipairs(names or {}) do
    add(name, nil)
  end
  return out
end

-- Every command as a record: user, buffer-local, then built-in names.
function M.list()
  return M.normalize(
    { vim.api.nvim_get_commands({}), vim.api.nvim_buf_get_commands(0, {}) },
    vim.fn.getcompletion('', 'command')
  )
end

-- A previewer that renders a command name's docs; built lazily so the palette
-- opts can be assembled without fzf-lua.
local commands_previewer
do
  local class
  commands_previewer = function()
    if not class then
      class = require('fzf-lua.previewer.builtin').buffer_or_file:extend()
      class.parse_entry = function(_, name)
        return { title = ' ' .. name .. ' ', filetype = 'help', content = M.docs(name, M._defs[name]) }
      end
    end
    return class
  end
end

-- Command palette (Space ?): a name list with a docs preview; Enter prefills
-- the cmdline so an argument-taking command can be finished by hand.
function M.pick()
  local names = {}
  M._defs = {}
  for _, rec in ipairs(M.list()) do
    names[#names + 1] = rec.name
    M._defs[rec.name] = rec.definition
  end
  table.sort(names)
  fzf().fzf_exec(names, {
    prompt = require('config.pickers').PROMPTS.command_palette,
    previewer = { _ctor = commands_previewer },
    actions = {
      default = function(selected)
        if selected[1] then
          vim.cmd('stopinsert')
          vim.fn.feedkeys(':' .. selected[1], 'nt')
        end
      end,
    },
  })
end

return M
