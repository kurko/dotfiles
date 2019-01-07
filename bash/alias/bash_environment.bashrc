function check_missing_binary() {
  if ! is_program_installed $1 ; then
    echo "$1 binary doesn't exist."
  fi
}
