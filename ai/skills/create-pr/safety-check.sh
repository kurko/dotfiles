#!/usr/bin/env bash
set -euo pipefail

# Pre-flight safety checks for creating a pull request.
#
# This script outputs structured results that the AI agent must parse and
# follow. Lines prefixed with INSTRUCTION: are directives for the agent.
# Lines prefixed with ERROR: indicate a blocking problem. Lines prefixed
# with WARNING_ indicate non-blocking issues that need user confirmation.

# --- Git repo check ---

if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
  echo "ERROR: Not inside a git repository."
  echo ""
  echo "INSTRUCTION: Tell the user this command must be run from inside a git"
  echo "repository. Do not proceed."
  exit 1
fi

# --- gh CLI check ---

if ! command -v gh > /dev/null 2>&1; then
  echo "ERROR: gh CLI is not installed."
  echo ""
  echo "INSTRUCTION: Tell the user to install the GitHub CLI (gh) before"
  echo "creating a PR. Installation: https://cli.github.com/"
  exit 1
fi

if ! gh auth status > /dev/null 2>&1; then
  echo "ERROR: gh CLI is not authenticated."
  echo ""
  echo "INSTRUCTION: Tell the user to authenticate with 'gh auth login'"
  echo "before creating a PR."
  exit 1
fi

# --- Determine base branch ---
# Try the remote's default branch first (most reliable), fall back to local.

base_branch=""
if command -v gh > /dev/null 2>&1; then
  base_branch=$(gh repo view --json defaultBranchRef --jq '.defaultBranchRef.name' 2>/dev/null || echo "")
fi

if [ -z "$base_branch" ]; then
  if git show-ref --verify --quiet refs/heads/main; then
    base_branch="main"
  elif git show-ref --verify --quiet refs/heads/master; then
    base_branch="master"
  fi
fi

if [ -z "$base_branch" ]; then
  echo "ERROR: Could not determine the default branch."
  echo ""
  echo "INSTRUCTION: Ask the user which branch is the base branch for this PR."
  exit 1
fi

# --- Current branch check ---

current_branch=$(git branch --show-current)

if [ -z "$current_branch" ]; then
  echo "ERROR: Detached HEAD state."
  echo ""
  echo "INSTRUCTION: You are in detached HEAD state. Create a new branch before"
  echo "proceeding. Ask the user for a branch name, or derive one from the most"
  echo "recent commit subject. If a branch prefix is present in the conversation"
  echo "context (from CLAUDE.md, AGENTS.md, memory, or the user's message),"
  echo "use it as a prefix (e.g., prefix/branch-name)."
  exit 1
fi

if [ "$current_branch" = "$base_branch" ]; then
  echo "ERROR: Currently on the default branch ($current_branch)."
  echo ""
  echo "INSTRUCTION: You are on $current_branch. You MUST create a new branch"
  echo "before creating a PR. Never push directly to $current_branch."
  echo ""
  echo "To create a branch:"
  echo "1. If the user specified a branch prefix in this conversation or it is"
  echo "   present in CLAUDE.md, AGENTS.md, or memory, use it as a prefix"
  echo "   (e.g., prefix/branch-name)."
  echo "2. Otherwise, derive a descriptive branch name from the first commit"
  echo "   subject using lowercase-hyphenated format."
  echo "3. Run: git checkout -b <branch-name>"
  echo "4. Then re-run this safety check script."
  exit 1
fi

# --- Remote check ---

remote_url=$(git remote get-url origin 2>/dev/null || echo "")

if [ -z "$remote_url" ]; then
  echo "ERROR: No 'origin' remote configured."
  echo ""
  echo "INSTRUCTION: There is no origin remote. Ask the user to add one with"
  echo "'git remote add origin <url>' before creating a PR."
  exit 1
fi

# --- Commits ahead check ---

commit_count=$(git rev-list "$base_branch"..HEAD --count 2>/dev/null || echo "0")

if [ "$commit_count" = "0" ]; then
  echo "ERROR: No commits ahead of $base_branch."
  echo ""
  echo "INSTRUCTION: There are no commits to create a PR for. The current branch"
  echo "is identical to $base_branch. Tell the user there is nothing to submit."
  exit 1
fi

# --- Sensitive files check ---

sensitive_files=$(git diff "$base_branch"..HEAD --name-only | grep -iE '\.env|credentials|secret|\.pem|\.key|id_rsa' || true)

# --- Uncommitted changes check ---

uncommitted=""
if ! git diff --quiet HEAD 2>/dev/null; then
  uncommitted="yes"
fi
if ! git diff --cached --quiet HEAD 2>/dev/null; then
  uncommitted="yes"
fi

# --- Collect commit messages ---

commit_log=$(git log "$base_branch"..HEAD --format="---COMMIT---%n%H%n%s%n%b" --)

# --- Output structured results ---

echo "SAFETY_CHECK=PASSED"
echo ""
echo "BRANCH=$current_branch"
echo "BASE=$base_branch"
echo "REMOTE=$remote_url"
echo "COMMITS_AHEAD=$commit_count"

if [ -n "$sensitive_files" ]; then
  echo ""
  echo "WARNING_SENSITIVE_FILES:"
  echo "$sensitive_files"
  echo ""
  echo "INSTRUCTION: The diff includes files that may contain secrets or"
  echo "credentials. Show this list to the user and ask for explicit"
  echo "confirmation before proceeding. Do NOT push if the user has concerns."
fi

if [ -n "$uncommitted" ]; then
  echo ""
  echo "WARNING_UNCOMMITTED_CHANGES=true"
  echo ""
  echo "INSTRUCTION: There are uncommitted changes in the working tree. Ask the"
  echo "user if they want to commit these changes first or proceed with only the"
  echo "existing commits."
fi

echo ""
echo "COMMIT_LOG:"
echo "$commit_log"
