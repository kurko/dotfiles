---
name: align
description: Restate, in Claude's own words, what the user's goals are and what problem the user is trying to solve, then stop so the user can confirm or correct it. Use to check shared understanding before or during a task. Manual only; the user invokes it with /align in Claude Code or $align in Codex.
argument-hint: "[optional focus, link, or file]"
disable-model-invocation: true
---

# Align

Restate the user's goals and the problem the user is trying to solve, in
Claude's own words. The user reads the restatement to check what Claude
understood. A wrong restatement costs one reply to fix; a wrong assumption
found after the work is done costs rework.

## Source

Work from the conversation so far: the user's messages, the links and files
the user shared, and what Claude found during the work.

Read links or files the user gave, with this invocation or earlier, that
Claude has not opened yet, because they are part of what the user said. Do not
search or explore beyond that. The restatement is a record of what Claude
understands now, and more research changes that understanding before the user
can check it.

When the user typed a focus after the skill name, restate that part of the
work only.

When the conversation has too little to go on, say what is missing and ask the
user to describe the goal.

## Write the restatement

- Paraphrase. Do not quote the user's phrasing back. A misunderstanding is
  visible in a paraphrase; a quote repeats the user's words whether or not
  Claude understood them.
- Goals: the outcome the user wants. When the conversation contains a larger
  goal behind the request, state both.
- Problem: the current state, what is wrong or missing, and what stands
  between the current state and the goal. Include constraints the user stated.
- List what Claude inferred and the user did not say, so the user knows where
  to look first.

Use this shape, and keep each part short:

    **Your goals**
    - [immediate goal]
    - [larger goal it serves, when known]

    **The problem**
    [2-4 sentences: current state, what is wrong or missing, what blocks the
    goal, constraints the user stated]

    **Inferred, not stated**
    - [assumption]

    Is this right? What did I miss or get wrong?

Omit **Inferred, not stated** when everything came from the user.

## After the restatement

Stop and wait for the user's reply. Do not resume the task in the same turn,
because the user invoked this skill to check understanding before more work
happens.

When the user corrects the restatement, restate the corrected parts in one or
two lines. When the plan or the work already done must change because of the
correction, list the changes and wait for the user's approval. Otherwise,
continue the work with the corrected understanding.
