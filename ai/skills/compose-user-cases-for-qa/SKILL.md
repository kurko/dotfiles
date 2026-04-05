---
name: compose-user-cases-for-qa
description: Write or update UI-independent use cases for QA. Use when the user says "write use cases", "add use cases", "QA use cases", "update use cases", "compose use cases", or when starting implementation of a new feature (after plan approval). Also activates for "what should we test", "regression cases", or "use cases for QA".
allowed-tools: Read, Grep, Glob, Edit, Write
---

# Compose Use Cases for QA

Write UI-independent behavioral use cases to a project QA document. These use
cases describe **what the user can do**, not how the UI renders it. They serve
as regression checklists for browser QA — both after completing a task and when
future work overlaps with existing behavior.

## File Location

1. Look for an existing use cases file:
   - `docs/usercases.md` (single-file default)
   - `docs/usercases/` directory (split by area)
2. If neither exists, create `docs/usercases.md`.
3. **Split heuristic**: When the single file exceeds ~150 use cases or covers
   3+ distinct areas (screens, features), propose splitting into
   `docs/usercases/<area>.md` files. Ask the user before splitting.

## File Header

Every use cases file MUST start with this disclaimer:

```markdown
# Use Cases

> **This document is for reference only.** The software is the source of truth.
> Use cases here describe expected behaviors at the time they were written.
> Always verify against the running application.
```

For split files, each file gets a header like:

```markdown
# Use Cases: Timeline

> **This document is for reference only.** The software is the source of truth.
> Use cases here describe expected behaviors at the time they were written.
> Always verify against the running application.
```

## Use Case Format

Use cases are grouped by feature area under `##` headings. Each use case is a
numbered item with a short, declarative sentence describing a behavior the user
can perform or observe. Use cases are **not** step-by-step browser instructions
— they describe the *what*, not the *how*.

```markdown
## Pagination

1. The user sees a limited set of tasks on initial load.
2. The user can load more tasks incrementally.
3. Previously loaded tasks remain visible after loading more.
4. Task ordering is stable across pages — no duplicates, no reordering.
5. Loaded tasks persist across other interactions (navigating, filtering, etc.).
```

### Writing Guidelines

- **UI-independent.** Describe behaviors, not affordances. "The user can load
  more tasks" not "the user clicks the Load More button". The UI may change;
  the capability should not.
- **One behavior per line.** Each use case tests one thing.
- **Declarative voice.** "The user can..." or "The system shows..." — not
  imperative instructions.
- **General enough to survive UI changes.** If a redesign wouldn't invalidate
  the statement, it's the right level of abstraction.
- **Specific enough to be testable.** "The app works" is too vague. "Loaded
  tasks persist across zoom changes" is testable.

## Workflow

### When invoked explicitly (user says "write use cases", etc.)

1. **Read the existing file** (if any) to understand current coverage and format.
2. **Identify the feature area** from conversation context or user input.
3. **Draft use cases** for that area. Present them to the user for review
   before writing to the file.
4. **Append** the new section to the file (or update an existing section if
   adding cases to an already-documented area).
5. **Do not modify existing use cases** unless the user explicitly asks or the
   approved plan supersedes a previously documented behavior. When updating,
   edit the case in place (preserve its number) and append `(updated)` to
   the end of the line so the change is visible in diffs.

### When invoked during development flow (after plan approval)

1. Read the approved plan.
2. Identify new behaviors the plan introduces.
3. Draft use cases for those behaviors.
4. Present them to the user: "Before implementation, here are the use cases
   I'd add for this feature. Any adjustments?"
5. Write them to the file after approval.

### Adding to an existing section

When the feature area already has use cases, read the existing ones first.
Add new cases at the end of that section, continuing the numbering. Do not
renumber existing cases — other documents or conversations may reference them
by number.

## What NOT to Include

- Specific UI elements (button labels, CSS classes, pixel positions)
- Browser-specific test steps (open DevTools, check Network tab)
- Implementation details (API endpoints, database queries)
- Performance benchmarks (those belong in dedicated perf docs)

These details belong in `docs/QA/` browser test scripts, not in use cases.

## Relationship to Other QA Documents

Projects may have other QA artifacts (e.g., `docs/QA/` browser test scripts,
`docs/qa_checklist.md`). Use cases in `docs/usercases.md` are the **abstract
behavioral layer** — they describe *what to test*. Browser scripts describe
*how to test it*.

When adopting this skill on a project that already has a behavioral QA
checklist (not browser-step scripts), migrate its content into
`docs/usercases.md` to avoid two parallel documents for the same purpose.
Ask the user before migrating.
