---
name: tdd-bug-fix
description: Enforce TDD when fixing bugs - write a failing test first, then make it pass. Use when about to fix a bug, correct broken behavior, or resolve an issue in production code. Activates for phrases like "let me fix", "I'll fix this", "same issue as", "the problem is", or when editing code after identifying a bug.
---

# Test-Driven Bug Fixing

When fixing bugs, you MUST follow Kent Beck's TDD discipline: write a failing test
first, then make it pass. There is no world in which production code changes
without a corresponding test change.

## When to Activate

- "Let me fix that" / "Let me fix this" / "I'll fix..."
- "Same [issue/problem/bug] as..."
- "The problem is..." followed by editing code
- "This isn't working because..." then editing code
- After identifying broken behavior and before editing production code
- When correcting any bug, defect, or incorrect behavior

## The Rule

**NEVER edit production code to fix a bug without first touching tests.**

The sequence is always:

1. **Reproduce** - Write a failing test that demonstrates the bug
2. **Verify red** - Confirm the test fails for the right reason
3. **Fix** - Make the minimal change to pass the test
4. **Verify green** - Confirm the test passes

## Workflow

### Step 1: Find Existing Tests

Before fixing anything, locate the test file:

```
spec/          # RSpec
test/          # Minitest, Jest, etc.
__tests__/     # Jest convention
*.test.ts      # Test file patterns
*.spec.rb
```

If no tests exist for the code being fixed, create them.

### Step 2: Write a Failing Test

Write a test that:
- Reproduces the exact bug scenario
- Fails with the current (broken) behavior
- Will pass once the bug is fixed

```ruby
# Example: Bug where API client uses wrong encoding
context 'when sending data to the API' do
  it 'sends JSON-encoded body, not form-encoded' do
    # This test will FAIL with current code (form encoding)
    # and PASS after the fix (JSON encoding)
    expect(request.content_type).to eq('application/json')
  end
end
```

### Step 3: Verify the Test Fails

Run the test and confirm it fails. This proves:
- The test is actually testing the bug
- The bug is real and reproducible

### Step 4: Fix the Production Code

Now, and only now, edit the production code to fix the bug.

### Step 5: Verify the Test Passes

Run the test again. It should pass. This proves:
- The fix works
- The bug is resolved
- Future regressions will be caught

## Exceptions

Do NOT require test changes for:

- **Configuration fixes** - `.env`, `.env.local`, credentials files
- **Infrastructure config** - `docker-compose.yml`, `Procfile`, CI config
- **Documentation** - README, CHANGELOG, comments-only changes
- **Dependency versions** - Gemfile.lock, package-lock.json updates
- **Data fixes** - Database seeds, fixtures, migrations that fix data
- **No test suite** - Codebase has no tests (common during prototyping)

If there's no `spec/`, `test/`, or `__tests__/` directory, skip the TDD workflow.

## Examples

### Good: TDD Bug Fix

```
User: The API calls are failing

Claude: I see the issue - HTTParty is using form encoding instead of JSON.
        First, let me write a failing test to reproduce this bug.

        [Writes test in spec/lib/api_client_spec.rb]

        Running the test... it fails as expected - the request uses
        form encoding.

        Now let me fix the client to use JSON:

        [Edits lib/api_client.rb]

        Running the test again... it passes. The bug is fixed.
```

### Bad: Skipping the Test

```
User: The API calls are failing

Claude: Same HTTParty issue as the rake task - form encoding isn't working
        correctly. Let me fix the client to use JSON:

        [Edits lib/api_client.rb WITHOUT touching tests]

        # THIS IS WRONG - no test was written to reproduce the bug
```

### Good: Config Fix (No Test Needed)

```
User: The API key isn't working

Claude: I see the issue - the .env file has an extra space in the API key.
        Let me fix .env:

        [Edits .env]

        # This is fine - config fixes don't require tests
```

## Self-Check

Before editing any production code to fix a bug, ask yourself:

1. Have I identified the failing behavior?
2. Have I written a test that reproduces it?
3. Have I seen the test fail?

If the answer to any of these is "no", STOP and write the test first.

## Why This Matters

From Kent Beck's "Test-Driven Development: By Example":

> "The goal is clean code that works. First we'll make it work, then we'll
> make it clean."

But we can't know it "works" without a test. A bug fix without a test is:
- Not provably correct
- Not protected against regression
- Not documenting the expected behavior

The test IS the proof that the bug is fixed.
