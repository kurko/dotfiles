#!/bin/bash
INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command')

if echo "$COMMAND" | grep -qE "git (add|stage)"; then
  jq -n '{
    "hookSpecificOutput": {
      "hookEventName": "PreToolUse",
      "additionalContext": "REMINDER: Use the git-commit skill for all commits. Do NOT run raw git add/commit commands. Also ensure code review has been run before committing."
    }
  }'
fi

exit 0
