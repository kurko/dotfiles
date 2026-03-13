---
name: create-and-edit-skills
description: Create, improve, or edit Claude Code skill files. Use when user asks to create a new skill, modify an existing skill, convert a command to a skill, turn a workflow into a skill, capture a conversation as a skill, or make a skill from a repeated pattern. Also triggers for "turn this into a skill", "save this as a skill", "make a skill from this", or "I keep doing this manually".
argument-hint: "[skill-name] [action: create|edit|convert|capture]"
---

# Create and Edit Claude Code Skills

You are helping the user create, edit, or improve a Claude Code skill file. Follow this guide strictly to ensure skills are well-structured and effective.

## Skill Fundamentals

Skills are markdown files that extend Claude's capabilities. They follow the [Agent Skills](https://agentskills.io) open standard with Claude Code-specific extensions.

### Directory Structure

```
<skill-name>/
├── SKILL.md           # Main instructions (REQUIRED)
├── template.md        # Template for Claude to fill in (optional)
├── examples/          # Example outputs (optional)
│   └── sample.md
└── scripts/           # Executable scripts (optional)
    └── validate.sh
```

**Skill Locations** (by scope):
| Location | Source Path | Symlinked To | Scope |
|----------|-------------|--------------|-------|
| Public | `~/.dotfiles/ai/skills/<skill-name>/` | `~/.claude/skills/<skill-name>/` and `~/.agents/skills/<skill-name>/` | All projects, shareable (Claude + Codex) |
| Private | `~/.private-prompts/skills/<skill-name>/` | `~/.claude/skills/<skill-name>/` | All projects, not committed |
| Project (Claude) | `.claude/skills/<skill-name>/` | N/A | Current project only |
| Project (Codex) | `.agents/skills/<skill-name>/` | N/A | Current project only |

**IMPORTANT**: Personal skills (public/private) are created in source directories and symlinked to their destinations. Never create personal skills directly in `~/.claude/skills/` or `~/.agents/skills/`.

**Filename**: Always use `SKILL.md` (uppercase). Claude accepts both cases; Codex requires uppercase.

**Symlink Scripts**:
- Public skills: Run `update_dotfiles` after creating/editing
- Private skills: Run `~/.private-prompts/install.sh` after creating/editing

## SKILL.md Format

**CRITICAL: Every skill MUST have YAML frontmatter.** This is not optional.

### Basic Template

```markdown
---
name: skill-name
description: What this skill does and when to use it
---

# Skill Title

[Instructions for Claude when this skill is active]
```

### Complete Frontmatter Reference

```yaml
---
# REQUIRED fields
name: skill-name                    # Lowercase, hyphens only, max 64 chars. Becomes /skill-name
description: Clear description      # What it does + when to use it. Claude uses this for auto-loading.

# OPTIONAL fields (spec standard)
allowed-tools: Read, Grep          # Tools the agent can use without permission when skill active

# OPTIONAL fields (Claude Code only)
argument-hint: "[arg1] [arg2]"     # Shown during autocomplete (e.g., "[issue-number]")
disable-model-invocation: false    # true = manual only (/skill), Claude won't auto-invoke
user-invocable: true               # false = hidden from / menu, background knowledge only
model: opus                        # Model override when skill is active
context: fork                      # "fork" = run in isolated subagent context
agent: Explore                     # Subagent type when context: fork (Explore, Plan, etc.)
---
```

### Frontmatter Decision Guide

| Use Case | Settings |
|----------|----------|
| General reference/knowledge | Default (both invocable) |
| Dangerous actions (deploy, delete) | `disable-model-invocation: true` |
| Background knowledge only | `user-invocable: false` |
| Read-only operations | `allowed-tools: Read, Grep, Glob` |
| Isolated research task | `context: fork`, `agent: Explore` |

## Capture Intent

Before writing anything, understand what the user actually needs. The best skills come from real workflows, not abstract ideas.

### Extract from Conversation First

If the user says "turn this into a skill" or "capture this as a skill", mine the current conversation before asking questions:
- What tools were used and in what sequence?
- Were there corrections or retries? Those reveal edge cases the skill should handle.
- What was the input format? What did the output look like?
- Were there decision points where the user chose between options?

This conversation archaeology often answers most questions before you need to ask them.

### Ask the 4 Key Questions

Use AskUserQuestion to clarify what the conversation doesn't reveal. Batch these into a single call when possible:

1. **What should it do?** - Core action in one sentence. If the user can't articulate this clearly, the skill probably isn't ready to be captured yet.
2. **When should it trigger?** - List the phrases or situations. Think broadly: what would a user say when they need this but don't know the skill exists?
3. **Expected output format?** - File, terminal output, clipboard, structured data?
4. **Public or private?** - Shareable via dotfiles, or contains sensitive patterns?

Skip questions the conversation already answered. Don't ask what you already know.

## Research Before Writing

Spend a minute researching before creating. This prevents duplicate skills and surfaces tools the skill should leverage.

### Check for Existing Skills

Glob `~/.claude/skills/` and `.claude/skills/` for similar skills. You might find:
- A skill that already does this (suggest editing instead of creating)
- A skill that does something adjacent (suggest extending or linking)
- Naming patterns to stay consistent with

### Check Available Tools

Look at what MCP servers and CLI tools are available. A skill that shells out to `jq` when there's an MCP tool for JSON processing is missing an opportunity. Run ToolSearch if the skill's domain suggests MCP tools might exist.

### Check for Patterns

If the skill wraps a CLI tool, read its `--help` output. If it wraps an API, check for existing SDK usage in the codebase. Build on what's already there.

## Writing Effective Skills

### 1. Description Best Practices

The description is the most important line in the skill. Claude uses it to decide when to auto-load, so an undertriggering description means the skill sits unused.

**The "pushiness" principle**: Claude errs on the side of NOT loading skills. Your description must actively reach out and claim trigger phrases. Think of it as advertising, not documentation.

**Weak description** (undertriggers):
```yaml
description: Helps with code review
```
Claude sees "code review" and nothing else. If the user says "check my changes" or "review this PR", the skill won't load.

**Strong description** (catches natural language):
```yaml
description: Review pull requests and uncommitted code changes. Use when user asks to review a PR, review changes, review uncommitted code, review a diff, or similar code review requests. Activates for phrases like "review this PR", "review my changes", "check this diff".
```

**Tips for strong descriptions**:
- List 3-5 trigger phrases the user might actually say
- Include both the formal name ("code review") and casual variants ("check my changes", "look at this diff")
- Mention the output type if it's distinctive ("generates a markdown report", "copies to clipboard")
- Simple tasks may not trigger skill loading at all. If the skill handles something Claude might try to do without help, signal the specialization: "Follows team-specific conventions that differ from defaults"

### 2. Content Structure

**Reference Skills** (add knowledge):
```markdown
---
name: api-conventions
description: API design patterns for this codebase
---

When writing API endpoints:
- Use RESTful naming conventions
- Return consistent error formats
- Include request validation
```

**Task Skills** (step-by-step actions):
```markdown
---
name: deploy
description: Deploy the application to production
disable-model-invocation: true
---

## Steps

1. Run the test suite
2. Build the application
3. Push to deployment target

## Error Handling

- If tests fail, abort deployment
- If build fails, show error and suggest fixes
```

### 3. Keep Skills Focused

- **Under 500 lines** in SKILL.md
- Move detailed content to supporting files:
  ```markdown
  For complete API details, see [reference.md](reference.md)
  For usage examples, see [examples.md](examples.md)
  ```

### 4. Dynamic Content

**Shell command injection** (runs before skill loads):
```markdown
## Current git status
!`git status --short`

## Recent commits
!`git log --oneline -5`
```

**String substitutions**:
- `$ARGUMENTS` - All arguments passed when invoking
- `${CLAUDE_SESSION_ID}` - Current session ID

### 5. Extended Thinking

Include "ultrathink" anywhere in content to enable extended thinking mode for complex analysis.

## Writing Philosophy

### Explain the Why, Not Just the What

Heavy-handed MUSTs without reasoning produce brittle skills. When Claude understands the reason behind an instruction, it can generalize to situations the skill author didn't anticipate.

**Brittle** (no reasoning):
```markdown
MUST use snake_case for all file names.
```

**Resilient** (reasoning included):
```markdown
Use snake_case for file names. The project's CI validates naming conventions
and kebab-case files will fail the lint step.
```

The second version lets Claude handle edge cases: "What about config files?" It knows the constraint comes from CI, so it can check whether config files go through the same lint.

### Generalize, Don't Overfit

Write instructions that handle the category of problem, not just the specific example you tested with. If your skill works for "deploy to staging" but breaks for "deploy to production", the instructions are too narrow.

Ask yourself: "If someone used this skill for a slightly different version of the same task, would it still work?"

### Use Imperative Form

Write instructions as direct commands: "Run the test suite", "Check for existing migrations", "Ask the user before deleting". This matches how Claude processes instructions most effectively.

### Progressive Disclosure

Not everything belongs in SKILL.md. Layer information by how often it's needed:

| Layer | Size Limit | What Goes Here |
|-------|-----------|----------------|
| Frontmatter description | ~100 words | Trigger phrases, one-sentence purpose |
| SKILL.md body | <500 lines | Core instructions, decision logic, workflows |
| Bundled files (template.md, etc.) | Unlimited | Templates, examples, reference data |

If SKILL.md is getting long, extract reference material into supporting files. The body should contain decision-making logic and workflows, not encyclopedic reference data.

## Workflow: Creating a New Skill

1. **Capture intent** (see "Capture Intent" section above). If the user described what they want, ask clarifying questions via AskUserQuestion. Batch the questions.
2. **Research**: Check existing skills and available tools (see "Research Before Writing").
3. **Determine skill type** (use AskUserQuestion if unclear):
   - **Reference** (adds knowledge): conventions, patterns, domain context
   - **Task** (performs actions): deployment, code generation, file manipulation
4. **Choose location** (use AskUserQuestion):
   - **Public**: Shareable via dotfiles repo → `~/.dotfiles/ai/skills/<skill-name>/`
   - **Private**: Not committed anywhere → `~/.private-prompts/skills/<skill-name>/`
   - **Project**: Current repo only → `.claude/skills/<skill-name>/`
5. **Draft the description first**: Write the frontmatter description before the body. This forces you to articulate the skill's purpose and triggers. Share it with the user for feedback, since this single line determines whether the skill ever gets loaded.
6. **Create the skill directory and SKILL.md** in the source location
7. **Write content**: Clear, structured instructions following the writing philosophy above
8. **Run symlink script**:
   ```bash
   # For public skills
   update_dotfiles

   # For private skills
   ~/.private-prompts/install.sh
   ```
9. **Test**: Invoke with `/skill-name` and verify behavior

## Workflow: Capturing a Conversation as a Skill

When the user says "turn this into a skill" or "save this workflow as a skill":

1. **Mine the conversation**: Review the transcript for the workflow that should become a skill. Identify:
   - The sequence of tool calls and their purpose
   - Decision points where the user made choices
   - Corrections or retries (these become edge case handling)
   - Input/output formats
2. **Identify the generalizable pattern**: Strip away the specific instance to find the reusable workflow. "I deployed the Ruby app to staging" becomes "deploy any app to any environment".
3. **Ask what's missing** (AskUserQuestion): The conversation shows what happened once. Ask about:
   - Variations the skill should handle
   - Error cases that didn't come up this time
   - Whether the trigger phrases feel right
4. **Follow the creation workflow** (above) from step 3 onward, pre-filling answers from the conversation analysis.

## Workflow: Converting a Command to a Skill

Commands (`.claude/commands/*.md`) are the older format. To convert:

1. **Ask public or private** (use AskUserQuestion tool):
   - **Public**: `~/.dotfiles/ai/skills/<name>/`
   - **Private**: `~/.private-prompts/skills/<name>/`
2. **Create directory**: `mkdir -p <source-path>/<name>/`
3. **Move and rename**: `mv .claude/commands/<name>.md <source-path>/<name>/SKILL.md`
4. **Update frontmatter**: Add `name:` field (commands only had `description:`)
5. **Enhance**: Add supporting files if needed
6. **Run symlink script**:
   ```bash
   # For public skills
   update_dotfiles

   # For private skills
   ~/.private-prompts/install.sh
   ```

## Workflow: Editing an Existing Skill

1. **Find the source location**: Check if it's in `~/.dotfiles/ai/skills/` or `~/.private-prompts/skills/`
2. **Read the current SKILL.md** from the source location (not the symlink)
3. **Identify what needs improvement**
4. **Preserve existing frontmatter fields** unless changing them
5. **Update content** while maintaining structure
6. **Validate frontmatter** is still valid YAML
7. **Run symlink script** (ensures symlinks are current):
   ```bash
   # For public skills
   update_dotfiles

   # For private skills
   ~/.private-prompts/install.sh
   ```

## Quality Checklist

Before finalizing any skill, verify:

- [ ] **Frontmatter exists** with valid YAML syntax
- [ ] **name** field is lowercase, hyphens only, max 64 chars
- [ ] **description** is specific, includes 3-5 trigger phrases, and follows the pushiness principle
- [ ] **Instructions are clear** and actionable, using imperative form
- [ ] **Instructions explain the why** behind non-obvious rules
- [ ] **Content is focused** (under 500 lines, reference data in supporting files)
- [ ] **Side-effect actions** have `disable-model-invocation: true`
- [ ] **File ends with newline**

## Common Mistakes to Avoid

1. **Missing frontmatter** - Every skill MUST have `---` delimited frontmatter
2. **Vague description** - Be specific about what triggers the skill. List trigger phrases explicitly.
3. **Too much content** - Keep SKILL.md focused, use supporting files
4. **Wrong invocation setting** - Dangerous actions must be manual-only
5. **Invalid YAML** - Check for proper quoting and indentation
6. **Overfitting to one example** - Instructions should generalize beyond the single case you tested with
7. **Heavy MUSTs without reasoning** - Explain why so Claude can generalize to edge cases

## Example: Complete Well-Structured Skill

```markdown
---
name: code-review
description: Review pull requests and uncommitted code changes. Use when user asks to review a PR, review changes, review uncommitted code, review a diff, or similar code review requests. Activates for phrases like "review this PR", "review my changes", "check this diff".
argument-hint: "[file-or-directory]"
allowed-tools: Read, Grep, Glob
---

# Code Review

Review the specified code for:

## Quality Checks
- Code organization and structure
- Naming conventions
- DRY principle adherence
- Error handling

## Security Checks
- Input validation
- SQL injection vulnerabilities
- XSS vulnerabilities
- Sensitive data exposure

## Output Format

Provide feedback as:
1. **Critical Issues** - Must fix before merge
2. **Suggestions** - Would improve the code
3. **Positive Notes** - What's done well

Be specific with line numbers and code examples.
```

## References

- [Claude Code Skills Documentation](https://code.claude.com/docs/en/skills)
- [Agent Skills Specification](https://agentskills.io)
- [Anthropic Skills Repository](https://github.com/anthropics/skills)
