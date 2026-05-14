---
description: Write plan, problem or large content to markdown file for human review.
---

# Write to markdown file and open it

The content above is hard for a human being to parse and read. Let's write it to
a markdown file and open it for the user to read in a more comfortable editor.

## Step 1: Write content to markdown file

### What

Write the content above to a markdown file so the user can read it in a
more comfortable editor. 

### Where

Save the file to a predefined directory if the user has it specific (e.g
ai-notes/, ./.ai-notes/), or a tmp directory (e.g ./tmp or /tmp).

Worktrees: DO NOT write the file inside the worktree directory because it become
ephemeral and deleted after some time. If the user has a worktree, check the parent directory for AI notes directories.

### How

Rule: a tl;dr section should always be present at the top

Start with an Overview section, one or two paragraphs describing the whole
content in a concise way. Then include the full content below it, with
appropriate markdown formatting (headings, bullet points, code blocks, etc.) to
make it easy to read.

If a problem is being described,

- Include a "Problem" section stating the problem clearly and concisely.
- Make sure to qualify the impact. Include how end-users would be impacted,
  costs, 2nd order effects.

If a solution is being proposed,

- include a "Proposed Solution" section outlining the solution in detail. This
  should include the technical approach, any trade-offs considered, and why this
- solution was chosen over alternatives. include what alternatives we considered
  and why we rejected them.


## Step 2: Open the file

```
open [path-to-file]
```

This should trigger the default markdown editor on the user's machine to open the file for review (e.g iA Writer).

## Things to know

- The user will write comments and notes in the file in formats that will vary,
  but are generally `[NAME: ...]`, `[COMMENT: ...; ...]`, or merely `[...]`.
- If the users says afterwards, `review comments`, that's what you will look
  for.
- Some comments are questions and some are change requests.
