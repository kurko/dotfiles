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

assert_equals() {
  local expected="$1"
  local actual="$2"
  local message="$3"

  [[ "$expected" == "$actual" ]] ||
    fail "$message: expected '$expected', got '$actual'"
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  local message="$3"

  [[ "$haystack" == *"$needle"* ]] ||
    fail "$message: expected '$needle' in '$haystack'"
}

refute_contains() {
  local haystack="$1"
  local needle="$2"
  local message="$3"

  [[ "$haystack" != *"$needle"* ]] ||
    fail "$message: did not expect '$needle' in '$haystack'"
}

make_fake_command() {
  local name="$1"
  local body="$2"
  local path="$tmpdir/bin/$name"

  mkdir -p "$tmpdir/bin"
  printf '%s\n' '#!/usr/bin/env bash' "$body" > "$path"
  chmod +x "$path"
}

# A fake `ps` driven by a "pid ppid command" table, so the ancestry walk can be
# exercised without real sshd or mosh-server processes. Commands in the table
# are absolute paths, the way real `ps -o comm=` reports them. Any pid missing
# from the table is reported as a child of FAKE_PS_ROOT, which lets the test
# shell's own pid hang off the head of the fake chain.
install_fake_ps() {
  make_fake_command "ps" '
target=""
while [ $# -gt 0 ]; do
  case "$1" in
    -p) target="$2"; shift ;;
  esac
  shift
done

while read -r pid ppid comm; do
  if [ "$pid" = "$target" ]; then
    printf " %s %s\n" "$ppid" "$comm"
    exit 0
  fi
done < "$FAKE_PS_TABLE"

printf " %s %s\n" "$FAKE_PS_ROOT" "/bin/bash"
'
}

# Describes the process chain the prompt will walk. Lines are "pid ppid command".
given_process_ancestry() {
  install_fake_ps
  export FAKE_PS_ROOT="$1"
  shift
  export FAKE_PS_TABLE="$tmpdir/ps_table"
  printf '%s\n' "$@" > "$FAKE_PS_TABLE"
}

given_ps_is_unavailable() {
  make_fake_command "ps" 'exit 1'
}

given_machine_named() {
  make_fake_command "hostname" "echo '$1'"
}

given_hostname_fails() {
  make_fake_command "hostname" 'echo "hostname: lookup failed" >&2; exit 127'
}

given_attached_tmux_client() {
  export TMUX="/tmp/tmux-test"
  make_fake_command "tmux" "echo '$1'"
}

# A detached tmux session: `tmux display-message -p '#{client_pid}'` prints an
# empty line and exits 0.
given_tmux_with_no_attached_client() {
  export TMUX="/tmp/tmux-test"
  make_fake_command "tmux" 'echo ""'
}

# A tmux client that changes between calls, standing in for detaching and
# reattaching the session from somewhere else.
given_tmux_client_changes_to() {
  export TMUX="/tmp/tmux-test"
  export FAKE_TMUX_CALLS="$tmpdir/tmux_calls"
  rm -f "$FAKE_TMUX_CALLS"
  make_fake_command "tmux" "
calls=\$(cat \"\$FAKE_TMUX_CALLS\" 2>/dev/null || echo 0)
calls=\$((calls + 1))
echo \"\$calls\" > \"\$FAKE_TMUX_CALLS\"
if [ \"\$calls\" -eq 1 ]; then echo '$1'; else echo '$2'; fi
"
}

given_no_tmux() {
  unset TMUX
}

host_tag() {
  bash -c "source '$repo_root/bash/remote_session'
           __refresh_remote_host_tag
           printf '%s' \"\$__REMOTE_HOST_TAG\""
}

# The prompt string set_ps1 actually builds, with the remote tag forced on or
# off so the test pins composition rather than detection.
rendered_ps1() {
  local dir="$1"
  local forced_tag="$2"

  bash -c "export DOTFILES='$repo_root'
           cd '$dir'
           source \$DOTFILES/bash/prompt_config >/dev/null 2>&1
           __refresh_remote_host_tag() { __REMOTE_HOST_TAG='$forced_tag'; }
           set_ps1
           printf '%s' \"\$PS1\""
}

################################
# join_array
################################

join_dir_info() {
  bash -c "source '$repo_root/bash/alias/bash.bashrc' &&
           DirInfo=($1) &&
           join_array DirInfo ', '"
}

test_join_array_ignores_a_leading_empty_value() {
  assert_equals \
    "0d3c" \
    "$(join_dir_info "'' '' '0d3c' ''")" \
    "a missing ruby version should not leave a stray comma"
}

test_join_array_ignores_empty_values_between_filled_ones() {
  assert_equals \
    "3.4.1, 0d3c" \
    "$(join_dir_info "'3.4.1' '' '0d3c' ''")" \
    "empty slots should collapse instead of doubling the delimiter"
}

test_join_array_ignores_whitespace_only_values() {
  assert_equals \
    "0d3c" \
    "$(join_dir_info "'   ' '0d3c'")" \
    "a whitespace-only slot should count as empty"
}

test_join_array_joins_every_filled_value() {
  assert_equals \
    "3.4.1, Rails 7.1, 0d3c" \
    "$(join_dir_info "'3.4.1' 'Rails 7.1' '0d3c'")" \
    "all filled values should be joined by the delimiter"
}

test_join_array_returns_nothing_when_all_values_are_empty() {
  assert_equals \
    "" \
    "$(join_dir_info "'' '' ''")" \
    "an entirely empty array should produce an empty string"
}

################################
# remote session detection
################################

test_local_shell_is_not_tagged() {
  given_no_tmux
  given_machine_named "Alexs-MacBook-Pro-2"
  given_process_ancestry 90 "90 1 /usr/bin/login"

  assert_equals "" "$(host_tag)" "a local shell should keep the prompt untagged"
}

test_ssh_shell_is_tagged_with_the_machine_name() {
  given_no_tmux
  given_machine_named "Alexs-MacBook-Air"
  given_process_ancestry 90 "90 80 /usr/sbin/sshd-session" "80 1 /usr/sbin/sshd"

  assert_equals "[MBA]" "$(host_tag)" "an ssh session should be tagged"
}

test_mosh_shell_is_tagged_with_the_machine_name() {
  given_no_tmux
  given_machine_named "Alexs-MacBook-Air"
  given_process_ancestry 90 "90 1 /opt/homebrew/bin/mosh-server"

  assert_equals "[MBA]" "$(host_tag)" "a mosh session should be tagged"
}

test_tmux_pane_is_tagged_when_its_client_is_remote() {
  given_machine_named "Alexs-MacBook-Air"
  given_attached_tmux_client 500
  given_process_ancestry 90 \
    "500 400 /opt/homebrew/bin/mosh-server" \
    "90 1 /usr/bin/login"

  assert_equals \
    "[MBA]" \
    "$(host_tag)" \
    "inside tmux the attached client decides, not the pane's own ancestry"
}

test_tmux_pane_is_not_tagged_when_its_client_is_local() {
  given_machine_named "Alexs-MacBook-Pro-2"
  given_attached_tmux_client 500
  given_process_ancestry 90 \
    "500 1 /usr/bin/login" \
    "90 80 /opt/homebrew/bin/mosh-server"

  assert_equals \
    "" \
    "$(host_tag)" \
    "reattaching locally should drop the tag even if the pane was born remote"
}

test_tag_is_recomputed_when_the_tmux_client_changes() {
  given_machine_named "Alexs-MacBook-Air"
  given_tmux_client_changes_to 500 501
  given_process_ancestry 90 \
    "500 400 /opt/homebrew/bin/mosh-server" \
    "501 1 /usr/bin/login"

  local tags
  tags="$(bash -c "source '$repo_root/bash/remote_session'
                   __refresh_remote_host_tag
                   printf '%s,' \"\$__REMOTE_HOST_TAG\"
                   __refresh_remote_host_tag
                   printf '%s' \"\$__REMOTE_HOST_TAG\"")"

  assert_equals \
    "[MBA]," \
    "$tags" \
    "the cached tag must follow the attached client across a reattach"
}

test_detached_tmux_session_falls_back_to_the_shell_ancestry() {
  given_machine_named "Alexs-MacBook-Air"
  given_tmux_with_no_attached_client
  given_process_ancestry 90 "90 1 /opt/homebrew/bin/mosh-server"

  assert_equals \
    "[MBA]" \
    "$(host_tag)" \
    "an empty client pid should fall back to this shell, not break detection"
}

test_shell_is_not_tagged_when_ps_is_unavailable() {
  given_no_tmux
  given_machine_named "Alexs-MacBook-Air"
  given_process_ancestry 90 "90 1 /opt/homebrew/bin/mosh-server"
  given_ps_is_unavailable

  assert_equals "" "$(host_tag)" "a broken ps should leave the prompt untagged"
}

test_macbook_pro_abbreviates_to_mbp() {
  given_no_tmux
  given_machine_named "Alexs-MacBook-Pro-2"
  given_process_ancestry 90 "90 1 /opt/homebrew/bin/mosh-server"

  assert_equals "[MBP]" "$(host_tag)" "a MacBook Pro should abbreviate to MBP"
}

test_unrecognised_machine_keeps_its_short_hostname() {
  given_no_tmux
  given_machine_named "buildbox"
  given_process_ancestry 90 "90 1 /usr/sbin/sshd"

  assert_equals \
    "[buildbox]" \
    "$(host_tag)" \
    "a machine that is not a laptop should fall back to its hostname"
}

test_unknown_hostname_does_not_render_an_empty_tag() {
  given_no_tmux
  given_hostname_fails
  given_process_ancestry 90 "90 1 /usr/sbin/sshd"

  assert_equals \
    "[remote]" \
    "$(host_tag)" \
    "a failing hostname should not produce a bare '[]'"
}

test_ancestry_walk_gives_up_instead_of_looping() {
  given_no_tmux
  given_machine_named "Alexs-MacBook-Pro-2"
  given_process_ancestry 90 "90 91 /usr/bin/login" "91 90 /usr/bin/login"

  assert_equals "" "$(host_tag)" "a cyclic ancestry should terminate untagged"
}

################################
# prompt composition
################################

test_remote_tag_survives_alongside_dir_info() {
  local ps1 commit
  commit="$(git -C "$repo_root" rev-parse --short=2 HEAD)"
  ps1="$(rendered_ps1 "$repo_root" '[MBA]')"

  assert_contains "$ps1" '[MBA]' "the host tag must reach PS1 inside a git repo"
  assert_contains "$ps1" "($commit)" "the commit info must survive next to the tag"
  [[ "$ps1" == *'[MBA]'*"($commit)"* ]] ||
    fail "expected the tag before the dir info, got: $ps1"
}

test_remote_tag_renders_outside_a_git_repo() {
  local ps1
  ps1="$(rendered_ps1 "$tmpdir" '[MBA]')"

  assert_contains "$ps1" '[MBA]' "the host tag must reach PS1 outside a git repo"
}

test_local_prompt_is_unchanged() {
  local ps1 commit
  commit="$(git -C "$repo_root" rev-parse --short=2 HEAD)"
  ps1="$(rendered_ps1 "$repo_root" '')"

  assert_contains "$ps1" "($commit)" "a local prompt should still show dir info"
  refute_contains "$ps1" '[MBA]' "a local prompt should carry no host tag"
  refute_contains \
    "$ps1" \
    '  ' \
    "an absent tag should leave no gap where it would have been"
}

install_fake_ps
export PATH="$tmpdir/bin:$PATH"

test_join_array_ignores_a_leading_empty_value
test_join_array_ignores_empty_values_between_filled_ones
test_join_array_ignores_whitespace_only_values
test_join_array_joins_every_filled_value
test_join_array_returns_nothing_when_all_values_are_empty
test_local_shell_is_not_tagged
test_ssh_shell_is_tagged_with_the_machine_name
test_mosh_shell_is_tagged_with_the_machine_name
test_tmux_pane_is_tagged_when_its_client_is_remote
test_tmux_pane_is_not_tagged_when_its_client_is_local
test_tag_is_recomputed_when_the_tmux_client_changes
test_detached_tmux_session_falls_back_to_the_shell_ancestry
test_shell_is_not_tagged_when_ps_is_unavailable
test_macbook_pro_abbreviates_to_mbp
test_unrecognised_machine_keeps_its_short_hostname
test_unknown_hostname_does_not_render_an_empty_tag
test_ancestry_walk_gives_up_instead_of_looping
test_remote_tag_survives_alongside_dir_info
test_remote_tag_renders_outside_a_git_repo
test_local_prompt_is_unchanged

echo "PASS: prompt tests"
