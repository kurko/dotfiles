# This file contains aliases and functions for managing AI worktrees and tasks.
# 
# The git-* ones are auxiliary functions to manage git worktrees. You should
# look into claude-new-worktree as entrypoint.
function claude-new() {

  INITIAL_PROMPT="$@"
  if [[ -d "ai-notes" ]]; then
    if [[ -f "ai-notes/AI-README.md" ]]; then
      README_FILE="ai-notes/README.md"
    elif [[ -f "ai-notes/README.md" ]]; then
      README_FILE="ai-notes/README.md"
    else
      README_FILE=""
    fi

    # Injects whatever is passed into claude-new as the initial prompt.
    INITIAL_PROMPT="$INITIAL_PROMPT.

    The AI notes are in ai-notes/. Read $README_FILE. Please read them before starting."
  fi

  echo "Running claude"

  claude \
    "$INITIAL_PROMPT" \
    --allowedTools " \
      Bash(mkdir:*) \
      ,Bash(curl:*) \
      ,Bash(ls:*) \
      ,Bash(bundle install) \
      ,Bash(bundle install:*) \
      ,Bash(bundle exec:*) \
      ,Bash(bin/rails:*) \
      ,Bash(bin/rake:*) \
      ,Bash(rm:*) \
      ,Bash(find:*) \
      ,Bash(ag:*) \
      ,Bash(rg:*) \
      ,Bash(npm run build:*) \
      ,Bash(npm install:*) \
      ,Bash(npm test:*) \
      ,Bash(npm run lint) \
      ,Bash(grep:*) \
      ,Bash(mv:*) \
      ,Bash(lsof:*) \
      ,Bash(log:*) \
      ,Bash(git add:*) \
      ,Bash(cat:*) \
      ,Bash(ps:*) \
      ,Bash(awk:*) \
      ,WebFetch(domain:github.com)"
}

function claude-new-worktree() {
  # create a new Claude conversation
  git-worktree-add "task-$1"

  # We store if the worktree was created successfully or not. If it was, it's a
  # new repo and need to setup the repository. We will set an initial prompt
  # based on that. If there was an error, the repo already exists and we won't
  # do anything initial.
  if [[ $? -ne 0 ]]; then
    echo "Worktree for task-$1 already exists. Exiting."
  fi

  INITIAL_PROMPT="This is a worktree for task $1"

  INITIAL_PROMPT="$INITIAL_PROMPT.
    Take a look around (README, ai-notes, etc.) to understand the context of the
    repository. You can also run some commands to get a feel of the repository.
    Once you understand what kind of codebase this is, wait for instructions before start coding.
  "

  # Passes the initial prompt to claude-new function, as well as $1
  claude-new "$INITIAL_PROMPT"
}

function git-worktree-add() {
  INITIAL_DIRECTORY=$(pwd)

  # only create work tree if it does not already exist
  if git-worktree-exists "$1"; then
    # create a new git worktree
    echo "Worktree for $1 already exists."
  else
    echo "Creating worktree for $1"
    git worktree add -b "worktree-$1" ../worktrees/"$1"
  fi

  if [[ -d "../worktrees/$1" ]]; then
    cd ../worktrees/"$1"
  elif [[ -d "../../worktrees/$1" ]]; then
    cd ../../worktrees/"$1"
  else
    echo "Can't cd into worktree $1, directory does not exist."
    return 1
  fi

  NEW_WORKTREE=$(pwd)

  # Creates a symlink between the initial directory's /ai-notes directory and
  # the new worktree's /ai-notes directory.
  if [[ -d "$INITIAL_DIRECTORY/ai-notes" ]]; then
    echo "Initial directory has ai-notes directory, creating symlink in new worktree"
    if [[ ! -d "$NEW_WORKTREE/ai-notes" ]]; then
      echo "Creating symlink to ai-notes directory"
      ln -s "$INITIAL_DIRECTORY/ai-notes" "$NEW_WORKTREE/ai-notes"
    fi
  fi
}

function git-worktree-exists() {
  # check if a git worktree exists
  if [[ -d "../worktrees/$1" ]]; then
    return 0
  elif [[ -d "../../worktrees/$1" ]]; then
    return 0
  else
    return 1
  fi
}

function git-worktree-clean() {
  git worktree list --porcelain | 
    grep -B2 "branch refs/heads/" | 
    grep "worktree" | 
    cut -d' ' -f2 | 
    xargs -I {} git worktree remove {}
}

