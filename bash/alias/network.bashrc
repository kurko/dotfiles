function port_3000() {
  lsof -wni tcp:3000
}

# Kills whatever is running on port 3000
function kill_3000() {
  kill -9 $(lsof -i :3000 -t)
}

# Live network-path monitor (ping + traceroute combined, via trippy). For
# diagnosing packet loss / Zoom drops. Runs unprivileged (no sudo).
#
# Optional arg = interface to pin to, so you KNOW which transport you're
# measuring: default en0 (Wi-Fi); pass en8/en10/en11 when on the wired dongle.
#
# Reading it: hop 1 = your Deco, hop 2 = ISP router. Loss only counts if it
# persists to the bottom row. Tab / arrows switch between targets.
function trippy-monitor() {
  local iface="${1:-en0}"
  trip -u -I "$iface" google.com 1.1.1.1
}
