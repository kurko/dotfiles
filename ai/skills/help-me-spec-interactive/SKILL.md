---
name: help-me-spec-interactive
description: Interview the user for a feature spec through an HTML questionnaire instead of chat prompts. Claude explores the codebase and writes a self-contained page of multiple-choice questions, each with a comment box and, where it helps, a diagram, chess board or other keyboard-driven example; the user answers in the browser and pastes back the answers text the page generates. Rounds repeat until the scope is clear, then Claude writes the spec. Use when the user says "/help-me-spec-interactive", "spec this with a form", "interactive spec", "give me the questions as a page", "HTML questionnaire", or wants to settle many scope questions in one sitting before Claude builds with less review.
argument-hint: "[feature description, file path, or URL]"
---

# Help Me Spec (interactive)

The interview of `help-me-spec`, with each round of questions delivered as a web page instead of AskUserQuestion prompts. A page holds a whole round, 8 to 20 questions, with room for context and pictures next to each; the user answers at their own pace, and one paste brings every answer back. The spec that comes out records the direction the user chose, so Claude can build from it with less review.

For one or two quick questions, AskUserQuestion is faster; use this skill when a feature has many open decisions.

## Files

Paths are relative to this skill's directory, `SKILL_DIR` (the base directory shown when the skill loads).

| File | Role |
|---|---|
| `form-template.html` | Page skeleton, styles and engine: renders the questions, keyboard shortcuts, the live answers text, copy buttons, and saving answers in localStorage. Never edited per round. |
| `scripts/build-page.mjs` | Builds one self-contained HTML file from a round's parts and checks it: schema, visuals, pinned libraries, then a headless Chrome render that fails on any script error. |
| `authoring.md` | How to write a round: questions, data format, visuals, build. The round subagent follows it. |
| `visuals.md`, `recipes/` | Tested recipes (Mermaid, chess boards and lines) and the rules for new interactive visuals and libraries. |
| `examples/pins/` | A complete round using every question and visual type, for a made-up feature. |
| `tests/` | `node --test SKILL_DIR/tests/*.test.mjs`. Run after changing the template, a recipe or a script. |

## Step 1: Starting context

Based on `$ARGUMENTS`:

- A URL: fetch it (WebFetch, or the matching tool for Linear, Asana, Notion and the like) and use the content.
- A file path (starts with `/`, `./`, `~`, or ends in `.md`, `.txt`): read it.
- Plain text: use it as is.
- Empty: ask "What do you want to spec?" with AskUserQuestion.

The result is `STARTING_CONTEXT`.

## Step 2: Work directory

Pick a kebab-case `SLUG` for the feature and create `WORK_DIR`: `$CLAUDE_JOB_DIR/tmp/spec-<SLUG>` when `CLAUDE_JOB_DIR` is set, since parallel jobs share `/tmp`; otherwise `/tmp/<YYYY-MM-DD>-spec-<SLUG>`. Outside the repository, the pages never reach git.

Write `WORK_DIR/transcript.md` with `STARTING_CONTEXT` under `# Starting context`. Every round's answers are appended to it, so the interview survives context compaction and each subagent reads it instead of receiving it inline.

## Step 3: Round loop

For round `N` = 1, 2, …, with `PAGE_ID` = `<YYYY-MM-DD>-spec-<SLUG>-r<N>` and `PAGE` = `WORK_DIR/<YYYY-MM-DD>-spec-<SLUG>-round-<N>.html`. The date sorts copies, and the name identifies a copy moved elsewhere.

### 3a. Launch the round subagent

Launch a `general-purpose` subagent (model `opus`) with this prompt, placeholders filled:

```
Role: senior product manager and technical architect, preparing round {N} of a
spec interview. The user answers in a web page built in this task, where
positions, flows and examples sit next to each question.

Read first:
- {SKILL_DIR}/authoring.md, and follow it. It points to visuals.md when a
  question needs a visual.
- {WORK_DIR}/transcript.md: the starting context, every answer so far and
  Claude's reading of each round.
- {WORK_DIR}/round-*/data.json: the questions behind those answers, with
  their context, option descriptions and recommended options.

Then:
1. Explore the codebase for what the feature touches: models, patterns,
   naming, extension points, tests, and anything the answers so far point to.
2. Decide whether the interview is complete. It is complete only when the
   direction-setting decisions are answered (architecture, data shape, edge
   cases, error handling, what is out of scope) and no non-obvious question
   is left. If it is, skip to the output.
3. Write round {N}'s parts in {WORK_DIR}/round-{N}/ with page id "{PAGE_ID}"
   and build the page to {PAGE}, as authoring.md describes. Rebuild until
   the build prints "ok".

Output only this JSON, no fencing:
{
  "exploration_summary": "2-3 sentences on what was found that shaped the questions",
  "page": "{PAGE}, or null when complete",
  "question_count": 12,
  "interview_complete": false,
  "completion_reason": null
}
```

### 3b. Check and open the page

Parse the JSON. If `interview_complete` is true, go to Step 4.

Otherwise re-run `node {SKILL_DIR}/scripts/build-page.mjs --check {PAGE}` rather than trusting the subagent's report. If it prints problems, send them to the subagent with SendMessage and check again.

Open the page in the default browser (`open` on macOS, `xdg-open` on Linux). Tell the user, briefly:

- the exploration summary
- the number of questions and the `file://` link
- "Answer in the browser, then paste the text from the bottom of the page here."

End the turn and wait for the paste.

### 3c. Read the answers

The paste starts with `help-me-spec-interactive answers` and names the page id and round.

1. If the page id is not the latest round's, say which round it belongs to and ask whether to use it.
2. Append the paste verbatim to `transcript.md` under `## Round {N} answers`.
3. Read `WORK_DIR/round-{N}/data.json`: an answer's meaning is in its option's description, the question's context and its visual, none of which the paste carries.
4. Restate the decisions in a few lines, one per answered question plus the general comment, so the user can catch a misreading before the next page. An unanswered question in the "Defaults I'll use unless you object" section takes its recommended option, as that section tells the user. For any other unanswered question, say whether the next round asks again or Claude decides and records the assumption. Append the restatement to `transcript.md` under `### Claude's reading`.
5. If the paste says `Next step: Stop asking and write the spec`, go to Step 4. Otherwise loop to 3a with `N + 1`, without waiting. If the user corrects the restatement while that subagent runs, append the correction to `transcript.md` and forward it to the subagent with SendMessage, so the next page is not built on the misreading.

The user may answer in chat instead ("Q3 is 2, skip Q5"); handle it the same way.

After round 3, ask whether to continue or write the spec. One page holds as much as five AskUserQuestion rounds, so three pages is a long interview.

## Step 4: Write the spec

Launch a final `general-purpose` subagent (model `opus`):

```
Role: senior technical writer creating a specification document.

Read {WORK_DIR}/transcript.md: the starting context, every round of answers
and Claude's reading of each. Read {WORK_DIR}/round-*/data.json alongside it:
an answer means what its option's description and the question's context
say. An unanswered question in a "Defaults I'll use unless you object"
section takes its recommended option.

1. Explore the codebase to verify and enrich the interview findings: read
   the relevant files, check existing patterns, understand the domain model.
2. Write a specification from the answers and the exploration. Include only
   the sections that apply:
   - Overview and goals
   - User stories or use cases
   - Technical architecture: how it fits the existing system
   - Data models: new or changed models, columns, indexes
   - API design: endpoints, parameters, responses
   - UI/UX: interactions, states, flows
   - Edge cases and error handling
   - Security: auth, validation, data access
   - Migration path
   - Decisions made without an answer: every question left unanswered or
     answered "Other" without detail, with the decision taken and why, so
     the user can review these instead of the whole spec
   - Open questions
   - Out of scope
3. Be specific: real file paths and class names, code examples where they
   clarify, and a note wherever the spec departs from an existing pattern.
   A spec is a reference document; keep it concise.

Save it to ./ai-notes/specs/{SLUG}.md when ./ai-notes exists, otherwise to
./docs/{SLUG}.md. Return the path and the full text.
```

## Step 5: Present the spec

Show the spec and its path, with the "Decisions made without an answer" section called out. Make small adjustments the user asks for directly, without another subagent.

## Usage

```
/help-me-spec-interactive Add a detector for knight forks
/help-me-spec-interactive https://linear.app/team/issue/HUM-123
/help-me-spec-interactive ./notes/feature-idea.md
/help-me-spec-interactive
```
