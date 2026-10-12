#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmpdir="$(mktemp -d)"

cleanup() {
  rm -rf "$tmpdir"
}
trap cleanup EXIT

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

# Sourcing install would run the whole installer, so only the checklist
# function is loaded from it.
checklist_function="$(sed -n '/^print_post_install_checklist() {$/,/^}$/p' "$repo_root/install")"
[[ -n "$checklist_function" ]] ||
  fail "could not find print_post_install_checklist in install"

# Fake scutil: answers `--get LocalHostName` with FAKE_LOCAL_HOSTNAME and logs
# every call, so tests can assert the checklist only ever reads the name. An
# empty FAKE_LOCAL_HOSTNAME fails the way the real scutil does for a key that
# is not set: message on stderr, nothing on stdout, exit 1.
make_fake_scutil() {
  mkdir -p "$tmpdir/bin"
  cat > "$tmpdir/bin/scutil" <<'EOF'
#!/usr/bin/env bash
printf "%s\n" "$*" >> "$SCUTIL_LOG"
if [[ "$*" == "--get LocalHostName" ]]; then
  if [[ -z "$FAKE_LOCAL_HOSTNAME" ]]; then
    echo "LocalHostName: not set" >&2
    exit 1
  fi
  echo "$FAKE_LOCAL_HOSTNAME"
  exit 0
fi
exit 1
EOF
  chmod +x "$tmpdir/bin/scutil"
}

# PATH leaves out /usr/sbin and Homebrew, so the real scutil, gh, nodenv and
# rbenv are never reached.
run_checklist() {
  local os="$1"
  local network_name="$2"

  : > "$tmpdir/scutil.log"
  (
    eval "$checklist_function"
    OSTYPE="$os"
    PATH="$tmpdir/bin:/usr/bin:/bin"
    export SCUTIL_LOG="$tmpdir/scutil.log"
    export FAKE_LOCAL_HOSTNAME="$network_name"
    print_post_install_checklist
  )
}

assert_scutil_never_set() {
  ! grep -q -- "--set" "$tmpdir/scutil.log" ||
    fail "checklist called scutil --set: $(cat "$tmpdir/scutil.log")"
}

test_shows_rename_step_while_name_is_apple_default() {
  local name out
  for name in Alexs-MacBook-Air Alexs-MacBook-Pro Alexs-iMac Alexs-Mac-mini \
              Alexs-Mac-Studio Alexs-Mac-Pro Alexs-MacBook-Air-2; do
    out="$(run_checklist darwin "$name")" || fail "$name: nonzero exit"
    echo "$out" | grep -qF "sudo scutil --set LocalHostName <name>" ||
      fail "$name: rename step missing from: $out"
    echo "$out" | grep -qF "$name.local" ||
      fail "$name: current name missing from: $out"
    assert_scutil_never_set
  done
}

test_hides_rename_step_once_name_is_chosen() {
  local out
  out="$(run_checklist darwin mba)" || fail "chosen: nonzero exit"
  ! echo "$out" | grep -q "scutil" ||
    fail "chosen: rename step shown for a chosen name: $out"
  assert_scutil_never_set
}

# stderr is captured too, so a leaked "not set" message fails the test.
test_hides_rename_step_when_name_cannot_be_read() {
  local out
  out="$(run_checklist darwin "" 2>&1)" || fail "unreadable: nonzero exit"
  ! echo "$out" | grep -q "scutil\|not set" ||
    fail "unreadable: rename step or scutil error shown: $out"
  assert_scutil_never_set
}

test_skips_rename_step_off_macos() {
  local out
  out="$(run_checklist linux-gnu Alexs-MacBook-Air)" || fail "linux: nonzero exit"
  ! echo "$out" | grep -q "scutil" ||
    fail "linux: rename step shown off macOS: $out"
  [[ ! -s "$tmpdir/scutil.log" ]] || fail "linux: scutil was called"
}

make_fake_scutil

test_shows_rename_step_while_name_is_apple_default
test_hides_rename_step_once_name_is_chosen
test_hides_rename_step_when_name_cannot_be_read
test_skips_rename_step_off_macos

echo "PASS: post-install checklist tests"
