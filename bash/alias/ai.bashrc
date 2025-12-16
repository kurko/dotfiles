# Disclaimer: the llm() function lives in llm.bashrc

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

    Start by running 'ls' to see what kind of project this is.

    The 'ai-notes/' has notes from past sessions. Don't read them yet, only if I
    ask you to (let's keep focused)."
  fi

  echo "Running claude"

  claude \
    "$INITIAL_PROMPT" \
    --allowedTools " \
      Bash(mkdir:*) \
      ,Bash(curl:*) \
      ,Bash(ls:*) \
      ,Bash(tree:*) \
      ,Bash(pwd) \
      ,Bash(which:*) \
      ,Bash(head:*) \
      ,Bash(tail:*) \
      ,Bash(wc:*) \
      ,Bash(file:*) \
      ,Bash(bundle install) \
      ,Bash(bundle install:*) \
      ,Bash(bundle exec:*) \
      ,Bash(bundle exec rspec:*) \
      ,Bash(bundle exec rails:*) \
      ,Bash(bundle exec rake:*) \
      ,Bash(bundle exec ruby:*) \
      ,Bash(bundle exec rubocop:*) \
      ,Bash(bundle list:*) \
      ,Bash(bundle show:*) \
      ,Bash(bin/rails routes:*) \
      ,Bash(bin/rails db:schema:dump:*) \
      ,Bash(bin/rails db:migrate:*) \
      ,Bash(bin/rails db:rollback:*) \
      ,Bash(bin/rails db:version:*) \
      ,Bash(bin/rails db:migrate:status:*) \
      ,Bash(bin/rails runner:*) \
      ,Bash(bin/rails console:*) \
      ,Bash(bin/rails c:*) \
      ,Bash(bin/rails generate:*) \
      ,Bash(bin/rails g:*) \
      ,Bash(bin/rails about:*) \
      ,Bash(bin/rails stats:*) \
      ,Bash(bin/rails notes:*) \
      ,Bash(bin/rails time:zones:*) \
      ,Bash(bin/rails middleware:*) \
      ,Bash(bin/rails log:*) \
      ,Bash(bin/rake routes:*) \
      ,Bash(bin/rake -T:*) \
      ,Bash(bin/rake --tasks:*) \
      ,Bash(bin/rake stats:*) \
      ,Bash(bin/rake notes:*) \
      ,Bash(bin/rake about:*) \
      ,Bash(bin/rspec:*) \
      ,Bash(bin/spring status) \
      ,Bash(bin/spring stop) \
      ,Bash(rspec:*) \
      ,Bash(ag:*) \
      ,Bash(rg:*) \
      ,Bash(npm run build:*) \
      ,Bash(npm install:*) \
      ,Bash(npm test:*) \
      ,Bash(npm run lint) \
      ,Bash(npm list:*) \
      ,Bash(npm ls:*) \
      ,Bash(grep:*) \
      ,Bash(lsof:*) \
      ,Bash(log:*) \
      ,Bash(log show:*) \
      ,Bash(git status:*) \
      ,Bash(git log:*) \
      ,Bash(git diff:*) \
      ,Bash(git branch:*) \
      ,Bash(git show:*) \
      ,Bash(git remote:*) \
      ,Bash(git ls-files:*) \
      ,Bash(git add:*) \
      ,Bash(cat:*) \
      ,Bash(ps:*) \
      ,Bash(awk:*) \
      ,Bash(echo:*) \
      ,Bash(date:*) \
      ,Bash(diff:*) \
      ,Bash(sort:*) \
      ,Bash(uniq:*) \
      ,Bash(jq:*) \
      ,Bash(defaults read:*) \
      ,Read(*) \
      ,Read(//Users/alex/.claude/**) \
      ,Read(//Users/alex/.dotfiles/**) \
      ,Read(//Users/alex/.dotfiles/**) \
      ,Read(//Users/alex/www) \
      ,Read(//Users/alex/work) \
      ,Read(//Users/alex/ai-notes) \
      ,Read(//Users/alex/humanics) \
      ,Read(/tmp/**) \
      ,WebFetch(domain:github.com) \
      ,WebSearch(*) \
      ,Bash(claude config get:*)"
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

# Wrapper that enables attention color alerts for any command. It just makes the
# whole tmux pane orange once Claude or any AI finishes running so my attention
# is caught.
#
# The program must have a hook that calls ~/bin/prompt-color-attention
# when it needs attention (and --disable when user resumes).
#
# Creates a temp file flag based on tmux pane ID so hooks can detect it.
#
# Usage: prompt-attention claude-new "my prompt"
#        prompt-attention rspec spec/
#
# Claude Code hook setup: see ai/claude-settings.json (symlinked to
# ~/.claude/settings.json). Documentation in ai/README.md.
function prompt-attention() {
  local pane_id=$(tmux display-message -p '#{pane_id}' | tr -d '%')
  local flag_file="/tmp/annoying-color-alert-$pane_id"
  touch "$flag_file"
  export ANNOYING_PANE_ID="$pane_id"
  trap "rm -f '$flag_file'" EXIT INT TERM
  "$@"
  local exit_code=$?
  rm -f "$flag_file"
  return $exit_code
}

# Make the screen orange everytime Claude finishes
function annoying-claude() {
  prompt-attention claude-new "$@"
}
