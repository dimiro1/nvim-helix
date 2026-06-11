-- Helix-flavored Neovim. Glossary: CONTEXT.md, decisions: docs/adr/.

-- Location independence: tests boot children as `nvim --clean -u init.lua`,
-- where neither this directory nor the vim.pack dir is on the default paths.
-- data/site must be on BOTH paths: packpath for vim.pack plugins,
-- runtimepath for loose runtime files like the tree-sitter parsers that
-- nvim-treesitter installs under site/parser/.
local root = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p:h')
vim.opt.runtimepath:prepend(root)
vim.opt.runtimepath:prepend(vim.fn.stdpath('data') .. '/site')
vim.opt.packpath:prepend(vim.fn.stdpath('data') .. '/site')

vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

require('config.options')
require('config.plugins').setup()
require('config.lsp').setup()
require('config.keymaps').setup()
require('config.pickers').setup()
require('config.worktrees').setup()
require('config.permalink').setup()
require('config.statusline').setup()
require('config.tabline').setup()
require('config.termbg').setup()
