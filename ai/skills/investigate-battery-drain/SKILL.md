---
name: investigate-battery-drain
description: Investigate macOS battery drain and unexpected battery death using local power logs. Use when the user asks why their battery died, drained fast, or didn't last; whether the Mac actually slept (in a bag, overnight, lid closed); what apps ate the battery; or what kept the Mac awake. Activates for phrases like "battery died", "battery drained", "what's eating my battery", "did it sleep in my bag", "what kept my Mac awake", "why is my Mac hot on battery".
---

# Investigate Battery Drain (macOS)

Answer three questions with real numbers: (1) did the machine sleep when it
should have, (2) what consumed the energy, (3) was the death a crash or a
controlled low-battery hibernation. Everything needed is in local logs — no
third-party tools.

## Ground rules

- Big outputs: redirect to a temp file and grep it. `pmset -g log` is tens of
  thousands of lines and `log show` takes minutes; never dump either into
  context.
- Parallelize with subagents when available: one builds the sleep/wake
  timeline, another checks shutdown cause + battery health + diagnostic
  reports.
- Assertions show who *blocked sleep*; only energy data shows who *used
  energy*. Don't name a culprit from assertions alone — get the per-app
  numbers first (Step 5).

## Step 1 — Current state (fast)

- `pmset -g batt` — charge, source, charging rate.
- `pmset -g assertions` — who is preventing sleep right now. Common holders:
  `caffeinate` (on this setup usually spawned by Claude Code with `-t 300`,
  so it self-expires), Electron apps (`NoIdleSleepAssertion`), `coreaudiod`
  (an app is holding an audio stream open).
- `ps -axo pid,ppid,pcpu,cputime,etime,comm -r` — runaway check. A process
  whose accumulated `cputime` is a large fraction of its `etime` has been
  pegging a core for its whole life. For suspects, walk up parents with
  `ps -p <ppid> -o command` until you find who launched them.

## Step 2 — Timeline from pmset log

Dump `pmset -g log > <tmpfile>` and grep for `Entering Sleep`, `Wake`,
`DarkWake`, `Charge:`, and `Low Power Sleep`. Most entries embed the battery
percentage (`Using Batt (Charge:NN%)`), so the file yields a full
charge-over-time curve. Reconstruct per-period drain rates in %/h.

Reference rates for an Apple Silicon MacBook — compare each period against
these to decide what was normal:

| Pattern | Signature | Rate |
|---|---|---|
| Healthy lid-closed sleep | DarkWake every 15–17 min for ~2 s (`rtc/Maintenance`, `rtc/SleepService`) | 0.3–0.5%/h |
| Network wake storm | DarkWake every ~1 min lasting tens of seconds; `wifibt`, `SMC.OutboxNotEmpty`, `centauri`, `E_TKO_TCP_DATA` | 3–6%/h |
| Light active use | screen on, normal workload | 5–10%/h |
| Pegged core / heavy load | — | 20%+/h |

Wake storms are a *failure mode* of TCP-keepalive offload (normally the Wi-Fi
chip answers keepalives with the Mac fully asleep, at ~zero cost): a host
keeps pushing data or errors to an offloaded socket, waking the machine over
and over. Dead sockets of a zombie process can cause this — fix the process
before considering `pmset -a tcpkeepalive 0`.

`Entering Sleep state due to 'Low Power Sleep' ... (Charge:1%)` is a
controlled shutdown at empty — not a crash.

## Step 3 — Crash or hibernation?

- `sysctl kern.boottime` and `last reboot` — if the kernel never rebooted,
  nothing "shut down".
- `log show --last 3d --predicate 'eventMessage CONTAINS "Previous shutdown
  cause"' --style syslog > <tmpfile>` (slow). Codes: 5 = clean shutdown,
  0 = sudden power loss, negative = hardware/power/thermal (look up the
  specific code before interpreting).
- With `hibernatemode 3` (check `pmset -g`), a drained Mac writes a
  hibernation image and suspends instead of powering off, then resumes in
  place. No shutdown event + old boottime = it hibernated; the battery
  percentages were real.

## Step 4 — Battery health

`system_profiler SPPowerDataType` (cycle count, condition, maximum capacity)
and `ioreg -rn AppleSmartBattery` (raw mAh: AppleRawMaxCapacity vs
DesignCapacity). A healthy battery means the problem is consumption, not the
gauge — rule this out early so the investigation stays on software.

## Step 5 — Per-app energy attribution (powerlog)

macOS keeps ~2 days of per-app energy in a root-only sqlite DB. Ask the user
to run (or run with sudo if available):

    sudo cp /var/db/powerlog/Library/BatteryLife/CurrentPowerlog.PLSQL /tmp/powerlog.sqlite

Key table: `PLCoalitionAgent_EventInterval_CoalitionInterval` — one row per
app coalition per interval, with `energy` (nanojoules), `cpu_time` (s),
`byteswritten`, `platform_idle_wakeups`, `timestamp` (epoch). Rank a time
window (the `'utc'` modifier converts a local-time string to epoch):

    SELECT LaunchdName,
           ROUND(SUM(energy)/1e9,1)  AS joules,
           ROUND(SUM(cpu_time))      AS cpu_s,
           ROUND(SUM(byteswritten)/1e6) AS mb_written,
           ROUND(SUM(platform_idle_wakeups)) AS wakeups
    FROM PLCoalitionAgent_EventInterval_CoalitionInterval
    WHERE timestamp >= strftime('%s','YYYY-MM-DD HH:MM:SS','utc')
      AND timestamp <  strftime('%s','YYYY-MM-DD HH:MM:SS','utc')
    GROUP BY LaunchdName ORDER BY SUM(energy) DESC LIMIT 20;

Also useful: `PLBatteryAgent_EventBackward_Battery` (battery-level curve) and
`PLProcessMonitorAgent_EventInterval_ProcessMonitorInterval` + `_Dynamic`
(per-process CPU samples, joined via `FK_ID`).

**Coalition gotcha (the big one):** energy bills to the coalition of whoever
*launched* the process. Anything started from a terminal — including a
browser spawned by AI tooling — bills to the terminal app's coalition. If a
terminal or launcher tops the ranking with implausible numbers, the real
culprit is one of its descendants: find it with the `ps` runaway check from
Step 1.

Sanity math: coalition energy covers CPU/GPU only, typically 30–40% of total
drain (display, radios, and power rails are unattributed). Battery capacity
in Wh ≈ design mAh × 11.4 V (≈72 Wh for a 14" MacBook Pro, ≈100 Wh for a
16"). joules / 3600 = Wh; compare against (% dropped × capacity) to check the
attribution is plausible.

## Step 6 — Corroborating diagnostics

`/Library/Logs/DiagnosticReports` and `~/Library/Logs/DiagnosticReports`,
sorted by mtime: resource-exception `.diag` reports name processes that
exceeded CPU or disk-write limits, with the time window and how many samples
were on battery. GB-scale background writes from Electron apps are common
findings here — they matter for SSD wear complaints, but their *energy* cost
is usually negligible; say so explicitly instead of letting them take the
blame.

## Known culprit patterns

- **Orphaned automation browser**: a Chrome process whose command line
  contains `--user-data-dir=.../agent-browser-chrome-<uuid>` and
  `--headless=new` was launched by agent-browser (AI browser tooling) —
  never the user's real Chrome, which uses its default profile. These can
  outlive their session and peg a core for days. Fix: kill the
  `agent-browser` daemon and its Chrome. Prevention:
  `AGENT_BROWSER_IDLE_TIMEOUT_MS` (set in `bashrc_source`) makes the daemon
  reap itself after idling.
- **cloudd churn** after a long offline stretch is iCloud resync — transient,
  resolves on its own.
- **coreaudiod assertions held for hours** mean some app kept an audio
  stream open the whole time (call, tab with audio) — the machine can't
  idle-nap around it.

## Output

Report: the timeline with %/h per period; a verdict on whether it slept;
ranked energy attribution with real numbers (J → Wh → % of battery); whether
the death was a crash or hibernation; and the culprit with fix/prevention
options. Killing processes, disabling tcpkeepalive, or installing watchdogs
are the user's decisions — present options with tradeoffs, don't act on them
unprompted.
