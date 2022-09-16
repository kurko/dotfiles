#!/bin/bash

alias fs="foreman start"
alias rs="be rails server"
alias rc="be rails console"
alias zc="zeus console"
alias zs="zeus server"
# Redirects port 80 on a Mac to 3000, allowing to run the server without root
alias railson80='sudo ipfw add 100 fwd 127.0.0.1,3000 tcp from any to any 80 in'

function ruby_server() { ruby -run -ehttpd . -p$1; }

# For some very rare occasions, we need to use a separate Gemfile that is not
# checked in git for running gems only locally. This is an alias for running
# bundler with that file. Usage:
#
#     local-bundle bundle exec rspec spec
#
# For more details, see https://github.com/gerrywastaken/Gemfile.local
function local-bundle() {
  BUNDLE_GEMFILE="Gemfile.local" $*
}

# Removes the redirection from port 80 to 3000
alias railsnoton80='sudo ipfw flush'
alias last_migration='vim $(ls db/migrate/* | tail -n1)'
alias deploystaging='echo "Running be cap staging deploy:migrations" && be cap staging deploy:migrations'
alias deployprod="echo \"Running be 'cap production deploy:migrations'\" && be cap production deploy:migrations"
alias pushdeployprod="echo \"git pushing & Running 'be cap production deploy:migrations'\" && gpush && be cap production deploy:migrations"

# Zeus fails with `Terminated: 15` for a year now and no one knows how to fix
# it, so this will check for success and run that again.
function zeus-and-retry() {
  if file-exists ".zeus.sock" ; then
    zeus $1
    if [ $? -eq 143 ] ; then
      echo "Exited with $?, retrying zeus with loop..."
      while zeus $1; [ $? -eq 143 ]; do : ; done
    fi
  fi
}

function dbmigratestatus() {
  if file-exists ".zeus.sock" ; then
    echo-command "zeus rake db:migrate:status"
    zeus-and-retry "rake db:migrate:status"
  else
    echo-command "rake db:migrate:status"
    bundle exec rake db:migrate:status
  fi
}

function dbmigrate() {
  if file-exists ".zeus.sock" ; then
    echo-command 'zeus rake db:migrate db:test:prepare'
    zeus-and-retry "rake db:migrate db:test:prepare"
  else
    echo-command 'rake db:migrate db:test:prepare'
    bundle exec rake db:migrate db:test:prepare
  fi
}

function dbmigratedown() {
  version=$(ls db/migrate | fzf | awk -F _ '{print $1}')
  if file-exists ".zeus.sock" ; then
    echo-command "zeus rake db:migrate:down VERSION=$version && zeus rake db:test:prepare"
    [[ -n "$version" ]] && zeus-and-retry "rake db:migrate:down VERSION=$version"
    zeus-and-retry "rake db:test:prepare"
  else
    echo-command "rake db:migrate:down VERSION=$version && rake db:test:prepare"
    bundle exec rake db:migrate:down VERSION=$version && bundle exec rake db:test:prepare
  fi
}

function dbrollback() {
  if file-exists ".zeus.sock" ; then
    echo-command 'zeus rake db:rollback db:test:prepare'
    zeus-and-retry "rake db:rollback db:test:prepare"
  else
    echo-command 'rake db:rollback db:test:prepare'
    bundle exec rake db:rollback db:test:prepare
  fi
}

#alias dbrollback='echo "Running be rake db:rollback && RAILS_ENV=test be rake db:rollback" && be rake db:rollback && RAILS_ENV=test be rake db:rollback'

function spn(){ time rspec $*; }
function be(){ time bundle exec $*; }
function t(){
  if file-exists "Gemfile" ; then
    SPEC_PATH='spec/'
    if [ ! -z "$*" ]; then
      SPEC_PATH="$*"
    fi
    echo-command "Running all tests in $SPEC_PATH"
    time bundle exec rspec $SPEC_PATH --format progress --color # 2> >(grep -v CoreText 1>&2);
  else
    echo "Don't know how to test."
  fi
}
function tchanged() {
  CHANGED=$(rspec_changed_files)
  if file-exists ".zeus.sock" ; then
    echo-command "zeus rspec $CHANGED"
    # [[ -n "$version" ]] &&
    zeus-and-retry "rspec $CHANGED"
  else
    echo-command "bundle exec rspec $CHANGED"
    bundle exec rspec $CHANGED
  fi
}
function zt(){
  SPEC_PATH='spec/'
  if [ ! -z "$*" ]; then
    SPEC_PATH="$*"
  fi
  echo-command "[Zeus] Running all tests in $SPEC_PATH" && time zeus rspec $SPEC_PATH --format progress --color 2> >(grep -v CoreText 1>&2);
}
function tf(){
  SPEC_PATH='spec/'
  if [ ! -z "$*" ]; then
    SPEC_PATH="$*"
  fi
  echo-command "Running all tests in $SPEC_PATH with --only-failure" && time bundle exec rspec $SPEC_PATH --only-failure --color 3> >(grep -v CoreText 1>&2);
}
alias ztf="echo Running all tests with --only-failure && zeus rspec spec/ --only-failure --color 2> >(grep -v CoreText 1>&2);"

function tff(){
  SPEC_PATH='spec/'
  if [ ! -z "$*" ]; then
    SPEC_PATH="$*"
  fi
  echo-command "Running all tests in $SPEC_PATH with --fail-fast" && time bundle exec rspec $SPEC_PATH --fail-fast --color 2> >(grep -v CoreText 1>&2);
}

function tsay(){
  echo-command 'Running all tests in spec/ and then shouting at you' && time bundle exec rspec spec/ $* --color && say 'SPECS ARE DONE! GET BACK HERE!';
}

function tn() {
  echo-command 'Running tests then notifying'
  time bundle exec rspec spec/ $* --color
  if [ $? == 0 ]; then
    mac_notify 'Specs are passing.'
  else
    mac_notify 'Some specs failed.'
  fi
}
# Zeus
  alias zst='rm -f .zeus.sock && zeus start'
  alias zsts='(tmux send-keys -t 8 "sleep 1 && zse" C-m &) && zst'
  alias zse='zeus server'
  alias zco='zeus console'
  function zra(){ zeus rake $*; }
  alias zro='zeus rake routes'
  alias zmi='zeus rake db:migrate db:test:prepare'
  alias zer='time zeus rspec spec/'
  function zrs(){ time zeus rspec $*; }
  alias zspl='time zeus rspec spec/lib/'
  alias zspc='time zeus rspec spec/controllers/'
  alias zspm='time zeus rspec spec/models/'
  alias zspa='time zeus rspec spec/acceptance/'
  alias zspr='time zeus rspec spec/request/'

# Spring gem
  alias sr='spring rake test'
  alias sse='spring rails server'
  alias sco='spring rails console'
  function sra(){ spring rake $*; }
  alias sro='spring rake routes'
  alias smi='spring rake db:migrate db:test:prepare'
  alias ser='time spring rspec spec/'
