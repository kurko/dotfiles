# Dotfiles Repository

Personal dotfiles managed via symlinks. The `update_symlinks` function in
`bashrc_source` links configuration files to their expected locations.

## AI Skills

The `ai/skills/` directory contains skills shared across AI coding agents.
Each skill lives in its own directory with a `SKILL.md` file (uppercase
required by Codex; Claude Code accepts either case).

### Symlink Destinations

`update_symlinks` in `bashrc_source` links each skill directory to:

- `~/.claude/skills/<name>/` — for Claude Code
- `~/.agents/skills/<name>/` — for Codex CLI (and other agents following the
  Agent Skills spec)

Skills are symlinked as directories, so adding or renaming files inside a
skill takes effect immediately without re-running the install.

### Other AI Configuration

| Source | Destination | Agent |
|--------|------------|-------|
| `ai/commands/` | `~/.claude/commands/` | Claude Code only |
| `ai/agents/` | `~/.claude/agents/` | Claude Code only |
| `ai/hooks/` | `~/.claude/hooks/` | Claude Code only |
| `ai/codex-agents.md` | `~/.codex/AGENTS.md` | Codex CLI |
| `ai/codex-config.toml` | `~/.codex/config.toml` | Codex CLI |
| `ai/claude-settings.json` | `~/.claude/settings.json` | Claude Code |

### Writing New Skills

Skills should work across all agents. Use `SKILL.md` (uppercase) as the
filename. Include all frontmatter fields — agents ignore fields they don't
understand. If a skill needs agent-specific instructions (e.g., subagent
spawning), use conditional sections (`## Claude Code`, `## Codex`) within
the same file.
