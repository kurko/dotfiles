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

# Fake tmux: show-environment reports the plugin-manager variable as unset
# (exit 1), everything else is logged so tests can assert on the calls.
make_fake_tmux() {
  mkdir -p "$tmpdir/bin"
  cat > "$tmpdir/bin/tmux" <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == "show-environment" ]]; then
  exit 1
fi
printf "%s\n" "$*" >> "$TMUX_LOG"
EOF
  chmod +x "$tmpdir/bin/tmux"
}

# Conf mirrors the real one: commented example lines must be ignored.
make_conf() {
  cat > "$1" <<'EOF'
# Examples:
#   set -g @plugin 'github_username/plugin_name'
set -g @plugin 'tmux-plugins/tpm'           # Plugin manager
set -g @plugin 'tmux-plugins/plugin-a'
set -g @plugin "tmux-plugins/plugin-b"
EOF
}

# Fake tpm whose install_plugins records the call and reports one successful
# download, mimicking tpm's real output.
make_stub_tpm() {
  mkdir -p "$1/bin"
  cat > "$1/bin/install_plugins" <<'EOF'
#!/usr/bin/env bash
touch "$(dirname "$0")/../invoked"
echo 'Installing "plugin-a"'
echo '  "plugin-a" download success'
EOF
  chmod +x "$1/bin/install_plugins"
}

# Fake tpm whose download fails: tpm prints "Installing" before attempting the
# clone, and the failure goes to stderr.
make_failing_stub_tpm() {
  mkdir -p "$1/bin"
  cat > "$1/bin/install_plugins" <<'EOF'
#!/usr/bin/env bash
echo 'Installing "plugin-a"'
echo '  "plugin-a" download fail' >&2
EOF
  chmod +x "$1/bin/install_plugins"
}

run_script() {
  local dir="$1"

  TMUX_LOG="$dir/tmux.log" \
  PATH="$tmpdir/bin:$PATH" \
  TMUX_PLUGINS_DIR="$dir/plugins" \
  TMUX_CONF="$dir/tmux.conf" \
  TPM_REPO="${2:-unused}" \
    "$repo_root/bin/tmux-ensure-plugins" 2>/dev/null
}

test_noop_when_all_plugins_installed() {
  local dir="$tmpdir/noop"
  mkdir -p "$dir/plugins/plugin-a" "$dir/plugins/plugin-b"
  touch "$dir/plugins/plugin-a/x" "$dir/plugins/plugin-b/x"
  make_stub_tpm "$dir/plugins/tpm"
  make_conf "$dir/tmux.conf"

  local out
  out="$(run_script "$dir")" || fail "noop: nonzero exit"
  [[ -z "$out" ]] || fail "noop: expected no output, got: $out"
  [[ ! -f "$dir/plugins/tpm/invoked" ]] || fail "noop: install_plugins was invoked"
}

test_installs_plugin_with_absent_directory() {
  local dir="$tmpdir/absent"
  mkdir -p "$dir/plugins/plugin-a"
  touch "$dir/plugins/plugin-a/x"
  make_stub_tpm "$dir/plugins/tpm"
  make_conf "$dir/tmux.conf"

  local out
  out="$(run_script "$dir")" || fail "absent: nonzero exit"
  [[ -f "$dir/plugins/tpm/invoked" ]] || fail "absent: install_plugins not invoked"
  echo "$out" | grep -q "Installed 1 missing tmux plugin(s)" ||
    fail "absent: unexpected output: $out"
}

# install_plugins aborts when the TMUX_PLUGIN_MANAGER_PATH server variable is
# unset, and on a fresh machine's first boot nothing else has set it yet.
test_sets_plugin_manager_path_before_installing() {
  local dir="$tmpdir/env"
  mkdir -p "$dir/plugins/plugin-a"
  touch "$dir/plugins/plugin-a/x"
  make_stub_tpm "$dir/plugins/tpm"
  make_conf "$dir/tmux.conf"

  run_script "$dir" > /dev/null || fail "env: nonzero exit"
  grep -Fx "set-environment -g TMUX_PLUGIN_MANAGER_PATH $dir/plugins/" \
    "$dir/tmux.log" > /dev/null ||
    fail "env: TMUX_PLUGIN_MANAGER_PATH was not set before install_plugins"
}

test_treats_empty_plugin_directory_as_missing() {
  local dir="$tmpdir/empty"
  mkdir -p "$dir/plugins/plugin-a" "$dir/plugins/plugin-b"
  touch "$dir/plugins/plugin-a/x"
  make_stub_tpm "$dir/plugins/tpm"
  make_conf "$dir/tmux.conf"

  run_script "$dir" > /dev/null || fail "empty: nonzero exit"
  [[ -f "$dir/plugins/tpm/invoked" ]] || fail "empty: install_plugins not invoked"
}

test_bootstraps_tpm_when_missing() {
  local dir="$tmpdir/bootstrap"
  mkdir -p "$dir/plugins"
  make_conf "$dir/tmux.conf"
  make_stub_tpm "$dir/tpm-src"
  git -C "$dir/tpm-src" init -q
  git -C "$dir/tpm-src" add -A
  git -C "$dir/tpm-src" -c user.email=t@test -c user.name=t commit -qm fixture

  local out
  out="$(run_script "$dir" "$dir/tpm-src")" || fail "bootstrap: nonzero exit"
  [[ -x "$dir/plugins/tpm/bin/install_plugins" ]] || fail "bootstrap: tpm not cloned"
  echo "$out" | grep -q "Cloning tpm" || fail "bootstrap: no clone message: $out"
  echo "$out" | grep -q "Installed 1 missing tmux plugin(s)" ||
    fail "bootstrap: plugins not installed: $out"
}

# tpm prints "Installing" before attempting a download, so a failed download
# must not be announced as an install.
test_stays_silent_when_download_fails() {
  local dir="$tmpdir/offline"
  mkdir -p "$dir/plugins/plugin-a"
  touch "$dir/plugins/plugin-a/x"
  make_failing_stub_tpm "$dir/plugins/tpm"
  make_conf "$dir/tmux.conf"

  local out
  out="$(run_script "$dir")" || fail "offline: nonzero exit"
  [[ -z "$out" ]] || fail "offline: expected no output on failed download, got: $out"
}

# tpm derives plugin directories by stripping '#branch' first, then the path,
# then '.git'; the detection must agree or it re-runs install on every boot.
test_derives_names_like_tpm() {
  local dir="$tmpdir/names"
  mkdir -p "$dir/plugins/plugin-c" "$dir/plugins/plugin-d"
  touch "$dir/plugins/plugin-c/x" "$dir/plugins/plugin-d/x"
  make_stub_tpm "$dir/plugins/tpm"
  cat > "$dir/tmux.conf" <<'EOF'
set -g @plugin 'git://github.com/user/plugin-c.git'
set -g @plugin 'user/plugin-d#feature/foo'
EOF

  local out
  out="$(run_script "$dir")" || fail "names: nonzero exit"
  [[ -z "$out" ]] || fail "names: expected no-op, got: $out"
  [[ ! -f "$dir/plugins/tpm/invoked" ]] || fail "names: install_plugins was invoked"
}

make_fake_tmux

test_noop_when_all_plugins_installed
test_installs_plugin_with_absent_directory
test_sets_plugin_manager_path_before_installing
test_treats_empty_plugin_directory_as_missing
test_bootstraps_tpm_when_missing
test_stays_silent_when_download_fails
test_derives_names_like_tpm

echo "PASS: tmux ensure-plugins tests"
