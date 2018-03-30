echo-command() {
  printf "${BLUE}• ${NO_COLOR}$1 ${BLUE}•${NO_COLOR}\n"
}

isFunction() { declare -F -- "$@" >/dev/null; }


strLen() {
    local bytlen sreal oLang=$LANG oLcAll=$LC_ALL
    LANG=C LC_ALL=C
    bytlen=${#1}
    printf -v sreal %q "$1"
    LANG=$oLang LC_ALL=$oLcAll
    printf "String '%s' is %d bytes, but %d chars len: %s.\n" "$1" $bytlen ${#1} "$sreal"
}

# join_array ('one two', 'three') ', '
#
# Avoid passing functions. If you have to use functions, make sure you escape
# the inputs so the function reference isn't passed in, e.g
#
#     DirInfo=(''"${js_info}"'')
#     DirInfoString=$(join_array DirInfo ', ')
#
function join_array() {
  local array_arg_name=$1[@]
  local array=("${!array_arg_name}")
  local delimiter=$2
  local result=""

  for ((i = 0; i < "${#array[@]}"; i++))
  do
    value="$(echo "${array[$i]}")"
    value="$(echo $(echo $value))"

    if [[ ! -z "${value/ /}" ]]; then
      if [ "$i" -gt 0 ]; then
        result="$result$delimiter$value"
      else
        result="$result$value"
      fi
    fi
  done
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

