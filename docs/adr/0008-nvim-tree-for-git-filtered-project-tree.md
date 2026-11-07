# nvim-tree for a persistent project tree with Git filtering

Code review needs a project hierarchy that can hide Git-clean files and
filter the remaining filenames. The existing fzf-lua directory explorer is
a level-by-level picker, and native directory browsing lacks a Git-filtered
project tree. nvim-tree supplies that missing capability under ADR 0004,
without adding a second picker engine or required dependencies.

## Considered options

- **Neo-tree** — a dedicated Git-status tree and comparison against other
  Git refs, but filesystem name filtering does not carry into the Git-status
  source. Also requires nui.nvim and plenary.nvim.
- **Snacks explorer** — built on another picker engine (against ADR 0001),
  with additional customization needed for a changed-only tree.
- **Diffview** — useful for reviewing committed branches with diffs, but
  a separate review interface rather than a general project explorer.
- **Oil / mini.files** — directory listings / Miller columns instead of a
  persistent project tree.

## Consequences

- `Space E` toggles the sidebar at the workspace root. Existing directory
  and changed-file pickers remain on `Space e`, `Space .`, and `Space g`.
- Tree-local `/` starts filename regex filtering; nested folders are
  expanded first, subject to nvim-tree's default discovery limit. `F`
  clears that filter; `C` toggles hiding Git-clean files. This is a
  working-tree status view, not a committed-branch comparison.
- Tree-local `<` / `>` adjust the width by five columns per count.
  `:NvimTreeResize` exposes absolute and relative widths from any window.
- No global Vim grammar mappings change. nvim-tree's other buffer-local
  defaults remain available through `g?`.
- Git metadata and ignored files are hidden, dotfiles are visible, and
  navigating the tree never changes the editor's cwd.
- Worktree switching closes tree windows before saving native sessions and
  reopens the sidebar at the target root without taking focus. nvim-tree's
  own session restoration requires Neovim 0.13; saving its scratch buffers
  on 0.12 would restore empty placeholder windows.
- The plugin and its lock entry are managed by native vim.pack. Optional
  file icons are disabled so no icon provider is needed.
