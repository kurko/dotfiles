# AI Tools Setup

Configuration for AI coding assistants. Files here are symlinked to tool-specific
locations via `update_symlinks` in `bashrc_source`.

## File Map

| Source File | Symlinked To | Purpose |
|-------------|-------------|---------|
| `claude.md` | `~/.claude/CLAUDE.md` | Claude Code instructions |
| `claude-settings.json` | `~/.claude/settings.json` | Claude Code settings |
| `codex-agents.md` | `~/.codex/AGENTS.md` | Codex CLI instructions |
| `aider.conf.yml` | `~/.aider.conf.yml` | Aider configuration |
| `skills/*/` | `~/.claude/skills/*/` | Claude skills (symlinked individually) |
| `skills/*/` | `~/.agents/skills/*/` | Codex skills (symlinked individually) |
| `commands/*/` | `~/.claude/commands/*/` | Claude commands (Claude-only) |
| `agents/*/` | `~/.claude/agents/*/` | Claude agents (Claude-only) |
| `hooks/*/` | `~/.claude/hooks/*/` | Claude hooks (Claude-only) |

## Skills

Skills use the `SKILL.md` filename (uppercase) to satisfy both Claude Code
(accepts either case) and Codex CLI (requires uppercase). Each skill directory
is symlinked independently to both `~/.claude/skills/` and `~/.agents/skills/`,
so private skills in either location don't leak to the other.

## Claude-Only Features

Commands, agents, and hooks have no Codex equivalent and are only symlinked
to `~/.claude/`.

## annoying-claude

Use `annoying-claude` instead of `claude` to make the tmux pane turn orange when
Claude is awaiting your input. This helps you notice when Claude needs attention.

```bash
annoying-claude "your prompt"
```

Requires `terminal-notifier` (`brew install terminal-notifier`) and tmux.

## Codex equivalents

Use `codex-new` to start Codex with the normal interactive defaults:
`--sandbox workspace-write` and `--ask-for-approval on-request`.

Use `annoying-codex` for the same tmux attention behavior with Codex. It runs
`codex-new` through the attention-color wrapper.

Use `dangerous-codex` only in externally sandboxed environments. It runs Codex
with `--dangerously-bypass-approvals-and-sandbox`, which disables approvals and
Codex sandboxing.

Codex attention alerts are configured in the private Codex config file through
`PermissionRequest`, `Stop`, and `UserPromptSubmit` hooks. If the alert color
gets stuck after Codex exits, press `Option-Esc` to force-reset the tmux pane.
