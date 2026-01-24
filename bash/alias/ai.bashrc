# Disclaimer: the llm() function lives in llm.bashrc

# This file contains aliases and functions for managing AI worktrees and tasks.
#
# The git-* ones are auxiliary functions to manage git worktrees. You should
# look into claude-new-worktree as entrypoint.
#
# claude-new and with_prompt_attention are bin scripts (not functions) so
# changes take effect immediately without reloading shells.

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
  local yes_flag=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -y|--yes)
        yes_flag=true
        shift
        ;;
      *)
        echo "Error: Unknown option: $1"
        echo "Usage: git-worktree-clean [-y|--yes]"
        return 1
        ;;
    esac
  done

  if [[ "$yes_flag" != true ]]; then
    echo "WARNING: This will remove ALL worktrees (except main)."
    echo "Use -y or --yes to confirm."
    return 1
  fi

  git worktree list --porcelain |
    grep -B2 "branch refs/heads/" |
    grep "worktree" |
    cut -d' ' -f2 |
    xargs -I {} git worktree remove {}
}

function git-worktree-list() {
  # Pretty-print active worktrees with task names
  echo "Active worktrees:"
  echo ""
  git worktree list | while read -r line; do
    local path branch
    path=$(echo "$line" | awk '{print $1}')
    branch=$(echo "$line" | grep -o '\[.*\]' | tr -d '[]')

    if [[ -z "$branch" ]]; then
      echo "  $path (bare)"
    else
      # Extract task name from branch (worktree-task-xxx -> task-xxx)
      local task_name
      task_name=$(echo "$branch" | sed 's/^worktree-//')
      echo "  $task_name -> $path [$branch]"
    fi
  done
}

function git-worktree-switch() {
  if [[ -z "$1" ]]; then
    echo "Error: Task name required"
    echo "Usage: git-worktree-switch <task-name>"
    echo ""
    echo "Available worktrees:"
    git-worktree-list
    return 1
  fi

  if git-worktree-exists "$1"; then
    if [[ -d "../worktrees/$1" ]]; then
      cd "../worktrees/$1" || { echo "Error: Failed to cd to worktree"; return 1; }
    elif [[ -d "../../worktrees/$1" ]]; then
      cd "../../worktrees/$1" || { echo "Error: Failed to cd to worktree"; return 1; }
    else
      echo "Error: Worktree directory not found (are you deep in a subdirectory?)"
      return 1
    fi
    echo "Switched to worktree: $1"
  else
    echo "Error: Worktree '$1' does not exist"
    echo ""
    echo "Available worktrees:"
    git-worktree-list
    return 1
  fi
}

function git-worktree-remove() {
  local yes_flag=false
  local task_name=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -y|--yes)
        yes_flag=true
        shift
        ;;
      *)
        if [[ -z "$task_name" ]]; then
          task_name="$1"
        else
          echo "Error: Unexpected argument: $1"
          return 1
        fi
        shift
        ;;
    esac
  done

  if [[ -z "$task_name" ]]; then
    echo "Error: Task name required"
    echo "Usage: git-worktree-remove [-y|--yes] <task-name>"
    return 1
  fi

  if ! git-worktree-exists "$task_name"; then
    echo "Error: Worktree '$task_name' does not exist"
    return 1
  fi

  if [[ "$yes_flag" != true ]]; then
    echo "This will remove worktree '$task_name' and delete branch 'worktree-$task_name'"
    read -p "Are you sure? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      echo "Cancelled."
      return 0
    fi
  fi

  local worktree_path
  if [[ -d "../worktrees/$task_name" ]]; then
    worktree_path="../worktrees/$task_name"
  else
    worktree_path="../../worktrees/$task_name"
  fi

  if ! git worktree remove "$worktree_path"; then
    echo "Error: Failed to remove worktree. It may have uncommitted changes."
    echo "Use 'git worktree remove --force $worktree_path' to force removal."
    return 1
  fi

  if ! git branch -D "worktree-$task_name" 2>/dev/null; then
    echo "Note: Branch 'worktree-$task_name' was already deleted or doesn't exist."
  fi
  echo "Removed worktree: $task_name"
}

function git-worktree-done() {
  local merge_flag=true
  local yes_flag=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --no-merge)
        merge_flag=false
        shift
        ;;
      -y|--yes)
        yes_flag=true
        shift
        ;;
      *)
        echo "Error: Unknown option: $1"
        echo "Usage: git-worktree-done [--no-merge] [-y|--yes]"
        return 1
        ;;
    esac
  done

  # Verify we're in a git worktree (not the main repo)
  local git_common_dir
  git_common_dir=$(git rev-parse --git-common-dir 2>/dev/null)

  if [[ -z "$git_common_dir" ]]; then
    echo "Error: Not in a git repository"
    return 1
  fi

  local git_dir
  git_dir=$(git rev-parse --git-dir 2>/dev/null)

  # If git-dir equals git-common-dir, we're in the main repo, not a worktree
  if [[ "$git_dir" == "$git_common_dir" ]]; then
    echo "Error: Not in a worktree (you're in the main repo)"
    return 1
  fi

  # Get the main repo path from git-common-dir (strip /.git)
  local main_repo_path
  main_repo_path=$(dirname "$git_common_dir")

  # Get current worktree path and extract task name
  local worktree_path
  worktree_path=$(pwd)
  local task_name
  task_name=$(basename "$worktree_path")

  # Get current branch name
  local branch_name
  branch_name=$(git branch --show-current)

  # Confirm action
  if [[ "$yes_flag" != true ]]; then
    echo "This will:"
    echo "  1. Return to main repo: $main_repo_path"
    if [[ "$merge_flag" == true ]]; then
      echo "  2. Merge branch '$branch_name' into default branch"
    fi
    echo "  3. Remove worktree: $task_name"
    echo "  4. Delete branch: $branch_name"
    echo ""
    read -p "Continue? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      echo "Cancelled."
      return 0
    fi
  fi

  # Go to main repo
  cd "$main_repo_path" || return 1

  # Checkout default branch
  local default_branch
  default_branch=$(git_repo_default_branch)
  git checkout "$default_branch"

  # Optionally merge
  if [[ "$merge_flag" == true ]]; then
    echo "Merging $branch_name into $default_branch..."
    if ! git merge "$branch_name"; then
      echo "Error: Merge failed. Resolve conflicts and run:"
      echo "  git worktree remove $worktree_path"
      echo "  git branch -d $branch_name"
      return 1
    fi
  fi

  # Remove worktree (use absolute path since we've cd'd)
  git worktree remove "$worktree_path"

  # Delete branch
  if [[ "$merge_flag" == true ]]; then
    git branch -d "$branch_name"
  else
    git branch -D "$branch_name"
  fi

  echo "Done! Worktree '$task_name' completed and cleaned up."
}

# Make the screen orange everytime Claude finishes
function annoying-claude() {
  with_prompt_attention claude-new "$@"
}
