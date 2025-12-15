---
description: Create a structured diary entry from the current session transcript
---

# Create Diary Entry from Current Session

You are going to create a structured diary entry that documents what happened in the current Claude Code session. This entry will be used later for reflection and pattern identification.

## Approach: Context-First Strategy

**Primary Method (use this first):**
Reflect on the conversation history loaded in this session. You have access to:
- All user messages and requests
- Your responses and tool invocations
- Files you read, edited, or wrote
- Errors encountered and solutions applied
- Design decisions discussed
- User preferences expressed

**When to use JSONL fallback (rare):**
- Session was compacted and context is incomplete
- You need precise statistics (exact tool counts, timestamps)
- User specifically requests detailed session analysis

## Steps to Follow

### 1. Create Diary Entry from Context (Primary Method)

Review the current conversation and create a diary entry based on what happened. No tool invocations needed for typical sessions.

Skip to Step 4 to write the diary entry.

### 2. Fallback: Locate Session Transcript (Only if context insufficient)

If you determine context is insufficient, run this command to find the transcript:

```bash
# Find the most recent session file for this project
# NOTE: Path format includes leading dash: -Users-name-Code-app
SESSION_FILE=$(ls -t ~/.claude/projects/-$(echo "{{ cwd }}" | sed 's/\//‐/g')/*.jsonl 2>/dev/null | head -1) && \
if [ -z "$SESSION_FILE" ]; then \
  echo "ERROR: No session file found" && \
  echo "Looking in: ~/.claude/projects/-$(echo "{{ cwd }}" | sed 's/\//‐/g')/" && \
  ls -la ~/.claude/projects/ | head -20; \
else \
  echo "FOUND: $SESSION_FILE" && \
  ls -lh "$SESSION_FILE"; \
fi
```

**What this does:**
- Converts current directory to project hash format (e.g., `/Users/name/Code/app` → `-Users-name-Code-app`)
- Note the LEADING DASH in the path format
- Finds the most recent `.jsonl` file in that project's directory

### 3. Fallback: Extract Key Metadata (Only if needed)

Only run this if you need precise statistics:

```bash
SESSION_FILE="[path-from-step-2]" && \
echo "=== SESSION METADATA ===" && \
echo "File: $SESSION_FILE" && \
echo "Size: $(ls -lh "$SESSION_FILE" | awk '{print $5}')" && \
echo "" && \
echo "=== TOOL COUNTS ===" && \
jq -r 'select(.message.content[]?.name) | .message.content[].name' "$SESSION_FILE" | sort | uniq -c && \
echo "" && \
echo "=== FILES MODIFIED ===" && \
grep -o '"filePath":"[^"]*"' "$SESSION_FILE" | sort -u
```

This is a simplified extraction - only metadata, tool counts, and files. Much faster than the old approach.

### 4. Create the Diary Entry

Based on the conversation context (and optional metadata from Step 3), create a structured markdown diary entry with these sections:

```markdown
# Session Diary Entry

**Date**: [YYYY-MM-DD from timestamp]
**Time**: [HH:MM:SS from timestamp]
**Session ID**: [uuid from filename]
**Project**: [project path]
**Git Branch**: [branch name if available]

## Task Summary
[2-3 sentences: What was the user trying to accomplish based on the user messages?]

## Work Summary
[Bullet list of what was accomplished:]
- Features implemented
- Bugs fixed
- Documentation added
- Tests written

## Design Decisions Made
[IMPORTANT: Document key technical decisions and WHY they were made:]
- Architectural choices (e.g., "Used React Context instead of Redux because...")
- Technology selections
- API design decisions
- Pattern selections

## Actions Taken
[Based on tool usage and file operations:]
- Files edited: [list paths from "FILES MODIFIED"]
- Commands executed: [from git operations]
- Tools used: [from tool usage counts]

## Code Review & PR Feedback
[CRITICAL: Capture any feedback about code quality or style:]
- PR comments mentioned
- Code quality feedback
- Linting issues
- Style preferences

## Challenges Encountered
[Based on errors and user corrections:]
- Errors encountered [from "ERRORS" section]
- Failed approaches
- Debugging steps

## Solutions Applied
[How problems were resolved]

## User Preferences Observed
[CRITICAL: Document preferences for commits, testing, code style, etc.]

### Commit & PR Preferences:
- [Any patterns around commit messages, PR descriptions]

### Code Quality Preferences:
- [Testing requirements, linting preferences]

### Technical Preferences:
- [Libraries, patterns, frameworks preferred]

## Code Patterns and Decisions
[Technical patterns used]

## Context and Technologies
[Project type, languages, frameworks]

## Notes
[Any other observations]
```

### 4. Save the Diary Entry

Run this command to save the entry:

```bash
# Create directory if needed
mkdir -p ~/.claude/memory/diary && \
# Determine filename
TODAY=$(date +%Y-%m-%d) && \
N=1 && \
while [ -f ~/.claude/memory/diary/${TODAY}-session-${N}.md ]; do N=$((N+1)); done && \
DIARY_FILE=~/.claude/memory/diary/${TODAY}-session-${N}.md && \
# Save entry (you'll need to write the content)
echo "[diary-content]" > "$DIARY_FILE" && \
echo "Saved to: $DIARY_FILE"
```

Use the Write tool to actually write the diary content to the determined file path.

### 5. Confirm Completion

Display:
- Path where diary was saved
- Brief summary of what was captured

## Important Guidelines

- **Be factual and specific**: Include concrete details (file paths, error messages)
- **Capture the 'why'**: Explain reasoning behind decisions
- **Document ALL user preferences**: Especially around commits, PRs, linting, testing
- **Include failures**: What didn't work is valuable learning
- **Keep it structured**: Follow the template consistently
- **Use context first**: Only parse JSONL files when truly necessary

## Decision Guide: When to Use Each Approach

| Situation | Approach | Reasoning |
|-----------|----------|-----------|
| During active session | **Context only** | All information available, 0 tool calls |
| PreCompact hook trigger | **Context only** | Session still in memory |
| Post-session analysis | **JSONL fallback** | Context no longer available |
| Need exact statistics | **JSONL metadata** | Precise counts unavailable from context |
| User says "create diary" | **Context first** | Assume current session unless specified |

## Error Handling

**Context-based errors:**
- If context seems incomplete, mention what's missing and offer to use JSONL fallback
- If uncertain about details, document with "approximately" or "unclear from context"

**JSONL-based errors:**
- If session file not found, show where you looked (remember: `-Users-...` format with leading dash)
- Check `ls -la ~/.claude/projects/` to help diagnose path issues
- If transcript is malformed, document what you could parse and fall back to context
