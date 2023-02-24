#!/usr/bin/env sh

function git_repo_default_branch() {
  git symbolic-ref refs/remotes/origin/HEAD | sed 's@^refs/remotes/origin/@@' | tr -d '\n'
}
git log origin/production..$(git_repo_default_branch) --no-merges --pretty=format:%s |
  egrep -o "[0-9]{6,}" |
  xargs -n1 -I :story_id echo "https://www.pivotaltracker.com/story/show/:story_id"
