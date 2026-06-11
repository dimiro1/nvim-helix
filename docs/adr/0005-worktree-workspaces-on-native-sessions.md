# Worktree workspaces: native sessions keyed by worktree root, no plugin

The user switches git worktrees constantly and wants each worktree to own its editing state — buffers, windows, tabs saved on leave, restored on return (a *Workspace*, see CONTEXT.md). We rolled this ourselves on `:mksession` keyed by worktree root: `git worktree list --porcelain` feeds an fzf-lua picker (`Space W` / `:Worktrees`); switching saves the current workspace, wipes buffers, `:cd`s (which feeds zoxide and refreshes the statusline branch), then restores the target's session — or opens the file picker on first visit. Switches are blocked while modified buffers exist. Switch-only by design: creating/deleting worktrees stays in the terminal, like the rest of git.

## Considered Options

- **git-worktree.nvim** (polarmutex fork) — has the worktree picker but the opposite state model: it re-points current buffers at the target worktree ("carry the window along") instead of per-worktree buffer sets; telescope-flavored. The carry-along idea survives as a possible future picker action.
- **auto-session** — the right state model (sessions keyed by cwd) but automagic for *every* directory, a new plugin, and a wrapper around the native `:mksession` we can call directly.
- **mini.sessions** — mechanism-only (named sessions); the worktree keying and switch pipeline would still be ours, and raw `mksession` keeps full control. No marginal win.

Per ADR 0004: sessions are native, worktree listing is the git CLI, the picker engine already exists — nothing here is structurally missing from Neovim, so no plugin earns a place.
