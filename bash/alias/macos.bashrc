if [[ "$OSTYPE" == "darwin"* ]]; then
  alias sleepless="pmset -g assertions | egrep '(PreventUserIdleSystemSleep|PreventUserIdleDisplaySleep)'"
fi
