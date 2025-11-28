---
name: code-review
description: Review pull requests and uncommitted code changes. Use when user asks to review a PR, review changes, review uncommitted code, review a diff, or similar code review requests. Activates for phrases like "review this PR", "review my changes", "review before I commit", "check this diff", "review diff", "review commit <sha>".
---

# Code Review

Review code changes from pull requests, git diffs, or uncommitted changes.

## CRITICAL: Always Use a Subagent

**You MUST spawn a `general-purpose` subagent to perform the review.** This keeps
review context separate from the main conversation and allows for thorough
exploration without polluting the chat history.

Pass all instructions below to the subagent. The subagent should return the
formatted review.

## When to Activate

- "review this PR" / "review PR #123" / "review <github-url>"
- "review my changes" / "review changes"
- "review before I commit" / "review uncommitted changes"
- "review this diff" / "check this code"
- "quick review before I continue" (WIP mode)

## Gathering the Diff

Determine the source and fetch the diff:

| Source | Command |
|--------|---------|
| PR URL or number | `gh pr diff <number>` and `gh pr view <number>` for context |
| Uncommitted changes | `git diff HEAD` (staged + unstaged) |
| Untracked files | `git status --porcelain` then read each untracked file |
| Specific commit | `git show <sha>` |

For uncommitted reviews, always include both `git diff HEAD` AND untracked files.
Ignore `.env`, `.secrets`, and similar sensitive files.

## Large Diffs (50+ files)

If the diff is massive, ask the user for confirmation before proceeding. Suggest
breaking it down into smaller reviews. Only continue if they confirm.

## WIP/Draft Mode

If the user says "quick review", "before I continue", or similar phrases
indicating work-in-progress:

- Skip test requirements (don't flag missing tests)
- Focus on architecture and overall approach
- Only flag critical issues that would be costly to fix later
- Still review database schema changes thoroughly (migrations are costly to change)

## Review Process

### 1. Read Related Files

Before commenting, understand the context:

- Read files that are modified to understand their full structure
- Check related models, services, or components referenced in the diff
- For DB changes: grep for the specific column names in schema.rb/structure.sql
  to verify indexes exist for queried columns
- For new columns: check if the model uses `enum`, `where`, `find_by`, or scopes
  on that column - if so, it needs an index (enums generate scopes automatically)

### 2. Review Priority (in order)

1. **Security issues** - SQL injection, XSS, auth bypasses, exposed secrets
2. **Database schema** - Missing indexes for queried columns, missing constraints
3. **Logic errors / bugs** - Off-by-one, null handling, race conditions
4. **Missing error handling** - Unhandled exceptions, missing validations
5. **Missing tests** - New methods without corresponding tests
6. **N+1 queries / DB concerns** - Queries in loops, missing eager loading
7. **API design / interface** - Public method signatures, breaking changes
8. **Edge cases** - Boundary conditions, empty states
9. **Naming clarity** - Misleading or vague names
10. **Method size** - Methods doing too much, extraction opportunities
11. **Style** - Minor improvements, readability

### 3. Test Requirements

- Every new public method should have a test (state as fact if missing)
- Complex methods missing tests are blockers
- Trivially simple methods (one-liners, simple delegation) can skip tests
- For WIP mode: skip test requirements entirely

### 4. Running Tests (Optional)

Only run tests when you need to verify behavior for the review:

```bash
# Prefer non-Docker approaches
bundle exec rspec path/to/spec.rb
npm test -- path/to/test.js
```

Run only tests related to changed files, not the full suite. If test fails due
to tooling, check package.json, Gemfile, Makefile or equivalent for correct
commands.

Overall, avoid running these unless absolutely necessary.

## Comment Format

Each comment should follow this structure:

```
**path/to/file.rb:42**
```diff
+ def fetch_all!
```

The comment text here. Be specific and actionable. [1]
```

Rules for comments:

- Include the line(s) of code being discussed using diff syntax
- Number each comment at the end: [1], [2], etc.
- Be direct (no "perhaps consider" hedging for local reviews)
- Explain WHY, not just WHAT (unless the what is cryptic)
- Don't state the obvious
- Don't be vague, speculative, or hand-wavy
- Comments must be specific, actionable, and evidence-based
- Cite evidence from production code (models, controllers, queries), not from tests
- Be assertive: state what you observed, then recommend. Don't hedge with "if you
  plan to..." - either make a clear recommendation or ask a clarifying question
- If a code is vague, ask for something that makes it deterministic, e.g instead of hash["key"], ask for hash.fetch("key") with a clear error if missing. Overall, we should only leave nullable code if we don't know the answer or if nil is handled. If we know a property can't be null, make the code treat it as non-nullable.

### Good vs Bad Comments

**Bad**: "This could potentially cause issues with larger datasets."
**Good**: "This loads all records into memory. With 10k+ planets, this will OOM."

**Bad**: "Nice use of has_many :through!"
**Good**: (Don't comment on obvious/standard patterns)

**Bad**: "Consider adding error handling here."
**Good**: "If `results` is null, `#each` raises NoMethodError. Check the API docs
for what's returned when there's no data."

### Praise Sparingly

- Include 1-2 genuine praises per review max, only for noteworthy decisions
- Don't praise standard patterns or obvious things
- Example of good praise: "Thanks for adding the index on api_id - that'll be
  needed for the lookups in fetch_info!"

### Grouping Related Issues

If the same pattern appears multiple times (e.g., missing null checks in 3
places), write ONE comment in the summary mentioning all locations:

> Missing null check before calling `#each` appears in `planet.rb:42`,
> `film.rb:28`, and `character.rb:55`.

Don't give these grouped comments a number. In other words, summary doesn't have
numbered comments.

## Output Format

```markdown
# Code Review

[Comments numbered [1], [2], etc.]

---

## Summary

[One-liner assessment OR list of required changes if there are architectural
problems. For clean PRs: brief statement of what the change accomplishes.]
```

### Example Output

```markdown
# Code Review

**app/services/planet_fetcher.rb:15**
```diff
+ data['results'].each do |planet_data|
```

What's the API response when there's no more data - empty array or null? If
null, this raises NoMethodError in production. [1]

**app/services/planet_fetcher.rb:22**
```diff
+ planet.films = planet_data['films'].map do |film_url|
+   Film.find_or_create_by_api_id(film_url.split('/').last)
+ end
```

This does a DB lookup per film. Given we have the IDs, store them directly
without loading each record - prevents N+1 and potential memory issues with
large sets. [2]

**db/migrate/20240115_create_films.rb:8**
```diff
+ add_index :films, :api_id, unique: true
```

Good call adding this index. [3]

`PlanetFetcher#fetch_all!` and `Planet#fetch_info!` are missing tests.

---

## Summary

Solid foundation for the import. Address the null check [1] and N+1 [2], add
tests for the new methods, and this is good to merge.
```

## Preserve Developer Intent

Suggest pragmatic solutions that preserve developer intent rather than blanket
prohibitions. Only push back hard when the intent is clearly low quality, unsafe,
or absurd.

**Good**: "Wrap this in `unless Rails.env.production?` to keep it safe"
**Bad**: "Remove this entirely" (when the code serves a legitimate dev purpose)

## Environment-Aware Recommendations

Understand the context of the file before commenting:

### seeds.rb / Development Fixtures

Hardcoded passwords and test data are fine in seeds. However, there's risk someone
runs seeds in production accidentally. Suggest environment guards:

```ruby
# Good recommendation
User.create!(password: "dev123") unless Rails.env.production?
```

Don't suggest ENV variables or Rails credentials for dev-only seed data.

### Debug Logging

- **Temporary debug code** (`puts "got here"`, `console.log("x is", x)`): Flag for
  removal before commit
- **Useful logging with sensitive data**: Suggest environment guards, not removal

```ruby
# Bad: "Remove this logging entirely"
# Good: "Wrap in `if Rails.env.development?` to avoid logging sensitive params in production"
Rails.logger.info(params.inspect) if Rails.env.development?
```

### Test Files

Apply production standards only to the code under test, not test setup. For example:
- Don't flag hardcoded credentials in test factories or fixtures
- Don't flag `let(:password) { "password123" }` in specs
- Do flag if test code would be copied into production (e.g., shared modules)

## Things to Avoid

- **No caching suggestions** unless obviously necessary and benefits far outweigh complexity
- **No testing framework functionality suggestions** - not tests needed for validations that come from Rails or similar frameworks
- **No sharding suggestions** ever
- **No "what if this scales" speculation** - review the code as-is
- **No over-engineering suggestions** - keep it pragmatic
- **No astronaut architecture** - don't suggest abstractions for one-time code
- **Don't praise standard patterns** - only noteworthy decisions
- **Don't be verbose** - keep comments concise

## Alternatives and Tradeoffs

Only mention alternative approaches when:

- There's a clear problem with the current approach
- You can articulate specific downsides of the current way
- The alternative is simpler, not more complex

Don't suggest alternatives just because you'd do it differently.

## REMINDER: Use a Subagent

Spawn a `general-purpose` subagent with these instructions. The subagent has
access to all tools (Bash, Read, Grep, Glob) needed to explore the codebase
and run read-only commands.

Return the formatted review from the subagent to the user.
