# Git
alias git_update_submodules="git submodule init && git submodule update && git pull --recurse-submodules && git submodule update --init --recursive --remote --merge"

# creates pull request and opens it in the browser
function pr() { gpush -u && hub pull-request -o $*; }

function git_repo_default_branch() {
  git symbolic-ref refs/remotes/origin/HEAD \
  | sed 's@^refs/remotes/origin/@@' \
  | sed -e 's/\\n//'
}
alias master='git checkout master'
alias main='git checkout main'
alias dev='git checkout develop'
alias develop='git checkout develop'

# Shorten git to one letter, execute status by default if no subcommand is
# specified.
function g() {
  if [[ $# > 0 ]]; then
    git "$@"
  else
    git status
  fi
}

function mgpr() {
  echo "DEPRECATED: use git mp alias instead"
  git checkout "$(git_repo_default_branch)"
  git pull --rebase origin "$(git_repo_default_branch)"
}

alias gt='git tag --sort=creatordate'

# This will output something like:
# Sha1    Author initials   Date   Commit message
# 16b30fd <AO> 2015-10-01 Merge pull request #71 from kurko/transformations-update
# 8545fff <JC> 2015-09-30 Code review
# 8c9fbe8 <JC> 2015-09-29 Adds string case modification actions for transformations
#
# The commits that are Merge or Revert are made red.

alias glsimpler="git log --pretty=format:'%C(yellow)%h %C(black)%ad%Creset %s %C(blue)<%an> %Creset' --date=short --abbrev-commit --color=always"
alias gl="glsimpler | sed ''/Merge/s//`printf "\035[31mMerge\033[0m"`/'' | sed ''/Revert/s//`printf "\033[31mRevert\033[0m"`/'' | less -rX"

alias gamend='git commit --amend'
alias gamendc='git commit --amend --no-edit'
alias gdm="git diff $(git_repo_default_branch)"
alias gdd='git diff develop'
#alias gdelete_merged_branches='git branch --merged | grep -v "\*" | xargs -n 1 git branch -d'
alias gdelete_merged_branches="git checkout $(git_repo_default_branch); git branch --merged | egrep -v ^$(git_repo_default_branch)$ | sed 's/^[ *]*//' | sed 's/^/git branch -D /' | bash"
alias gshow_unmerged_branches='git branch --no-merged'

	# Commit pending changes and quote all args as message
	function gc(){ echo "Do you mean gco?"; }
	function gco(){
    if [ ! -z "$*" ]; then
      git commit -v -m "$*";
    else
      git commit -v;
    fi
  }
	function gch(){ git checkout $*; }

  function export_git_branch_variable() {
		export CURRENT_BRANCH=`git branch 2> /dev/null | grep -e ^* | sed -E  s/^\\\\\*\ \(.+\)$/\\\\\\1\\/`
  }

	function gfacepunch(){
		# Defines the current git branch
    export_git_branch_variable

		echo Face punching to origin $CURRENT_BRANCH...
		git push --force origin $CURRENT_BRANCH
	}

  function git_current_branch() {
    git branch 2> /dev/null | grep -e ^* | sed -e 's/^* \(.*\)/\1/'
  }

# Development
alias tdiff="git diff --name-only spec/**/*_spec.rb | xargs bin/rspec"

