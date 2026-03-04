---
description: Interview the user in depth to create a detailed specification document
---

# Help Me Spec

This command runs an iterative interview loop to create a comprehensive
specification document. Subagents handle codebase exploration and question
generation; the main thread handles user interaction via AskUserQuestion.

## Why This Architecture

Subagents cannot use AskUserQuestion (they run autonomously). But we want
subagents to do the heavy exploration (saving main context window). Solution:
an iterative loop where subagents explore and generate questions, the main
thread presents them interactively, and the next subagent round gets the
accumulated answers to go deeper.

## Instructions

### Step 1: Determine the starting context

Based on `$ARGUMENTS`:

- If it looks like a URL (contains `http://` or `https://`): Use WebFetch to
  load the content, then use that as `STARTING_CONTEXT`
- If it looks like a file path (starts with `/`, `./`, `~`, or contains common
  extensions like `.md`, `.txt`): Use Read to load the file, then use that as
  `STARTING_CONTEXT`
- If it is plain text: Use it directly as `STARTING_CONTEXT`
- If it is empty: Use AskUserQuestion to ask "What do you want to spec?" with
  a free-text option, then use the answer as `STARTING_CONTEXT`

### Step 2: Run the interview loop

Maintain a `QA_TRANSCRIPT` variable (initially empty string). Then loop:

#### 2a. Launch an Explore subagent (codebase research + question generation)

Use subagent_type=`general-purpose` with model=`opus`. Send this prompt:

```
You are a senior product manager and technical architect. Your job is to
explore the codebase and generate interview questions for a specification.

## Starting Context
[INSERT STARTING_CONTEXT]

## Previous Q&A
[INSERT QA_TRANSCRIPT — empty on first round]

## Your Task

1. Explore the codebase thoroughly to understand the current architecture,
   patterns, and relevant code related to the starting context. Read files,
   search for patterns, understand the domain model.

2. Based on your exploration AND any previous Q&A answers, generate 1-4
   focused questions that probe non-obvious aspects of the feature. Each
   question should:
   - Have 2-4 concrete options (with brief descriptions of tradeoffs)
   - Be specific to THIS codebase, not generic
   - Build on previous answers (don't re-ask what's been answered)
   - Surface hidden complexity, edge cases, or architectural decisions

3. Determine if the interview should continue or is complete.

## What to Explore

Adapt to the project type. Focus on areas relevant to the feature:
- Technical: data models, state management, integration points, performance
- Architecture: existing patterns, extension points, naming conventions
- Edge cases: error handling, race conditions, boundary conditions
- Product: user flows, empty states, failure modes
- Tradeoffs: simplicity vs flexibility, consistency vs pragmatism

## Question Guidelines

- DO NOT ask obvious questions a competent developer would figure out
- DO NOT re-ask anything already covered in Previous Q&A
- DO ask about the non-obvious: edge cases, implicit assumptions, "what if" scenarios
- Prefer specific questions over broad ones
- Surface hidden complexity early
- If previous answers reveal new considerations, probe those

## Output Format

Return ONLY a JSON object (no markdown fencing, no extra text):

{
  "exploration_summary": "Brief summary of what you found in the codebase that informed these questions (2-3 sentences)",
  "questions": [
    {
      "question": "The complete question text ending with ?",
      "header": "Short label (max 12 chars)",
      "options": [
        {"label": "Option name (1-5 words)", "description": "What this means and tradeoffs"},
        {"label": "Another option", "description": "What this means and tradeoffs"}
      ],
      "multi_select": false
    }
  ],
  "interview_complete": false,
  "completion_reason": null
}

Set "interview_complete" to true ONLY when:
- All major architectural decisions have been covered
- Edge cases and error handling have been discussed
- The previous Q&A covers enough ground for a solid spec
- You have no more non-obvious questions to ask

When complete, set "completion_reason" to a brief explanation of why the
interview is sufficient (e.g., "All major areas covered: architecture,
data model, error handling, and UI interactions").
```

#### 2b. Parse the subagent's response

Extract the JSON from the subagent's response. If `interview_complete` is
true, skip to Step 3.

#### 2c. Present the exploration summary

Show the user the `exploration_summary` so they see what the subagent found.

#### 2d. Present questions via AskUserQuestion

Use the AskUserQuestion tool with the questions from the JSON. Pass them
exactly as structured (question, header, options, multiSelect).

#### 2e. Append to QA_TRANSCRIPT

After the user answers, append the questions and their answers to
`QA_TRANSCRIPT` in a readable format:

```
### Round N

Q: [question text]
A: [user's answer]

Q: [question text]
A: [user's answer]
```

#### 2f. Loop back to 2a

Continue the loop with the updated QA_TRANSCRIPT. The next subagent round
will see all previous answers and can explore deeper based on them.

**Safety valve:** If you've completed 5+ rounds, ask the user if they want
to continue or finalize the spec.

### Step 3: Generate the spec document

Launch a final `general-purpose` subagent (model=`opus`) with this prompt:

```
You are a senior technical writer creating a specification document.

## Starting Context
[INSERT STARTING_CONTEXT]

## Complete Interview Transcript
[INSERT FULL QA_TRANSCRIPT]

## Your Task

1. First, explore the codebase to verify and enrich the interview findings.
   Read relevant files, check existing patterns, understand the domain model.

2. Write a comprehensive specification document based on the interview
   answers AND your codebase exploration.

## Spec Structure

Include only sections relevant to the feature:

- **Overview & Goals**: What we're building and why
- **User Stories / Use Cases**: Who benefits and how
- **Technical Architecture**: How it fits into the existing system
- **Data Models**: New or modified models, columns, indexes
- **API Design**: Endpoints, parameters, responses (if applicable)
- **UI/UX Specifications**: Interactions, states, flows (if applicable)
- **Edge Cases & Error Handling**: What could go wrong and how to handle it
- **Security Considerations**: Auth, validation, data access
- **Migration Path**: How to get from current state to target state
- **Open Questions**: Anything still unresolved from the interview
- **Out of Scope**: Explicitly what this does NOT include

## Writing Guidelines

- Be specific and concrete, not vague or aspirational
- Reference actual file paths and class names from the codebase
- Include code examples where they clarify the design
- Note where the spec departs from existing patterns and why
- Keep it concise — a spec is a reference document, not a novel

## Output

Return the complete spec document in markdown format. Check if `./ai-notes`
directory exists:
- If yes: save to `./ai-notes/specs/[feature-name].md`
- If no: save to `./docs/[feature-name].md`

Also return the full document text so it can be shown to the user.
```

### Step 4: Present the spec

Show the user the completed spec document. Ask if they want any adjustments.
If they do, make the edits directly (no need for another subagent round for
small tweaks).

## Usage

```
/help-me-spec Add user authentication with OAuth
/help-me-spec https://app.asana.com/0/123/456
/help-me-spec ./notes/feature-idea.md
/help-me-spec
```
