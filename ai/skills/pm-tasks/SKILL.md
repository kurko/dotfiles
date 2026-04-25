---
name: pm-tasks
description: >
  Work off tasks from an external project management tool (Asana, Linear, Jira,
  etc.). Use when the user says "pick a task", "next task", "what should I work
  on", "update task", "create task", "mark done", "task status", or similar PM
  workflow requests. Also activates when starting a new work session and needing
  to select work. ONLY load this skill when CLAUDE.md configures an external PMT
  with a tool value other than "none". Do NOT load this skill if the project uses
  markdown or txt files for task tracking (use the working-off-of-todo-files
  skill instead).
---

# pm-tasks

Work off tasks from an external project management board. This skill handles
the full lifecycle: picking tasks, tracking status, creating new tasks, and
marking work complete.

## Configuration

On activation, read the project's CLAUDE.md (or CLAUDE.local.md) for a
`### Project Management` section. It contains:

- **PM tool or equivalent**: which MCP integration to use (e.g., Asana MCP, Linear MCP)
- **Shared project**: the team's board (URL/GID and section names)
- **Agent project**: the agent's private scratchpad board (optional)
- **Content format**: html (Asana) or markdown (Linear, Jira)

If this section is missing or says `tool: none`, fall back to the
`working-off-of-todo-files` skill and work from `ai-notes/**/todo.md`.

## Workflow

### 1. Resume Session (ALWAYS do this first)

On activation, before picking new tasks, check for in-progress work:

1. Read `tmp/current-task.pid` for the task id being worked on. If set, fetch
   that task from the PM tool and resume it. The PID file is the sole authority
   for whether THIS agent has a task in progress — it is per-worktree and
   therefore per-agent.
2. If no `current-task.pid` exists, this agent has NO in-progress work.
   Do NOT fetch the agent board's "current work" section to find tasks —
   those tasks belong to OTHER agents running in other worktrees. Proceed
   directly to "Pick Next Task".
3. **Exception — dirty git status**: If no PID file exists but `git status`
   shows uncommitted changes, inspect them to infer what was being worked on.
   If you can match changes to a task on the shared board's "in progress"
   section, ask the user whether to resume it. If you're confused, ask the
   user what to do.

**Why `current-task.pid` is authoritative**: In a multi-worktree setup,
multiple agents share the same agent board. The PID file lives inside
`tmp/` which is per-worktree, making it the only reliable indicator of
what THIS specific agent is working on.

### 2. Pick Next Task

When the user says "pick a task", "next task", "what should I work on"
(and no in-progress work exists from step 1):

1. Fetch **incomplete** tasks from the shared board's priority section (the
   section designated for "ready to start" work, e.g., "Up next", "Todo",
   "Ready"). Use the PM tool's completion filter (e.g., Asana's
   `opt_fields=completed` and filter client-side) to exclude tasks already
   marked as done.
   **Sort by priority.** If tasks have a Priority field (custom field, label,
   or tag), always fetch it in the same request and sort results
   **High > Medium > Low > unset** before presenting candidates. Never
   present tasks in arbitrary section order when priority data is available.
   **Skip tasks assigned to someone else.** If a task has an assignee and
   that assignee is not the current user (or the agent), do not include it
   in the candidate list — someone else is responsible for it. Unassigned
   tasks are fair game.
2. If a private agent board is configured, also fetch its "current work"
   section to see which tasks other agents are already working on. Exclude
   those from the candidates presented to the user.
   **The agent board fetch is mandatory, not best-effort.** If the fetch fails
   (network error, timeout, MCP error), retry up to 2 times. If still failing,
   STOP and tell the user: "I can't fetch the agent board to check what other
   agents are working on. Proceeding without this check risks picking a task
   that's already claimed." Do NOT proceed without the exclusion list.
3. Present the top 3-5 tasks with titles and short summaries.
4. Let the user choose, or pick the first one if they say "just pick one".
5. **If the user rejects a pick** (e.g., "that one is taken", "pick another"),
   re-fetch the agent board's "current work" section before picking again.
   The exclusion list may have changed since the original fetch.
6. CRITICAL: Write the task id to `tmp/current-task.pid` to track it for future sessions.
7. If a private agent board is configured, list tasks that are marked as Blocked
   or Needs Input so the user can act on them.

### 3. Start Working on a Task

When a task is selected, **claim it on the board IMMEDIATELY** — before
reading details, comments, or doing any other work. This is a recurring
failure mode: the agent reads task details, launches a spec or plan, and
never moves the task on the board. Claim first, explore second.

Do ALL of these steps in order:

**PHASE 1: CLAIM THE TASK (do this BEFORE anything else)**

1. **Verify not already claimed.** Check that the task is not already on
   the agent board's "current work" section. If it is, another agent
   already claimed it — do NOT proceed. Clear your PID file and return
   to "Pick Next Task".
2. **Move the task to the "in progress" section on the shared board.**
   This is the FIRST visible action. Do it NOW.
3. **Add to agent board (REQUIRED if configured).** Multi-home the task
   to the agent board's "current work" section. Use multi-homing (Asana
   `addProject` API) or cross-project references (Linear) — never
   duplicate the task. Do not skip this step.
4. **Write `tmp/current-task.pid`.** (Should already exist from Pick
   Next Task, but verify it's set.)

**PHASE 2: UNDERSTAND THE TASK (only after Phase 1 is complete)**

5. Read the full task description from the PM tool.
6. **Read the task's comment history** (e.g., Asana stories). Comments often
   contain scoping decisions, open questions, or prior agent triage notes.
   If the comments indicate that the task still needs scoping or shaping
   (e.g., open questions, "triage needed", multiple competing approaches,
   unclear requirements), do NOT jump into implementation. Instead:
   - Summarize the current state of the discussion.
   - Propose a plan or recommendation addressing the open questions.
   - Wait for the user's approval before writing any code.
7. Announce the task title, description summary, and key requirements to
   establish context for the session.

### 4. Update Task Status

When the user says "update task", "add note", "blocked":

- **Add context**: post a comment or note on the task in the PM tool.
- **Blocked**: if a private agent board is configured, move the task to the
  "blocked/needs input" section there. Leave position on the shared board
  unchanged (still "in progress").
- **Progress note**: add a comment summarizing what was done so far.

### 5. Create a New Task

When the user says "create task", "new task", "write task":

1. Delegate to the `write-task` skill for content formatting. The write-task
   skill handles template selection (short vs full), content structure, and
   output format (HTML or markdown based on CLAUDE.md).
2. Use the PM tool's MCP to create the task in the **shared project only**.
3. Place in the section the user specifies, defaulting to the "inbox" or
   "triage" section.
4. **Do NOT add the task to the agent board.** Creating a task is not the
   same as working on it. The agent board's "current work" section is
   exclusively for tasks THIS agent is actively implementing. A newly
   created task should be visible on the shared board so the user (or a
   future agent session) can prioritize and pick it up through the normal
   "Pick Next Task" flow. Adding it to the agent board makes it invisible
   to other agents and implies someone is working on it when no one is.

### 6. Mark Task Complete

When the user confirms a task is done (or an automated completion criterion
defined by the user is met):

1. **Set the task's completion status** in the PM tool. This is NOT the
   same as moving it to a section — it means marking the task itself as
   done (e.g., Asana: `asana_update_task` with `completed: true`; Linear:
   update state to "Done"). **Verify** the API response confirms the task
   is now marked complete before proceeding.
   **Note (Asana):** Completed tasks automatically disappear from board
   views, so no section move is needed on the shared board.
2. If a private agent board is configured, move the task to the "done"
   section there as well.
4. CRITICAL: Delete the task id from `tmp/current-task.pid`. Only do so
   when the task was QA'd and successfully marked complete in the PM tool.
5. Announce completion and ask if the user wants to pick the next task.

### 7. Read Task Details

When the user says "show task", "task details", "what's this task about":

1. Fetch the task from the PM tool.
2. Display: title, description, assignee, current section, and recent
   comments or activity.

### 8. Session Status

When the user says "task status", "what am I working on":

1. Read `tmp/current-task.pid` for the task id being worked on. If set, fetch
   that task from the PM tool. This is YOUR current task.
2. If no PID file exists, report that this agent has no task in progress.
3. If a private agent board is configured, list tasks in the "current work"
   section as **other agents' work** (for visibility, not for claiming).
4. If a private agent board is configured, list tasks that are marked as Blocked
   or Needs Input so the user can act on them.
5. Show title and brief status for each.

## PM Tool Examples

This skill itself never contains tool-specific API calls. The CLAUDE.md
configuration tells the agent which MCP tools to use and what section names
map to each workflow state.

### Asana Configuration Example

```markdown
### Project Management

- **PM tool**: Asana MCP
- **Shared project**: My Project (GID: 1234567890)
  - Sections: Inbox, Up next, In progress, Backlog
  - "Ready" section: Up next
  - "In progress" section: In progress
- **Agent project**: AI Agent (GID: 0987654321)
  - Sections: Current session, Blocked/Needs input, Done
- **Content format**: html
```

**Asana: fetching priority.** To get priority data, include
`custom_fields,custom_fields.name,custom_fields.enum_value,custom_fields.enum_value.name`
in the `opt_fields` parameter when calling `asana_get_tasks`. The Priority
custom field's `enum_value.name` will be "High", "Medium", or "Low". Tasks
without a priority value will have `enum_value: null`.

### Linear Configuration Example

```markdown
### Project Management

- **PM tool**: Linear MCP
- **Shared project**: My Team (ID: TEAM-123)
  - States: Triage, Todo, In Progress, Done, Cancelled
  - "Ready" state: Todo
  - "In progress" state: In Progress
- **Agent project**: none
- **Content format**: markdown
```

### No PM Tool (Fallback)

```markdown
### Project Management

- **PM tool**: none
- **Fallback**: ai-notes/todo.md
```

When `tool: none`, activate the `working-off-of-todo-files` skill instead.

## Principles

1. **Single task focus**: work on ONE task at a time until complete or blocked.
2. **User controls pacing**: never advance to the next task without the user's
   go-ahead (unless they've set an automated criterion).
3. **Shared board is source of truth**: the private agent board is a
   scratchpad. Status on the shared board is what teammates see.
4. **Don't duplicate tasks**: use multi-homing or cross-references, never
   copy tasks between boards.
5. **Announce transitions**: always tell the user when you move a task
   between sections or mark it complete.
6. **Never modify other agents' state.** Only add or remove YOUR task
   (the one in your `current-task.pid`) on the agent board. Never remove,
   move, or update tasks that belong to other agents. If you accidentally
   claimed a task that another agent owns, simply clear your PID file and
   pick a different task — do not touch the agent board entry.
