# Access services like chat over SSH without needing to pay for Wi-Fi, as DNS
# requests are typically free and not subject to the same restrictions as other
# internet traffic
function chat_in_airplane_via_dns() {
  if [[ -z "$1" ]]; then
    echo "Usage: chat_in_airplane <message>"
    return 1
  fi

  local message="$1"
  dig @ch.at "$message" TXT +short
}

# Mostly so I can remember the URL
function chat_in_airplane_via_ssh() {
  ssh ch.at
}
