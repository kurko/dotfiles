---
description: Write plan, problem or large content to markdown file for human review.
---

# Write to markdown file and open it

The content above is hard for a human to parse in the conversation. Write it to
a markdown file and open it so the user can review it in a more comfortable
editor.

## Step 1: Write content to markdown file

### What

Write the content above to a markdown file so the user can read it in a
more comfortable editor.

### Where

Save the file to a directory the user has specified, such as `ai-notes/` or
`./.ai-notes/`. If the user has not specified a location, use a temporary
directory such as `./tmp` or `/tmp`.

Worktrees: Do not write the file inside an ephemeral worktree directory. If the
user is working in a worktree, check the parent repository directory for an
existing notes directory before falling back to a temporary directory.

### How

Rule: a TL;DR section should always be present at the top.

Start with an Overview section, one or two paragraphs describing the whole
content in a concise way. Then include the full content below it, with
appropriate markdown formatting (headings, bullet points, code blocks, etc.) to
make it easy to read.

If a problem is being described,

- Include a "Problem" section stating the problem clearly and concisely.
- Make sure to qualify the impact. Include how end-users would be impacted,
  costs, 2nd order effects.

If a solution is being proposed,

- Include a "Proposed Solution" section outlining the solution in detail. This
  should include the technical approach, any trade-offs considered, and why this
  solution was chosen over alternatives. Include what alternatives were
  considered and why they were rejected.

## Step 2: Open the file

```
open [path-to-file]
```

Use the platform's default file opener. On macOS, `open [path-to-file]` should
open the file in the user's default markdown editor.

## Things to know

- The user will write comments and notes in the file in formats that will vary,
  but are generally `[NAME: ...]`, `[COMMENT: ...; ...]`, or merely `[...]`.
- If the user says afterwards, `review comments`, that's what you will look
  for.
- Some comments are questions and some are change requests.
