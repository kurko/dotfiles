function port_3000() {
  lsof -wni tcp:3000
}

# Kills whatever is running on port 3000
function kill_3000() {
  kill -9 $(lsof -i :3000 -t)
}

# The interface carrying the default route right now (en0 on Wi-Fi, en8/en10/
# en11 on the wired dongle). Measuring a hardcoded interface is the classic
# mistake: the idle one always looks perfect, because nothing is using it.
function default_network_interface() {
  route -n get default 2>/dev/null | awk '/interface: /{print $2}'
}

# Live network-path monitor (ping + traceroute combined, via trippy). For
# diagnosing packet loss / Zoom drops. Runs unprivileged (no sudo).
#
# Optional arg = interface to pin to; defaults to whichever one is actually
# carrying traffic, so this measures the transport you're really on.
#
# Reading it: hop 1 = your Deco, hop 2 = the box between it and the ISP. Loss
# only counts if it persists to the bottom row -- middle hops that show 100%
# are just routers deprioritising ICMP. Tab / arrows switch between targets.
function trippy-monitor() {
  local iface="${1:-$(default_network_interface)}"

  if [[ -z "$iface" ]]; then
    echo "trippy-monitor: no default route, nothing to measure." >&2
    return 1
  fi

  trip -u -I "$iface" google.com 1.1.1.1
}

# Is anything recording, and is anything stopping this Mac from sleeping?
#
# The second question is here because a collector once ran for 27 hours and
# the laptop was found hot, so "is something of mine still going?" is now a
# question worth being able to answer in one command.
function network-status() {
  local state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/network-logger"
  local log="$state_dir/trace.csv"
  local lock="$state_dir/collector.lock"

  # Check the command too, not just the PID. Once the system reuses a stale
  # PID this would otherwise report an unrelated process as the collector.
  local holder
  holder="$(cut -d' ' -f1 "$lock" 2>/dev/null)"

  if [[ "$holder" =~ ^[0-9]+$ ]] && kill -0 "$holder" 2>/dev/null &&
    ps -o args= -p "$holder" 2>/dev/null | grep -q network-logger; then
    echo "Collector: running (pid $holder)"
  else
    echo "Collector: not running"
  fi

  # A log with only a header is non-empty but has no measurement in it.
  local newest
  newest="$(tail -1 "$log" 2>/dev/null | cut -d, -f1)"

  if [[ "$newest" =~ ^[0-9]+$ ]]; then
    local age
    age=$(( $(date +%s) - newest ))
    echo "Newest measurement: ${age}s ago ($(du -h "$log" | cut -f1) log)"
  else
    echo "Newest measurement: none recorded"
  fi

  # ping and trippy never take a power assertion, so this should stay empty.
  # If it ever does not, that is worth seeing rather than guessing about.
  local blockers
  blockers="$(pmset -g assertions 2>/dev/null |
    grep -iE "PreventSystemSleep|PreventUserIdleSystemSleep" |
    grep -icE "network-logger|trip|ping")"

  if [[ "${blockers:-0}" -gt 0 ]]; then
    echo "Sleep: BLOCKED by a network tool (unexpected, worth investigating)"
  else
    echo "Sleep: not blocked by anything of ours"
  fi
}
