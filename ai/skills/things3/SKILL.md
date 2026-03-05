---
name: things3
description: Manage Things 3 tasks, projects, and lists via CLI
allowed-tools: Bash(things3:*)
---

# Things 3 CLI

Use the `things3` command to manage Things 3 tasks. This avoids raw `osascript`
calls which trigger per-invocation permission prompts.

## Reading Data

```bash
things3 today              # Today's tasks
things3 inbox              # Inbox
things3 upcoming           # Upcoming tasks
things3 anytime            # Anytime tasks
things3 someday            # Someday tasks
things3 logbook            # Completed tasks
things3 logbook --period 7d --limit 20
things3 trash              # Trashed tasks
things3 todos              # All todos
things3 todos --project "Project Name"
things3 projects           # All projects
things3 areas              # All areas
things3 tags               # All tags
things3 tagged "tag name"  # Items with a specific tag
things3 headings           # All headings
things3 headings --project "Project Name"
things3 search "query"     # Search todos by text
things3 search-advanced --status completed --tag "work"
things3 recent 3d          # Items created in last 3 days
```

## Creating Tasks

```bash
things3 add "Task title"
things3 add "Task title" --when today --tags "work,urgent"
things3 add "Task title" --notes "Details" --deadline 2026-12-31
things3 add "Task title" --checklist "Step 1,Step 2,Step 3"
things3 add "Task title" --project "Project Name" --heading "Section"
```

## Creating Projects

```bash
things3 add-project "Project title"
things3 add-project "Project title" --notes "Description" --area "Work"
```

## Updating Items

```bash
things3 update UUID --title "New title"
things3 update UUID --completed
things3 update UUID --when tomorrow --add-tags "urgent"
things3 update-project UUID --completed
```

## Navigating Things UI

```bash
things3 show UUID          # Open item in Things
things3 search-ui "query"  # Open search in Things
```

## Output Format

Each item shows: title, notes, dates, tags, project, checklist, and UUID.
The UUID is needed for `update`, `update-project`, and `show` commands.

## When Values

The `--when` flag accepts: `today`, `tomorrow`, `evening`, `tonight`,
`anytime`, `someday`, or a date in `YYYY-MM-DD` format.
