if [[ "$OSTYPE" == "darwin"* ]]; then
  alias sleepless="pmset -g assertions | egrep '(PreventUserIdleSystemSleep|PreventUserIdleDisplaySleep)'"

  function iterm_command_done() {
    osascript -e 'display notification "Check the terminal" with title "Terminal attention required"'
  }

  alias set_ttl65="sudo sysctl -w net.inet.ip.ttl=65"

  function textexp() {
    /usr/libexec/PlistBuddy -c 'Print :NSUserDictionaryReplacementItems' \
      ~/Library/Preferences/.GlobalPreferences.plist |
      awk -F'= ' '/replace =/{r=$2} /with =/{w=$2; sub(/;$/, "", w); gsub(/"/,"",r); gsub(/"/,"",w); print r "\t→\t" w}' |
      sort -f
  }
fi

