#!/usr/bin/env bash

set -euo pipefail

input="$(cat)"
command="$(jq -r '.tool_input.command // ""' <<<"$input")"

git_subcommand_pattern='(^|[[:space:];|&])git([[:space:]]+(-C|-c)[[:space:]]+([^[:space:]]+|"[^"]*"|'"'"'[^'"'"']*'"'"'))*[[:space:]]+(add|stage)([[:space:]]|$)'

if printf '%s\n' "$command" | grep -qE "$git_subcommand_pattern"; then
  reminder="REMINDER: The agent must use the git-commit skill for all commits. Do not run raw git add/commit commands. The agent must ensure code review has been run before committing."

  if [[ -f "tmp/current-task.pid" ]]; then
    task_id="$(< tmp/current-task.pid)"
    reminder="$reminder

TASK LIFECYCLE: The agent has an active task (ID: $task_id). After committing:
- If work is COMPLETE: invoke pm-tasks to mark the task done (marks complete on shared board, moves to Done on agent board, deletes tmp/current-task.pid).
- If work is NOT complete: add a progress comment to the task before ending.
- The agent must not end the session with an active task and no update."
  fi

  jq -n --arg message "$reminder" '{ "systemMessage": $message }'
fi
