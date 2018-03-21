echo-command() {
  printf "${BLUE}• ${NO_COLOR}$1 ${BLUE}•${NO_COLOR}\n"
}

isFunction() { declare -F -- "$@" >/dev/null; }

# join_array , a "b c" d #a,b c,d
# join_array / var local tmp #var/local/tmp
# join_array , "${FOO[@]}" #a,b,c
function join_array {
  local d=$1;
  shift;
  echo -n "$1";
  shift;
  result=$(printf "%s" "${@/#/$d} ");
  echo $result
}

# Finds out if a program is installed
function is_program_installed() {
  if which $1 > /dev/null ; then
    return 0
  else
    return 1
  fi
}


# Usage: file-exists ".zeus.sock"
#
#   if file-exists ".zeus.sock" ; then
#     echo "file exists"
#   else
#     echo "file doesn't exist"
#   fi
#
function file-exists() {
  if [ -e $1 ]; then
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

