#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmpdir="$(mktemp -d)"

cleanup() {
  rm -f "/tmp/annoying-color-alert-attention-test-$$"
  rm -rf "$tmpdir"
}
trap cleanup EXIT

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_file_contains_line() {
  local file="$1"
  local expected="$2"

  grep -Fx -- "$expected" "$file" >/dev/null ||
    fail "expected '$file' to contain: $expected"
}

assert_file_missing_line() {
  local file="$1"
  local unexpected="$2"

  [[ ! -f "$file" ]] && return 0

  if grep -Fx -- "$unexpected" "$file" >/dev/null; then
    fail "expected '$file' not to contain: $unexpected"
  fi
}

make_fake_command() {
  local name="$1"
  local body="$2"
  local path="$tmpdir/bin/$name"

  mkdir -p "$tmpdir/bin"
  printf '%s\n' '#!/usr/bin/env bash' "$body" > "$path"
  chmod +x "$path"
}

run_with_fake_tmux_env() {
  export TMUX="/tmp/tmux-test"
  export TMUX_PANE="%attention-test-$$"
  export TMUX_LOG="$tmpdir/tmux.log"
  export CODEX_LOG="$tmpdir/codex.log"
  export PATH="$tmpdir/bin:$repo_root/bin:$PATH"
}

test_disable_is_noop_without_active_alert() {
  : > "$tmpdir/tmux.log"
  rm -f "/tmp/annoying-color-alert-attention-test-$$"

  prompt-color-attention --disable

  assert_file_missing_line \
    "$tmpdir/tmux.log" \
    "select-pane -t %attention-test-$$ -P bg=default,fg=default"
}

test_force_disable_resets_without_active_alert() {
  : > "$tmpdir/tmux.log"
  rm -f "/tmp/annoying-color-alert-attention-test-$$"

  prompt-color-attention --force-disable

  assert_file_contains_line \
    "$tmpdir/tmux.log" \
    "select-pane -t %attention-test-$$ -P bg=default,fg=default"
  assert_file_contains_line "$tmpdir/tmux.log" "refresh-client"
}

test_with_prompt_attention_resets_before_cleanup() {
  : > "$tmpdir/tmux.log"
  rm -f "/tmp/annoying-color-alert-attention-test-$$"

  with_prompt_attention true

  assert_file_contains_line \
    "$tmpdir/tmux.log" \
    "select-pane -t %attention-test-$$ -P bg=default,fg=default"
  assert_file_contains_line "$tmpdir/tmux.log" "refresh-client"
}

test_with_prompt_attention_preserves_exit_status() {
  : > "$tmpdir/tmux.log"
  rm -f "/tmp/annoying-color-alert-attention-test-$$"

  set +e
  with_prompt_attention bash -c 'exit 37'
  local status="$?"
  set -e

  [[ "$status" -eq 37 ]] ||
    fail "expected with_prompt_attention to preserve exit 37, got $status"

  assert_file_contains_line \
    "$tmpdir/tmux.log" \
    "select-pane -t %attention-test-$$ -P bg=default,fg=default"
}

test_tmux_option_escape_uses_forced_disable() {
  assert_file_contains_line \
    "$repo_root/tmux/tmux.conf" \
    'bind-key -n M-Escape run-shell "prompt-color-attention --force-disable"'
}

test_annoying_codex_uses_codex_new() {
  assert_file_contains_line \
    "$repo_root/bash/alias/ai.bashrc" \
    '  with_prompt_attention codex-new "$@"'
}

test_codex_new_uses_expected_defaults() {
  : > "$tmpdir/codex.log"

  codex-new "write tests" >/dev/null

  assert_file_contains_line \
    "$tmpdir/codex.log" \
    "--sandbox workspace-write --ask-for-approval on-request write tests"
}

make_fake_command "tmux" 'printf "%s\n" "$*" >> "$TMUX_LOG"'
make_fake_command "codex" 'printf "%s\n" "$*" >> "$CODEX_LOG"'
run_with_fake_tmux_env

test_disable_is_noop_without_active_alert
test_force_disable_resets_without_active_alert
test_with_prompt_attention_resets_before_cleanup
test_with_prompt_attention_preserves_exit_status
test_tmux_option_escape_uses_forced_disable
test_annoying_codex_uses_codex_new
test_codex_new_uses_expected_defaults

echo "PASS: ai attention tests"
