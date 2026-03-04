---
name: working-off-of-todo-files
description: Use when the user asks you to interact, work, read, create or update tasks in ai-notes/**/*/todo.{md,txt} files, or when user asks you to look at the "todo file".
---

## Overview
This skill enables Claude Code to work systematically with
`ai-notes/**/*/todo.{md,txt}` files in your codebase. The agent focuses on
completing one task at a time with precision, breaking complex tasks into
subtasks mentally before execution.

## Core Principles

1. **Single Task Focus**: Work on ONE task at a time until completion or user intervention
2. **Mental Decomposition**: Break tasks into subtasks in memory before starting
3. **Progressive Status**: Use clear markers for task progress
4. **User Control**: Only advance to next task when explicitly instructed
5. **Context Awareness**: Understand the broader project while maintaining task focus

## Task Format Specification

### Basic Structure

```markdown
## Context
Brief overview of the project goals and current state

## Tasks

- [ ] Task 1: Clear task description
    Additional context or requirements indented by 4 spaces
    Can include multiple lines of detail
    
- [ ] Task 2: Another task
    Context and requirements
    
- [/] Task 3: Currently in progress
    This task is being worked on
    Progress notes can be added here
    
- [x] Task 4: Completed task
    This task has been finished
    Completion notes or results
```

### Task States

- `- [ ]` Pending: Task not yet started
- `- [/]` In Progress: Currently working on this task
- `- [x]` Completed: Task finished successfully

## Working Protocol

### 1. Initial Assessment

When starting work on a todo.md file:

```
1. Read the entire file to understand project context
2. Identify the next uncompleted task (first `- [ ]`, unless instructed otherwise)
3. Mentally decompose the task into subtasks
4. Announce which task you'll be working on
```

### 2. Task Execution Process

#### Before Starting

- Identify the task clearly: "I'll work on: [Task description]"
- Generate mental subtasks (do not write these to file):
  - Analyze requirements
  - Identify dependencies
  - Plan implementation steps
  - Define success criteria
- Mark task as in-progress: change `- [ ]` to `- [/]`

#### During Execution
- Work through mental subtasks systematically
- Add progress notes under the task (indented)
- If encountering blockers, document them
- Keep changes focused on the current task only

#### After Completion
- Verify all requirements are met
- Run relevant tests/specs
- Mark task complete: change `- [/]` to `- [x]`
- Add completion notes if valuable
- Stop and wait for user confirmation to continue

### 3. Communication Protocol

Always communicate:
- Which task you're starting
- Key decisions or assumptions
- Any blockers encountered
- When task is complete
- Request for permission to change plan if needed. Explain why and trade-offs.
- Request for permission to continue

Example interaction:
```
Agent: "I've identified Task 2: 'Implement user authentication'. I'll start by setting up the authentication middleware. Marking as in progress."

[Works on task]

Agent: "Task 2 is complete. The authentication system is now functional with JWT tokens. Should I proceed to Task 3 for adding a password reset functionality?"

User: "Yes, continue"

Agent: "Starting Task 3: 'Add password reset functionality'..."
```

## Mental Subtask Generation

For each task, generate (but don't write) subtasks like:

### Example: "Implement API endpoint"
Mental subtasks:
1. Define route structure
2. Write e2e tests (if applicable) to settle the expectations
3. Create controller function
4. Add input validation
5. Implement business logic
6. Add error handling
7. Write tests
8. Consider simplifications, optimizations, and readability.
9. Update documentation

### Example: "Fix bug in payment processing"

Mental subtasks:
1. Reproduce the bug
2. Write a test that fails due to the bug
3. Identify root cause
4. Review related code
5. Implement fix
6. Test edge cases
7. Run test that reproduced the bug
8. Verify no regression with existing tests
9. Document the fix

## File Discovery and Management

### Locating Todo Files
```bash
# Find all todo.md files in ai-notes directories
find . -path "*/ai-notes/*" -name "todo.md" -type f

# List with context
find . -path "*/ai-notes/*" -name "todo.md" -exec echo "Found: {}" \; -exec head -n 5 {} \;
```

### Safe File Operations
- Always backup before major changes
- Use atomic operations when possible
- Preserve file formatting and structure
- Maintain consistent indentation (4 spaces for task details)

## Task Dependencies and Context

### Understanding Dependencies
Before starting a task, check for:
- References to other tasks
- Required prerequisites
- Related code files mentioned
- External dependencies

### Maintaining Context
- Keep track of completed tasks for reference
- Note patterns or decisions from previous tasks
- Build on work from completed tasks
- Document assumptions for future tasks

## Error Handling

### Common Scenarios
1. **Ambiguous task description**
   - Ask for clarification
   - Document interpretation
   
2. **Blocked by external dependency**
   - Document the blocker
   - Suggest alternatives or workarounds
   - Move to next task only if instructed

3. **Task too large**
   - Suggest breaking into multiple tasks
   - Complete what's reasonable
   - Document remaining work

## Best Practices

### Do's
- ✅ Focus completely on one task
- ✅ Think through subtasks before starting
- ✅ Update status markers promptly
- ✅ Add helpful progress notes
- ✅ Verify completion thoroughly
- ✅ Wait for user permission between tasks
- ✅ Maintain clean, readable formatting

### Don'ts
- ❌ Jump between multiple tasks
- ❌ Skip marking progress states
- ❌ Add visible subtasks to the file (keep them mental)
- ❌ Continue to next task without permission
- ❌ Modify completed tasks unnecessarily
- ❌ Lose track of the big picture

## Advanced Features

### Task Annotations
You may encounter special annotations:

```markdown
- [ ] Task with priority !high
- [ ] Task with deadline @2024-12-31
- [ ] Task with assignee @alex
- [ ] Task with tag #backend
```

Respect these but don't require them.

- If you see !high, prioritize if user allows

### Progress Tracking

When requested, provide summary:
```
Total Tasks: X
Completed: Y (Z%)
In Progress: 1
Remaining: W
Current Focus: [Task description]
```

### Integration Notes

- Compatible with version control (git-friendly)
- Works alongside issue tracking systems
- Can reference external tickets or PRs
- Supports cross-referencing between projects

## Example Session

```markdown
# Initial State
- [ ] Set up database schema
- [ ] Create API endpoints
- [ ] Add authentication

# After starting Task 1
- [/] Set up database schema
    Creating tables for users, sessions, and permissions
    Using PostgreSQL with migrations
    
# After completing Task 1
- [x] Set up database schema
    Completed: 5 tables created, migrations ready
- [ ] Create API endpoints
- [ ] Add authentication

# User says "continue"
- [x] Set up database schema
    Completed: 5 tables created, migrations ready
- [/] Create API endpoints
    Working on RESTful endpoints for user management
- [ ] Add authentication
```

## Troubleshooting

### Issue: Task unclear
**Solution**: Ask for clarification, document assumptions

### Issue: Multiple todo.md files
**Solution**: Ask which project to focus on or work through them systematically

### Issue: Conflicting priorities
**Solution**: Follow file order unless user specifies otherwise

### Issue: Task partially complete from before
**Solution**: Assess current state, complete remaining work

## Remember
- Quality over speed
- One task, done well, is better than multiple tasks done poorly
- The user is in control of pacing
- Document your work for future reference
- Think in subtasks, but execute as one cohesive task
