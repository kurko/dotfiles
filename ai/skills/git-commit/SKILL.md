---
name: git-commit
description: Stage and commit git changes, and open PRs. Use when committing, pushing, or opening a pull request, including when wrapping up your own work in a background job. Activates on "commit", "push", "create a PR", "open a PR", "draft PR", or any end-of-task workflow that produces a commit or PR. Never commit or open a PR without loading this skill.
---

# Git Commit and PR Workflow

Stage all relevant changes, create a conventional commit following patterns below.
When the workflow also calls for a PR, open one using the commit message as the
description (see the "Pull Requests" section).

## When to Use

Automatically activate when:
- The user asks to commit, push, or open a PR
- You are finishing work (background job, worktree task) and need to commit, push, or open a PR
- The user says "commit and push", "push this up", "save to github", "create a PR",
  "open a PR", "draft PR", "open a pull request", or similar
- Another skill or workflow asks you to commit or create a PR

## Commit Message Patterns

Here's a model Git commit message:

```
Capitalized, short (50 chars or less) summary

More detailed explanatory text, if necessary.  Wrap it to about 80
characters or so.  In some contexts, the first line is treated as the
subject of an email and the rest of the text as the body.  The blank
line separating the summary from the body is critical (unless you omit
the body entirely); tools like rebase can get confused if you run the
two together.

Write your commit message in the imperative: "Fix bug" and not "Fixed bug"
or "Fixes bug."  This convention matches up with commit messages generated
by commands like git merge and git revert.

Further paragraphs come after blank lines.

- Bullet points are okay, too
- Typically a hyphen or asterisk is used for the bullet, followed by a
  single space, with blank lines in between, but conventions vary here
- Use a hanging indent
```

The rules:

- The first line is a concise summary of the change, 50 characters or less.
- Wrap all lines in the body to 80 characters maximum.
- The first paragraph must explain what the PROBLEM is before the commit, and
  what impact it had. If there's an obvious counterargument or objection to the
  change ("why not just X?"), acknowledge it briefly and explain why the change
  is still worthwhile.
- The second paragraph must explain what the implemented SOLUTION in the commit
  is. Write it as proper prose, not bullet-point style - start sentences with a
  subject like "This commit...", "This change...", or "This modification...",
  and use "It also..." for follow-up sentences rather than starting with a verb.
  It doesn't need to go into all details that the code itself does, but should
  explain the approach taken, the reasoning. It needs to be as concise as possible.
- The third paragraph should explain what an ideal solution would look like this
  is not what the commit implements. It includes things that could be improved later,
  edge cases. It makes the current solution be intentional.
- Never use em dashes or double hyphens in commit messages. Use commas,
  parentheses, or separate sentences instead.
- Do not push directly after committing. Wait for user confirmation.
- Do not include Co-Authored-By: Claude <noreply@anthropic.com> or equivalent.
  You MUST NOT include any indication that an AI assisted in the commit or that
  the commit message was generated.

## Examples

### Refactoring for clarity

```
Move EmailValidator to Notifications namespace

The EmailValidator class validates email format, delivery status, and bounce
handling, all specific to our notification system. Its generic name and
top-level location made it look like a general-purpose utility when it's
tightly coupled to notification internals. Sure, someone could read the code
to understand this, but the name should communicate intent upfront.

This commit moves the class under the Notifications namespace to clarify its
scope. It also updates the three call sites in the mailer classes accordingly.
```

### Bug fix

```
Fix race condition in payment processing

When two requests hit the payment endpoint simultaneously, both could pass
the idempotency check before either wrote to the database. This caused
duplicate charges in production roughly once per 10k transactions.

This change wraps the check-and-write in a database transaction with row-level
locking. It also adds an index on the idempotency key to keep the lock fast.

A distributed lock (Redis/etc) would handle cross-server races better, but
our current single-database setup makes this sufficient for now.
```

### Simple feature

```
Add retry button to failed export jobs

Users had no way to retry a failed export without re-entering all parameters.
Support tickets about this increased after we added the larger export types
last month.

This commit adds a retry action to the exports controller that clones the
original job's parameters into a new job. It also adds the button to the
job status page, visible only for failed jobs.
```

## Cross-Repo Commits

When committing in a repo that is NOT the current working directory, use
`git -C <path>` instead of `cd <path> && git ...`. This avoids repeated
permission prompts from safety hooks that flag `cd` to external directories.

```bash
# Good: stays in current directory
git -C ~/.dotfiles status
git -C ~/.dotfiles add ai/skills/tool-sentry/
git -C ~/.dotfiles commit -m "Add sentry skill"

# Bad: triggers permission prompt for each command
cd ~/.dotfiles && git status
cd ~/.dotfiles && git add ai/skills/tool-sentry/
cd ~/.dotfiles && git commit -m "Add sentry skill"
```

## Workflow

**ALWAYS use the terminal**: example of passing paragraphs via `-m` flags:

```bash
git commit \
  -m "paragraph 1" \
  -m "paragraph 2" \
  -m "paragraph 3"
```

If you pass all in one line in bash/zsh, you have to use `$'...'` syntax with
`\n\n` for new paragraphs:

```bash
git commit -m $'paragraph 1\n\nparagraph 2\n- bullet point\n- bullet point'
```

Once you commit, let me know what the commit title was.

## Pull Requests

When the workflow includes opening a PR (background job wrap-up, user asks for
a PR, pushing a worktree branch):

1. Push the branch with `git push -u origin <branch>`.
2. Open the PR with `gh pr create`. Use `--draft` unless told otherwise.
3. **The PR description is the commit message body, plus a task link.** Nothing
   else. No bullet-point summaries, no "## Summary" sections, no test plan
   checklists, no reformatting. Copy the commit body paragraphs verbatim.
4. If there is an Asana task, Linear issue, or similar link, append it after the
   commit body as a plain line (e.g. `https://app.asana.com/...`).
5. The PR title is the commit summary line.

```bash
# Example: single-commit branch, task link known
gh pr create --draft \
  --title "Add Looking Glass resource for vendor_incidents" \
  --body "$(cat <<'EOF'
The vendor_incidents table tracks catalog outages synced to the Instatus
status page, but there was no way to query it through Looking Glass.
Investigating stale incidents required either a Rails console session
or a new tool.

This commit adds a VendorIncidentResource exposing all non-sensitive
columns plus three association-derived attributes. It includes custom
filters for product_id and product_public_token and declares
serialization_preloads to avoid N+1 queries on list requests.

A richer resource could expose the vendor_error_metrics table as well.
That can be a separate resource if the need arises.

https://app.asana.com/0/1201647585774820/1218502568297202
EOF
)"
```

For multi-commit branches, use the full `git log --format` body of all commits
on the branch (not just the latest), separated by blank lines.
