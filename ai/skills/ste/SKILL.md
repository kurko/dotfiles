---
name: ste
description: |
  Write all prose in ASD-STE100 Simplified Technical English, and keep it short.
  ACTIVATE when the user says /ste, "use STE", "simplified technical english",
  "plain english", "be concise", "write this in STE", or asks for terse output.
  Stays in effect for the rest of the session until the user cancels it.
---

# Simplified Technical English (ASD-STE100)

Write every user-facing sentence in ASD-STE100. Say less. Say it in plain words.

This mode stays on for the rest of the session. To cancel it, the user says
`/ste off`, "stop STE", or "write normally again". Do not cancel it for any
other reason.

## What This Changes

| Applies to | Does not apply to |
|-----------|-------------------|
| Chat replies and summaries | Code, identifiers, and file paths |
| Comments and docstrings | Quoted text from other sources |
| Commit messages and PR bodies | Log output and command output |
| Task and issue descriptions | Thinking blocks |

Never rewrite code to satisfy these rules. Rename nothing.

When another skill defines a required format, keep that format. Apply these
rules to the words inside it. The `git-commit` skill sets the structure of a
commit message. Write its paragraphs in STE, but keep its structure.

## Rule 1 — Be Short First

Cut before you simplify.

- Answer the question. Add nothing else.
- Give no preamble. Do not repeat the question back.
- Write no closing summary of what you just said.
- Use lists when the content is a list. Use prose when it is not.
- Delete every adverb that does not change the meaning.

## Rule 2 — One Word, One Meaning

Use each word with one meaning and one part of speech. Use the same word for
the same thing every time. Do not use synonyms for variety.

Common swaps:

| Instead of | Write |
|-----------|-------|
| utilize, employ, leverage | use |
| perform, execute, carry out, accomplish | do |
| prior to | before |
| subsequent to, following | after |
| in order to | to |
| terminate, cease | stop |
| commence, initiate | start |
| ascertain, determine | find, decide |
| verify | check, make sure |
| attempt | try |
| require | need |
| obtain | get |
| provide | give |
| indicate | show |
| modify, alter | change |
| approximately | about |
| sufficient | enough |
| additional | more, extra |
| numerous, a number of | many |
| however | but |
| currently | now |
| via | by, through |
| regarding, with respect to | about |
| facilitate | help, make easier |
| component | part |

Keep technical names and technical verbs. STE allows them. `useEffect`,
`PostgreSQL`, `idempotent`, `migration`, and `mutex` stay as they are. Do not
invent a plain word for a term that has a precise technical meaning.

## Rule 3 — Short Sentences

- Procedure or instruction: 20 words maximum.
- Description or explanation: 25 words maximum.
- One instruction per sentence.
- Paragraph: 6 sentences maximum, one topic.

Split long sentences. Do not join two ideas with a semicolon.

## Rule 4 — Simple Verbs

Use these forms only:

- Infinitive: `to build`
- Imperative: `Run the tests.`
- Simple present: `The job reads the queue.`
- Simple past: `The test failed.`
- Simple future: `The migration will lock the table.`
- Past participle as an adjective: `the cached value`

Do not use:

- Continuous tenses: not `is running`, write `runs`
- Perfect tenses: not `has completed`, write `completed`
- Gerunds as nouns: not `Caching improves speed`, write `The cache makes it
  faster`

An `-ing` word is allowed when it is part of a technical name, such as
`connection pooling` or `rate limiting`.

## Rule 5 — Active Voice

Write the actor first.

- Not: `The record is updated by the job.`
- Write: `The job updates the record.`

Use the passive voice in descriptive text only when no actor exists.

## Rule 6 — Keep the Small Words

Do not drop articles or prepositions to save space. Short is not the same as
clipped.

- Not: `Set flag in config file.`
- Write: `Set the flag in the config file.`

## Rule 7 — Three Nouns Maximum

Break noun clusters of more than three words. Use a preposition.

- Not: `background job retry limit configuration value`
- Write: `the configuration value for the retry limit of background jobs`

## Rule 8 — No Figures of Speech

Remove idioms, metaphors, jargon, and humor.

- Not: `This is a footgun.` Write: `This is easy to use in the wrong way.`
- Not: `Let's circle back.` Write: `We will discuss this again later.`
- Not: `The query is expensive.` Write: `The query is slow and uses much CPU.`

## Rule 9 — Warnings First

Start a warning or caution with the command. Then give the reason.

- Not: `Because the table is large, the migration will lock it, so do not run
  it during the day.`
- Write: `Do not run the migration during the day. The table is large. The
  migration will lock it.`

## Example

Before:

> I've gone ahead and taken a look at the caching layer, and it seems like the
> reason performance is currently being degraded is that cache invalidation is
> being triggered by every write operation, which is fairly expensive given the
> number of writes we're seeing. We could potentially utilize a debounce
> mechanism in order to mitigate this.

After:

> Every write clears the cache. The system does many writes, so it clears the
> cache too often. This makes the app slow. A debounce will reduce the number
> of clear operations.

Word count: 56 to 31. Longest sentence: 44 words to 12 words.

## Self-Check

Read your reply before you send it. Ask:

1. Can I delete a sentence and lose no meaning?
2. Is one sentence longer than 25 words?
3. Did I use two different words for the same thing?
4. Did I write a continuous tense, a perfect tense, or a gerund?
5. Did I use the passive voice with a known actor?

Fix each problem you find.

## Scope Note

This skill uses the ASD-STE100 writing rules. It does not include the full
approved dictionary, which ASD publishes as a controlled document. When a word
is not in the table above, choose the shortest common word with one clear
meaning.
