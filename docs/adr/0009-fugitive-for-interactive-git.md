# Fugitive for interactive Git operations

The user requested Tim Pope's vim-fugitive. It provides an interactive Git
status buffer with staging and commit actions, repository object buffers,
and index diffs. Native Neovim can run the Git CLI but lacks these integrated
interfaces, so the plugin earns its place under ADR 0004.

## Consequences

- Managed by native vim.pack, with its revision recorded in the lockfile.
- Access through Fugitive's commands (`:Git`, `:Gdiffsplit`, `:Git blame`).
- Existing Space mode mappings and mini.diff navigation remain in place.
