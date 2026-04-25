---
name: code-review
description: Review pull requests and uncommitted code changes. Use when user asks to review a PR, review changes, review uncommitted code, review a diff, or similar code review requests. Activates for phrases like "review this PR", "review my changes", "review before I commit", "check this diff", "review diff", "review commit <sha>".
---

# Code Review

Review code changes from pull requests, git diffs, or uncommitted changes.

## CRITICAL: Instructions for Parent Agent (YOU)

1. You MUST gather **Coder Intent** and pass it to the subagent (see below)
2. You MUST spawn a subagent with the "Subagent Instructions" below
   - **Use the most capable model available** (e.g., Opus) - code review requires deep reasoning and thorough analysis; never use a fast/cheap model for reviews
3. When the subagent returns, you MUST display the complete review to the user verbatim
   - Do NOT summarize or abbreviate the review
   - The user needs to read every comment and the full summary

### Gathering Coder Intent and Plan

**CRITICAL**: You MUST pass any implementation plan to the subagent. This enables the
most important check: verifying the code actually implements what was planned.

Pass relevant context as "CODER INTENT" at the start of your prompt to the subagent:

| Review Type | What to Pass |
|-------------|--------------|
| **Git diff** (uncommitted changes) | The FULL implementation plan from this conversation (check for plan mode files or earlier discussion). Include ALL planned features, not just a summary. |
| **Pull Request** | The PR number or URL. Subagent will fetch details. |

**Finding the plan:**
1. Check if a plan file exists (mentioned in system messages or earlier in conversation)
2. Look for plan mode discussions earlier in the conversation
3. Check for user requirements that spawned the work
4. If no explicit plan exists, pass whatever user intent/requirements you have - the review
   will note that formal completeness verification isn't possible, but won't block on it

**Example prompt to subagent:**

```
CODER INTENT:
- Implementation plan from this conversation:
  1. Add OAuth controller with GitHub strategy
  2. Create User model with github_id field
  3. Add login button to homepage
  4. Handle OAuth callback and session creation
  5. Add logout functionality

PLAN FILE (if exists):
[Include full contents of any plan file]

REVIEW TYPE: final (or "wip" if user indicated work-in-progress)

[Subagent instructions below...]
```

**IMPORTANT**: Always specify whether this is a "final" review (before commit/merge) or
"wip" review (mid-implementation). Final reviews MUST check plan completeness.

---

## Subagent Instructions

Pass everything below this line to the subagent.

**CRITICAL: You MUST return the full formatted review.** The parent agent will
display it verbatim to the user - do not assume they can see your work. Your
final message MUST contain the complete review output.

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

## Understanding Coder Intent

The parent agent may pass "CODER INTENT" with context about what the developer intended.
Use this to evaluate whether the implementation matches the stated goals.

### Plan Completeness Check (CRITICAL for Final Reviews)

**This is the most important check for final reviews.** Before examining code quality,
verify the implementation is COMPLETE against the plan.

When "REVIEW TYPE: final" is specified (or not specified, assume final):

1. **Extract all planned features** from the CODER INTENT section
2. **For each planned feature**, verify it exists in the diff:
   - Search the diff for code that implements that feature
   - If not found, flag it as MISSING
3. **Report findings** in a dedicated section BEFORE code comments

Report your findings in a "Plan Completeness" section at the start of the review.
Make it clear which features are done and which are missing, with evidence.

**Rules:**
- If ANY planned features are missing, the review is BLOCKING regardless of code quality
- "Partially implemented" counts as MISSING - the feature must be complete
- If the plan mentions "deferred" or "future work" items, note them but don't block
- If no formal plan was provided (only user intent/requirements), note this and do your
  best to verify against the stated intent. Don't block, but mention that a formal plan
  would enable better completeness verification.

**For WIP reviews** (when "REVIEW TYPE: wip" is specified):
- Skip the plan completeness check
- Focus only on code quality of what's been written so far
- Note: "WIP review - skipping plan completeness check"

### For Pull Requests

When reviewing a PR, fetch the full context:

1. Run `gh pr view <number>` to get title, description, and linked issues
2. **Extract task links** from the PR description (Asana, Linear, Jira, Notion, Trello, etc.)
3. **Fetch task details via MCP** if task links are found:
   - Use the appropriate MCP tool for the task system (e.g., Asana MCP, Linear MCP)
   - Get the task title, description, acceptance criteria, and comments
   - This provides the original requirements the code should satisfy

### Graceful Degradation

If you cannot fetch task details (MCP unavailable, auth issues, network errors):

1. **Proceed with the review anyway** - do not block on missing context
2. Note in your output: "Could not load linked task: <url>. Reviewing based on PR description and code."
3. Use whatever context you do have (PR description, commit messages, code comments)

The review must happen regardless of whether all context sources are available.

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

### Mindset: Patterns Are a Floor, Not a Ceiling

The patterns below help catch common issues, but they are NOT exhaustive. Stay
alert for ANY issue that would cause bugs, waste resources, or make the code
harder to maintain. Ask: "What could go wrong here that isn't on my checklist?"

The review happens in two phases:

### Phase A: Identify Potential Issues

Read the diff and identify potential issues. For each issue, note:
- What you observed in the code
- What needs verification (schema, related files, tests, etc.)
- The specific question to answer
- **Why it matters** (the intent behind checking)

**CRITICAL: Do NOT write "worth verifying" or "consider checking" in your final
output.** If something needs verification, YOU verify it in Phase B.

### Phase B: Verify Each Issue with Subagents

For each potential issue that requires verification, spawn a dedicated subagent:

```
Spawn a subagent (use the most capable model available, e.g., Opus) for each verification task.
```

**Why subagents?**
- Fresh context window = unbiased investigation
- Focused attention on one specific question
- Prevents the main reviewer from getting overwhelmed
- Each verification is thorough and isolated

**Example verifications to delegate:**
- "Check if `user_external_id` has an index in structure.sql"
- "Find the default value for `restrictions` column in the migration"
- "Search for existing constants that match this hardcoded string"
- "Check if any subclasses override this method"

**Subagent prompt template:**
```
VERIFICATION TASK: [specific question]

INTENT: [why this matters - what problem we're trying to prevent]

Context: I'm reviewing a PR that [brief context]. I need to verify:
[the specific thing to check]

Instructions:
1. Search/read the relevant files
2. Return your findings in this format:

VERDICT: CONFIRMED | REFUTED | INCONCLUSIVE
EVIDENCE: [file path, line number, actual content you found]
CONTEXT: [any caveats, related findings, or nuances the main reviewer should
know about - e.g., "the index exists but only on a partial condition" or
"the constant exists but in a deprecated module"]

Do NOT speculate. If you can't find evidence, say INCONCLUSIVE with what you
searched.

REVIEW STANDARDS (apply these to your investigation):
- Be specific and evidence-based
- Cite file paths and line numbers
- Don't hedge - state facts
```

**Parallelization:**
Spawn subagents in parallel when their questions are independent:
- "Does column X have an index?" + "Are there subclasses overriding method Y?" → parallel

Sequential is fine when one answer informs the next question.

**After subagents return:**
1. Review the CONTEXT from each subagent for caveats you didn't anticipate
2. If a subagent's context reveals something unexpected, spawn another subagent
   to investigate further
3. Incorporate confirmed findings into your review as facts, not speculation
4. For INCONCLUSIVE results, either spawn a refined subagent or note the
   uncertainty explicitly in your review

---

### 1. Read Related Files

Before commenting, understand the context:

- Read files that are modified to understand their full structure
- Check related models, services, or components referenced in the diff
- For DB changes: grep for the specific column names in schema.rb/structure.sql
  to verify indexes exist for queried columns
- For new columns: check if the model uses `enum`, `where`, `find_by`, or scopes
  on that column - if so, it needs an index (enums generate scopes automatically)

#### Check for Inheritance Hierarchies

When a class method is modified, check if the class has subclasses:

1. **Search for subclasses** using the appropriate file extension:
   ```bash
   # Use the language's file extension (e.g., .rb, .py, .ts, .java)
   grep -r "class.*extends.*ClassName" . --include="*.{ext}"
   grep -r "class.*<.*ClassName" . --include="*.{ext}"
   grep -r "class.*ClassName" . --include="*.{ext}"

   # Ruby example:
   grep -r "class.*<.*Product::BasePresenter" app/ --include="*.rb"

   # TypeScript example:
   grep -r "extends.*BasePresenter" src/ --include="*.ts"

   # Python example:
   grep -r "class.*\(.*BasePresenter.*\)" . --include="*.py"
   ```

2. **Check for method overrides** in each subclass found:
   ```bash
   # Check if subclasses override the modified method
   grep -A 3 "def method_name" path/to/subclass.ext
   ```

3. **Detect polymorphism-breaking changes**:
   - Changes from calling a method to directly accessing a property bypass subclass overrides
   - Common patterns that break polymorphism:
     - Shorthand property syntax → direct property access (e.g., `{foo}` → `{foo: model.foo}`)
     - Method call → direct property access (e.g., `foo()` → `model.foo`)
     - `this.method()` → `this.model.method()` in serializers/presenters

   **Ruby example**: In `as_json` methods, `countries:` is shorthand for `countries: countries`,
   which calls `self.countries` and respects subclass overrides. Changing to `countries: model.countries`
   bypasses this polymorphism.

   **TypeScript example**: Changing `{country: this.getCountry()}` to `{country: this.model.country}`
   bypasses any subclass override of `getCountry()`.

4. **Verify test coverage** for subclass-specific behavior:
   - Search for tests related to each subclass that overrides the method
   - Flag if overridden behavior lacks test coverage

5. **Check if new subclass methods belong in the base class** ("push up"):

   When a new method is added to a subclass, grep for sibling subclasses and ask:
   would this apply there too? Guards, validations, and cross-cutting concerns
   (error wrapping, rate limiting, telemetry) almost always belong in the parent.
   If all siblings except one special case (e.g., a local/mock adapter) need it,
   it still belongs in the base class -- the exception overrides, not the other
   way around.

#### Check for Variable-Filter Semantic Mismatches

When code assigns the result of a collection lookup to a variable, check whether
the variable name semantically matches the filter predicate:

```ruby
# Suspicious: variable says "product" but filter is on currency, not product attributes
product = catalog.find { |p| p.currency_code == currency }

# Suspicious: variable says "email" but filter is on first_name
email = users.find { |u| u.first_name == name }

# Suspicious: variable says "order" but filter is only on generic status
order = records.where(status: "active").first
```

This pattern may return the wrong item if the collection is heterogeneous (e.g.,
contains gift cards AND bank transfers, both with matching currency).

**To verify:**
1. Check if the collection source is already constrained upstream
2. Look for uniqueness constraints or 1:1 relationships (e.g., one product per currency)
3. Check if the containing context (folder/class name) implies a domain constraint
   not reflected in the filter

If unverifiable, flag it - the filter may need an additional predicate (e.g.,
`category == "bank"`).

#### Check for Single Source of Truth Violations

When a value is hardcoded that already exists elsewhere (constant, config file, or
another definition), flag it. **Also flag when the same identifier string appears in
multiple locations even if no constant exists yet** -- that duplication is the signal
that a constant should be created. Reason: When the canonical meaning changes in the
future, every duplicate must be found and updated. The more scattered the string, the
higher the chance one gets missed, causing partial failures that are hard to diagnose.

**Two forms of this violation:**

**Form 1 - Constant exists but isn't used:**

When you see a hardcoded string that looks like a status, type, or category, search
for existing constants:

```bash
# Search for constants containing the value (use regex, don't load full files).
# This is just a suggestion, please adapt and find more effective ways of
# accomplishing your goal.
grep -rE "(EXPIRED|expired.*=|:expired)" . --include="*.rb" --include="*.ts" -l
```

If a constant like `Order::STATUS_EXPIRED` or `OrderStatus.EXPIRED` exists, flag
the hardcoded string and recommend using the constant.

```ruby
# Bad: Order::STATUS_EXPIRED constant exists but code uses a string
def expired?
  status == "expired"
end

# Good
def expired?
  status == Order::STATUS_EXPIRED
end
```

**Form 2 - No constant exists, but the same string appears in multiple places:**

When you see a hardcoded string that acts as an identifier (type, status, category,
kind, key in a registry hash), search for that same string across the codebase:

```bash
grep -rE "unanswered_question" . --include="*.rb" --include="*.ts" --include="*.yml" -l
```

If the same string appears in **2+ files** as an identifier (not just documentation
or test descriptions), flag it and recommend extracting to a constant, even if one
doesn't exist yet. The patterns to watch for:
- Hash keys in registries or lookup tables (`SCHEMAS = { "unanswered_question" => ... }`)
- Return values that identify a type (`def risk_type; "unanswered_question"; end`)
- Conditional comparisons (`if type == "unanswered_question"`)
- Config keys that are referenced in code (`risk_types.yml` key matched by string in Ruby)

```ruby
# Bad: "unanswered_question" appears in risk_types.yml, attention_helper.rb,
# and risk_detection/tasks/unanswered_question.rb as a bare string
{ "unanswered_question" => {color: "var(--unanswered-question)"} }

# Good: extract to or use an existing constant, reference it everywhere
{ Risk::TYPES.fetch(:unanswered_question) => {color: "var(--unanswered-question)"} }
```

**Example 3 - Infrastructure value in workflow:**

```yaml
# .github/workflows/ci.yml - Bad: IP may duplicate config/deploy.yml
- run: ssh-keyscan -H 192.0.2.1 >> ~/.ssh/known_hosts
```

**Detection:** Search for the value in config files:

```bash
grep -r "192.0.2.1" . --include="*.yml" --include="*.yaml" --include="*.env*"
```

If the value exists in a config file, flag it and recommend reading from the
canonical source instead of duplicating.

**Severity: MEDIUM-HIGH** - These violations cause subtle bugs when the canonical
source is updated but the duplicate is forgotten. The system partially works,
making the bug hard to diagnose. Form 2 (no constant yet) is equally dangerous --
the absence of a constant is itself the problem to flag.

#### Check for Silent Hash/Map Key Access

When code accesses a hash with `[]` and the key is expected to always exist,
`[]` silently returns `nil` on a missing key. The `nil` propagates through the
system and causes a `NoMethodError` or wrong behavior far from the source.

Use `.fetch(key)` when the key MUST exist. It raises `KeyError` immediately at
the point of failure.

```ruby
# Bad: silently returns nil if risk_type is invalid
schema = SCHEMAS[risk_type]

# Good: raises KeyError immediately
schema = SCHEMAS.fetch(risk_type)
```

**Detection:** Look for `CONSTANT[variable]` or `hash[dynamic_key]` where:
- The hash is a known, finite lookup table (constants, type maps, registries)
- The key is a variable or parameter (not a literal)
- There is no `nil` check on the result before use

**When `[]` is acceptable:**
- Code explicitly handles `nil` after access (`return default if value.nil?`)
- The hash is a cache/memo where `nil` means "not yet computed"
- The access uses a literal key in a controlled context (e.g., `params[:id]`)

**What to flag:** "This accesses `HASH[key]` without handling nil. Use
`.fetch(key)` to fail immediately if the key is missing, or add explicit nil
handling if nil is a valid case."

#### Check for Magic Numbers and Unnamed Values

When a literal value appears inline, ask: "Would a reader understand why this
specific value was chosen?" If not, extract to a named constant.

```ruby
# Bad: Why 1.day? Cache TTL? Expiration? Grace period?
if record.updated_at > 1.day.ago

# Good: Constant name explains intent
CACHE_TTL = 1.day
if record.updated_at > CACHE_TTL.ago
```

**Why it matters:**
- **Discoverability**: Search for `CACHE_TTL` vs hoping to find every `1.day`
- **Self-documentation**: The name explains the business reason
- **Single point of change**: Update once, applies everywhere

**When NOT to flag:** Values inherently clear from context (e.g., `100` for
percentage max), or test setup where specific values don't matter.

#### Check for Race Condition Patterns

**Pattern: Duplicate Work Before Conflict Resolution**

When code rescues `RecordNotUnique` or similar, check what happens BEFORE the
save attempt:

```ruby
def find_or_create(params)
  return existing if existing&.fresh?

  # PROBLEM: Expensive API call happens before we know if we'll use the result
  result = ExternalAPI.fetch(params)
  Record.create!(data: result)
rescue ActiveRecord::RecordNotUnique
  Record.find_by!(params)
end
```

Two concurrent requests both call `ExternalAPI.fetch` before either wins the
race. One succeeds, one rescues - but both made the costly API call.

**What to flag:** "Both requests will call the external API before one wins the
race. If this is high-traffic, consider an advisory lock to avoid duplicate calls."

#### Check for Nested Subquery Scoping

When a `WHERE id IN (SELECT ...)` subquery contains another subquery inside it,
PostgreSQL's planner has limited flexibility to optimize the execution plan. A
single-level `IN (SELECT ...)` is usually fine — the planner can convert it to a
semi-join. But nesting reduces options at each level.

**How it happens in Rails:**

`has_many :through` associations produce subqueries when used in `where` clauses.
If you chain them, nesting appears:

```ruby
# scoped_projects returns current_workspace.projects (has_many :through)
# This is already a subquery internally
task_ids = Task.joins(:projects).where(projects: {id: scoped_projects}).select(:id)

# Now this wraps that subquery inside another one
@actors = Actor.joins(:tasks).where(tasks: {id: task_ids}).distinct
```

The generated SQL has `WHERE id IN (SELECT ... WHERE id IN (SELECT ...))` — two
levels of nesting. Add another `has_many :through` and you get three.

**Detection:** Look for this pattern:
1. A variable or method returns a `.select(:id)` or `.pluck(:id)` result
2. That result is used in `where(column: {id: ...})` or `where(column_id: ...)`
3. The source relation itself contains `joins` + `where` with another relation

Specifically watch for:
- `where(x: {id: scope_that_returns_relation})` — the scope may contain its own subquery
- Chaining `.select(:id)` results through multiple `where` clauses
- Private methods like `workspace_task_ids` that hide a subquery behind a method name

**The fix:** Define model scopes using `joins()` through the full association chain,
then compose them with `merge()`:

```ruby
# Model scope: joins through the full chain, single WHERE clause
scope :in_workspace, ->(workspace) {
  joins(projects: :workspaces)
    .where(workspaces: {id: workspace.id})
}

# Controller: compose via merge — produces flat joins, no nesting
Actor.joins(:tasks).merge(Task.in_workspace(current_workspace)).distinct
```

**When subqueries are still appropriate:** Polymorphic associations (`subject_type`
+ `subject_id`) can't be joined cleanly, so `WHERE subject_id IN (SELECT ...)`
is correct. But the inner query should use joins, not contain another subquery:

```ruby
# Good: subquery needed for polymorphic, but inner query uses joins
Risk.where(subject_type: "Task", subject_id: Task.in_workspace(ws).select(:id))

# Bad: subquery inside subquery inside subquery
Risk.where(subject_id: Task.where(project_id: workspace.projects).select(:id))
```

**What to flag:** "This `WHERE IN` subquery contains another subquery. PostgreSQL's
planner has limited optimization options for nested subqueries. Extract a model
scope using `joins()` and compose with `merge()` to flatten the query."

**Literal ID lists degrade over time:**

A separate but related problem: `WHERE id IN (1, 2, 3, ..., N)` with a
materialized list of IDs. With small lists, PostgreSQL uses an index scan. As
the list grows into hundreds or thousands, the planner may switch to a
sequential table scan because it estimates too many index pages would be touched.

This is insidious because it works fine in development and early production, then
slows down considerably after months as data accumulates. By the time it's
noticed, the query is in a hot path.

In Rails, this happens when `.pluck(:id)` materializes IDs into Ruby, then
passes them back to the database:

```ruby
# Bad: round-trips IDs through Ruby, creates literal IN list
task_ids = Task.where(project_id: project.id).pluck(:id)
Event.where(task_id: task_ids)
# SQL: WHERE task_id IN (1, 2, 3, ..., 50000)

# Good: keep it as a subquery — the DB handles it internally
task_ids = Task.where(project_id: project.id).select(:id)
Event.where(task_id: task_ids)
# SQL: WHERE task_id IN (SELECT id FROM tasks WHERE project_id = ?)
```

**Detection:** Look for `.pluck(:id)` or `.map(&:id)` followed by `.where(column: ids)`.
The fix is almost always to use `.select(:id)` instead, keeping the query in the
database. Even better: use joins or `merge()` to avoid the subquery entirely.

**What to flag:** "This materializes IDs into Ruby with `pluck`/`map` and passes
them back as a literal list. Use `.select(:id)` to keep it as a subquery, or
refactor to joins. Literal `IN` lists degrade as data grows — PostgreSQL may
switch from index scan to sequential scan with large lists."

#### Check for Ruby-Level Filtering That Belongs in SQL

When code loads records from the database and then filters them in Ruby using
`reject`, `select { }`, `if`/`unless`, or similar, check whether the condition
could be expressed as a SQL `WHERE` clause instead. Loading rows into memory
only to discard them wastes database bandwidth, Ruby memory, and CPU.

```ruby
# Bad: loads ALL projects, then filters in Ruby
projects = user.projects.includes(:workspace)
syncable = projects.reject { |p| p.workspace.service == "development" }

# Good: filter in SQL — development projects never leave the database
projects = user.projects
  .joins(:workspace)
  .merge(Workspace.syncable)
```

**Detection:** Look for:
- `.reject { }` or `.select { }` (Enumerable, not ActiveRecord) after a query
- `.each` loops with `next if` / `next unless` that check an association attribute
- `.filter` / `.find` (Ruby) on an ActiveRecord result set
- Any pattern where records are loaded then conditionally skipped

**When Ruby-level filtering is acceptable:**
- The condition involves computed values not in the database (e.g., API
  responses, in-memory state, complex Ruby logic with no SQL equivalent)
- The collection is already loaded for other purposes and is known to be small
- The condition requires Ruby-specific logic (regex not supported by the DB,
  custom objects, etc.)

**What to flag:** "This loads N records and discards some in Ruby. Move the
condition into the query with `where`/`joins`/`merge` so the database handles
the filtering. Less data transferred, less memory used."

#### Check for Inline Query Conditions That Duplicate Model Scopes

When code writes inline `where` conditions or raw SQL fragments, check whether
the model already defines a scope for the same logic. Duplicated query conditions
diverge silently — someone updates the scope but misses the inline copy.

```ruby
# Bad: service rewrites logic the model already encapsulates
# (model has: scope :incomplete, -> { where(completed: false).or(where(completed: nil)) })
Question.where("tasks.completed = false OR tasks.completed IS NULL")

# Good: reuse the model scope
Question.merge(Task.incomplete)
```

**Detection:** When you see an inline `where` condition, name the domain concept
it represents ("incomplete", "unresolved", "active"), then search the model:

```bash
grep -n "scope :" app/models/task.rb
grep -n "def self\." app/models/task.rb
```

Scopes don't need to be character-identical to match — `where(completed: [false, nil])`
and `where("completed = false OR completed IS NULL")` are semantically the same.
If a scope exists, recommend `merge()` or direct chaining. If no scope exists but
the condition is reusable, recommend extracting a new scope.

**When inline conditions are acceptable:**
- One-off queries in migrations or data scripts that run once
- Performance-critical queries where scope composition would prevent plan
  optimization (CTEs, window functions)
- Trivially simple conditions unlikely to change (e.g., `where(id: id)`)

**What to flag:** "This inline `where` condition duplicates `ModelName.scope_name`.
Use `merge(ModelName.scope_name)` — duplicated query logic diverges silently when
one copy is updated but the other isn't."

For reusable conditions with no existing scope: "Extract this condition into a
scope on `ModelName` so it's defined once and reusable."

#### Check for Leaky Abstractions (Data vs Decisions)

When a method returns raw data that callers must interpret, the decision logic
spreads across the codebase. Each caller reimplements the same interpretation,
making the code harder to read and the abstraction fails to encapsulate.

**Note:** Returning nil is sometimes fine - use judgment. The issue is when
nil forces every caller to implement the same interpretation logic.

**Pattern 1: Names that promise more than they deliver**

A method named `*_limit`, `*_threshold`, `*_count`, or `*_value` promises to return
that thing. Returning `nil` breaks the contract - callers must know nil is possible
and decide what it means.

```ruby
# Bad: name promises a limit, but nil is possible
def rate_limit
  config[:requests_per_minute]  # might be nil
end

# Caller must interpret:
limit = rate_limit
return unless limit && requests > limit
```

```ruby
# Good: honor the contract with a default
def rate_limit
  config[:requests_per_minute] || DEFAULT_RATE_LIMIT
end

# Or answer the real question with a predicate:
def rate_limit_exceeded?
  requests > (config[:requests_per_minute] || DEFAULT_RATE_LIMIT)
end
```

**Pattern 2: Callers all do the same interpretation**

When every caller performs identical logic on a return value, that logic belongs
inside the method.

```javascript
// Bad: every caller interprets the same way
const settings = getSettings();  // might be null
const timeout = settings?.timeout ?? 30;

// If this pattern repeats, the method should encapsulate it:
function getTimeout() {
  return getSettings()?.timeout ?? 30;
}
```

**Mental tool:** Ask "could this be a predicate method (returns true/false)?"
If the callers are using the return value to make a yes/no decision, a predicate
often encapsulates better and reads more naturally at call sites.

**Detection:**
- Method returns `X | nil` but name doesn't suggest optionality
- Callers immediately check for nil/null/undefined after calling
- Multiple callers do the same fallback or comparison logic
- Guard clauses like `return unless value && condition` right after fetching

**What to flag:**
- "This returns nil but the name suggests a value. Either provide a default or
  rename to `*_if_configured` to be honest about the contract."
- "Every caller checks `&& count >= threshold` - consider a predicate method
  that encapsulates this decision."

**Why it matters:** When interpretation logic lives at call sites, it's easy for
one caller to get it wrong, and impossible to change the interpretation without
updating every caller. Encapsulating decisions makes the code easier to read and
reason about.

#### Check for Misleading State Mutations

When code transforms invalid or problematic data into a "normal-looking" value
before storing or transmitting it, it makes the stored state lie about reality.
Anyone reading the data later — a human debugging in error tracking, an agent
triaging, a downstream system — draws wrong conclusions.

Common forms:

| Mutation | What it hides | What the debugger sees |
|----------|--------------|----------------------|
| invalid → `nil` | "data exists but is bad" | "no data was ever provided" |
| invalid → plausible value | "code silently substituted a value" | "user/system chose this value" |
| stale → overwrite silently | "fetch failed, data is old" | "data is current" |

**Detection — look for these shapes:**
1. `x = transform(input); x = nil unless valid?(x)` — clean-then-nullify
2. `value = valid?(x) ? x : DEFAULT` — code picks a value the user never chose
3. `return unless valid?(field)` in a sync/worker — silently skips with no log
4. `parsed = SomeParser.parse(raw) rescue nil` — when the field is expected, not optional
5. `record.update!(field: fetched_value)` inside a `rescue` that swallows the
   fetch error — stale data overwrites without a trace

**Key question:** "If I read this stored value in 6 months, will I be able to
tell whether it reflects reality or a silent transformation of bad data?" If no,
flag it.

**The correct responses, in order of preference:**
1. **Reject loudly** at the boundary — raise, log at warn/error, return failure
2. **Track the distinction** — separate status field, error reason, wrapper type
3. **Skip with visibility** — log why the operation was skipped, at a level that
   shows up in error tracking (not just debug)

**What to flag:** "This transforms invalid/failed data into a normal-looking
value before storing it. When someone sees [nil / the default / the stale value]
in error tracking or logs, they'll draw the wrong conclusion about what happened.
Either reject the bad data loudly or store it with a marker that distinguishes
it from legitimate values."

#### Check for Temporal Snapshot Names

When a computed value (duration, count, elapsed time) is stored in a record,
the name must signal it's a snapshot. `hours_unanswered` reads as current;
`hours_unanswered_at_analysis` makes the freeze point obvious.

**Detection:** Columns, hash keys, or metadata containing `hours_`, `days_`,
`count_`, `time_since_`, `_ago`, `_until`, `_elapsed` that are persisted
(not computed on read).

**The fix:** Append `_at_analysis`, `_as_of_date`, or `_when_computed`.

**Skip:** Timestamps (`created_at`, `resolved_at`) and values recomputed on
every read.

**What to flag:** "This stores a computed duration/count (`field_name`) but
the name reads as live. Rename to include temporal context (e.g.,
`field_name_at_analysis`) so readers know it's a point-in-time snapshot."

#### Check for Backend/Frontend Boundary Violations

These checks apply whenever code crosses the boundary between data (backend,
serializers, APIs) and presentation (frontend, templates, components).

**Pattern 1: Serializers emitting presentation values**

When a serializer computes a position, index, offset, color, grid coordinate,
or layout value, it's coupling to a specific consumer's rendering logic.

```ruby
# Bad: columnIndex is a grid concept — if the layout changes, this breaks
def as_json
  { columnIndex: (event.occurred_at - start_date).to_i, ... }
end

# Good: emit the domain fact — the consumer maps it to whatever layout it uses
def as_json
  { occurredAt: event.occurred_at.iso8601, ... }
end
```

**Key question:** "Would this field still make sense if the consumer changed
from a web timeline to a mobile list, a PDF report, or an API client?" If not,
it's a presentation concern leaking into the data layer.

**What to flag:** "This serializer emits a presentation value (`fieldName`).
Emit the domain fact (date, state, relationship) instead — let the consumer
handle positioning/layout."

**Pattern 2: APIs hiding record lifecycle**

When a new endpoint or serializer only returns active/current records, but the
domain has a lifecycle (created → resolved, active → cancelled, open → closed),
the consumer loses history.

```ruby
# Bad: only open alerts — resolved alerts disappear from the dashboard
def alerts
  object.alerts.where(resolved_at: nil)
end

# Good: return all non-dismissed alerts with resolved_at (nil when unresolved)
# The consumer decides whether to show resolved records
def alerts
  object.alerts.where.not(status: :dismissed)
end
```

**Detection:** Look for `where(ended_at: nil)`, `where(resolved_at: nil)`,
`where(status: :active)`, or `.active` scopes in serializers/API endpoints.
Ask: "Does the user of this API ever need to know that a record existed and
was resolved?" If yes, the filter is hiding useful information.

**Exception:** User-dismissed records (explicit editorial judgment) should be
excluded.

**What to flag:** "This filters to only active records, but the domain has a
lifecycle. Include resolved records with their `resolved_at` timestamp — let
the consumer decide what to show."

**Pattern 3: Serializers querying the database**

Serializers should only read data already loaded on the model. If a serializer
triggers database queries — directly or through unloaded associations — it
creates hidden performance costs and makes serializer behavior depend on how
the caller loaded data.

```ruby
# Bad: serializer triggers a query — tags weren't eager-loaded
class ArticleSerializer
  def tag_names
    Tag.where(article: object).pluck(:name)
  end
end

# Bad: serializer calls an association that wasn't included — silent N+1
class ArticleSerializer
  def tag_names
    object.tags.map(&:name)  # N+1 if not eager-loaded
  end
end

# Good: controller eager-loads, serializer just reads what's already there
# Controller: Article.includes(:tags)
# Serializer: object.tags (already loaded, no query)
```

**Detection:** Look for:
- Serializer methods that call `.where`, `.find_by`, `.count`, or other
  query methods directly (not through a pre-loaded association)
- Serializer methods that access associations not listed in the controller's
  `includes`

**What to flag:** "This serializer queries the database. Eager-load the
association in the controller with `includes` and read from the model
directly."

**Pattern 4: Non-generic naming and component reusability**

When a new component, class, or module is named after a specific scenario rather
than the category it belongs to, it'll need renaming or duplicating when the
second use case arrives.

```javascript
// Bad: named after the first scenario — what happens for email or SMS notifications?
function SlackNotifier({ message }) { ... }

// Good: named after the category — works for any channel
function Notifier({ message, channel }) { ... }

// Bad: domain-specific modal that bundles UI chrome with domain content
function TimelineTaskModal({ task }) {
  return <div className="modal-overlay">
    <div className="modal-content">
      <h2>{task.name}</h2>
      <p>{task.description}</p>
    </div>
  </div>
}

// Good: generic modal in reusable/, thin domain wrapper on top
// reusable/Modal.tsx
function Modal({ title, children, onClose }) { ... }

// domain/TaskDetail.tsx — just the content, no modal chrome
function TaskDetail({ task }) {
  return <Modal title={task.name} onClose={...}>
    <p>{task.description}</p>
  </Modal>
}
```

**Three tests to apply:**

1. **Reuse test:** "If I needed this same UI chrome (modal, popover, dropdown)
   on another page, would I have to duplicate it?" If yes, extract the generic
   component to `reusable/`.

2. **Naming test:** "If I needed a second instance of this category, would I
   have to rename this class/component?" If yes, the name is too specific.

3. **Logic extraction test:** "Is there conditional logic, data transformation,
   or domain rules baked into this UI component that could be extracted into a
   testable, reusable function?" If yes, extract it. Components should render
   state; separate modules should compute it.

**What to flag:**
- "This is named after a specific instance (`SpecificName`) rather than the
  category. Consider `CategoryName` — it'll accommodate future variants."
- "This component mixes UI chrome (overlay, positioning, dismiss) with domain
  content. Extract the generic UI to `reusable/` and keep domain content in a
  thin wrapper."
- "This component contains business logic (filtering, computation, conditional
  rules) that should be in a separate module for testability and reuse."

**Pattern 5: Business logic in UI components**

When a frontend component contains conditional logic, data transformation,
formatting rules, or domain decisions, that logic becomes untestable without
rendering the component and unreusable outside it.

```javascript
// Bad: business logic (status derivation, date comparison) lives in the component
function TaskCard({ task }) {
  const isOverdue = task.dueDate && new Date(task.dueDate) < new Date();
  const isBlocked = task.dependencies.some(d => d.status !== "done");
  const priority = isOverdue ? "critical" : isBlocked ? "high" : "normal";
  return <Card className={`priority-${priority}`}>...</Card>
}

// Good: logic extracted, testable without rendering
// lib/taskStatus.ts
function deriveTaskPriority(task) { ... }

// components/TaskCard.tsx — just renders
function TaskCard({ task }) {
  const priority = deriveTaskPriority(task);
  return <Card className={`priority-${priority}`}>...</Card>
}
```

**Detection:** Look for:
- Ternary chains or `if`/`switch` statements in render bodies
- `new Date()`, `.filter()`, `.reduce()`, `.sort()` in components
- Domain terms (status, priority, threshold, deadline) computed inline
- Logic that would need to be duplicated if another component needs the same decision

**What to flag:** "This component computes [business logic] inline. Extract to
a separate module (e.g., `lib/taskStatus.ts`) so it can be unit-tested and
reused across components."

### 2. Review Priority (in order)

1. **Security issues** - SQL injection, XSS, auth bypasses, exposed secrets
2. **Plan completeness** - Are ALL planned features implemented? (final reviews only)
3. **Database schema** - Missing indexes for queried columns, missing constraints
4. **Logic errors / bugs** - Off-by-one, null handling, race conditions
5. **Missing error handling** - Unhandled exceptions, missing validations
6. **Missing tests** - New methods without corresponding tests
7. **N+1 queries / DB concerns** - Queries in loops, missing eager loading
8. **API design / interface** - Serializer JSON shapes, public method signatures, breaking changes, data generality
9. **Edge cases** - Boundary conditions, empty states
10. **Naming / genericity** - Names too specific for their category, components that should be generic, business logic mixed into UI
11. **Method size** - Methods doing too much, extraction opportunities
12. **Style** - Minor improvements, readability

### 3. Test Requirements

- Every new public method should have a test (state as fact if missing)
- Complex methods missing tests are blockers
- Trivially simple methods (one-liners, simple delegation) can skip tests
- For WIP mode: skip test requirements entirely

**Error handling paths need test coverage too.** When code has `rescue`, `catch`,
or similar error handling with meaningful behavior (logging, fallback, retry),
that behavior should be verified by a test.

```ruby
# This rescue has logic worth testing
rescue ActiveRecord::RecordNotUnique
  find_existing_record(params)  # Fallback behavior - does it work?
end
```

Flag: "The rescue block falls back to `find_existing_record`, but there's no
test verifying this fallback works."

**When you recommend adding defensive code, require a test for it.** If the
review suggests adding a clamp (`[value, max].min`), guard clause, validation,
or any other defensive behavior, the recommendation MUST include writing a test
that exercises the defensive path. Untested defensive code gives false
confidence — it looks safe but nobody knows if it actually works. The test
proves the invariant holds.

Example: If you recommend `detected_at: [onset_at(subject), Time.current].min`
to prevent future dates, also require a test that constructs a scenario where
`onset_at` would return a future time and asserts `detected_at <= Time.current`.

**CRITICAL: Never accept "matches existing pattern's test coverage" as justification
for missing tests.** If similar code elsewhere lacks tests, that's technical debt to
fix, not a pattern to follow. A pragmatic engineer improves the codebase rather than
perpetuating gaps.

Sometimes tests genuinely aren't needed - the code is trivial, the test would be
redundant with existing coverage, or the test would just restate the implementation.
That's fine. But if you're skipping tests, use the right argument:

- **Good reasons**: "This is a one-liner delegation", "Already covered by feature spec X",
  "Testing this would just duplicate the framework's own tests"
- **Bad reason**: "Similar code elsewhere also lacks tests"

The argument matters. We never justify gaps by pointing to other gaps.

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

````
**path/to/file.rb:42**
```diff
+ def fetch_all!
```

The comment text here. Be specific and actionable. [1]
````

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

## Plan Completeness

[Report which planned features are done vs missing, with evidence.
If any missing: note that the review is BLOCKING until they're implemented.]

---

[Comments numbered [1], [2], etc.]

---

## Summary

[One-liner assessment OR list of required changes if there are architectural
problems. For clean PRs: brief statement of what the change accomplishes.
If plan incomplete, summary MUST mention the missing features.]
```

**For WIP reviews**, note that plan completeness check was skipped.

### Example Output (Complete Implementation)

```markdown
# Code Review

## Plan Completeness

| Planned Feature | Status | Evidence |
|-----------------|--------|----------|
| PlanetFetcher service | ✅ DONE | `app/services/planet_fetcher.rb` |
| Film model and migration | ✅ DONE | `app/models/film.rb`, `db/migrate/...` |
| API pagination handling | ✅ DONE | `PlanetFetcher#fetch_all!` loops until no next page |

All planned features implemented.

---

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

### Example Output (Missing Features - BLOCKING)

```markdown
# Code Review

## Plan Completeness

| Planned Feature | Status | Evidence |
|-----------------|--------|----------|
| Basic data import service | ✅ DONE | `app/services/data_importer.rb` |
| Change detection for updates | ❌ MISSING | No comparison of existing vs incoming records |
| Audit trail events | ❌ MISSING | No event creation for changes |

**BLOCKING: 2 planned features are missing.** This review cannot pass until:
- Change detection is implemented
- Audit trail events are implemented

---

## Summary

2 of 3 planned features are missing. This is incomplete.
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

### Method clarity

- Suggest simplifications that make the code more readable

Examples:

```
**path/to/file.rb:42**
```diff
+ def fetch_events
+   CalendarEvent
+     .for_user_and_date(user, date, time_zone)
+     .confirmed
+     .visible
+     .includes(:calendar)
+ end
+
+ def fallback_content
+   events = fetch_events
+   return "No events scheduled for today." if events.empty?
+
+   count = events.count
+   "You have #{count} event#{"s" if count != 1} today."
+ end
```

If we memoize `fetch_events`, we simplify `fallback_content`. For example,
`@fetch_events ||= CalendarEvent...` prevents the need for `events = fetch_events`
below.
```

If there are multiple calls to `fetch_events` above, we'd also comment that it
prevents multiple database calls.

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

## Investigative Questions

The pattern checks above catch issues visible in the diff. The questions below
catch issues that require **investigating the surrounding system** -- things no
pattern matcher can see. For each question that seems relevant to the diff,
spawn a subagent to investigate and return: **RELEVANT** (with finding) or
**NOT RELEVANT** (with brief reason why it doesn't apply).

Use the most capable model available for these subagents. Each subagent gets:
the question, the relevant file paths from the diff, and enough context to
search the codebase. Spawn in parallel when questions are independent.

### Scale & Bounds

1. **Does any new query have an upper bound on the data it processes?**
   Queries without time limits, `LIMIT` clauses, or pagination will silently
   degrade as data accumulates over months and years.

2. **If a collection is processed in a loop, what happens at 10x and 100x
   current volume?**
   In-memory iteration that works at today's scale can OOM or timeout when the
   dataset grows -- check whether batching or streaming is needed.

### Sophistication Mismatch

3. **Does a cheap/naive step gate an expensive/sophisticated step?**
   A simple string match before an LLM call, a regex before a complex
   computation -- the cheap filter adds false negatives without meaningful cost
   savings if the expensive step exists precisely to handle ambiguity.

### Human Time vs Wall-Clock Time

4. **Do any duration calculations involving people account for non-working
   periods?**
   "Hours since X" using wall-clock time is wrong for human activity -- it
   counts weekends, holidays, and nights. If the threshold triggers actions
   or alerts, this creates false positives on Monday mornings.

### Silent Failures

5. **Do any early returns on nil/blank/empty guard against conditions that
   should never happen?**
   `return if data.blank?` is correct when data is optional. When data should
   always exist, the guard hides an upstream bug -- the code should raise or
   log at a visible level instead.

### Naming & Structural Fit

6. **Would any new class/module name still work when a second variant arrives?**
   A name like `StripeGateway` breaks when you need `StripeConnectGateway` vs
   `StripeDirectGateway`. Names should accommodate the category, not just the
   first instance.

7. **Is any structured information encoded as a plain string that could drift
   from its source of truth?**
   JSON schemas in prompt strings, format descriptions in comments, duplicated
   structure definitions -- if the string encodes something that also exists as
   code (a schema, a type, a validation), connect them so mismatches are caught
   at definition time.

### Extraction Signals

8. **Does any new calculation embed domain knowledge (calendars, configs,
   business rules) that belongs in a shared layer?**
   Time-difference calculations in work-tracking systems always eventually need
   to exclude non-working periods. Cost calculations always eventually need
   currency handling. If the domain knowledge is inline, it will be duplicated
   when the next consumer needs the same calculation.

9. **Does any new conditional branch represent a product decision that should
   be configurable rather than hardcoded?**
   Thresholds, limits, feature flags, and policy decisions embedded in code
   require a deploy to change. If the value is likely to be tuned, it should
   be extractable to configuration.

