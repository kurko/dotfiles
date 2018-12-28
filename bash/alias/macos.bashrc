if [[ "$OSTYPE" == "darwin"* ]]; then
  alias sleepless="pmset -g assertions | egrep '(PreventUserIdleSystemSleep|PreventUserIdleDisplaySleep)'"

  function iterm_command_done() {
    osascript -e 'display notification "Check the terminal" with title "Terminal attention required"'
  }
fi
