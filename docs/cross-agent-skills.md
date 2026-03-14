# Cross-Agent Skills Specification

Make skills in the dotfiles repo work across both Claude Code and Codex CLI
(and potentially other AI agents in the future).

## Overview & Goals

The dotfiles repo at `~/.dotfiles/ai/skills/` contains skill definitions used
by Claude Code. Codex CLI has adopted the [Agent Skills](https://agentskills.io)
open standard, which expects skills at `~/.agents/skills/<name>/SKILL.md`
(uppercase filename required). Claude Code accepts both `skill.md` and
`SKILL.md`.

**Goals:**

1. Rename all `skill.md` files to `SKILL.md` so both agents can load them.
2. Dual-symlink public skills to `~/.claude/skills/` and `~/.agents/skills/`.
3. Dual-symlink private skills (from `~/.private-prompts/`) to both agents.
4. Add conditional sections within skills that have agent-specific behavior
   (e.g., subagent spawning in Claude vs. Codex's multi-agent approach).
5. Merge changes from two laptops cleanly (this laptop has renames + Codex
   support; the other has skill content edits).

**Non-goals:**

- Rewriting skills to be agent-neutral. Skills keep Claude Code-specific
  frontmatter fields (Codex ignores unknown fields).
- Moving `things3-applescript.md` into a directory structure (deferred).
- Committing `codex-agents.md` or `codex-config.toml` in the same commit as
  skill changes.

## Technical Architecture

### Current State

```
~/.dotfiles/ai/
├── skills/
│   ├── clipboard/SKILL.md          (renamed from skill.md, staged)
│   ├── code-review/SKILL.md        (renamed from skill.md, staged)
│   ├── create-and-edit-skills/SKILL.md  (modified, staged)
│   ├── git-commit/SKILL.md         (renamed from skill.md, staged)
│   ├── rails-app-generator/SKILL.md
│   ├── review-recommendations/SKILL.md
│   ├── rspec-rails/                (not renamed yet — already SKILL.md or missing)
│   ├── tdd-bug-fix/SKILL.md
│   ├── tool-agent-browser/SKILL.md
│   ├── working-off-of-todo-files/SKILL.md
│   ├── write-task/SKILL.md
│   └── things3-applescript.md      (loose file, not in a directory — ignored)
├── codex-agents.md                 (new, untracked)
├── codex-config.toml               (new, untracked)
├── claude-settings.json            (modified, machine-specific — excluded)
└── commands/
    └── help-me-spec.md             (modified)
```

### Symlink Flow

`bashrc_source` function `update_symlinks()` handles all linking. The relevant
section (lines 81-109 of `/Users/alex/.dotfiles/bashrc_source`):

```bash
# Public commands/skills/agents from dotfiles
for f in ~/.dotfiles/ai/skills/*; do
  [ -e "$f" ] && ln -nfs "$f" ~/.claude/skills/
done

# Codex skills (spec requires ~/.agents/skills/, not ~/.codex/skills/)
mkdir -p ~/.agents/skills
find ~/.agents/skills -type l -lname "$HOME/.dotfiles/*" -delete 2>/dev/null || true
for f in ~/.dotfiles/ai/skills/*/; do
  [ -d "$f" ] && ln -nfs "$f" ~/.agents/skills/
done
```

Key difference: The Claude loop links all entries (`*`), including loose files.
The Codex loop links only directories (`*/`), which is correct since skills must
be in `<name>/SKILL.md` directories. The loose `things3-applescript.md` is
naturally excluded from Codex by this pattern.

## Migration Path

The merge involves two laptops with divergent changes. This is the step-by-step
workflow.

### Step 1: Stash local changes on this laptop

```bash
cd ~/.dotfiles
git stash push -m "cross-agent-skills: renames + codex support"
```

**Gotcha:** `git stash` with renames (`skill.md` -> `SKILL.md`) can be tricky.
Git tracks renames as delete + add. The stash will preserve this correctly, but
when popping, if the other laptop's changes also touched the old filename
(`skill.md`), there will be a conflict. See Edge Cases section.

### Step 2: Pull the other laptop's changes

```bash
git pull origin master
```

This brings in the skill content edits (e.g., code-review changes from the
other laptop). These edits target `skill.md` (lowercase), since the other
laptop does not have the renames yet.

### Step 3: Pop the stash

```bash
git stash pop
```

**Expected conflicts:** If the other laptop edited `code-review/skill.md` and
this laptop renamed it to `code-review/SKILL.md`, git will report a conflict.
Resolution:

1. Accept the content from the other laptop's edit (the newer content).
2. Apply it to the uppercase filename (`SKILL.md`).
3. Remove the lowercase file if git left it behind.

```bash
# For each conflicted skill:
git show stash@{0}:ai/skills/code-review/SKILL.md > /dev/null 2>&1
# If conflict, manually merge content into SKILL.md:
mv ai/skills/code-review/skill.md ai/skills/code-review/SKILL.md
git add ai/skills/code-review/SKILL.md
git rm ai/skills/code-review/skill.md 2>/dev/null || true
```

### Step 4: Verify all renames are complete

```bash
# Should return nothing — all skill files should be uppercase
find ai/skills -name "skill.md" -type f
```

### Step 5: Stage and commit (see Commit Strategy below)

## Skill File Convention

### Filename

Always `SKILL.md` (uppercase). Claude Code accepts both cases; Codex requires
uppercase. This is already documented in
`/Users/alex/.dotfiles/ai/skills/create-and-edit-skills/SKILL.md` line 37.

### Frontmatter

All frontmatter fields are always included, even Claude Code-only fields.
Codex ignores unknown fields, so there is no harm. This keeps skills
self-documenting and avoids a "which fields do I include?" decision for each
new skill.

```yaml
---
name: skill-name
description: What this skill does
# Claude Code-only fields (Codex ignores these):
argument-hint: "[arg]"
allowed-tools: Read, Grep
context: fork
agent: Explore
---
```

### Conditional Sections for Agent-Specific Behavior

Some skills use Claude-specific concepts like "spawn a subagent." Rather than
maintaining separate files, use conditional sections within the same SKILL.md.

**Format:**

```markdown
# Skill Title

[Shared instructions that work for any agent]

## Claude Code

[Instructions specific to Claude Code, e.g., subagent spawning]

## Codex

[Instructions specific to Codex CLI, e.g., multi-agent delegation]
```

**Which skills need this today:**

| Skill | Why |
|-------|-----|
| `code-review` | Uses "spawn a subagent" extensively (Phase B verification). Codex uses `multi_agent = true` in config instead. |

**Which skills do NOT need this:**

Most skills (clipboard, git-commit, write-task, etc.) use generic instructions
that work across agents. Only add conditional sections when the agent dispatch
mechanism genuinely differs.

### Allowed-Tools Field

The `allowed-tools` frontmatter field uses Claude Code syntax. Codex ignores
unknown frontmatter fields, so this is kept as-is. No translation needed.

## Symlink Architecture

### Public Skills (from dotfiles)

Source: `~/.dotfiles/ai/skills/<name>/SKILL.md`

Destinations:
- `~/.claude/skills/<name>/` (symlink to directory)
- `~/.agents/skills/<name>/` (symlink to directory)

Both are handled by `update_symlinks()` in
`/Users/alex/.dotfiles/bashrc_source` (lines 85-87 for Claude, lines 104-109
for Codex). No changes needed to `bashrc_source` — the Codex section already
exists in the current working tree.

### Private Skills

Source: `~/.private-prompts/skills/<name>/SKILL.md`

Current state: The install script at `~/.private-prompts/install.sh` only
symlinks to `~/.claude/skills/`:

```bash
for f in "$SCRIPT_DIR"/skills/*; do
  [ -e "$f" ] && ln -nfs "$f" ~/.claude/skills/
done
```

**Required change** — add Codex linking to `~/.private-prompts/install.sh`:

```bash
# After the existing Claude skills loop, add:

# Codex skills (private)
mkdir -p ~/.agents/skills
for f in "$SCRIPT_DIR"/skills/*/; do
  [ -d "$f" ] && ln -nfs "$f" ~/.agents/skills/
done
```

Note the trailing `/` in the glob and the `-d` test, matching the pattern used
in `bashrc_source` for Codex. This ensures only directories are linked (not
loose files).

The install script also needs the stale-symlink cleanup pattern from
`bashrc_source`:

```bash
find ~/.agents/skills -type l -lname "$HOME/.private-prompts/*" -delete 2>/dev/null || true
```

**Important:** The `~/.private-prompts/` repo is separate from dotfiles. The
install.sh change must be committed there, not in the dotfiles repo.

## Create-and-Edit-Skills Template

The template skill at
`/Users/alex/.dotfiles/ai/skills/create-and-edit-skills/SKILL.md` already
reflects the cross-agent setup:

- Line 30: Location table shows both `~/.claude/skills/` and
  `~/.agents/skills/` as symlink destinations.
- Line 37: Documents `SKILL.md` (uppercase) as the required filename.
- Line 39-41: Documents both `update_dotfiles` and `install.sh` as symlink
  scripts.

No further changes needed to this template for the initial cross-agent work.

**Future consideration:** When the first skill genuinely needs conditional
sections, add a "Conditional Sections" heading to the template with the
`## Claude Code` / `## Codex` pattern and guidance on when to use it.

## Commit Strategy

Split into three separate commits, in this order:

### Commit 1: Skill renames and content changes

- All `skill.md` -> `SKILL.md` renames
- Content edits merged from the other laptop
- Updates to `create-and-edit-skills/SKILL.md`
- Changes to `ai/commands/help-me-spec.md`
- Changes to `ai/README.md`

This is the main cross-agent compatibility commit.

### Commit 2: Codex configuration files

- `ai/codex-agents.md` (new file, symlinked to `~/.codex/AGENTS.md`)
- `ai/codex-config.toml` (new file, symlinked to `~/.codex/config.toml`)

Separate because Codex config is independent of the skill format changes and
may need different review/iteration.

### Commit 3 (separate repo): Private-prompts install.sh

- Update `~/.private-prompts/install.sh` to dual-link to `~/.agents/skills/`
- Rename any private `skill.md` files to `SKILL.md`

This commit happens in the `~/.private-prompts/` repository, not in dotfiles.

### Excluded from all commits

- `ai/claude-settings.json` — contains machine-specific paths (e.g., MCP
  server paths with machine-specific directories). Reset with
  `git checkout ai/claude-settings.json` before committing.
- `ai/skills/things3-applescript.md` — loose file, not in a skill directory.
  Deferred to a future cleanup.

## Edge Cases & Gotchas

### 1. Git stash + rename interaction

Git represents renames as delete + add. When the stash contains a rename
(`skill.md` -> `SKILL.md`) and the pulled changes modify the old name
(`skill.md`), `git stash pop` will report a conflict on the deleted file.

**Resolution:** For each conflicted skill, take the content from whichever
source is newer, place it in `SKILL.md`, and ensure `skill.md` is removed.

### 2. Case-insensitive filesystems (macOS default)

macOS with APFS (case-insensitive by default) treats `skill.md` and `SKILL.md`
as the same file. The `git mv skill.md SKILL.md` works because git tracks the
rename internally, but filesystem operations outside git (e.g., `mv`) may
silently no-op.

**Mitigation:** Always use `git mv` for the rename, never raw `mv`. If a raw
rename is needed, use a two-step approach:

```bash
mv skill.md skill.md.tmp
mv skill.md.tmp SKILL.md
```

### 3. Stale symlinks after rename

After renaming `skill.md` to `SKILL.md`, existing symlinks in `~/.claude/skills/`
and `~/.agents/skills/` point to the directory, not the file, so they remain
valid. No symlink breakage occurs from the rename.

### 4. Loose files in skills directory

`things3-applescript.md` sits directly in `ai/skills/` without a containing
directory. The Claude symlink loop picks it up (links all entries); the Codex
loop ignores it (links only directories). This is acceptable for now. If it
needs to work in Codex later, move it to `ai/skills/things3-applescript/SKILL.md`.

### 5. Codex multi_agent config

The Codex config at `/Users/alex/.dotfiles/ai/codex-config.toml` sets
`multi_agent = true`. This is required for skills like code-review that
instruct the agent to delegate to sub-processes. Without it, Codex would
ignore subagent instructions silently.

### 6. Private skills directory may not exist

The `~/.private-prompts/skills/` directory does not currently exist on this
machine (verified during exploration). The install.sh update should handle this
gracefully — the glob `"$SCRIPT_DIR"/skills/*/` simply matches nothing if the
directory is empty or missing.

## Open Questions

1. **Codex conditional section content.** The spec defines the _format_ for
   `## Codex` sections but not the actual Codex-equivalent instructions for
   code-review. What does "spawn a subagent" translate to in Codex's
   multi-agent mode? This needs experimentation with Codex CLI before the
   conditional section content can be written.

2. **Agent Skills spec evolution.** The [agentskills.io](https://agentskills.io)
   spec may standardize more frontmatter fields over time. Currently,
   `allowed-tools` is the only spec-standard optional field; the rest are
   Claude Code extensions. If the spec adds fields that conflict with Claude's
   extensions, the frontmatter will need reconciliation.

3. **Other agents beyond Codex.** The architecture (directory-based skills,
   `SKILL.md` uppercase, conditional sections) is designed to extend to future
   agents. But the symlink setup in `bashrc_source` would need a new block for
   each agent's expected location. Consider whether a loop over a config-defined
   list of agent paths would be cleaner if a third agent is added.

4. **Private skills rename.** If any private skills in `~/.private-prompts/`
   still use lowercase `skill.md`, they need renaming too. This cannot be
   verified from the dotfiles repo since the private-prompts directory has no
   skills subdirectory on this machine.
