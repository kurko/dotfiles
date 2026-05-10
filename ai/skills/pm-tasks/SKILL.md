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

On activation, before picking new tasks, read both PID files:
`tmp/current-task.pid` and `tmp/current-parent-task.pid`.

1. If `tmp/current-task.pid` exists and `tmp/current-parent-task.pid` does not,
   fetch the current task from the PM tool and resume it. This is the normal
   top-level task flow.
   - If the fetched task is already completed, verify completion in the PM
     tool, clear `tmp/current-task.pid`, and proceed to "Pick Next Task".
   - If the current task is in this agent's "blocked/needs input" section on
     the agent board, announce the blocked state and stop for user input.
   - Before doing parent-level implementation work, fetch the task's direct
     subtasks when the PM tool supports them. If incomplete direct subtasks
     exist, this is a parent container that was interrupted before Subtask
     Selection. Confirm it is still this agent's claimed container when an
     agent board is configured, then run "Subtask Selection" instead of
     implementing the parent body. If it is not claimed by this agent, clear
     both PID files and proceed to "Pick Next Task".
2. If both PID files exist, the current task is a subtask and the parent task is
   the claimed container. Fetch both records before doing anything else.
   - If the parent task is already completed, stop and ask the user for
     confirmation before continuing. Do not silently work under a completed
     parent. The user can choose whether to release the local claim and clear
     both PID files, reopen/continue the parent, or inspect the task history
     first.
   - If the parent container is in this agent's "blocked/needs input" section
     on the agent board, announce the blocked state and stop for user input.
   - If the active subtask is incomplete, still belongs to the parent, and is
     still assigned to the current user/agent or unassigned, announce the parent
     and active subtask, then continue work on the subtask.
   - If the active subtask is already completed, run "Subtask Transition" to
     select the next eligible direct subtask or prepare the parent for explicit
     completion. Do not mark the already-completed subtask complete again.
   - If the active subtask no longer belongs to the parent, or was reassigned
     to someone else while this agent was offline, fetch the parent's remaining
     direct subtasks and run "Subtask Selection" again. Do not mark the parent
     complete during this recovery.
3. If `tmp/current-parent-task.pid` exists but `tmp/current-task.pid` does not,
   treat this as stale local state from an interrupted subtask transition.
   Fetch the parent task, confirm it is still this agent's claimed container
   when an agent board is configured, then run "Subtask Selection" again. If
   the parent is not claimed by this agent, clear both PID files and proceed to
   "Pick Next Task".
4. If neither PID file exists, this agent has NO in-progress work. Do NOT fetch
   the agent board's "current work" section to find tasks; those tasks belong
   to OTHER agents running in other worktrees. Proceed directly to "Pick Next
   Task".
5. **Exception - dirty git status**: If no PID file exists but `git status`
   shows uncommitted changes, inspect them to infer what was being worked on.
   If you can match changes to a task on the shared board's "in progress"
   section, ask the user whether to resume it. If you're confused, ask the
   user what to do.

**Why the PID files are authoritative**: In a multi-worktree setup, multiple
agents share the same agent board. The PID files live inside `tmp/`, which is
per-worktree, making them the only reliable indicator of what THIS specific
agent is working on.

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
3. If a private agent board is configured, list tasks that are marked as Blocked
   or Needs Input so the user can act on them.
4. Present the top 3-5 tasks with titles and short summaries.
5. Let the user choose, or pick the first one if they say "just pick one".
6. **If the user rejects a pick** (e.g., "that one is taken", "pick another"),
   re-fetch the agent board's "current work" section before picking again.
   The exclusion list may have changed since the original fetch.
7. Do not write PID files during picking. The selected task is not this agent's
   durable work until "Start Working on a Task" claims it on the shared board
   and agent board. Subtask selection also does not happen in this phase; it
   happens only after the selected parent task is claimed.

### 2a. Subtask Selection

Run Subtask Selection only after the selected top-level parent task has been
claimed on the shared board and, when configured, on the private agent board.
The board claim belongs to the parent container; the active subtask is tracked
only in local PID state unless the PM tool has an explicit subtask workflow.

1. Fetch the selected parent task's **direct** subtasks before doing any work
   on the parent. Include completion status, assignee, priority if available,
   and parent relationship in the response.
   - Do not recurse into nested subtasks. Grandchildren belong to the selected
     subtask's own scope and are not auto-claimed by this workflow.
2. Partition direct subtasks into:
   - completed subtasks, which are ignored;
   - eligible incomplete subtasks, which are unassigned or assigned to the
     current user/agent;
   - ineligible incomplete subtasks, which are assigned to someone else.
3. If there are eligible incomplete subtasks:
   - Auto-pick one subtask because the user already selected or approved the
     parent container. Prefer priority order if priority data is available;
     otherwise use the PM tool's direct subtask order.
   - Keep the parent task incomplete and in progress. Do NOT mark the parent
     complete.
   - Keep the parent task on the agent board's "current work" section to
     reserve the container. Do not duplicate the parent task.
   - Write the parent task id to `tmp/current-parent-task.pid` first, then write
     the active subtask id to `tmp/current-task.pid`. Parent-first ordering
     makes crash recovery land in the stale-parent recovery path instead of
     treating a subtask as a top-level task.
   - Announce both names: "Working on subtask X under parent task Y."
4. If the parent has incomplete direct subtasks but none are eligible, release
   this agent's claim and return to "Pick Next Task":
   - add a parent-task comment explaining that this agent is releasing the
     container because all remaining incomplete direct subtasks are assigned to
     other people;
   - remove only this agent's parent container from the agent board's "current
     work" section when an agent board is configured;
   - clear both PID files;
   - leave the parent task incomplete and do not mark it done;
   - leave the parent in the shared board's "in progress" section because the
     remaining direct subtasks have explicit non-agent owners.
5. If the parent has no direct subtasks at all, remove any stale
   `tmp/current-parent-task.pid`, keep the parent id in `tmp/current-task.pid`,
   and continue with the parent as the active top-level work item.
6. If the parent has direct subtasks and zero incomplete direct subtasks, remove
   any stale `tmp/current-parent-task.pid` and keep the parent id in
   `tmp/current-task.pid`. The parent is now the completion target, not an
   implementation task. Ask the user whether to mark it complete; do not invent
   extra parent-body work unless the user says the parent has remaining work.
7. While a parent is claimed, "next task" means the next eligible direct subtask
   under that parent. "Switch tasks", "different task", or an equivalent
   explicit redirect means release this agent's parent claim, clear both PID
   files, and return to the top-level task queue.

### 2b. Subtask Transition

Use this after an active subtask is completed, or when resume discovers the
active subtask was already completed elsewhere. This section does not mark any
task complete; it only chooses the next local state after completion is already
true in the PM tool.

1. Fetch the parent task's remaining incomplete direct subtasks.
2. If another eligible incomplete subtask exists, pick it next, write its id to
   `tmp/current-task.pid`, keep `tmp/current-parent-task.pid`, and announce the
   transition. Continue with that subtask rather than picking a new top-level
   task.
3. If incomplete direct subtasks remain but none are eligible, add a parent-task
   comment explaining that this agent is releasing the container because all
   remaining incomplete direct subtasks are assigned to other people. Remove
   only this agent's parent container from the agent board's "current work"
   section when configured, clear both PID files, leave the parent incomplete,
   and return to "Pick Next Task". Leave the parent in the shared board's
   "in progress" section because the remaining direct subtasks have explicit
   non-agent owners.
4. If no incomplete direct subtasks remain, write the parent task id back to
   `tmp/current-task.pid`, delete `tmp/current-parent-task.pid`, and tell the
   user the subtask queue is finished. The parent is now only a completion
   target. Wait for explicit confirmation before marking the parent task
   complete; do not implement extra parent-body work unless the user says there
   is remaining parent-level work.

### 3. Start Working on a Task

When a task is selected, **claim it on the board IMMEDIATELY** — before
reading details, comments, or doing any other work. This is a recurring
failure mode: the agent reads task details, launches a spec or plan, and
never moves the task on the board. Claim first, explore second.

Do ALL of these steps in order:

**PHASE 1: CLAIM THE TASK (do this BEFORE anything else)**

1. **Verify not already claimed.** The task being claimed here is the selected
   top-level task or parent container. Check that it is not already on the
   agent board's "current work" section. Also treat the parent as claimed if any
   current agent-board item is a subtask under that parent. If another agent
   already claimed it, do NOT proceed. Clear both PID files and return to "Pick
   Next Task".
2. **Move the parent task to the "in progress" section on the shared board.**
   This is the FIRST visible action. Do it NOW. Do not try to move subtasks
   through top-level board sections; in tools like Asana, subtasks often do not
   belong to those sections.
3. **Add the parent task to the agent board (REQUIRED if configured).**
   Multi-home the parent task to the agent board's "current work" section. Use
   multi-homing (Asana `addProject` API) or cross-project references (Linear) -
   never duplicate the task. Do not skip this step.
4. **Write `tmp/current-task.pid` with the parent task id** and delete any stale
   `tmp/current-parent-task.pid`. At this point the parent is visibly claimed
   on the board, so later subtask PID changes cannot create an invisible race.

**PHASE 2: UNDERSTAND THE TASK (only after Phase 1 is complete)**

5. Read the parent task's full description from the PM tool.
6. **Read the parent task's comment history** (e.g., Asana stories). Comments often
   contain scoping decisions, open questions, or prior agent triage notes.
   If the comments indicate that the task still needs scoping or shaping
   (e.g., open questions, "triage needed", multiple competing approaches,
   unclear requirements), do NOT jump into implementation. Instead:
   - Summarize the current state of the discussion.
   - Propose a plan or recommendation addressing the open questions.
   - Wait for the user's approval before writing any code.
7. Run **Subtask Selection** exactly once for the claimed parent. If it selects
   an active subtask, read that subtask's full description and comments before
   coding.
8. Announce the active work item title, parent title when present, description
   summary, and key requirements to establish context for the session.

### 4. Update Task Status

When the user says "update task", "add note", "blocked":

- **Add context**: post a comment or note on the active task in the PM tool.
  If the active task is a subtask, mention the parent task in the note so the
  thread is understandable later.
- **Blocked top-level task**: if no parent PID exists and a private agent board
  is configured, move the active task to the "blocked/needs input" section
  there. Leave position on the shared board unchanged.
- **Blocked subtask**: if `tmp/current-parent-task.pid` exists, the active task
  is a subtask.
  - Post the blocking context on the subtask and parent task.
  - Move the parent container to the agent board's "blocked/needs input"
    section when configured, keep both PID files, and stop for user input.
  - If no agent board is configured, there is no durable machine-readable
    blocked state for future sessions. Say that explicitly, keep both PID
    files, and stop for user input. Do not pretend the block can be safely
    remembered across restarts.
  - Do not pick another direct subtask while the active subtask is blocked.
    Otherwise the blocked subtask still matches the normal eligibility filter
    and can be re-selected later.
  - Do not pick an unrelated top-level task unless the user explicitly
    redirects the session.
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

1. Check whether `tmp/current-parent-task.pid` exists. If it does, the active
   task is a subtask and the parent task must stay incomplete.
2. If completing a top-level task with no active parent:
   - First fetch direct subtasks when the PM tool supports them. If incomplete
     direct subtasks exist, do not mark the parent complete or silently re-enter
     Subtask Selection. Stop and ask the user to confirm whether to continue
     through the remaining subtasks or mark the parent complete despite
     incomplete direct subtasks. If the user chooses to continue through
     subtasks, run "Subtask Selection" and stop this completion flow. Continue
     to the next bullet only if the user explicitly confirms parent completion.
   - Set the active task's completion status in the PM tool. This is NOT the
     same as moving it to a section; it means marking the task itself as done
     (e.g., Asana: `asana_update_task` with `completed: true`; Linear: update
     state to "Done"). Verify the API response confirms the task is now marked
     complete before proceeding.
   - If a private agent board is configured, move the task to the "done"
     section there as well.
   - CRITICAL: Delete `tmp/current-task.pid` and
     `tmp/current-parent-task.pid`. Only do so when the task was QA'd and
     successfully marked complete in the PM tool.
   - Announce completion and ask if the user wants to pick the next task.
3. If completing a subtask:
   - Set the active subtask's completion status in the PM tool and verify the
     API response confirms the subtask is now marked complete before proceeding.
     **Note (Asana):** Completed tasks automatically disappear from board views,
     so no section move is needed on the shared board.
   - Leave the parent task incomplete and in progress.
   - Do not remove the parent task from the agent board's "current work"
     section.
   - Run "Subtask Transition" to select the next eligible direct subtask,
     release the parent if remaining direct subtasks belong to other people, or
     prepare the parent for explicit completion.

### 7. Read Task Details

When the user says "show task", "task details", "what's this task about":

1. Fetch the task from the PM tool.
2. Fetch subtasks when the PM tool supports them.
3. Display: title, description, assignee, current section, subtask completion
   summary, and recent comments or activity.

### 8. Session Status

When the user says "task status", "what am I working on":

1. Read both PID files. If `tmp/current-task.pid` is set, fetch that task from
   the PM tool. This is YOUR current task.
2. If `tmp/current-parent-task.pid` exists, also fetch the parent task and
   report that the current task is a subtask under that parent. Include the
   remaining incomplete direct subtask count when available.
3. If only `tmp/current-parent-task.pid` exists, report stale local state and
   follow Resume Session recovery before presenting status.
4. If no PID file exists, report that this agent has no task in progress.
5. If a private agent board is configured, list tasks in the "current work"
   section as **other agents' work** (for visibility, not for claiming).
6. If a private agent board is configured, list tasks that are marked as Blocked
   or Needs Input so the user can act on them.
7. Show title and brief status for each.

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

1. **Single active work item**: work on ONE task or subtask at a time until
   complete or blocked. A parent task can remain claimed as the container while
   the active work item is one of its subtasks.
2. **User controls top-level pacing**: never advance to an unrelated top-level
   task without the user's go-ahead. Within a claimed parent task, continue to
   the next eligible incomplete subtask after the current subtask is complete.
   "Next task" means the next subtask in the current parent; "switch tasks" or
   "different task" means release the parent and return to the top-level queue.
3. **Direct subtasks only**: this skill auto-selects only direct subtasks of the
   claimed parent. Nested subtasks are part of the selected subtask's scope and
   are not separate parent containers unless the user explicitly selects them.
4. **Shared board is source of truth**: the private agent board is a
   scratchpad. Status on the shared board is what teammates see.
5. **Don't duplicate tasks**: use multi-homing or cross-references, never
   copy tasks between boards.
6. **Announce transitions**: always tell the user when you move a task
   between sections or mark it complete.
7. **Never modify other agents' state.** Only add or remove YOUR active task
   (`tmp/current-task.pid`) or parent container (`tmp/current-parent-task.pid`)
   on the agent board. Never remove, move, or update tasks that belong to other
   agents. If you accidentally claimed a task that another agent owns, simply
   clear both PID files and pick a different task; do not touch the other
   agent's board entry.
