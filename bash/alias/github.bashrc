#!/bin/bash

function gist_create() {
  stdin=$(cat)

  # only runs this if gist is installed
  is_program_installed gist
  result=$?
  IFS=''
  if [[ $result == 0 ]] ; then
    echo "$stdin" | gist -p -o -f $*
  else
    echo "Fail: gist is not installed"
  fi
}
