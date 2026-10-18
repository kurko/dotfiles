---
name: pr-is-merged-work-is-done
description: >-
  Wrap up a session whose pull request is merged: move the task named in the
  session's pm-tasks PID file to Done (or In Review), tear down every git
  worktree the session created or entered (its servers, per-worktree
  databases, branch and directory), then end the reply with the word
  "goodbye" so the user knows the session is safe to close. Use when the user
  runs
  /pr-is-merged-work-is-done or says "the PR is merged", "work is done, close
  the session", "tear down the worktree", or "clean up, I'm closing this".
disable-model-invocation: true
---

# PR Is Merged, Work Is Done

The user merged the pull request and is about to close this session. Claude
closes out the task in the session's PID file when there is one, tears down
every worktree the session used, so no directory, branch, database or process
is left behind, and ends the reply with "goodbye". The user closes the
session when they see that word, so Claude writes it only when nothing would
be lost.

## 1. Find the session's worktrees

A worktree belongs to this session when the session created or entered it:
with `EnterWorktree` (usually under `.claude/worktrees/<name>`), with
`git worktree add`, or as the directory the session started in. Run
`git worktree list` and match those paths. The first entry is the main
worktree, which is never torn down.

Leave every other worktree alone, even when it looks finished: another session
may be working in it. When ownership is unclear, ask the user.

If the session used no worktree, say so, run step 3, and skip to step 7.

## 2. Check that nothing would be lost

Teardown deletes the worktree's directory and its branch, so check each one
first. Run each git command as its own call: worktree-isolated sessions refuse
git commands chained with `&&` or wrapped in `$(...)`.

- `git status --porcelain` is empty. Untracked files count, because they
  disappear with the directory.
- `git fetch origin`, then `git log origin/<branch>..HEAD` is empty, so every
  local commit reached the remote.
- The branch's pull request is merged: `gh pr view <branch> --json
  state,mergedAt` shows `MERGED`. Without a pull request,
  `git merge-base --is-ancestor HEAD origin/<default-branch>` exits 0.

Squash and rebase merges leave the branch looking unmerged to git, so for a
branch with a pull request the `MERGED` state is what counts.

If any check fails, stop for that worktree, report what would be lost
(uncommitted files, unpushed commits, an open pull request), and ask the user
what to do. Do not write "goodbye" while a worktree is in that state.

## 3. Close out the task

Close out a task only when `tmp/current-task.pid` exists at the checkout's
root and holds a task id. `pm-tasks` writes that file when it claims a task
and deletes it at handoff, so it is the record of a task this session still
owes an update.

With no PID file, do not move any task on Claude's own judgment. If a task
came up in the conversation (a link, an id, or work the user described as a
task), ask the user what to do about it, because it may have been handed off
already or belong to someone else. Finish the rest of the teardown, end the
reply with that question instead of "goodbye", and say goodbye once the user
has answered and the task is handled. If no task came up, skip this step and
say no task was tracked.

When the file holds a task id, fetch that task and move it. Use Done when the
merged pull request completes the task. Use In Review when work remains
outside the pull request (for example a package release, a deploy, or QA).
If the conversation does not make the choice clear, ask. Follow the project's
`### Project Management` section in CLAUDE.md for the tool and state names,
move the task on the agent board too when one is configured, and confirm the
tool's response shows the new state. Then delete the PID file.

When `tmp/current-parent-task.pid` also exists, the PID task is a subtask.
Close out the subtask only and leave the parent as it is; `pm-tasks` completes
a parent only on the user's explicit confirmation. Delete both files.

Do this before step 6. The PID files live inside the worktree, so they
disappear with it.

## 4. Stop what the session started

Stop the background tasks this session launched (servers, watchers, monitors)
with `TaskStop`. A running server holds database connections, which makes the
database drop in step 5 fail, and a process whose working directory is inside
the worktree keeps running after the directory is gone.

## 5. Run the project's teardown

Projects that give each worktree its own resources (databases, ports, env
files) usually ship a teardown command next to the setup one, such as
`bin/teardown-worktree`, or document it in AGENTS.md, CLAUDE.md or the README.
Look for it and run it from inside the worktree before removing the
directory, because it reads the worktree's own files (for example
`.env.local`) to find what to drop. Report what it dropped.

## 6. Remove the worktree and its branch

**Worktrees the session entered with `EnterWorktree`:** call `ExitWorktree`
with `action: "remove"`. It deletes the directory and the branch and returns
the session to its original directory.

`ExitWorktree` refuses when the branch has commits that are not on the
original branch. That is expected after a squash merge, or when the local
default branch has not been pulled. When step 2 showed the pull request merged
and every commit pushed, the user's invocation of this skill is the
confirmation to call it again with `discard_changes: true`. Uncommitted or
untracked files are different: never discard them without asking.

**Other worktrees:** run `git worktree remove <path>` from outside it, without
`--force`, so git refuses if anything changed since step 2. Then delete the
branch with `git branch -d <branch>`. When `-d` refuses because of a squash
merge, `git branch -D <branch>` is safe only because step 2 confirmed the merge.
Run `git worktree prune` at the end.

Leave remote branches alone unless the user asks. Deleting one is visible to
others, GitHub may already delete merged branches, and something else may
still point at it (for example a dependency installed from a git branch).

## 7. Report and say goodbye

When step 3 moved a task, report its new state and link. For each worktree,
report its path and branch, what the teardown dropped (databases, processes,
env entries), and anything kept, with the reason.

When every worktree is torn down (or kept because the user said so) and no
task question from step 3 is open, make "goodbye" the last word of the reply.
Status lines that other workflows require, such as a background job's
`result:` line, go before it. When something is still blocked or a question
is open, end with the question for the user instead; the missing "goodbye"
tells them the session is not safe to close yet.

## Error handling

| Scenario | Action |
|----------|--------|
| Task tracker unreachable (MCP error, auth) | Retry once; then report the task id and the state it needs, because the PID files go away with the worktree |
| Uncommitted or untracked files | Stop; list them and ask whether to commit, keep the worktree, or discard |
| Commits not on the remote | Stop; offer to push them, or ask whether they can go |
| Pull request open or closed without merging | Stop; the work did not land, so ask before deleting it |
| `ExitWorktree` lists unmerged commits after step 2 passed | Call it again with `discard_changes: true` |
| `ExitWorktree` reports no active worktree session | The worktree came from `git worktree add` or another session; use `git worktree remove` |
| Teardown script fails (for example a database still in use) | Stop the process holding it and run the script again; report it if it still fails |
| Worktree belongs to another session | Leave it and mention it in the report |
