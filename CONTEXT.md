# Helix-on-Neovim

A personal Neovim configuration that recreates Helix's interaction layer — pickers, window management, search — on stock Neovim, while keeping Vim's editing grammar (motions, operators, marks, registers).

## Language

**Picker**:
An interactive overlay for selecting one item among many (files, buffers, symbols, diagnostics, …) with fuzzy filtering and an always-visible preview pane. All item kinds share one picker surface with consistent behavior.
_Avoid_: finder, fuzzy finder, selector

**Everything picker**:
The one picker whose result list spans multiple item kinds at once — files, buffers, document symbols, and commands — matched by name, so you search without first choosing the kind. Distinct from global search, which matches file contents.
_Avoid_: search everywhere, omni picker, global picker

**Fidelity Rule**:
The boundary that decides every keybinding question: Helix owns the leader layer and LSP gotos; Vim owns the grammar. Additions in Vim-idiomatic style are allowed; overriding the grammar with Helix keys is not.

**Space mode**:
The Space-prefixed key layer replicated from Helix: pickers, LSP actions, clipboard operations, comment toggling, window-mode alias.
_Avoid_: leader menu, which-key menu

**Grammar**:
Vim's editing language — motions, operators, text objects, marks, registers, search keys — kept stock per the Fidelity Rule.
_Avoid_: movements

**Native-first**:
The principle that a built-in Neovim capability is used whenever it covers the Helix behavior at acceptable fidelity; a plugin must provide something Neovim structurally lacks to earn its place.

**Infobox**:
The auto-appearing panel that lists available continuation keys after a prefix (Space, `g`, `z`, `Ctrl-w`) is pressed. Helix's term; the core discoverability feature of the leader layer.
_Avoid_: which-key menu, cheatsheet

**Breadcrumbs**:
The chain of named scopes enclosing the cursor (`Type › method`), rendered in the statusline center segment next to the file name — not in a winbar, which was tried and vetoed because it costs a fixed extra line at the top of every window.

**Workspace**:
A git worktree root plus its saved editing state (buffers, windows, tabs). Pickers operate at the workspace root; switching worktrees swaps workspaces — leaving saves the state, returning restores it.
_Avoid_: session (that's the persistence mechanism, not the concept), project
