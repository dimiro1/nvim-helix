# No tab bar

The user's Helix config sets `bufferline = "multiple"`, and this config
used to copy it: a hand-written bar listing open buffers whenever two or
more were open. In practice the user switches buffers with the `Space b`
picker, not by reading the bar, and Emacs, their other editor, has no tab
bar at all. The bar also duplicated the statusline, which already shows
the current file's path (shortened to 40 columns) and the breadcrumbs. It
broke down when two buffers shared a file name across worktrees: telling
them apart took every directory up to the worktree folder, so a single tab
spanned most of the screen. `'showtabline'` is now `0`, even with
several tab pages open.

## Consequences

- One option line replaces a 256-line module and its tests (ADR 0004).
- Seeing that another buffer has unsaved changes needs `Space b`; `:qa`
  still refuses to quit while one is unsaved.
- Tab pages still work (`Ctrl-t` from a picker opens one, `gt` switches)
  but nothing on screen shows how many exist. If that matters, the
  statusline is the place to show it, not a returning tab bar.
- The look diverges from the Helix config on purpose; CLAUDE.md's target
  look records the exception.
- Themes keep their `TabLine*` groups: they are standard Neovim groups,
  and `:set showtabline=2` still draws a themed bar.
