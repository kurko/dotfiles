---
name: create-and-edit-skills
description: Create, improve, or edit Claude Code skill files. Use when user asks to create a new skill, modify an existing skill, or convert a command to a skill. Ensures proper YAML frontmatter and follows Anthropic best practices.
argument-hint: "[skill-name] [action: create|edit|convert]"
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
| Public | `~/.dotfiles/ai/skills/<skill-name>/` | `~/.claude/skills/<skill-name>/` | All projects, shareable |
| Private | `~/.private-prompts/skills/<skill-name>/` | `~/.claude/skills/<skill-name>/` | All projects, not committed |
| Project | `.claude/skills/<skill-name>/` | N/A | Current project only |

**IMPORTANT**: Personal skills (public/private) are created in source directories and symlinked to `~/.claude/skills/`. Never create personal skills directly in `~/.claude/skills/`.

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

# OPTIONAL fields
argument-hint: "[arg1] [arg2]"     # Shown during autocomplete (e.g., "[issue-number]")
disable-model-invocation: false    # true = manual only (/skill), Claude won't auto-invoke
user-invocable: true               # false = hidden from / menu, background knowledge only
allowed-tools: Read, Grep          # Tools Claude can use without permission when skill active
model: opus                        # Model override when skill is active
context: fork                      # "fork" = run in isolated subagent context
agent: Explore                     # Subagent type when context: fork (Explore, Plan, general-purpose)
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

## Writing Effective Skills

### 1. Description Best Practices

The description is CRITICAL - Claude uses it to decide when to auto-load the skill.

**Good** (specific, keyword-rich):
```yaml
description: Explains code with visual diagrams and analogies. Use when explaining how code works, teaching about a codebase, or when the user asks "how does this work?"
```

**Bad** (vague, missing keywords):
```yaml
description: Helps with code
```

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

## Workflow: Creating a New Skill

1. **Determine skill type**: Reference (knowledge) or Task (actions)?
2. **Choose location**: Personal or Project (`.claude/skills/`)?
3. **If personal, ask public or private** (use AskUserQuestion tool):
   - **Public**: Shareable via dotfiles repo → `~/.dotfiles/ai/skills/<skill-name>/`
   - **Private**: Not committed anywhere → `~/.private-prompts/skills/<skill-name>/`
4. **Create the skill directory and SKILL.md** in the source location
5. **Write frontmatter**: Name, description, and relevant options
6. **Write content**: Clear, structured instructions
7. **Run symlink script**:
   ```bash
   # For public skills
   update_dotfiles

   # For private skills
   ~/.private-prompts/install.sh
   ```
8. **Test**: Invoke with `/skill-name` and verify behavior

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
- [ ] **description** is specific and includes trigger keywords
- [ ] **Instructions are clear** and actionable
- [ ] **Content is focused** (under 500 lines)
- [ ] **Side-effect actions** have `disable-model-invocation: true`
- [ ] **File ends with newline**

## Common Mistakes to Avoid

1. **Missing frontmatter** - Every skill MUST have `---` delimited frontmatter
2. **Vague description** - Be specific about what triggers the skill
3. **Too much content** - Keep SKILL.md focused, use supporting files
4. **Wrong invocation setting** - Dangerous actions must be manual-only
5. **Invalid YAML** - Check for proper quoting and indentation

## Example: Complete Well-Structured Skill

```markdown
---
name: code-review
description: Review code for quality, security, and best practices. Use when user asks to review code, check for issues, or wants feedback on implementation.
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
