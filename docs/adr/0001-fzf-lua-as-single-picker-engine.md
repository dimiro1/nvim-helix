# fzf-lua as the single picker engine

Helix presents one picker UI for every item kind (files, buffers, symbols, diagnostics, jumplist, global search, command palette, resume), using fzf match syntax and an always-visible preview pane. We chose **fzf-lua** to recreate that: it covers the full Helix picker set with one plugin, uses exact fzf syntax, and shows the preview pane permanently — the two properties that make pickers *feel* like Helix.

## Considered Options

- **mini.pick + mini.extra** — most minimal (pure Lua, no binary), but preview is a `Tab` toggle rather than an always-visible pane, and the match syntax is custom rather than fzf's. Rejected on picker fidelity, the project's #1 feature.
- **fff.nvim** — superior file-finding (frecency, typo-resistant Rust matcher, always-on preview) but covers only files + grep; the other ~8 pickers would need a second engine, meaning two picker UIs with different syntax and internal keybindings. Rejected for incoherence; can be revisited later as a `Space f`-only upgrade without disturbing the rest.
- **telescope.nvim** — heavy plus a plenary dependency; against the minimalism constraint.
- **snacks.nvim picker** — part of the LazyVim author's kitchen-sink ecosystem the project explicitly avoids.

## Consequences

- External binaries required: `fzf` and `ripgrep` (both brew-installable; rg already present).
- Supporting UX modules (key-hint popup, autopairs, …) are decided separately and may still come from mini.nvim.
