# flash.nvim as the jump engine

`gw` jumps to a location by label. The wanted shape is incremental: type a query
and let matches narrow live, each tagged with a label you press to land. Native
Neovim has no label jump at all, and mini.jump2d (the first engine tried) labels
either every word at once or reads a whole query from an Enter-terminated command
line, then labels — no live narrowing. **flash.nvim** supplies the live-narrowing
form, so it earns its place under native-first and becomes the single jump
engine, mapped to `gw`. mini.jump2d is dropped (mini.nvim stays for its other
modules).

## Considered Options

- **mini.jump2d `word_start`** — labels every word instantly, no typing. Fine,
  but a different interaction from the type-to-narrow flow wanted.
- **mini.jump2d `query` / `single_character`** — query reads an Enter-terminated
  input line then labels (no live narrowing); single_character caps narrowing at
  one keypress. Neither is the incremental flow.
- **leap.nvim / hop.nvim** — also label jumpers; leap is two-char-then-label,
  hop has no live-narrowing form either. flash's incremental jump is the closest
  match and the most active project.

## Consequences

- New plugin under native vim.pack; `nvim-pack-lock.json` gains a flash entry,
  written by vim.pack on install. mini.jump2d's setup is removed.
- flash's `char` mode (rebinds `f`/`t`/`F`/`T`/`;`/`,`) and `search` mode
  (hooks `/`) are disabled. Those are Vim grammar keys the Fidelity Rule keeps
  stock, so flash only ever fires from its explicit `gw` invocation.
- Jump labels are the colemak home row plus a few easy neighbours
  (`arstneiodhgm`), lowercase only — uppercase labels are disabled so excess
  matches never spill into shift-typed keys.
- `gw` still sacrifices Vim's `gw` format operator — see ADR 0002; `gq` remains
  for formatting.
