# Helix-flavored Neovim

A Neovim 0.12 configuration that recreates [Helix](https://helix-editor.com)'s
interaction layer — pickers, window management, search, LSP ergonomics — on
stock Neovim, while keeping Vim's editing grammar untouched.

Two laws decide everything here (see `CONTEXT.md` and `docs/adr/`):

1. **Fidelity Rule** — Helix owns Space mode and LSP gotos; Vim owns the
   grammar (motions, operators, text objects, marks, registers, search).
2. **Native-first** — a plugin must provide something Neovim structurally
   lacks. Plugins supply pickers (fzf-lua), a Git-filterable project tree
   (nvim-tree), tree-sitter features, surrounds, incremental label jumps
   (flash.nvim), small editing/UI modules (mini.nvim), and colorschemes.
   Plugin management is native `vim.pack`; completion is the native
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
| `jdtls` | Java LSP (Eclipse JDT.LS launcher) | `brew install jdtls` |
| `lua-language-server` | Lua LSP (this config itself) | `brew install lua-language-server` |
| `zoxide` (optional) | recent-dirs picker, `:Z` | `brew install zoxide` |
| `lsof` | `:KillPort` process lookup | preinstalled on macOS/Linux |

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
| `Space Space` | everything picker — files, buffers, document symbols, and commands in one list, matched by name |
| `Space f` / `Space F` | file picker (workspace root / cwd, dotfiles shown) |
| `Space b` `Space j` `Space g` | buffer / jumplist / changed-file pickers |
| `Space s` / `Space S` | document / workspace symbol picker |
| `Space d` / `Space D` | buffer / workspace diagnostics picker |
| `Space /` | global search (live grep) |
| `Space ?` | command palette — preview shows the command's `:help` entry, else its description |
| `Space '` | resume last picker |
| `Space e` | directory search across the whole workspace → explorer at the pick |
| `Space E` | toggle project tree at the workspace root, revealing the current file |
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
| `iq`/`aq` `im`/`am` | quotes (any of `"` `'` `` ` ``) / closest surrounding pair text objects (mini.ai; stock `i(`, `ib`, … untouched) |
| `ys` `cs` `ds` | surround (tpope) |
| `Space G` | toggle inline git diff overlay (mini.diff) |
| `Space l` / `Space L` / `:Permalink [open]` | copy / browse a git permalink — commit-pinned URL to the current file and line (range in visual mode) on GitHub/GitLab/Codeberg; warns when uncommitted changes make it stale |
| `Ctrl-\` | toggle floating terminal (`Esc Esc` leaves terminal mode) |

Everything else is stock Vim. Pressing `Space`, `g`, `z`, `Ctrl-w`, `[`, `]`
pops a Helix-style infobox (mini.clue) listing the continuations.

At the native `:` command line, completion opens as you type. `Ctrl-n` and
`Ctrl-p` move through matches; Up and Down recall command history regardless
of the typed prefix; `Ctrl-k` deletes from the cursor to the end. `q:` opens
the editable command history, and `:history` lists it.

## Project tree

`Space E` opens a persistent sidebar at the current file's workspace root.
Inside the tree:

| Key | Action |
|---|---|
| `Enter` / `o` | open file or expand/collapse directory |
| `C` | toggle changed files only (staged, unstaged, and untracked) |
| `/` | filter filenames with a Vim regular expression; `Enter` keeps the filter |
| `F` | clear the filename filter, keeping the Git filter |
| `>` / `<` | widen / narrow by 5 columns; counts work, e.g. `2>` adds 10 |
| `E` / `W` | expand / collapse all directories |
| `g?` | show all tree keybindings |

`/` expands nested directories before filtering, subject to nvim-tree's
300-folder discovery limit. Dotfiles are visible; Git metadata and ignored
files are hidden. The changed-only view follows working-tree Git status;
committed branch changes are outside its scope.

Width commands work even while an editing window is focused:

```vim
:NvimTreeResize +5
:NvimTreeResize -5
:NvimTreeResize 40
```

Width adjustments persist when toggling the tree during the current Neovim
session. `Space e`, `Space .`, and `Space g` keep their existing pickers.
An open sidebar follows worktree switches, while focus returns to the
target workspace's editing window.

## Utility commands

`:KillPort [port]` — kill the process listening on a TCP port. Prompts for
the port when omitted, offers a picker when several processes listen, and
confirms before sending SIGKILL. Only LISTEN-state sockets match, so a
process merely connected to the port is never offered as a target.

## Personalization layer

Mirrors the user's actual Helix `config.toml`, not stock defaults: relative
line numbers, soft wrap, bordered popups, a `┊` active-scope indent guide, end-of-line
diagnostics with expanded cursor-line rendering, colored `❮N❯/❮I❯/❮V❯` mode
segment with git branch and worktree name (`main (kelowna)`), centered
filename, rich right-side statusline
segments, and a bufferline that appears only with 2+ buffers (hand-rolled
native `'tabline'`). Colorscheme: `anysphere`, a local port of
`~/.emacs.d/themes/anysphere-theme.el`: charcoal background, italic grey
comments, teal keywords, pink strings, peach declarations, gold calls and
numbers, blue types, and lavender properties. It covers native completion,
LSP tokens and diagnostics, pickers, the project tree, and inline diffs.
Use `:colorscheme anysphere` to apply it to an existing session;
`rose-pine`, `melange`, `oshen-night`, and `oshen-day` remain available.
Palette attribution and license: [docs/anysphere-LICENSE](docs/anysphere-LICENSE).
The scheme's background is reported to the terminal with OSC 11 (and
reset with OSC 111 on exit/suspend), the same escape Helix emits — so
Ghostty colors its tabs and titlebar to match the editor theme.
The `┊` indent guide marks only the scope at the cursor (mini.indentscope),
drawn instantly with no animation, rather than every indent level.

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
