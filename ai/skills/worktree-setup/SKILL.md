---
name: worktree-setup
description: >-
  Set up git worktree database isolation for a project. Use when adding worktree
  support, parallel branch development, or worktree database setup. Investigates
  the project's database config and env loading, then creates bin/setup-worktree
  and bin/teardown-worktree scripts with per-branch database names.
---

# Worktree Database Isolation Setup

Guide the user through adding git worktree database isolation to their project.
This enables running multiple branches simultaneously with separate databases,
avoiding collisions between worktrees.

## When to Activate

- "Add worktree support"
- "Set up worktree isolation"
- "I want to work on multiple branches at once"
- "Parallel branch development"
- "Worktree database setup"
- "Setup worktree"

## Phase 1: Investigation

Before writing any code, investigate the project. Present findings to the user
before proceeding to design.

### 1.1 Database Configuration

Read the database config file:

| Framework | Config File | Notes |
|-----------|-------------|-------|
| Rails | `config/database.yml` | ERB supported, uses env names like `development`, `test` |
| Django | `settings.py` | DATABASES dict, often with `dj_database_url` |
| Node/Prisma | `prisma/schema.prisma` | `DATABASE_URL` env var |
| Node/Knex | `knexfile.js` | Per-environment config object |
| Phoenix | `config/dev.exs`, `config/test.exs` | Elixir config |

Determine:
- Are database names hardcoded or already read from ENV?
- What is the naming pattern? (e.g., `myapp_development`, `myapp_test`)
- Which database engine? (PostgreSQL: 63-char identifier limit, MySQL: 64, SQLite: file-based)

### 1.2 Environment Variable Loading

Identify the env loading mechanism and its file priority order per environment.

**Rails with dotenv-rails**:
- Check Gemfile for `dotenv-rails` version
- In dotenv-rails 2.x (known loading order):
  - Development: `.env.development.local` > `.env.local` > `.env.development` > `.env`
  - Test: `.env.test.local` > `.env.test` > `.env` (`.env.local` is **EXCLUDED** in test)
  - "First wins" — once a var is set, lower-priority files don't override
- If the project uses dotenv-rails 3.x or higher, read the gem source to confirm
  the loading order — it may have changed. Find it with:
  `bundle show dotenv-rails` then read `lib/dotenv/rails.rb`, look for `dotenv_files`.
- For Rails: use `.env.development.local` + `.env.test.local` (NOT `.env.local`)

**Node frameworks**:
- Vite: native `.env.local` support (loaded in all modes including test)
- Next.js, CRA: `.env.local` is **EXCLUDED** in test (same behavior as dotenv-rails).
  Use `.env.test.local` for test overrides.
- Plain dotenv: single `.env` by default, manual loading for others
- Always verify per-framework behavior before choosing the override file

**Django**:
- `django-environ` or `python-dotenv`: typically single `.env`, no per-environment split

**Other**:
- Check for `direnv` (`.envrc`), `asdf` (`.tool-versions`), or framework-specific mechanisms

### 1.3 Gitignored Secrets Required for Boot

Find files that are gitignored but required for the app to start:

```
git ls-files --others --ignored --exclude-standard | head -30
```

Common boot-critical gitignored files:
- Rails: `config/master.key`, `config/credentials/*.key`
- Node: `.env.local` (if it contains non-DB secrets)
- Any: service account JSON files, SSL certs

These files must be copied into new worktrees by `bin/setup-worktree` (for manual
`git worktree add`) and listed in `.worktreeinclude` (for Claude Code worktrees).

### 1.4 Existing Setup Scripts

Read existing setup/bootstrap scripts to match conventions:
- `bin/setup`, `bin/dev`, `Makefile`, `script/bootstrap`
- Note the language (Ruby, bash, etc.) and patterns (`system!`, `APP_ROOT`, etc.)
- Docker compose files (if they define DB names)

### 1.5 Dev Server Tools

Check for local dev server routing tools:
- puma-dev: `~/.puma-dev/` directory (macOS). Symlink-based app discovery.
- Caddy/nginx: local reverse proxy configs
- Framework dev server: port in `Procfile`, `package.json` scripts

## Phase 2: Design

Present the plan to the user for approval before implementing. Cover:

### Database Naming Strategy

Use a **suffix approach** with a `DB_SUFFIX` env var:

```
{base_name}_{slug}
```

Example for branch `feature/user-dashboard`:
- Dev: `myapp_development_feature_user_dashboard`
- Test: `myapp_test_feature_user_dashboard`

The base names stay visible and readable in the database config file.

**Slug derivation from branch name**:
1. Lowercase
2. Replace non-alphanumeric chars with underscore
3. Collapse consecutive underscores
4. Strip leading/trailing underscores
5. If over max length: truncate and append `_` + 6-char SHA1 hash of the original branch name

**Max slug length**: Calculate from the actual database name prefix. The longest
prefix is typically `{app}_development_` — measure its length and subtract from
the database engine's identifier limit (PostgreSQL: 63, MySQL: 64). For example,
if the prefix is `myapp_development_` (18 chars), max slug = 63 - 18 = 45 chars.

### Environment Override Strategy

Use the project's EXISTING env loading mechanism. Do not invent custom file formats.

**For Rails with dotenv-rails**:
- `.env.development.local` sets `DB_SUFFIX=<slug>` (loaded in development)
- `.env.test.local` sets `DB_SUFFIX=<slug>` (loaded in test)
- `database.yml` appends the suffix: `myapp_development<%= "_#{ENV['DB_SUFFIX']}" if ENV['DB_SUFFIX'].present? %>`

**For Node with framework-native .env.local**:
- `.env.local` sets `DB_SUFFIX=<slug>` (or overrides `DATABASE_URL` directly)

**For other frameworks**:
- Use the most environment-specific override file available

### Files to Create/Modify

Present a list:
1. **Database config** — add ENV-based suffix to base names
2. **.gitignore** — add `.env.local` and `.env.*.local` if not present
3. **bin/setup-worktree** — creates DBs, writes env files, copies secrets, runs migrations
4. **bin/teardown-worktree** — drops DBs, removes env files, cleans up
5. **.worktreeinclude** — lists gitignored boot-critical files (for Claude Code worktrees)

## Phase 3: Implementation

### bin/setup-worktree

**Language**: Match the project's `bin/setup` convention. Ruby for Rails, bash for
Node/Python. If `bin/setup` is Ruby, use `Pathname`, `system!`, `APP_ROOT` — same patterns.

**Requirements** (the script MUST):

1. **Detect linked worktree**: Compare `git rev-parse --git-common-dir` (stripped of
   `/.git` suffix) with `git rev-parse --show-toplevel`. If equal, this is the main
   worktree — print a message and exit (do not abort; this allows safe use from hooks).

2. **Copy boot-critical secrets from main worktree**: For each gitignored file needed
   for boot (e.g., `config/master.key`), check if it exists in the current worktree.
   If not, copy it from the main worktree path (derived from `--git-common-dir`).
   This handles the manual `git worktree add` case where `.worktreeinclude` doesn't apply.

3. **Derive slug from branch**: Sanitize, collapse, truncate (see Design section).

4. **Write env override files**: Set `DB_SUFFIX=<slug>`. Behavior per file:
   - If file doesn't exist: create it with `DB_SUFFIX=<slug>`
   - If file exists but has no `DB_SUFFIX=`: append `DB_SUFFIX=<slug>`
   - If file exists and already has `DB_SUFFIX=`: skip (print message)

5. **Check databases independently**: Check BOTH dev and test databases before creating.
   For Rails, use `bin/rails runner` to attempt a connection per environment:
   ```ruby
   system({ "RAILS_ENV" => env }, "bin/rails", "runner",
     "ActiveRecord::Base.connection_pool.with_connection { }",
     out: File::NULL, err: File::NULL)
   ```
   This is more reliable than parsing `psql -lqt` because it uses the actual
   Rails config with the suffix applied.

6. **Create databases and load schema**:
   - Dev (if missing): `db:create db:schema:load db:seed`
   - Test (if missing): `RAILS_ENV=test db:create db:schema:load`
   - Use `db:schema:load` not `db:migrate` — faster, no need to replay history.

7. **puma-dev (optional)**: If `~/.puma-dev/` exists, create symlink
   `~/.puma-dev/{app}-{slug}` pointing to the worktree directory. Convert
   underscores to hyphens in the slug for domain names. Print the resulting
   URL so the user can access it, e.g.: `==> puma-dev: https://{app}-{slug}.test`

8. **Print a final summary** that includes:
   - The dev and test database names
   - The puma-dev URL (if configured)
   - How to start the dev server
   Print informative messages at each step too. Never be silent — the user
   should see what's happening.

**The script MUST NOT**:
- Modify any tracked (git) files
- Require interactive input
- Touch Redis, Memcached, or other shared services (collision risk is acceptable in dev)
- Hard-code app names in output (derive from config or use relative descriptions)

### bin/teardown-worktree

**Requirements**:
- Accept an optional branch name argument (for cleanup from outside the worktree)
- If no argument, derive branch from `git branch --show-current`
- Derive the same slug (must use identical logic as setup)
- Drop databases if they exist
- Remove puma-dev symlink if present (use the same underscore-to-hyphen slug conversion as setup)
- Remove env override files (`.env.development.local`, `.env.test.local`)
- Idempotent — safe to run multiple times
- Print what it does at each step

### database.yml (or equivalent)

Modify the database config to append `DB_SUFFIX` when present:

**Rails** (`config/database.yml`):
```yaml
development:
  <<: *default
  database: myapp_development<%= "_#{ENV['DB_SUFFIX']}" if ENV['DB_SUFFIX'].present? %>

test:
  <<: *default
  database: myapp_test<%= "_#{ENV['DB_SUFFIX']}" if ENV['DB_SUFFIX'].present? %>
```

Zero behavioral change when `DB_SUFFIX` isn't set (main worktree).

**Prisma** (`prisma/schema.prisma`):
```prisma
datasource db {
  url = env("DATABASE_URL")
}
```
(Already ENV-driven; the setup script writes the full URL to `.env.local`.)

### .worktreeinclude

Created in the project root, checked into git. Lists gitignored files that
Claude Code should copy when creating worktrees:

```
config/master.key
```

Rules:
- Only list files that are gitignored AND required for boot
- Do NOT list env override files (`.env.development.local`, `.env.test.local`)
  — these are generated by `bin/setup-worktree` with branch-specific values
- Do NOT list `vendor/bundle`, `node_modules` — too large, package managers handle these

This file is ONLY used by Claude Code's worktree feature. The `bin/setup-worktree`
script independently copies these same files (see requirement 2), so it works
regardless of how the worktree was created.

### .gitignore

Ensure these patterns are present (append if missing):

```
.env.local
.env.*.local
```

## Phase 4: Verification

After implementation, verify by walking through this checklist:

1. **Main worktree**: Run `bin/setup-worktree` — should print "not a linked worktree" and exit
2. **Create a test worktree**: `git worktree add ../project-test-wt -b test-worktree-setup`
3. **Run setup**: `cd ../project-test-wt && bin/setup-worktree`
   - Should create env files with `DB_SUFFIX`
   - Should copy boot-critical secrets
   - Should create both dev and test databases
   - Should load schema and seed (dev)
4. **Run tests**: `bundle exec rspec` (or equivalent) in the worktree — uses worktree-specific test DB
5. **Run dev server**: `make server` (or equivalent) — uses worktree-specific dev DB
7. **Main worktree unaffected**: Return to main worktree, run tests — still uses original DB
8. **Idempotent**: Run `bin/setup-worktree` again — skips existing databases, skips existing env vars
9. **Teardown**: `bin/teardown-worktree` — drops databases, removes env files
10. **Teardown idempotent**: Run teardown again — no errors
11. **Remove worktree**: `cd .. && git worktree remove project-test-wt`

## Out of Scope

These are acceptable to leave for future work:

- **Redis isolation**: Shared Redis is fine for local dev. Sidekiq uses test mode in specs.
- **Background jobs**: Jobs from different worktrees may collide in Redis queues. Acceptable for dev.
- **Search indexes**: Elasticsearch/Meilisearch isolation. Rarely needed for local dev.
- **File storage**: ActiveStorage/CarrierWave paths. Usually fine sharing `/storage`.
