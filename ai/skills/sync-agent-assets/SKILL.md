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

## Locate The Source Of Truth

Treat agent runtime directories as entrypoints, not necessarily as the files to
edit. A runtime file may be a symlink, generated output, a copied install
artifact, or the true source file.

1. Start from the active location used by the agent. Common examples include
   project-local skill directories such as `./.agents/skills/<name>/` or
   `./.claude/skills/<name>/`, global locations such as
   `~/.claude/skills/<name>/`, `~/.agents/skills/<name>/`,
   `~/.codex/skills/<name>/`, `~/.claude/commands/`,
   `~/.claude/settings.json`, `~/.codex/AGENTS.md`,
   `~/.codex/config.toml`, and `~/.codex/hooks.json`.
   For Codex skills, check both `~/.agents/skills/<name>/` and
   `~/.codex/skills/<name>/` when they exist. Different installers and Codex
   versions may use one as the runtime location, a mirror, or a compatibility
   path.
2. If the user asks for project-local skills or the skill lives under the
   current repository, treat the current repository as the working scope. Edit
   files in that repo, preserve its conventions, and do not move the skill to a
   global agent directory unless the user explicitly asks for a global install.
3. Check whether the active file or directory is a symlink. Use `ls -l`,
   `readlink`, or `pwd -P` to identify the real path.
4. If it is a symlink, follow it to the source repository or source directory.
   Edit the source, not the runtime symlink target, unless the user explicitly
   asks for a local-only runtime change.
5. Read the source repository's README, install script, or setup docs to learn
   how changes are propagated back into the agent runtime directories.
6. If the active file is not a symlink, inspect nearby docs and config before
   deciding whether it is the canonical file or generated state.
7. When source and runtime locations differ, report both paths and the command
   or setup step used to refresh the runtime location.

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
- Confirm the active agent locations point to the source files that were edited
  when symlinks or generated installs are involved.
- Use the agent CLI help or official docs before claiming a flag or config key
  is current.
- Validate shell files with `bash -n` and machine-readable config with its
  native parser or a no-op CLI command where available.
- Summarize source files changed, target files affected by symlink, and any
  unsupported agent-specific behavior.
