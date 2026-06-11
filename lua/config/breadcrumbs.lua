-- Breadcrumbs (ADR 0004, hand-rolled): the chain of named scopes enclosing
-- the cursor — `Type › method` — shown in the statusline center segment
-- next to the file name. (A winbar version was tried and vetoed: it costs
-- a fixed extra line at the top of every window.)
local M = {}

M.separator = ' › '

-- Scope = a named declaration worth showing. Type-name heuristics keep it
-- language-agnostic; 'call' is excluded so lua function_call etc. never
-- become crumbs.
local scope_markers =
  { 'function', 'method', 'class', 'struct', 'interface', 'type', 'impl', 'module' }

function M.is_scope(node_type)
  if node_type:find('call', 1, true) then
    return false
  end
  for _, marker in ipairs(scope_markers) do
    if node_type:find(marker, 1, true) then
      return true
    end
  end
  return false
end

function M.build(names)
  return table.concat(names, M.separator)
end

-- Named scopes from the cursor outwards (outermost first).
function M.scope_names()
  local ok_parser, parser = pcall(vim.treesitter.get_parser)
  if not ok_parser or parser == nil then
    return {}
  end
  -- 0.12 parses asynchronously on redraw; without forcing the (incremental,
  -- cheap-when-clean) parse here the tree may not exist at eval time
  parser:parse()
  local ok, node = pcall(vim.treesitter.get_node)
  if not ok or node == nil then
    return {}
  end
  local names = {}
  while node do
    if M.is_scope(node:type()) then
      local name_node = node:field('name')[1]
      if name_node then
        local text = vim.treesitter.get_node_text(name_node, 0)
        table.insert(names, 1, text)
      end
    end
    node = node:parent()
  end
  return names
end

-- Statusline-safe trail: file-derived text must not be parsed as items.
function M.trail()
  return M.build(M.scope_names()):gsub('%%', '%%%%')
end

return M
