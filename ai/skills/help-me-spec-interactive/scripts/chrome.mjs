// Headless Chrome over the DevTools protocol on a pipe, for checks that click and type like a reader.
import { spawn } from 'node:child_process';
import { existsSync, mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';

const CHROME_CANDIDATES = [
  process.env.CHROME_BIN,
  '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
  '/Applications/Chromium.app/Contents/MacOS/Chromium',
  '/usr/bin/google-chrome',
  '/usr/bin/chromium',
];
const COMMAND_TIMEOUT_MS = 30_000;
const CLOSE_TIMEOUT_MS = 3_000;
const DUMP_TIMEOUT_MS = 60_000;
const NAMED_KEYS = {
  Escape: { code: 'Escape', keyCode: 27 },
  Tab: { code: 'Tab', keyCode: 9 },
  ArrowDown: { code: 'ArrowDown', keyCode: 40 },
};

export const findChrome = () => CHROME_CANDIDATES.find((candidate) => candidate && existsSync(candidate));

const settlesWithin = (promise, ms) => new Promise((resolve) => {
  const timer = setTimeout(() => resolve(false), ms);
  const settled = () => {
    clearTimeout(timer);
    resolve(true);
  };
  promise.then(settled, settled);
});

// Messages on the pipe are JSON, each ended by a NUL byte.
const connect = (toChrome, fromChrome, exited) => {
  const pending = new Map();
  let nextId = 1;
  let buffer = '';
  const settle = (id, outcome) => {
    const waiting = pending.get(id);
    pending.delete(id);
    waiting?.(outcome);
  };
  fromChrome.setEncoding('utf8');
  fromChrome.on('data', (chunk) => {
    const messages = (buffer + chunk).split('\0');
    buffer = messages.pop();
    messages.map((text) => JSON.parse(text)).filter((message) => message.id).forEach((message) => settle(message.id, message));
  });
  let gone = false;
  toChrome.on('error', () => {});
  exited.then(() => {
    gone = true;
    [...pending.keys()].forEach((id) => settle(id, { error: { message: 'Chrome exited' } }));
  });
  return (method, params = {}, sessionId) => new Promise((resolve, reject) => {
    if (gone) {
      reject(new Error('Chrome exited'));
      return;
    }
    const id = nextId++;
    const timer = setTimeout(() => settle(id, { error: { message: `Chrome did not answer ${method} within ${COMMAND_TIMEOUT_MS / 1000} s` } }), COMMAND_TIMEOUT_MS);
    pending.set(id, ({ result, error }) => {
      clearTimeout(timer);
      if (error) reject(new Error(error.message));
      else resolve(result);
    });
    toChrome.write(`${JSON.stringify({ id, method, params, sessionId })}\0`);
  });
};

const characterKey = (char) => {
  if (!/^[a-z0-9 ]$/i.test(char)) throw new Error(`cannot type "${char}"; use letters, digits and spaces`);
  if (char === ' ') return { code: 'Space', keyCode: 32 };
  return /\d/.test(char) ? { code: `Digit${char}`, keyCode: char.charCodeAt(0) } : { code: `Key${char.toUpperCase()}`, keyCode: char.toUpperCase().charCodeAt(0) };
};

const keyEvents = (key) => {
  const named = NAMED_KEYS[key];
  const { code, keyCode } = named ?? characterKey(key);
  const common = { key, code, windowsVirtualKeyCode: keyCode };
  return [
    named ? { type: 'rawKeyDown', ...common } : { type: 'keyDown', ...common, text: key, unmodifiedText: key },
    { type: 'keyUp', ...common },
  ];
};

const openPage = async (send, url, { initScript }) => {
  const { targetId } = await send('Target.createTarget', { url: 'about:blank' });
  const { sessionId } = await send('Target.attachToTarget', { targetId, flatten: true });
  const call = (method, params) => send(method, params, sessionId);
  await call('Emulation.setDeviceMetricsOverride', { width: 1100, height: 900, deviceScaleFactor: 1, mobile: false });
  await call('Emulation.setEmulatedMedia', { features: [{ name: 'prefers-reduced-motion', value: 'reduce' }] });
  await call('Page.enable');
  if (initScript) await call('Page.addScriptToEvaluateOnNewDocument', { source: initScript });
  await call('Page.navigate', { url });
  const press = async (key) => {
    for (const event of keyEvents(key)) await call('Input.dispatchKeyEvent', event);
  };
  return {
    evaluate: async (expression) => {
      const { result, exceptionDetails } = await call('Runtime.evaluate', { expression, returnByValue: true, awaitPromise: true });
      if (exceptionDetails) throw new Error(exceptionDetails.exception?.description ?? exceptionDetails.text);
      return result.value;
    },
    click: async (x, y) => {
      for (const type of ['mousePressed', 'mouseReleased']) await call('Input.dispatchMouseEvent', { type, x, y, button: 'left', clickCount: 1 });
    },
    press,
    type: async (text) => {
      for (const char of text) await press(char);
    },
    reload: () => call('Page.reload'),
  };
};

// Processes. Under load Chrome hung in its shutdown for minutes, ignoring SIGTERM, and its helpers outlived a killed
// Chrome holding its pipes open, which kept the caller from exiting. So Chrome runs in a process group of its own,
// every wait for it is bounded, and stopping it kills the whole group.
//
// Every launch gets a throwaway profile under the temp directory: without --user-data-dir, headless Chrome ran in
// the reader's own Chrome profile. Stopping Chrome removes it, on every path, including the caller's exit.

const running = new Set();

const startChrome = (chrome, flags, url, stdio) => {
  const profile = mkdtempSync(path.join(tmpdir(), 'hmsi-chrome-'));
  const child = spawn(chrome, [...flags, `--user-data-dir=${profile}`, url], { stdio, detached: true });
  const launched = { child, profile };
  running.add(launched);
  return launched;
};

const stopChrome = (launched) => {
  running.delete(launched);
  try {
    process.kill(-launched.child.pid, 'SIGKILL');
  } catch { /* the group is gone already */ }
  launched.child.stdio.forEach((stream) => stream?.destroy());
  rmSync(launched.profile, { recursive: true, force: true, maxRetries: 5 });
};

process.on('exit', () => running.forEach(stopChrome));

// The page is taken once it has been printed; Chrome gets a moment to exit on its own, then is stopped.
export const dumpDom = (chrome, url, { printTimeoutMs = DUMP_TIMEOUT_MS } = {}) => new Promise((resolve, reject) => {
  const launched = startChrome(chrome, ['--headless', '--disable-gpu', '--no-first-run', '--virtual-time-budget=15000', '--dump-dom'], url, ['ignore', 'pipe', 'ignore']);
  const { child } = launched;
  let output = '';
  let grace;
  const end = (settle) => {
    clearTimeout(deadline);
    clearTimeout(grace);
    stopChrome(launched);
    settle();
  };
  const allowExit = () => {
    grace = grace ?? setTimeout(() => end(() => resolve(output)), CLOSE_TIMEOUT_MS);
  };
  const deadline = setTimeout(() => end(() => reject(new Error(`Chrome did not print the page within ${printTimeoutMs / 1000} s`))), printTimeoutMs);
  child.stdout.setEncoding('utf8');
  child.stdout.on('data', (chunk) => {
    output += chunk;
    if (output.trimEnd().endsWith('</html>')) allowExit();
  });
  child.once('exit', allowExit);
  child.once('error', (error) => end(() => reject(error)));
  child.once('close', () => end(() => resolve(output)));
});

// The fresh profile also means no answers saved by an earlier run are restored into the page.
export const launchChrome = (chrome) => {
  const launched = startChrome(chrome, [
    '--headless', '--disable-gpu', '--no-first-run', '--no-default-browser-check', '--remote-debugging-pipe',
  ], 'about:blank', ['ignore', 'ignore', 'ignore', 'pipe', 'pipe']);
  const { child } = launched;
  const exited = new Promise((resolve) => {
    child.once('exit', resolve);
    child.once('error', resolve);
  });
  const send = connect(child.stdio[3], child.stdio[4], exited);
  return {
    openPage: (url, options = {}) => openPage(send, url, options),
    close: async () => {
      await settlesWithin(send('Browser.close'), CLOSE_TIMEOUT_MS);
      await settlesWithin(exited, CLOSE_TIMEOUT_MS);
      stopChrome(launched);
    },
  };
};
