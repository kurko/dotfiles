#!/bin/bash

alias fs="foreman start"
alias rs="be rails server"
alias rc="be rails console"
alias zc="zeus console"
alias zs="zeus server"
# Redirects port 80 on a Mac to 3000, allowing to run the server without root
alias railson80='sudo ipfw add 100 fwd 127.0.0.1,3000 tcp from any to any 80 in'
alias rails_reset="bin/rails db:drop db:create db:schema:load db:seed"

# Wrapper for `rbenv install`, but always runs this before each command:
#
#   git -C ~/.rbenv/plugins/ruby-build pull
function rbenv_install() {
  if [ -d ~/.rbenv/plugins/ruby-build ]; then
    echo "Updating ruby-build plugin..."
    git -C ~/.rbenv/plugins/ruby-build pull
  else
    echo "ruby-build plugin not found, skipping update."
  fi

  echo "Installing Ruby version..."
  rbenv install $*
  rbenv rehash
}

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

# DEPRECATED - we don't use zeus anymore
#
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
  # DEPRECATED - we don't use zeus anymore
  if file-exists ".zeus.sock" ; then
    echo-command "zeus rake db:migrate:status"
    zeus-and-retry "rake db:migrate:status"
  else
    echo-command "rake db:migrate:status"
    bundle exec rake db:migrate:status
  fi
}

function dbmigrate() {
  # DEPRECATED - we don't use zeus anymore
  if file-exists ".zeus.sock" ; then
    echo-command 'zeus rake db:migrate db:test:prepare'
    zeus-and-retry "rake db:migrate db:test:prepare"
  else
    echo-command "bin/rails db:migrate$1 && RAILS_ENV=test bin/rails db:migrate$1"
    bin/rails db:migrate$1 && \
      RAILS_ENV=test bin/rails db:migrate$1
  fi
}

function dbmigratedown() {
  version=$(ls db/migrate | fzf | awk -F _ '{print $1}')

  # DEPRECATED - we don't use zeus anymore
  if file-exists ".zeus.sock" ; then
    echo-command "zeus rake db:migrate:down VERSION=$version && zeus rake db:test:prepare"
    [[ -n "$version" ]] && zeus-and-retry "rake db:migrate:down VERSION=$version"
    zeus-and-retry "rake db:test:prepare"
  else
    echo-command "bin/rails db:migrate:down VERSION=$version && RAILS_ENV=test bin/rails db:migrate:down VERSION=$version"
    bin/rails db:migrate:down VERSION=$version && RAILS_ENV=test bin/rails db:migrate:down VERSION=$version
  fi
}

function dbrollback() {
  if file-exists ".zeus.sock" ; then
    echo-command 'zeus rake db:rollback db:test:prepare'
    zeus-and-retry "rake db:rollback db:test:prepare"
  else
    echo-command 'bin/rails db:rollback && RAILS_ENV=test bin/rails db:rollback'
    bin/rails db:rollback && RAILS_ENV=test bin/rails db:rollback
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

# Runs fzf so I can select a file to run tests, and then run the tests with
# xargs bundle exec rspec --format progress --color
#
# fzf will also only show files ending in _spec or _test
function tfzf(){
  selected_file=$(find spec -type f -name "*_spec.rb" | fzf)
  command="bundle exec rspec --format progress --color $selected_file"

  echo "Running: $command"
  # Add command to shell history
  if [ -n "$selected_file" ]; then
    echo "$command" >> ~/.bash_history  # For Bash
    history -s "$command"               # Works in Bash & Zsh
  fi
  eval "$command"
}

# Helper function to run rubocop with config file if it exists
function run_rubocop() {
  local rubocop_cmd="bundle exec rubocop"
  if [ -f "rubocop.yml" ]; then
    rubocop_cmd="$rubocop_cmd -c rubocop.yml"
  fi
  # Use --no-parallel for immediate progress output (parallel mode buffers all output)
  time $rubocop_cmd --no-parallel "$@"
}

function tcop(){
  t \
    && echo-command "\nRunning rubocop -A" \
    && run_rubocop -A \
    && echo "All good"
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

function changed_cop_t() {
  CHANGED=$(git_changed_files_versus_main)
  TESTS_FOR_CHANGED=$(rspec_changed_files)

  if [ -z "$CHANGED" ]; then
    echo "No changes found."
    return
  fi

  echo-command "Running rubocop -A on changed files"
  run_rubocop -A $CHANGED

  echo-command "bundle exec rspec $CHANGED"
  t $TESTS_FOR_CHANGED
}

function zt(){
  SPEC_PATH='spec/'
  if [ ! -z "$*" ]; then
    SPEC_PATH="$*"
  fi
  echo-command "[Zeus] Running all tests in $SPEC_PATH" && time zeus rspec $SPEC_PATH --format progress --color 2> >(grep -v CoreText 1>&2);
}

# test only failing tests
function tf(){
  SPEC_PATH='spec/'
  if [ ! -z "$*" ]; then
    SPEC_PATH="$*"
  fi
  echo-command "Running all tests in $SPEC_PATH with --only-failure" && time bundle exec rspec $SPEC_PATH --only-failure --color 3> >(grep -v CoreText 1>&2);
}
alias ztf="echo Running all tests with --only-failure && zeus rspec spec/ --only-failure --color 2> >(grep -v CoreText 1>&2);"

# test --fail-fast
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

# test & notify
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
