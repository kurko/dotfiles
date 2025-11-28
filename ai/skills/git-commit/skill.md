---
name: git-commit
description: Stage and commit git changes with conventional commit messages. Use when user wants to commit changes, or asks to save their work. Also activates when user says "commit changes", simply "commit", or similar git workflow requests. Never commit without loading this skill.
---

# Git Commit Workflow

Stage all relevant changes, and create a conventional commit following patterns below.

## When to Use

Automatically activate when the user:
- Explicitly asks to push changes ("push this", "commit and push")
- Mentions saving work to remote ("save to github", "push to remote")
- Completes a feature and wants to share it
- Says phrases like "let's push this up" or "commit these changes"

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
- The first paragraph must explain what the PROBLEM is before the commit, and
  what impact it had.
- The second paragraph must explain what the implemented SOLUTION in the commit
  is. It doesn't need to go into all details that the code itself does, but should
  explain the approach taken, the reasoning. It needs to be as concise as possible.
- The third paragraph should explain what an ideal solution would look like this
  is not what the commit implements. It includes things that could be improved later,
  edge cases. It makes the current solution be intentional.
- Do not push directly after committing. Wait for user confirmation.
- Do not include Co-Authored-By: Claude <noreply@anthropic.com> or equivalent.
  You MUST NOT include any indication that an AI assisted in the commit or that
  the commit message was generated.

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
