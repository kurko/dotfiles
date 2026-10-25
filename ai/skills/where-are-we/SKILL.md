---
name: where-are-we
description: Tell the user, in a few sentences, what problem the session is solving, what the agent does next, and what the agent needs from the user. Use when the user wants the short version of where the work stands. Manual only; the user invokes it with /where-are-we in Claude Code or $where-are-we in Codex.
disable-model-invocation: true
---

# Where are we

The user runs several sessions in parallel and comes back to this one without
its context. The answer has to tell the user, in a few seconds, what the
session is about and whether anything is waiting on them.

## Source

Answer from the conversation so far. When the "What I need from you" part
depends on state that may have changed since the agent last looked (a PR
merged, a question answered on the task), check that state with one quick
command first, so the user isn't asked for something already done. Don't
research beyond that.

## The four parts

Use these labels, in this order. Each part is at most two sentences.

**What I did:** the problem solved or being solved. Start at the level of the
product: the screen, endpoint or feature, and what was wrong with it for its
user. Add technical detail only after that. A reader who switched in from
another project can't place "we're improving the queue cache"; they can place
"we're making saved expenses reach the server even when the app goes offline,
by caching the sync queue". When the session covers several pieces of work,
name the goal they share, or name each piece by what it is for.

**Next:** leave this part out unless the agent has more work to do. Include
work that follows the user's part, for example what the agent will do after
the user reviews a PR, so the user reviews knowing what comes after.

**Suggestion:** leave this part out unless something critical needs action:
a security gap, a crash, data loss, or something that breaks the larger plan.
The user prefers no suggestions over minor ones.

**What I need from you:** where the agent is blocked by the user, for example
a PR to review or a requirement to decide. Name each PR or task by what it is,
"PR #31 (the entry form)", because the number alone doesn't say which one it
is. When there are questions that take more than two sentences, list them as
a numbered list so the user can reply by number. When nothing is waiting on
the user, write "Nothing."

## Example

    **What I did:** We're fixing sign-up, where new users couldn't finish
    because the email check rejected valid addresses with a "+". The fix and
    its tests are in PR #42 (sign-up email check).
    **What I need from you:** Review PR #42 (sign-up email check).

"Changed the EmailValidator regex and added specs" would fail the first part:
it says what changed, not what problem it solves or where in the app.

## After the answer

End the reply there. No preamble before the parts and no offer after them.
Don't continue the work in the same turn, because the user asked for a status
check and reads it to decide what happens next.
