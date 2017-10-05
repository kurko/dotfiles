# Git
alias git_update_submodules="git submodule init && git submodule update && git pull --recurse-submodules && git submodule update --init --recursive --remote --merge"

# creates pull request and opens it in the browser
alias pr='gpush && hub pull-request -o'

alias master='git checkout master'
alias dev='git checkout develop'
alias develop='git checkout develop'
alias mgpr='git checkout master && gpr'
alias dgpr='git checkout develop && gpr'
alias g='git status -sb'
alias gst='git status'
alias ga='git add . --all && git status'
alias gb='git branch'
alias gd='git diff --compaction-heuristic'
alias gdc='git diff --cached'
alias glog='git log'

# This will output something like:
# Sha1    Author initials   Date   Commit message
# 16b30fd <AO> 2015-10-01 Merge pull request #71 from kurko/transformations-update
# 8545fff <JC> 2015-09-30 Code review
# 8c9fbe8 <JC> 2015-09-29 Adds string case modification actions for transformations
#
# The commits that are Merge or Revert are made red.

alias gl="git log --pretty=format:'%C(yellow)%h %C(blue)<<%an>> %C(black)%ad%C(yellow)%d%Creset %s %Creset' --date=short --abbrev-commit | sed -e 's/<<\([A-Za-z]\).* \([A-Za-z]\).*>>/<\1\2>/' | sed ''/Merge/s//`printf "\033[31mMerge\033[0m"`/'' | sed ''/Revert/s//`printf "\033[31mRevert\033[0m"`/'' | less -rX"

alias gamend='git commit --amend'
alias gamendc='git commit --amend --no-edit'
alias gdm='git diff master'
alias gdd='git diff develop'
#alias gdelete_merged_branches='git branch --merged | grep -v "\*" | xargs -n 1 git branch -d'
alias gdelete_merged_branches="git checkout master; git branch --merged | egrep -v ^master$ | sed 's/^[ *]*//' | sed 's/^/git branch -D /' | bash"
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

  # rmr = Rebase Master Rebase
	function rmr(){
		# Defines the current git branch
		export CURRENT_BRANCH=`git branch 2> /dev/null | grep -e ^* | sed -E  s/^\\\\\*\ \(.+\)$/\\\\\\1\\/`

    echo Checking out master, rebasing and returning to $CURRENT_BRANCH...
		git checkout master
    git pull --rebase origin master
		git checkout $CURRENT_BRANCH
    git rebase master
	}

  # rmd = Rebase Develop Rebase
	function rdr(){
		# Defines the current git branch
		export CURRENT_BRANCH=`git branch 2> /dev/null | grep -e ^* | sed -E  s/^\\\\\*\ \(.+\)$/\\\\\\1\\/`

    echo 1. Checkout develop branch
    echo 2. Rebase: git pull --rebase origin develop
    echo 3. Checkout $CURRENT_BRANCH
    echo 4. Rebase on top of develop
		git checkout develop
    git pull --rebase origin develop
		git checkout $CURRENT_BRANCH
    git rebase master
	}

	function gfacepunch(){
		# Defines the current git branch
		export CURRENT_BRANCH=`git branch 2> /dev/null | grep -e ^* | sed -E  s/^\\\\\*\ \(.+\)$/\\\\\\1\\/`

		echo Face punching to origin $CURRENT_BRANCH...
		git push --force origin $CURRENT_BRANCH
	}

	function gpush(){
		# Defines the current git branch
		export CURRENT_BRANCH=`git branch 2> /dev/null | grep -e ^* | sed -E  s/^\\\\\*\ \(.+\)$/\\\\\\1\\/`

		echo Pushing to origin $CURRENT_BRANCH...
		git push origin $CURRENT_BRANCH
	}

	function gpr(){
		# Defines the current git branch
		export CURRENT_BRANCH=`git branch 2> /dev/null | grep -e ^* | sed -E  s/^\\\\\*\ \(.+\)$/\\\\\\1\\/`

		echo Pulling origin/$CURRENT_BRANCH, rebasing on it and fetching origin...
		git pull --rebase origin $CURRENT_BRANCH && git fetch origin
	}

	function gprs(){
		# Defines the current git branch
		export CURRENT_BRANCH=`git branch 2> /dev/null | grep -e ^* | sed -E  s/^\\\\\*\ \(.+\)$/\\\\\\1\\/`

		echo Pulling origin/$CURRENT_BRANCH, rebasing on it and fetching origin, then running git_update_submodules...
		git pull --rebase origin $CURRENT_BRANCH && git fetch origin && git_update_submodules
	}

	function gpul(){
		# Defines the current git branch
		export CURRENT_BRANCH=`git branch 2> /dev/null | grep -e ^* | sed -E  s/^\\\\\*\ \(.+\)$/\\\\\\1\\/`

		echo Pulling from origin $CURRENT_BRANCH...
		git pull origin $CURRENT_BRANCH
	}

	alias gpull=gpul

# Development
alias tdiff="git diff --name-only spec/**/*_spec.rb | xargs bin/rspec"

