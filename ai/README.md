# AI Tools Setup

Configuration for Claude Code and other AI tools. Files here are symlinked to
`~/.claude/` via `bashrc_source`.

## annoying-claude

Use `annoying-claude` instead of `claude` to make the tmux pane turn orange when
Claude is awaiting your input. This helps you notice when Claude needs attention.

```bash
annoying-claude "your prompt"
```

Requires `terminal-notifier` (`brew install terminal-notifier`) and tmux.
