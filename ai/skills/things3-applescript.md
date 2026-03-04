# Things 3 AppleScript Integration

Use AppleScript via `osascript` to interact with Things 3. No MCP required.

## Create a Task in Today

```bash
osascript -e '
tell application "Things3"
    set newToDo to make new to do with properties {name:"Task title", notes:"Optional notes"}
    schedule newToDo for (current date)
end tell
'
```

## Create a Task with Checklist

```bash
osascript -e '
tell application "Things3"
    set newToDo to make new to do with properties {name:"Task title", notes:"Details here"}
    schedule newToDo for (current date)
    tell newToDo
        make new checklist item with properties {name:"Step 1"}
        make new checklist item with properties {name:"Step 2"}
        make new checklist item with properties {name:"Step 3"}
    end tell
end tell
'
```

## Create a Task in a Specific Project

```bash
osascript -e '
tell application "Things3"
    set targetProject to project "Project Name"
    make new to do with properties {name:"Task title", project:targetProject}
end tell
'
```

## Create a Task with Due Date

```bash
osascript -e '
tell application "Things3"
    set dueDate to (current date) + (3 * days)
    set newToDo to make new to do with properties {name:"Task title", due date:dueDate}
end tell
'
```

## Common Mistakes

- **Wrong**: `tag names:{"Today"}` - This creates a TAG called "Today", not a schedule
- **Right**: `schedule newToDo for (current date)` - This puts the task in Today view

## Reference

Full AppleScript guide: https://culturedcode.com/things/support/articles/2803574/
