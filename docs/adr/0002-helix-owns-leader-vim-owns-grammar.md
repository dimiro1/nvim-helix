# Keybinding boundary: Helix owns the leader layer and LSP gotos; Vim owns the grammar

Recreating Helix on Neovim forces dozens of key-conflict decisions. Instead of case-by-case debate, we adopted one rule: Space mode and `g`-prefixed LSP jumps are replicated from Helix; everything that is Vim's editing grammar — motions, operators, text objects, marks, registers, search keys — stays stock Vim. Additions in Vim-idiomatic style (e.g. new text objects) are allowed; Helix keys never override grammar.

## Consequences

- `m` stays marks — Helix match mode is not replicated. Surround uses tpope keys (`ys`/`cs`/`ds`), `mm` → `%`, `mi`/`ma` → Vim's native `i`/`a` objects.
- `gd`/`gy`/`gi`/`gr` become Helix LSP jumps (definition / type-definition / implementation / references). Vim's `gi` (jump to last insert) is knowingly sacrificed; Neovim's entire default `gr*` family (`gra gri grn grr grt grx` as of 0.12 — a growing list) is swept by prefix so `gr` fires without a timeout wait.
- `ge`, `ga`, `gm`, `gn`, `gp` keep their Vim meanings; buffer navigation uses Neovim's native `]b`/`[b`, alternate file is `Ctrl-^`.
- `gw` becomes a daily-driven label jump (flash.nvim; see ADR 0007), knowingly sacrificing Vim's `gw` format-in-place operator — `gq` remains for formatting. Like `gi`, an explicit casualty, not an oversight.
- `Space h` (Helix: select all references as multiple selections) is out of scope — it depends on Helix's multi-selection model, which this project deliberately excludes.
