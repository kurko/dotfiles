---
name: decision-brief
description: Use when the user needs a quick overview to make a decision, says "brief me", "decision brief", "quick overview", "what are my options", asks "X or Y?" (cron or webhooks, database or files), or hands over a task with too much going on. Produces a short brief with a proposed approach and alternatives, not a spec or RFC.
argument-hint: "[task link, file, or problem description]"
---

# Decision brief

The reader is an engineer who knows the domain and wants to agree on the problem and the approach before work starts. Keep every section short. The reader asks for detail when they need it, and a long brief buries the one decision it exists for.

## Steps

1. **Read the input.** Open every link (task, ticket, Slack thread, PR, doc) and read the code and data it touches.
2. **Research.** Look at how the codebase already solves similar problems, at the docs for any library or service involved, and at the data when the decision depends on volume or shape.
3. **Choose.** Pick the approach you would build, and two to four alternatives. Include the cheapest credible option (a config change, a manual step, doing nothing) when there is one.
4. **Confirm.** List what the proposal depends on (a vendor feature, a library version, data volume, access, existing code) and check each item yourself: read the docs, the config and the code, and query the data. If a check rules the proposal out, move it to Alternatives with the reason, pick the next option, and check that one. Under "Needs confirmation", keep only what you could not check, with who or what can settle it.
5. **Write** the brief in chat, in the format below.

## Format

```
**Decision:** <the question, one line>

**Problem**
<Restate the problem as the user brought it, so we agree on what it is. Don't
reframe it, add scope, or report research here. Two to four sentences; two
paragraphs at most.>

**Proposed approach**
<What to do and why. One or two sentences; two paragraphs at most.>

**Alternatives**
- **<Name>:** <one sentence: what it is and why it isn't the proposal>

**Drawbacks**  (optional)
<The proposal's main downsides, one or two sentences.>

**Needs confirmation**  (omit when empty)
- <What is still unverified, and who or what can confirm it>
```

## Rules

- The proposed approach comes before the alternatives, so the reader sees the recommendation first and reads the alternatives as context.
- Research findings appear only where they drive the decision: in the proposal, an alternative, or a drawback. The exception is a finding that contradicts the problem as stated (the bug doesn't reproduce, the file doesn't exist); add it to Problem in one sentence.
- One sentence per alternative, two at most. An alternative ruled out during confirmation says what ruled it out.
- No other sections, no preamble, no closing offer of more detail.
- State facts plainly. Hedge only what is uncertain, and say why it is uncertain.

## Example

**Decision:** how do we learn about failed payouts?

**Problem**
A nightly job polls the vendor's status API, so payout failures surface up to 24 hours late and support hears about them from customers first.

**Proposed approach**
Subscribe to the vendor's `payout.failed` webhook and keep the nightly poll as a reconciliation pass for events the webhook misses.

**Alternatives**
- **Webhooks only:** ruled out, the vendor's docs say failed deliveries are not retried.
- **Poll every 5 minutes:** a one-line cron change, but at current volume it uses 30% of the vendor's rate limit.
- **Do nothing:** support keeps learning about failures from customers.

**Drawbacks**
Two code paths update the same payout status, so the update has to be idempotent.

**Needs confirmation**
- Whether the vendor signs webhook payloads on our plan; the docs don't say. Vendor support can confirm.
