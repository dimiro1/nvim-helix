# Everything picker: a names-only merge of static sources

The Everything picker (`Space Space`) merges files, buffers, document symbols,
and commands into one fuzzy list — a single entry point so you search without
first choosing the kind. It matches **names only**, because a single fzf process
has one input model: either a static list filtered client-side, or a command
re-run on every keystroke. Merging heterogeneous kinds requires the static
model, so content search (`Space /`) and live workspace symbols (`Space S`) stay
as their own query-driven pickers — the same split IntelliJ IDEA draws between
Search Everywhere (names) and Find in Files (contents). Ranking is fzf's fuzzy
score, so an exact match wins — typing `restart` surfaces the `:restart` command
first; the `buffers → symbols → files → commands` concatenation sets only the
pre-query view and the order of score ties. Forcing those kinds into hard tiers
with `--no-sort` was tried and rejected: it ranks by input order, which buries an
exact match in a low-priority kind beneath fuzzy noise from a higher one (the
`:restart` command sank below scattered file matches). Tiering that still honours
match quality needs per-entry scoring in Lua, which fzf — scoring in the binary —
cannot do.

## Consequences

- Adds no capability and no dependency: every kind is already reachable through
  its focused picker (`Space f` / `Space b` / `Space s` / `Space ?`), all of
  which remain. The picker earns its place as a convenience entry point.
- Pulling content search or workspace symbols into the merge later means
  re-architecting from a static list to a live/hybrid input model — a deliberate
  boundary, not an oversight.
