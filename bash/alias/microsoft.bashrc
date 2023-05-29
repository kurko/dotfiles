# This autoupdater on MacOS is so annoying
function disable_microsoft_autoupdater() {
  sudo rm -rf /Library/Application\ Support/Microsoft/MAU/Microsoft\ AutoUpdate.app /Library/Application\ Support/Microsoft/MAU2.0/Microsoft\ AutoUpdate.app /Library/LaunchAgents/com.microsoft.update.agent.plist /Library/LaunchDaemons/com.microsoft.autoupdate.helper.plist /Library/LaunchDaemons/com.microsoft.autoupdate.helper.plist.lockfile /Library/Preferences/com.microsoft.autoupdate2.plist /Library/PrivilegedHelperTools/com.microsoft.autoupdate.helper*
}
