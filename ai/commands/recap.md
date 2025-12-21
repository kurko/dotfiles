# Recap Command

Generate a quick recap for someone returning to this project after a few days away.

## Instructions

1. **Scan ai-notes/ directory** (if it exists at project root):
   - List all files to understand project structure
   - Note file names - they often indicate key topics/features

2. **Extract task status from todo files**:
   - Find files matching `ai-notes/**/todo.{txt,md}`
   - First, extract only lines matching `- [ ]`, `- [x]`, `- [/]` to get task overview
   - Use a subagent to read full todo files for deeper context if needed

3. **Review recent conversation** (if any):
   - Focus on the latest iteration - what was being worked on
   - Key decisions made
   - Blockers or open questions

4. **Produce a condensed recap** in this format:

```
## Recap

**Context:** [1-2 sentences: what is this project/feature about]

**Recent decisions:**
- [bullet points of key decisions, if any]

**Current state:**
- [what's done, what's in progress]

**Next actions:**
- [ ] [specific actionable next step]
- [ ] [another next step]
- [ ] [etc.]

**Open questions:** [if any blockers or decisions pending]
```

## Key principles

- Be terse. User works on parallel projects and needs quick pointers.
- Focus heavily on **next actions** - that's the starting point for the next prompt.
- If no ai-notes/ exists and no conversation context, say so briefly.
- Use subagents to read files to avoid context bloat.
