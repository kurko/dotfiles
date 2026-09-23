// A stand-in for Chrome as it behaved under load: it ignores SIGTERM, never exits, and starts a helper that
// ignores SIGTERM too and holds the same pipes, as Chrome's helper processes do. It records the flags it was given.
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { existsSync, readFileSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';

export const pause = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

export const writeStubbornChrome = (dir, ...lines) => {
  const chrome = path.join(dir, 'chrome');
  writeFileSync(`${chrome}-helper`, "#!/bin/sh\ntrap '' TERM\nwhile :; do sleep 1; done\n", { mode: 0o755 });
  writeFileSync(chrome, [
    '#!/bin/sh',
    "trap '' TERM",
    `printf '%s\\n' "$@" > "$0.args"`,
    '"$0-helper" &',
    ...lines,
    'while :; do sleep 1; done',
    '',
  ].join('\n'), { mode: 0o755 });
  return chrome;
};

const profileOf = (chrome) => readFileSync(`${chrome}.args`, 'utf8')
  .split('\n')
  .find((flag) => flag.startsWith('--user-data-dir='))
  ?.slice('--user-data-dir='.length);

// Without --user-data-dir, headless Chrome ran in the reader's own Chrome profile.
export const assertThrowawayProfile = (chrome) => {
  const profile = profileOf(chrome);
  assert.ok(profile?.startsWith(tmpdir()), `Chrome was launched with ${profile ? `--user-data-dir=${profile}` : 'no --user-data-dir'}`);
  assert.equal(existsSync(profile), false, `${profile} is still there after Chrome was stopped`);
};

const processesIn = (dir) => {
  try {
    return execFileSync('pgrep', ['-f', dir], { encoding: 'utf8' }).trim().split('\n');
  } catch {
    return [];
  }
};

// Killed processes take a moment to disappear from the process table.
export const processesLeftIn = async (dir, deadline = Date.now() + 2_000) => {
  const left = processesIn(dir);
  if (!left.length || Date.now() > deadline) return left;
  await pause(50);
  return processesLeftIn(dir, deadline);
};
