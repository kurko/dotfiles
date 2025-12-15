---
name: write-task
description: Skill on how to write a task. Use when user asks you to write a task (for Asana, Linear, Jira, Notion and equivalent). Also activates when user says "create task", "write task", or similar task creation workflow requests.
---

# Write a task

Write a task using with the following sections:

- "Background": something the reader should know
- "Why is it important?": reasoning behind the work and the cost of inaction
- "Proposed changes": what needs to happen.

If a Slack thread is passed in, use that as context for making it richer.

## Rules

- Avoid fancy words, like: stems, delve.
- Avoid em-dashes (—). Use commas or split into separate sentences instead.
- Don't use bullet points a lot.
- Keep proposed changes at the level of detail provided in the request. If
  detailed implementation guidance is given, include it. Otherwise, keep it
  high-level and let engineers determine the approach.
- When there are multiple valid approaches, present them as options rather than
  picking one. Let the team decide which path to take.

## Choosing the Right Template

Use the **short template** (Background + Proposed changes) for:
- Bug fixes with obvious impact
- Typo corrections and link updates
- Simple configuration changes
- Sentry exceptions that need silencing
- Straightforward tasks where the importance is self-evident

Use the **full template** (Background + Why is it important? + Proposed changes) for:
- New features
- Tasks involving non-engineering stakeholders
- Work requiring prioritization decisions
- Systematic problems that need deeper analysis
- Complex tasks that might sit in the backlog for months and need context
  preservation (so future readers understand why this mattered)

When in doubt, use the full template. The "Why is it important?" section helps
teams remember context when revisiting old tasks.

## Writing Task Titles

A good task title should be specific enough to distinguish from similar tasks
and scannable in a list of 50+ items.

**Solution-focused titles** start with a verb (Fix, Add, Update, Remove). Use
when the approach is known:
- "Add webhook delivery audit log"
- "Update payment retry logic to 3 attempts"

**Problem-focused titles** describe the issue without prescribing a solution.
Use when you want engineers to determine the approach:
- "Cart times out with 50+ items"
- "Users confused by generic error message on login"

Avoid vague titles like "Checkout issues" or "Webhooks" that don't distinguish
the task from others.

## Anti-patterns to Avoid

**Don't bury the action in vague language**
Bad: "We should probably consider maybe looking into potentially improving..."
Good: "Update the payment processor to retry failed transactions"

**Don't use corporate speak**
Bad: "Leverage synergies to optimize the data pipeline infrastructure"
Good: "Fix the slow database queries in the reporting system"

**Don't make tasks too abstract**
Bad: "Improve user experience in the checkout flow"
Good: "The checkout flow times out when users have more than 50 items in their cart"

## Writing the Background Section

The Background section should progress from high-level to detailed:

1. **First sentence**: Very high-level explanation that someone unfamiliar with
   the system can understand. Introduce basic concepts.
2. **Following sentences**: Gradually add technical details, building on the
   foundation. Each sentence goes one level deeper.
3. **Final sentences**: Specific context about the current state, the problem,
   or the gap that needs filling.

This progressive structure ensures anyone can understand the basics before
encountering technical specifics.

## Template

Here's one template you can use:

### Writing the tl;dr

The tl;dr is a single line at the very top that lets someone understand the core
issue without reading the full task. It should capture the gap between
expectation and reality, or the core problem in plain terms.

Examples:
- "tl;dr use_new_vendor is confusing because the name suggests it controls all
  card types, but it only affects prepaid cards, not debit."
- "tl;dr checkout times out when carts have 50+ items because we load all item
  images synchronously."
- "tl;dr customers can't tell if a webhook failed on our side or theirs because
  we don't log delivery attempts."

### Short Template

```markdown
tl;dr [One-line summary of the core issue]

## Background
[Explanation that makes the importance self-evident]

## Proposed changes
[What needs to happen]
```

### Full Template

Use this when the task involves non-engineering stakeholders, new features, or
needs context preservation.

```markdown
tl;dr [One-line summary of the core issue]

## Background
[Explanation]

## Why is it important?
[Cost of not doing it]

## Proposed changes
[What needs to happen]
```

### Acceptance Criteria (Optional)

Add this section only when explicitly requested. Many teams prefer to let
engineers determine implementation details and testing approaches.

```markdown
## Acceptance criteria

- Criterion 1
- Criterion 2
```

## Examples

### Short Template Example

```markdown
tl;dr login form shows "Invalid credentials" for timeouts, confusing users who think their password is wrong.

## Background
The login form shows "Invalid credentials" when the authentication service times
out, confusing users who think their password is wrong. This causes unnecessary
support tickets and password reset requests.

## Proposed changes

Update the authentication service to distinguish between authentication failures
and network errors. Show "Unable to connect, please try again" for timeout
errors instead of the generic credentials message.
```

### Full Template Example

```markdown
tl;dr customers can't tell if a webhook failed on our side or theirs because we don't log delivery attempts.

## Background
When customers report missing or incorrect webhook notifications, we currently
have no way to verify what data was actually sent to their endpoints. We rely on
application logs which get rotated after 7 days and don't always capture the
full request/response cycle. This makes debugging webhook delivery issues time
consuming and often impossible if the issue happened more than a week ago.

## Why is it important?

We have spent considerable engineering time investigating webhook issues due
to lack of proper records, effort which could be spent on new features or
improving reliability. Support tickets about webhooks take hours to investigate
without proper records, leading to frustrated customers.

Customers rely on our webhook delivery for their integrations, yet we can't
prove whether an issue was on our side or the customer's endpoint when they
report missing webhooks.

## Proposed changes

- Create a new `WebhookDelivery` model to store outbound webhook attempts.
This should capture the request payload, headers, response status, response
body, and timestamp. The model could reference the triggering event (like an
Article or Comment) through a polymorphic association.

Store at least 90 days of webhook history to cover most support cases. Consider
adding an index on organization_id and created_at for quick lookups. We should
also add a simple admin interface to search webhook deliveries by organization,
date range, and status code.

For the actual implementation, we'd modify our existing webhook service (likely
in app/services/webhook_service.rb) to create a WebhookDelivery record after
each attempt. This gives us the full picture when customers ask "did you send a
webhook for order X?" or "why didn't we receive the gift.created event
yesterday?"
```

### Example with Options

When multiple approaches are valid, present them as options:

```markdown
tl;dr use_new_vendor is confusing because the name suggests it controls all card types, but it only affects prepaid cards, not debit.

## Background
We have a config called `use_new_vendor` that controls whether prepaid cards use the new vendor or the legacy one. The name is misleading because it suggests it controls all card types, but it actually only affects prepaid cards. Debit cards use a completely different mechanism and are not affected by this config.

During a recent incident, this caused confusion and required multiple people to clarify what the config actually did.

## Why is it important?

The current name caused real confusion during incident response. While it's tacitly known by some engineers, others will need to verify whether debit cards would be affected by toggling this config (and some would assume its name is what it does). Future engineers will likely make the same incorrect assumptions.

## Proposed changes

Options:
- Rename `use_new_vendor` to something that clearly indicates it only controls prepaid card vendor selection, such as `prepaid_use_new_vendor`, or
- Make `use_new_vendor` cover debit card situations as well.
```

## Using Slack Thread Context

When the user provides a Slack thread (or similar conversation context):

1. **Read the entire thread carefully** to understand the discussion, concerns
   raised, and any decisions made.
2. **Extract key information**:
   - Technical details or constraints mentioned
   - User pain points or customer feedback
   - Proposed solutions or approaches discussed
   - Any disagreements or alternatives considered
3. **Incorporate into the task**:
   - Use thread content to enrich the Background section
   - Include relevant technical details in Proposed changes
   - Reference specific concerns in the "Why is it important?" section
4. **Attribute appropriately**: If someone in the thread made a key observation
   or proposal, consider mentioning it to preserve context.

The goal is to transform the conversational thread into a well-structured,
standalone task that captures the discussion's value.

## Exploring the Codebase for Context

When the user mentions file paths, class names, method names, or other code
references while requesting a task:

1. **Search the codebase** to locate the mentioned code:
   - Use Grep to find class names, method names, or identifiers
   - Use Glob to find files by path or pattern
   - Read the relevant files to understand the current implementation

2. **Gather context** by examining:
   - What the class/method currently does
   - Where it's called or used in the system
   - Related classes or dependencies
   - Any comments or documentation in the code
   - Existing tests that might reveal expected behavior

3. **Enrich the task** with findings:
   - Add technical details that clarify the current state
   - Reference specific file paths or line numbers for precision
   - Identify potential complications or edge cases
   - Suggest implementation approaches based on existing patterns

4. **Reduce ambiguity**: The goal is to make the task clearer and more
   actionable by grounding it in the actual codebase, reducing the chance of
   vague or incorrect technical descriptions.

This investigation should be done **before** writing the task to ensure accuracy
and completeness.

## Output

After creating the task:

1. **Explain your template choice**: Tell the user which template you used
   (short or full) and why. This helps identify when the wrong template was
   chosen so the skill can be improved. For example:
   - "I used the full template because this is a systematic problem that needs
     context preservation for future reference."
   - "I used the short template because this is a straightforward bug fix with
     obvious impact."

2. **Copy to clipboard**: Attempt to copy the task description to the user's
   clipboard using a heredoc (more reliable with multi-line content and quotes):
   - On macOS: Use `cat << 'EOF' | pbcopy` followed by the content and `EOF`
   - On Linux: Use `cat << 'EOF' | xclip -selection clipboard` or `xsel --clipboard`
   - After copying, verify with `pbpaste | head -3` to confirm it worked
   - If the clipboard command fails or isn't available, inform the user and
     simply output the task text directly.

   Example:
   ```bash
   cat << 'EOF' | pbcopy
   tl;dr The task content goes here...

   ## Background
   More content...
   EOF
   ```
