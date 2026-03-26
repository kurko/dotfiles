#!/bin/bash
INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command')

if echo "$COMMAND" | grep -qE "git (add|stage)"; then
  REMINDER="REMINDER: Use the git-commit skill for all commits. Do NOT run raw git add/commit commands. Also ensure code review has been run before committing."

  if [ -f "tmp/current-task.pid" ]; then
    TASK_ID=$(cat tmp/current-task.pid)
    REMINDER="$REMINDER

TASK LIFECYCLE: You have an active task (ID: $TASK_ID). After committing:
- If work is COMPLETE: invoke pm-tasks to mark the task done (marks complete on shared board, moves to Done on agent board, deletes tmp/current-task.pid).
- If work is NOT complete: add a progress comment to the task before ending.
- Do NOT end the session with an active task and no update."
  fi

  jq -n --arg ctx "$REMINDER" '{
    "hookSpecificOutput": {
      "hookEventName": "PreToolUse",
      "additionalContext": $ctx
    }
  }'
fi

exit 0
