isFunction() { declare -F -- "$@" >/dev/null; }

# Finds out if a program is installed
function is_program_installed() {
  if which $1 > /dev/null ; then
    return 0
  else
    return 1
  fi
}

# Find out if arguments were passed in.
#
#   if has-argument $1; then
#     do_something
#   else
#     do_something_else
#   fi
function has-argument() {
  if [[ -z $1 ]]; then
    return 1
  else
    return 0
  fi
}

