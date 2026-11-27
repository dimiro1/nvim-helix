# Helix-flavored Neovim

A Neovim 0.12 setup for people who like how [Helix](https://helix-editor.com)
*feels*: pickers for everything, a Space menu that tells you what's next,
LSP actions one keystroke away. It keeps Vim's editing language — motions,
operators, text objects, registers — exactly as you know it.

The rule of thumb: if it's about **finding, navigating, or acting on code**,
it works like Helix. If it's about **editing text**, it's plain Vim. When in
doubt, press `Space` and read the menu.

It also leans on what Neovim already ships. Completion, plugin management,
and LSP are all built in; plugins are only here for things Neovim can't do
on its own.

## Getting started

You need Neovim 0.12.2 or newer, plus a few command-line tools:

```sh
brew install neovim fzf ripgrep tree-sitter-cli
```

Then clone and launch:

```sh
git clone <this repo> ~/.config/nvim
nvim
```

The first launch installs plugins and compiles syntax parsers in the
background. Give it a minute before judging the highlighting.

### Language servers

Install the ones for the languages you use. Each is picked up automatically
when it's on your `PATH`:

| Language | Install |
|---|---|
| Go | `go install golang.org/x/tools/gopls@latest` |
| TypeScript / JavaScript | `npm i -g typescript-language-server` |
| Python | `uv tool install pyright` |
| Java | `brew install jdtls` |
| Lua | `brew install lua-language-server` |

### Optional extras

| Tool | What it unlocks | Install |
|---|---|---|
| `zoxide` | jump to recently visited directories (`Space z`) | `brew install zoxide` |
| `claude` | Claude Code inside the editor (`:ClaudeCode`) | `brew install --cask claude-code` |
| `lsof` | `:KillPort` | already on macOS and most Linux systems |

### Updating plugins

Run `:lua vim.pack.update()`, look over what changed, and `:write` to
accept. Plugin versions are pinned in `nvim-pack-lock.json`, so every
machine gets the same ones.

## Finding things

Everything starts from `Space`. Press it and wait — a menu shows what each
next key does. The same help appears after `g`, `z`, `[`, `]`, and `Ctrl-w`.

| Key | Opens |
|---|---|
| `Space Space` | **everything** — files, open buffers, symbols, and commands in one list |
| `Space f` | files in the project (`Space F`: from the current directory, dotfiles included) |
| `Space /` | search file contents across the project |
| `Space b` | open buffers |
| `Space s` / `Space S` | symbols in this file / the whole project |
| `Space d` / `Space D` | diagnostics in this file / the whole project |
| `Space g` | files with uncommitted changes |
| `Space j` | jump list |
| `Space ?` | all commands, with their help shown alongside |
| `Space '` | reopen the last picker where you left it |

Inside any picker:

| Key | Does |
|---|---|
| `Enter` | open |
| `Ctrl-s` / `Ctrl-v` / `Ctrl-t` | open in a horizontal split / vertical split / new tab |
| `Ctrl-d` / `Ctrl-u` | scroll the preview down / up |
| `F1` | list every picker key |

`Ctrl-u` scrolls the preview rather than clearing what you typed; use
`Ctrl-w` to delete backwards a word at a time.

## Working with code

| Key | Does |
|---|---|
| `gd` `gy` `gi` `gr` | go to definition / type / implementation / references |
| `Space k` | show documentation for the symbol under the cursor |
| `Space r` | rename it everywhere |
| `Space a` | code actions (quick fixes, imports, refactors) |
| `]f` `[f` · `]t` `[t` · `]a` `[a` | next / previous function · type · argument |
| `]g` `[g` | next / previous git change |
| `gw` | label every word on screen and jump to one by typing its label |
| `Space c` | comment / uncomment |
| `Space y` / `Space p` | yank to / paste from the system clipboard |

Text objects work with any operator (`d`, `c`, `y`, `v`, …):

| Object | Selects |
|---|---|
| `if` / `af` | inside / around a function |
| `ic` / `ac` | inside / around a type (class, struct, interface) |
| `ia` / `aa` | an argument |
| `iq` / `aq` | inside / around the nearest quotes, whichever kind |
| `im` / `am` | inside / around the nearest brackets or quotes |

`ys`, `cs`, and `ds` add, change, and delete surrounding pairs.

A few things happen on their own. Resting the cursor on a symbol highlights
its other uses. When you scroll past the top of a long function, its
signature sticks to the top of the window. Completion pops up as you type —
`Ctrl-n` / `Ctrl-p` to move, `Ctrl-y` to accept.

> `gw` replaces Vim's "format without moving the cursor". Use `gq` to format.

## Moving around the project

| Key | Does |
|---|---|
| `Space E` | toggle the project tree, opened at the current file |
| `Space .` | browse the current file's folder, one level at a time |
| `Space e` | search every folder in the project, then browse from the one you pick |
| `Space z` | recently visited directories — `Enter` to switch, `Ctrl-f` to switch and pick a file |
| `Space W` | switch git worktree (see below) |

### The project tree

Hidden files show; ignored files and `.git` don't.

| Key (in the tree) | Does |
|---|---|
| `Enter` / `o` | open a file, or expand a folder |
| `C` | show only changed files (staged, unstaged, and new) |
| `/` | filter by name; `F` clears the filter |
| `>` / `<` | make the tree wider / narrower (`2>` for double) |
| `E` / `W` | expand / collapse everything |
| `g?` | every tree key |

The tree keeps its width while you toggle it, and follows you when you
switch worktrees.

### Worktrees

`Space W` lists the git worktrees of the current repository. Switching saves
your open files and window layout for the worktree you're leaving and
restores the ones for the worktree you're entering — like separate editor
windows, one per branch. The first visit to a worktree opens the file picker.
Save your changes first; switching is blocked while buffers are unsaved.

## The command line

Typing after `:` shows matching commands as you go — `Ctrl-n` / `Ctrl-p` to
move through them. Up and Down walk your command history whatever you've
typed so far, and `Ctrl-k` deletes to the end of the line. `q:` opens the
history in an editable window.

## Windows and the terminal

`Space w` is the window menu, the same as `Ctrl-w`. `Ctrl-w <` and
`Ctrl-w >` always move the divider left and right, whichever side of it
you're on.

`Ctrl-\` toggles a floating terminal. Press `Esc Esc` to get back to normal
mode inside it.

## Git

| | |
|---|---|
| `:Git` (or `:G`) | interactive status — stage, unstage, commit; `g?` lists the keys |
| `:Git blame` | who changed each line |
| `:Gdiffsplit` | compare the file against what's staged |
| `Space G` | show changes inline in the current file |
| `Space l` | copy a link to the current line on GitHub, GitLab, or Codeberg (select lines first for a range) |
| `Space L` | open that link in the browser |

Links point at the exact commit, so they keep working after the file
changes. You'll get a warning if uncommitted edits mean the link won't
match what you see.

## Claude Code

Neovim talks to Claude Code the same way VS Code does: Claude sees the file
you're in, your selection, and your diagnostics, and proposes edits as diffs
you can review.

- `:ClaudeCode` opens Claude in a split on the right (`--resume` or
  `--continue` to pick up an earlier conversation).
- `:'<,'>ClaudeCodeSend` sends the selected lines.
- `:ClaudeCodeAdd %` adds the current file.
- `:ClaudeCodeTreeAdd` adds the file under the cursor in the project tree.

Already running `claude` in another terminal? Type `/ide` there to connect
it. When Claude proposes an edit, `:w` accepts it and `:q` rejects it — and
you can tweak the proposal before saving.

`Ctrl-o` in Claude's window always reaches Claude (its transcript view,
which you can scroll with the keyboard), even after `Esc Esc` has taken
you out of typing mode. The same goes for every terminal: there, `Ctrl-o`
never jumps back to the previous file.

## Reading the screen

**The status bar** keeps the file name centered, with context on either
side:

```
 NOR  main (kelowna) +3 ~1      lua/config/init.lua › M › setup      jdtls 45%  E:1 W:2  12:4  LF  lua
```

Reading left to right: the mode, the git branch (and worktree), lines
changed but not yet staged, the file and the function you're in, a busy
language server, problems, cursor position, line endings, and file type.

- The **mode** badge changes color with the mode; the line:column at the
  right matches it.
- **Changes** count lines added (`+`), changed (`~`), and removed (`-`)
  that aren't staged yet.
- A **`[+]`** after the name means unsaved changes.
- **Problems** in brackets, like `[E:3]`, are project-wide; the plain ones
  are for this file.
- While a language server is loading or indexing, its name and progress
  show on the right.
- Help pages, the terminal, the project tree, and other non-file windows get
  a short label instead — `help › options`, `terminal › zsh`.

There is **no tab bar**. Switch files with `Space b`, which lists the
open buffers, most recent first. Tab pages still work (`gt` cycles
through them); there's just no bar showing them.

**Diagnostics** appear at the end of the offending line. On the line under
the cursor they expand in full below it.

## Themes

The default theme is **modus-vivendi-deuteranopia**: white text on a black
background, with diffs in blue (added) and yellow (removed) instead of
green and red, so they stay distinct for red–green color blindness. It
comes from Protesilaos Stavrou's Emacs themes
([license](docs/modus-LICENSE)). The whole collection is installed —
switch with `:colorscheme`:

- **Modus**, high-contrast and color-blind friendly: `modus-operandi`
  (light) and `modus-vivendi` (dark), each also as `-tinted`,
  `-deuteranopia` (red–green), and `-tritanopia` (blue–yellow).
- **Standard**, the look of plain Emacs: `standard-light`, `standard-dark`,
  their `-tinted` variants, `standard-adwaita`, and `standard-wombat`.

Also installed: **anysphere**, a charcoal background with teal keywords,
pink strings, and blue types, ported from an Emacs theme of the same name
([license](docs/anysphere-LICENSE)); plus `rose-pine`, `melange`,
`oshen-night`, and `oshen-day`.

On terminals that support it (Ghostty, for one), the window's tabs and title
bar take on the editor's background color.

## Utilities

`:KillPort [port]` stops whatever is listening on a TCP port. It asks for the
port if you leave it out, lets you pick when there are several processes,
and asks before killing anything.

## Hacking on this config

```sh
make run        # try this checkout without touching ~/.config/nvim
make test       # run the test suite
make check      # type-check the Lua
make bootstrap  # install plugins and wait for parsers to compile
```

Why things are the way they are — the choice of each plugin, the keybinding
boundary between Helix and Vim — is written up in [`docs/adr/`](docs/adr/).

---

_Generated with Claude AI — please review before distribution._
