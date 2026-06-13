-- The picker registry: thin fzf-lua wrappers for the core set, plus re-exports
-- of the pickers implemented in their own modules (config.explorer,
-- config.zoxide, config.everything, config.worktrees), so every picker is
-- reachable uniformly through config.pickers and the keymap `pick` helper.
local M = {}

local function fzf()
  return require('fzf-lua')
end

-- Workspace root: VCS root of the current buffer, else cwd. The shared anchor
-- the file pickers and the explorer/everything modules root themselves at.
function M.workspace_root()
  local name = vim.api.nvim_buf_get_name(0)
  local dir = name ~= '' and vim.fs.dirname(name) or assert(vim.uv.cwd())
  return vim.fs.root(dir, '.git') or assert(vim.uv.cwd())
end

-- Space mode pickers; hidden = true shows dotfiles while .gitignore is still
-- respected.
function M.files() fzf().files({ cwd = M.workspace_root(), hidden = true }) end
function M.files_cwd() fzf().files({ cwd = vim.uv.cwd(), hidden = true }) end
function M.buffers() fzf().buffers() end
function M.jumps() fzf().jumps() end
function M.changed_files() fzf().git_status({ cwd = M.workspace_root() }) end
function M.document_symbols() fzf().lsp_document_symbols() end
function M.workspace_symbols() fzf().lsp_live_workspace_symbols() end
function M.diagnostics_buffer() fzf().diagnostics_document() end
function M.diagnostics_workspace() fzf().diagnostics_workspace() end
function M.global_search() fzf().live_grep({ cwd = M.workspace_root() }) end
function M.command_palette() require('config.commands').pick() end
function M.resume() fzf().resume() end

-- Goto-mode LSP jumps: jump straight to a single result and open the picker
-- only when there are several.
function M.definitions() fzf().lsp_definitions({ jump1 = true }) end
function M.type_definitions() fzf().lsp_typedefs({ jump1 = true }) end
function M.implementations() fzf().lsp_implementations({ jump1 = true }) end
function M.references() fzf().lsp_references({ jump1 = false }) end

-- Pickers implemented in their own modules, re-exported under their picker name
-- so the keymap `pick` helper reaches them the same way it reaches the core set.
function M.everything() require('config.everything').pick() end
function M.directories() require('config.explorer').directories() end
function M.explorer_buffer_dir() require('config.explorer').explorer_buffer_dir() end
function M.zoxide() require('config.zoxide').pick() end
function M.worktrees() require('config.worktrees').pick() end

return M
