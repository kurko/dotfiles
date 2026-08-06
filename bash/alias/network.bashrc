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

# Roughly 15 seconds of evidence about the current network path.
function _network_evidence() {
  local iface="$1"
  local gateway="$2"

  echo "Interface: $iface"
  echo "Gateway: ${gateway:-unknown}"

  # Only ping a real address. When a VPN holds the default route, macOS reports
  # an interface name here, and ping would error straight into the report.
  if [[ "$gateway" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    # One throwaway ping first. The opening packets to the gateway often time
    # out while ARP resolves, which reads as ~15% loss that isn't real.
    ping -c 1 -t 2 "$gateway" >/dev/null 2>&1

    echo
    echo "Ping gateway:"
    ping -c 10 -i 0.5 -t 6 "$gateway" 2>&1 | tail -3
  fi

  echo
  echo "Per-hop trace (only loss reaching the last hop is real):"

  # Say so loudly when there's no trace. Silence here reads as "traced fine,
  # found nothing", and a confident verdict built on no data is worse than
  # an error -- especially when you're skimming this between meetings.
  local trip_errors="${TMPDIR:-/tmp}/network-triage-trip.err"

  if ! command -v trip >/dev/null 2>&1; then
    echo "UNAVAILABLE: trip is not installed (brew install trippy)."
  elif ! trip -u -I "$iface" -m csv --report-cycles 8 1.1.1.1 2>"$trip_errors"; then
    echo "UNAVAILABLE: the trace failed: $(tail -1 "$trip_errors")"
  fi
}

# Ask Claude what is wrong with the network right now, in three lines.
#
# Built for use mid-meeting: it gathers evidence, then asks for the guilty hop
# and one action. The answer uses ASD-STE100 Simplified Technical English, so
# it stays fast to read when you have no attention to spare.
#
# Optional arg = interface to pin to; defaults to the live default route.
function network-triage() {
  # Check this before spending 30 seconds on evidence we could not use.
  if ! command -v claude >/dev/null 2>&1; then
    echo "network-triage: claude is not on PATH." >&2
    return 1
  fi

  # One lookup, so the interface and the gateway always describe the same
  # route. Two lookups can straddle a Wi-Fi/wired handover, which is exactly
  # the moment you most want a trustworthy report.
  local route_info
  route_info="$(route -n get default 2>/dev/null)"

  local iface="${1:-$(awk '/interface: /{print $2}' <<<"$route_info")}"
  local gateway
  gateway="$(awk '/gateway: /{print $2}' <<<"$route_info")"

  if [[ -z "$iface" ]]; then
    echo "network-triage: no default route, nothing to measure." >&2
    return 1
  fi

  # Private context wins, so anything you'd rather not publish can live
  # outside this repo. The committed doc is the fallback.
  local context_doc="${AI_PRIVATE_CONFIG_DIR:+$AI_PRIVATE_CONFIG_DIR/NETWORK.md}"
  [[ -f "$context_doc" ]] || context_doc="$HOME/.dotfiles/docs/NETWORK.md"

  local evidence
  echo "Collecting about 15 seconds of evidence on $iface..." >&2
  evidence="$(_network_evidence "$iface" "$gateway")"
  echo "Asking Claude..." >&2

  {
    echo "You triage a live network fault. Reply in exactly this format:"
    echo
    echo "VERDICT: <what is wrong>"
    echo "BLAME: <the device or hop at fault>"
    echo "DO: <one action to try now>"
    echo
    echo "Rules:"
    echo "- Write in ASD-STE100 Simplified Technical English."
    echo "- Use the active voice and the present tense."
    echo "- Write a maximum of 20 words in each sentence."
    echo "- Give three lines only. No preamble, markdown, or notes."
    echo "- Use plain text. Do not use backticks."
    echo "- Ignore loss at every hop but the last one. Routers, including"
    echo "  hop 1, give a low priority to ICMP. Only loss that continues to"
    echo "  the last hop is real."
    echo "- Trust the gateway ping more than hop 1 of the trace."
    echo "- If the trace says UNAVAILABLE, say this. Do not guess the cause."
    echo "- The action must take less than 60 seconds."
    echo "- Do not tell the user to install software."
    echo "- If you find no fault, write: VERDICT: No fault found."

    if [[ -f "$context_doc" ]]; then
      echo
      echo "Network context:"
      cat "$context_doc"
    fi

    echo
    echo "Evidence:"
    echo "$evidence"
  } | claude -p
}
