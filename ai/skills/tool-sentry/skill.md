---
name: tool-sentry
description: Fetches Sentry issue details by URL. Use when the user asks about a Sentry error, issue, or exception, or shares a Sentry link. Also, when Slack conversation include a Sentry issue URL.
argument-hint: "[sentry-issue-url]"
---

# Sentry Issue Lookup

Fetches a Sentry issue and its most representative event, then prints a
structured debugging summary: error details, stacktrace (in-app frames
first), HTTP request context, breadcrumbs, user info, and tags.

## Prerequisites

The `SENTRY_AUTH_TOKEN` environment variable must be set.

If the token is missing, tell the user:

> `SENTRY_AUTH_TOKEN` is not set. Create a token at
> https://sentry.io/settings/account/api/auth-tokens/ with `event:read`
> scope, then run:
>
> ```bash
> export SENTRY_AUTH_TOKEN='your-token-here'
> ```

Do NOT attempt to run the script without the token.

## Usage

```bash
# Fetch issue details (the full URL with query params is fine — only org and issue ID are used)
~/.claude/skills/tool-sentry/sentry-readonly-cli "https://myorg.sentry.io/issues/7044654032/"

# Show help with full output format documentation
~/.claude/skills/tool-sentry/sentry-readonly-cli help
```

## Output Sections

The script outputs these sections (omitted if no data):

1. **Header** — short ID, title, status, level, culprit, event/user counts, timestamps, assignee
2. **Error** — error message from issue metadata
3. **Request** — HTTP method, URL, query string, body (if the error was from an HTTP request)
4. **User** — affected user's ID, email, username, IP
5. **Contexts** — runtime (e.g., Ruby 3.4.8), OS, browser
6. **Stacktrace** — in-app frames with source context first, then vendor/framework frames
7. **Breadcrumbs** — last 15 timestamped actions before the error (HTTP calls, DB queries, etc.)
8. **Link** — permalink to Sentry web UI
9. **Tags** — all event tags (environment, server, release, transaction, etc.)

## Tips for AI Consumers

- The stacktrace separates **in-app frames** (your code) from vendor frames. Focus on in-app frames first.
- Breadcrumbs show the sequence of events leading to the crash — useful for understanding what the user/system was doing.
- Request context helps reproduce HTTP-triggered errors.
- Tags include the environment, release SHA, server name, and transaction — useful for scoping the issue.
