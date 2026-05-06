---
name: sync-agent-assets
description: Synchronize AI agent skills, commands, configs, permissions, hooks, and instructions across Claude Code, Codex CLI, and other Agent Skills-compatible tools. Use when the user asks to pull skills from Claude into Codex, sync Codex work back to Claude, migrate agent commands, reconcile frontmatter, update permissions, or keep agent setup files in parity.
argument-hint: "[source-agent] [target-agent] [asset-type]"
---

# Sync Agent Assets

Use this skill when synchronizing agent setup across Claude Code, Codex CLI,
and other tools that follow the Agent Skills spec.

## Core Rule

Synchronization is additive. Preserve fields, sections, comments, and files
that belong to another agent unless the user explicitly asks to remove them.
Unknown frontmatter keys are compatibility data, not clutter.

## Workflow

1. Identify the source and target agents.
2. Read the source files and the target agent documentation or local help.
3. Compare what the target agent actually supports today.
4. Update shared files first, then agent-specific config files.
5. Verify symlinks, filenames, frontmatter, and config syntax.
6. Report what was synchronized, what has no equivalent, and what remains
   intentionally agent-specific.

## Local Locations

- Public shared skills: `~/.dotfiles/ai/skills/<name>/SKILL.md`
- Private shared skills: `$AI_PRIVATE_CONFIG_DIR/skills/<name>/SKILL.md`
- Claude skills: `~/.claude/skills/<name>/`
- Codex skills: `~/.agents/skills/<name>/`
- Claude commands: `~/.dotfiles/ai/commands/` linked to `~/.claude/commands/`
- Claude settings: `~/.dotfiles/ai/claude-settings.json` linked to `~/.claude/settings.json`
- Codex instructions: `~/.dotfiles/ai/codex-agents.md` linked to `~/.codex/AGENTS.md`
- Codex config: `$AI_PRIVATE_CONFIG_DIR/codex-config.toml` linked to `~/.codex/config.toml`

Run `update_dotfiles` after adding public shared skills or changing symlinked
dotfiles. Run `$AI_PRIVATE_CONFIG_DIR/install.sh` after adding private shared
skills.

## Skill File Rules

- Use `SKILL.md` uppercase. Codex requires it; Claude accepts it.
- Keep required frontmatter fields `name` and `description`.
- Preserve Claude-specific keys such as `allowed-tools`, `argument-hint`,
  `disable-model-invocation`, `user-invocable`, `model`, `context`, and `agent`.
- Preserve Codex-compatible `agents/openai.yaml` metadata when present.
- Put agent-specific behavior in `## Claude Code`, `## Codex`, or similarly
  named conditional sections inside the same skill.
- Do not split one shared workflow into separate agent skills unless the tools
  are fundamentally incompatible.

## Permissions And Commands

Map behavior, not flag names.

- Claude per-command permissions usually live in `allowed-tools`, command
  wrappers, or `~/.claude/settings.json`.
- Codex permission behavior usually maps to `approval_policy`, `sandbox_mode`,
  profiles, rules, hooks, or CLI flags such as `--full-auto`,
  `--ask-for-approval`, `--sandbox`, and
  `--dangerously-bypass-approvals-and-sandbox`.
- Prefer explicit Codex flags like `--sandbox workspace-write` and
  `--ask-for-approval on-request` over deprecated compatibility aliases when
  the current docs recommend that.
- If a Claude command is a Markdown slash command, Codex may not have a direct
  command equivalent. Prefer a shared skill or explicit shell wrapper.
- If a feature has no exact equivalent, document the nearest behavior and the
  gap instead of inventing a silent approximation.

## Verification

Before finishing:

- Confirm each shared skill has `SKILL.md`.
- Confirm symlink destinations exist for both `~/.claude/skills` and
  `~/.agents/skills` when the skill is meant to be shared.
- Use the agent CLI help or official docs before claiming a flag or config key
  is current.
- Validate shell files with `bash -n` and machine-readable config with its
  native parser or a no-op CLI command where available.
- Summarize source files changed, target files affected by symlink, and any
  unsupported agent-specific behavior.
