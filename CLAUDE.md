# Working on this repo

A Neovim 0.12 config recreating Helix's interaction layer. Before changing
anything, read `CONTEXT.md` (project glossary) and `docs/adr/` — especially
ADR 0002 (keybinding boundary) and ADR 0004 (native-first). Changes that add
plugins or shadow Vim grammar keys need to clear those bars, not just work.

## Rules

- **Every code change ships with unit tests.** Suite: mini.test, run via
  `make test` (headless, isolated `XDG_CONFIG_HOME`, children boot the real
  `init.lua`). Design for testability: specs and configs as data tables,
  pure functions for rendering.
- **Keep tests comprehensive — do not trim.** The suite deliberately mixes
  behavioral tests, pure-function tests, structural sweeps, AND
  config-state assertions. The state assertions are wanted: they pin
  intent, catch one-sided edits, and each runs against a real booted
  instance. (A leaner suite was tried and explicitly reverted by the user
  on 2026-06-10.)
- **Lua changes also pass `make check`** — a lua_ls `--check` sweep with
  the same settings the editor uses; fix findings, don't suppress them.
- **Neutral namespaces**: modules live in `lua/config/`; no codenames.
  Colorscheme modules use their theme's name (for
  example, `lua/config/anysphere.lua`), as requested by the user.
- The vim.pack lockfile `nvim-pack-lock.json` is committed; don't hand-edit.
- nvim-treesitter and nvim-treesitter-textobjects are pinned to their `main`
  branches — the default branches are frozen legacy. Don't "fix" the pin.

## Layout

- `init.lua` — entry; makes itself location-independent (tests boot
  `nvim --clean -u init.lua`)
- `lua/config/{options,plugins,anysphere,lsp,keymaps,pickers,explorer,tree,zoxide,everything,commands,worktrees,permalink,processes,statusline,tabline,breadcrumbs,terminal,termbg}.lua`
- `colors/anysphere.lua` — native `:colorscheme anysphere` entry point
- `tests/test_*.lua` — one file per module plus behavioral textobject tests
- The target look mirrors the user's personal Helix `config.toml` (see
  README "Personalization layer"), not stock Helix defaults.

## External tools assumed on PATH

fzf, rg, lsof, tree-sitter (CLI, parser builds), gopls,
typescript-language-server, pyright, jdtls, lua-language-server. CI installs
all but gopls, jdtls, and lua-language-server (those integration tests
self-skip); lsof ships preinstalled on macOS and the ubuntu runner image.
