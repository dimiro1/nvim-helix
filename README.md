# Helix-flavored Neovim

A Neovim 0.12 configuration that recreates [Helix](https://helix-editor.com)'s
interaction layer — pickers, window management, search, LSP ergonomics — on
stock Neovim, while keeping Vim's editing grammar untouched.

Two laws decide everything here (see `CONTEXT.md` and `docs/adr/`):

1. **Fidelity Rule** — Helix owns Space mode and LSP gotos; Vim owns the
   grammar (motions, operators, text objects, marks, registers, search).
2. **Native-first** — a plugin must provide something Neovim structurally
   lacks. Seven plugins pass the bar: fzf-lua, nvim-treesitter,
   nvim-treesitter-textobjects, nvim-treesitter-context, vim-surround,
   vim-repeat, mini.nvim (clue/pairs/diff/jump2d/test modules only). Plugin
   management is native `vim.pack`; completion is the native
   `'autocomplete'` option; LSP servers are hand-configured system binaries.

## Requirements

| Binary | Why | Install |
|---|---|---|
| `nvim` ≥ 0.12.2 | `vim.pack`, `'autocomplete'`, `vim.lsp.config` | `brew install neovim` |
| `fzf` | picker matching engine | `brew install fzf` |
| `rg` | file listing + global search | `brew install ripgrep` |
| `tree-sitter` | parser builds (CLI, build-time only) | `brew install tree-sitter-cli` |
| `gopls` | Go LSP | `go install golang.org/x/tools/gopls@latest` |
| `typescript-language-server` | JS/TS LSP | `npm i -g typescript-language-server` |
| `pyright` | Python LSP | `npm i -g pyright` |
| `lua-language-server` | Lua LSP (this config itself) | `brew install lua-language-server` |
| `zoxide` (optional) | recent-dirs picker, `:Z` | `brew install zoxide` |

## Install

```sh
git clone <this repo> ~/.config/nvim
nvim   # first launch: vim.pack installs plugins, parsers compile in background
```

The vim.pack lockfile (`nvim-pack-lock.json`) is committed; update plugins
with `:lua vim.pack.update()`, review the diff, `:write` to confirm.

## Keymap (the Helix parts)

| Key | Action |
|---|---|
| `Space Space` | buffer picker (personal helix shortcut) |
| `Space f` / `Space F` | file picker (workspace root / cwd, dotfiles shown) |
| `Space b` `Space j` `Space g` | buffer / jumplist / changed-file pickers |
| `Space s` / `Space S` | document / workspace symbol picker |
| `Space d` / `Space D` | buffer / workspace diagnostics picker |
| `Space /` | global search (live grep) |
| `Space ?` | command palette |
| `Space '` | resume last picker |
| `Space e` | directory search across the whole workspace → explorer at the pick |
| `Space .` | file explorer at the buffer's directory (level-by-level, `../` to go up) |
| `Space z` / `:Z [query]` | recent directories via zoxide (Enter = cd, `Ctrl-f` = cd + file picker); every `:cd` feeds the zoxide db |
| `Space W` / `:Worktrees` | switch git worktree, swapping workspaces — buffers/layout saved per worktree, restored on return; blocked while unsaved buffers exist; first visit opens the file picker |
| `Space k` `Space r` `Space a` | hover / rename / code action |
| `Space y` `Space p` … | system clipboard yank/paste family |
| `Space c` | toggle comment |
| `Space w` | window mode (alias of `Ctrl-w`) |
| `gd` `gy` `gi` `gr` | goto definition / type-def / implementation / references |
| `gw` | word jump labels (colemak alphabet, shadows Vim's `gw` — use `gq` to format) |
| `]f` `[f` `]t` `[t` `]a` `[a` | next/prev function, type, argument |
| `]g` `[g` | next/prev git change |
| `if`/`af` `ic`/`ac` `ia`/`aa` | function / type / argument text objects |
| `ys` `cs` `ds` | surround (tpope) |
| `Space G` | toggle inline git diff overlay (mini.diff) |
| `Ctrl-\` | toggle floating terminal (`Esc Esc` leaves terminal mode) |

Everything else is stock Vim. Pressing `Space`, `g`, `z`, `Ctrl-w`, `[`, `]`
pops a Helix-style infobox (mini.clue) listing the continuations.

## Personalization layer

Mirrors the user's actual Helix `config.toml`, not stock defaults: relative
line numbers, soft wrap, bordered popups, `┊` indent guides, end-of-line
diagnostics with expanded cursor-line rendering, colored `❮N❯/❮I❯/❮V❯` mode
segment with git branch and worktree name (`main (kelowna)`), centered
filename, rich right-side statusline
segments, and a bufferline that appears only with 2+ buffers (hand-rolled
native `'tabline'`). Colorscheme: `melange` (`rose-pine` also installed).
The scheme's background is reported to the terminal with OSC 11 (and
reset with OSC 111 on exit/suspend), the same escape Helix emits — so
Ghostty colors its tabs and titlebar to match the editor theme.
Known gap: `indent-guides.skip-levels = 1` isn't expressible with
`listchars` — guides start at column 1.

## Reading aids

Sticky scope headers while scrolling (nvim-treesitter-context, capped at 3
lines), breadcrumbs in the statusline center — the enclosing scope chain
after the file name (`file.go › Type › method`, hand-rolled treesitter
walk) — and LSP document highlight: rest the cursor on a symbol and its
other uses light up (`updatetime=250`).

## Development

```sh
make test       # mini.test suite, headless, isolated XDG_CONFIG_HOME
make check      # lua_ls type-check of the whole repo (editor-equivalent settings)
make run        # interactive session against this repo without ~/.config
make bootstrap  # install plugins + block until parsers compile
```
