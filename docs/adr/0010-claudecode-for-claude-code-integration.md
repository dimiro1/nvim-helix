# claudecode.nvim for Claude Code integration

The user requested coder's claudecode.nvim. The Claude Code CLI connects to
IDEs through a WebSocket MCP server that it finds via a lock file in
`~/.claude/ide/`. That server sends the current selection and diagnostics to
Claude and opens Claude's proposed edits as diffs. Neovim has no such server,
so the plugin passes ADR 0004's bar.

## Consequences

- Managed by native vim.pack, with its revision recorded in the lockfile.
- Uses the `native` terminal provider. The README's snacks.nvim dependency
  is optional, and adding it would pull in a large plugin to show one split.
- Commands only, as with Fugitive (ADR 0009): `:ClaudeCode`,
  `:'<,'>ClaudeCodeSend`, `:ClaudeCodeAdd %`. The README's `<Leader>a*`
  keys would shadow Helix's `Space a` code action (ADR 0002). Diffs are
  accepted with `:w` and rejected with `:q` in the proposal buffer.
- The server starts with Neovim (`auto_start`), so a `claude` started in
  any terminal can attach to it with `/ide`.
- `make test` sets `CLAUDE_CONFIG_DIR` to a directory inside `.testenv`.
  Each test child starts its own server, and their lock files must not
  appear in the real `~/.claude/ide`.
