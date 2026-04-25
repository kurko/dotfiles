---
name: worktree-merge-to-main
description: >-
  Merge the current worktree branch into main and sync main back. Use when
  the user says "merge to main", "ship it", "merge and continue", or after
  completing a task in a worktree and wanting to continue with the next one.
---

# Worktree Merge to Main

Merge the current worktree branch into main, sync main back, and reset the
environment so the user can continue working on a new task in the same worktree.

## Prerequisites

- The current directory must be inside a git worktree (not the main working tree).
- The working tree must be clean (no uncommitted changes). If dirty, ask the
  user whether to commit or stash before proceeding.

## Steps

### 1. Detect Context

```bash
git rev-parse --is-inside-work-tree   # must be true
git worktree list                     # identify main worktree path
git branch --show-current             # current branch name
git status --porcelain                # must be empty
```

Extract the **main worktree path** from `git worktree list` (the first entry
in the output is always the main worktree).
Extract the **current branch name** for the merge command.

If the working tree is dirty, stop and ask the user what to do.

### 2. Merge Worktree Branch into Main

Use `git -C` to operate on the main worktree without leaving the current
directory. This is an intentional exception to the "avoid git -C" guideline —
the agent must operate on a different worktree than the current directory.

```bash
git -C <main_worktree_path> merge <current_branch_name>
```

If the merge has conflicts:
- Show the conflicted files.
- Resolve them (the conflicts are in the **main** worktree's files, so use
  `git -C` or absolute paths to read/edit them).
- After resolution, stage and commit the merge in the main worktree.
  Use raw git here (not the git-commit skill) because this is a merge
  commit with an auto-generated message:
  ```bash
  git -C <main_worktree_path> add -A
  git -C <main_worktree_path> commit --no-edit
  ```

### 3. Merge Main Back into Worktree

This brings the worktree branch up to date with main (including any other
work that landed on main since the branch diverged).

```bash
git merge main
```

If this produces conflicts, resolve them in the current worktree (normal
workflow since the files are local).

Handle stashed changes: if the working tree had unstaged changes from
dependency files (yarn.lock, Gemfile.lock) that conflict, resolve by
accepting the merged version and re-running the setup step.

### 4. Reset Environment

If `bin/setup-worktree` exists, run it to:
- Install dependencies (bundle, yarn)
- Run migrations
- Re-seed the database with fresh data

```bash
if [ -f bin/setup-worktree ]; then
  bin/setup-worktree
fi
```

### 5. Confirm

Report what happened:
- Which branch was merged into main
- Whether any conflicts were resolved
- Whether `bin/setup-worktree` ran
- The worktree is ready for the next task

## Error Handling

| Scenario | Action |
|----------|--------|
| Dirty working tree | Ask user: commit, stash, or abort |
| Merge conflicts (into main) | Resolve using `git -C` on the main worktree |
| Merge conflicts (main into worktree) | Resolve locally in the worktree |
| `bin/setup-worktree` fails | Show the error output, suggest manual intervention |
| Not in a worktree | Abort with message: "This command is for worktrees only" |
