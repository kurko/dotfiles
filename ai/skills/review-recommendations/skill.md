---
name: review-recommendations
description: Review technical recommendations before presenting them to the user. Use BEFORE suggesting config changes, optimizations, refactors, or architecture decisions. Spawns a subagent to challenge assumptions and filter out generic advice that doesn't apply to the user's context.
---

# Review Recommendations

Before presenting technical recommendations to the user, run them through a
critical review to filter out generic advice and verify they apply to the
user's specific context.

## When to Activate

Use this skill BEFORE presenting:

- Performance optimizations (Dockerfile, database, caching)
- Configuration changes (CI/CD, deployment, infrastructure)
- Architecture suggestions (refactoring, new patterns)
- "Best practices" recommendations
- Any suggestion that changes how something works

## Why This Exists

Generic "best practices" advice often doesn't apply to specific contexts:

- Cache mounts help local builds but not CI without explicit setup
- Indexing advice assumes query patterns that may not exist
- Optimization suggestions assume a problem exists
- Refactoring advice assumes the current code is wrong

If you'd fold immediately when challenged on a recommendation, you shouldn't
present it in the first place.

## How to Use

Before presenting recommendations, spawn a `general-purpose` subagent with:

```
Review these technical recommendations I'm about to give:

[YOUR DRAFT RECOMMENDATIONS]

Context about the user's situation:
[RELEVANT CONTEXT - where builds run, current performance, actual problem]

For each recommendation, answer:

1. PROBLEM CHECK: Is there actually a problem to solve? What evidence do we have?
   - What's the current metric (build time, response time, etc.)?
   - Is that metric actually bad, or just "could be better"?

2. CONTEXT CHECK: Does this apply to THIS user's setup?
   - Where does this run? (CI, local, production)
   - What tools/services are they using?
   - What's already in place that might make this redundant?

3. ASSUMPTION CHECK: What am I assuming?
   - Am I assuming they have a problem they didn't mention?
   - Am I assuming infrastructure that doesn't exist?
   - Am I giving generic advice I'd give to anyone?

4. CONFIDENCE CHECK: Would I defend this if challenged?
   - If an expert said "that won't help here," would I agree?
   - Is this based on their specific situation or general knowledge?

5. VERDICT: Keep, modify, or drop?
   - KEEP: Specific to their context, addresses real problem
   - MODIFY: Good idea but needs caveats for their situation
   - DROP: Generic advice, no evidence it applies, or no real problem

Return a filtered list with only recommendations that pass these checks.
```

## Example: Dockerfile Optimization

**Bad approach (what went wrong):**

```
User: Review our Dockerfile for speed improvements

Claude: Here are 4 optimizations:
1. BuildKit cache mounts for bundle install
2. APT cache mounts
3. Separate Tailwind build
4. --jobs flag for bundle
```

**Good approach (using this skill):**

```
User: Review our Dockerfile for speed improvements

Claude: [Spawns review subagent with draft recommendations]

Subagent review:
- Current deploy time: 2m35s (is this actually slow? No baseline given)
- Builds run in: GitHub Actions CI
- Already has: registry caching via Kamal

1. Cache mounts - DROP: Don't persist in CI without explicit actions/cache setup.
   User already has layer caching via registry.
2. APT cache mounts - DROP: Same issue.
3. Tailwind separation - DROP: COPY . . invalidates the layer anyway.
4. --jobs flag - MODIFY: Harmless but Bundler 2.x already parallelizes.

Verdict: The Dockerfile is already well-optimized for their CI setup.
```

**Final response to user:**

```
Claude: I reviewed the Dockerfile looking for optimizations. Given that you're
building in GitHub Actions with registry caching already configured, the
Dockerfile is already well-optimized. The 2m35s deploy time is mostly
image push and Kamal orchestration, not build time.

Is there a specific part of the deploy that feels slow?
```

## Red Flags That Trigger This Skill

- "Here are N things you could improve..."
- "Best practices suggest..."
- "You should consider..."
- "A common optimization is..."
- Listing multiple suggestions without checking if any apply

## Output

After the subagent review, either:

1. **Present filtered recommendations** - Only those that passed all checks
2. **Ask clarifying questions** - If you need more context to evaluate
3. **Report no changes needed** - If nothing applies to their situation

Never present generic advice. Every recommendation must be specific to the
user's context and address a verified problem.
