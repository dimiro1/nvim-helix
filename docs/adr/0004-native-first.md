# Native-first: built-in Neovim machinery beats a plugin whenever it covers the Helix behavior

When a Helix behavior can be recreated with Neovim 0.12 built-ins at acceptable fidelity, we use the built-in — even when a popular plugin is more polished. A plugin must earn its place by providing something native Neovim structurally lacks. Canonical instance: completion uses the native `'autocomplete'` option with an LSP-first `'complete'` source list (`completeopt=menuone,noselect,fuzzy,popup`, `vim.snippet` for snippets) instead of blink.cmp/nvim-cmp — accepted gaps are as-you-type path completion and auto-popping signature help, both available on demand (`CTRL-X CTRL-F`, insert-mode `CTRL-S`). Same principle drove ADR 0003 (no lspconfig/Mason). Plugins that pass the bar so far: fzf-lua (picker UI), nvim-treesitter (+textobjects), vim-surround/vim-repeat.

## Consequences

- Reversal per-feature is cheap and contained (e.g. blink.cmp could replace native completion without touching pickers or keymaps) — but the default posture is "exhaust the built-in first."
- Newer built-ins (e.g. `'autocomplete'`, shipped in 0.12) may be rougher than mature plugins; we accept polish gaps and tune options before reaching for a plugin.
