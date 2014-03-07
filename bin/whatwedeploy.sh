#!/usr/bin/env sh

git log origin/production..master --no-merges --pretty=format:%s |
  egrep -o "[0-9]{6,}" |
  xargs -n1 -I :story_id echo "https://www.pivotaltracker.com/story/show/:story_id"
