#!/bin/bash

alias fs="foreman start"
alias rs="be rails server"
alias rc="be rails console"
alias zc="zeus console"
alias zs="zeus server"
alias zt="zeus rspec spec/"
# Redirects port 80 on a Mac to 3000, allowing to run the server without root
alias railson80='sudo ipfw add 100 fwd 127.0.0.1,3000 tcp from any to any 80 in'

# Removes the redirection from port 80 to 3000
alias railsnoton80='sudo ipfw flush'
alias last_migration='vim $(ls db/migrate/* | tail -n1)'
alias dbmigrate='echo "Running rake db:migrate db:test:prepare" && be rake db:migrate db:test:prepare'
alias dbrollback='echo "Running rake db:rollback db:test:prepare" && be rake db:rollback db:test:prepare'
alias dbmigratestatus='echo "Running rake db:migrate:status" && be rake db:migrate:status'
alias deploystaging='echo "Running be cap staging deploy:migrations" && be cap staging deploy:migrations'
alias deployprod="echo \"Running be 'cap production deploy:migrations'\" && be cap production deploy:migrations"
alias pushdeployprod="echo \"git pushing & Running 'be cap production deploy:migrations'\" && gpush && be cap production deploy:migrations"

function spn(){ time rspec $*; }
function be(){ time bundle exec $*; }
function t(){
  SPEC_PATH='spec/'
  if [ ! -z "$*" ]; then
    SPEC_PATH="$*"
  fi
  echo "Running all tests in $SPEC_PATH" && time bundle exec rspec $SPEC_PATH --color 2> >(grep -v CoreText 1>&2);
}
function tf(){
  SPEC_PATH='spec/'
  if [ ! -z "$*" ]; then
    SPEC_PATH="$*"
  fi
  echo "Running all tests in $SPEC_PATH and failing-fast" && time bundle exec rspec $SPEC_PATH --fail-fast --color 2> >(grep -v CoreText 1>&2);
}
function tsay(){
  echo 'Running all tests in spec/ and then shouting at you' && time bundle exec rspec spec/ $* --color && say 'SPECS ARE DONE! GET BACK HERE!';
}

function tn() {
  echo 'Running tests then notifying'
  time bundle exec rspec spec/ $* --color
  if [ $? == 0 ]; then
    mac_notify 'Specs are passing.'
  else
    mac_notify 'Some specs failed.'
  fi
}
# Zeus
  alias zst='zeus start'
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
