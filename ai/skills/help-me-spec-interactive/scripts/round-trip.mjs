// Answers every question of a built page in headless Chrome, once by mouse and once by keyboard, and reads the
// answers text after each step, so an answer that never reaches the text, or reaches it only later, fails the check.
import { pathToFileURL } from 'node:url';
import { findChrome, launchChrome } from './chrome.mjs';

const READY_TIMEOUT_MS = 30_000;
const READ_TIMEOUT_MS = 2_000;
const POLL_MS = 25;
const STILL_FRAMES = 3;
const MAX_AIM_FRAMES = 120;
const CLICK_ATTEMPTS = 5;
const WRITE_SPEC = 'Stop asking and write the spec';

const entriesOf = (data) => data.sections
  .flatMap((section) => section.questions)
  .map((question, index) => ({ question, number: index + 1 }));

const heading = ({ question, number }) => `Q${number} [${question.header}] ${question.question}`;

const answerLine = (question, picks) => `A: ${[...picks].sort((a, b) => a - b).map((pick) => question.options[pick].label).join('; ')}`;

const quoted = (labels) => labels.map((label) => `"${label}"`).join(' and ');

// Reading the answers text, field by field

const textFields = (text, entries) => {
  const lines = text.split('\n');
  const lineStarting = (prefix) => lines.find((line) => line.startsWith(prefix)) ?? '(missing)';
  const questionFields = entries.flatMap((entry) => {
    const at = lines.indexOf(heading(entry));
    const absent = `(no "${heading(entry)}" line)`;
    const comment = lines[at + 2]?.startsWith('Comment: ') ? lines[at + 2] : '(no comment)';
    return [[`Q${entry.number}'s answer`, at < 0 ? absent : lines[at + 1]], [`Q${entry.number}'s comment`, at < 0 ? absent : comment]];
  });
  return Object.fromEntries([
    ...questionFields,
    ['the answered count', lineStarting('Answered: ')],
    ['the next step', lineStarting('Next step: ')],
    ['the general comment', lineStarting('General comment: ')],
  ]);
};

const withAnsweredCount = (expected, total) => ({
  ...expected,
  'the answered count': `Answered: ${Object.keys(expected).filter((field) => field.endsWith("'s answer")).length} of ${total}`,
});

// Page actions

const pause = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

const waitFor = async (page, expression, what) => {
  const deadline = Date.now() + READY_TIMEOUT_MS;
  while (!(await page.evaluate(expression))) {
    if (Date.now() > deadline) throw new Error(`${what} within ${READY_TIMEOUT_MS / 1000} s`);
    await pause(POLL_MS);
  }
};

// The engine marks the form ready before the includes run, so a slow blocking include (Mermaid) can still be
// loading, with every chess board empty and the questions about to move by hundreds of pixels.
const waitForPage = (page) => waitFor(
  page,
  "!window.roundTripLeft && document.readyState === 'complete' && document.documentElement.getAttribute('data-spec-form') === 'ready'",
  'the page did not finish loading',
);

const pageErrors = async (page) => JSON.parse(await page.evaluate("document.documentElement.getAttribute('data-spec-errors') || '[]'"));

// The page lists its errors on <html>, which a reload empties, so they are collected first.
const reloadPage = async (page, errors) => {
  errors.push(...await pageErrors(page));
  await page.evaluate('window.roundTripLeft = true');
  await page.reload();
  await waitForPage(page);
};

const answersText = (page) => page.evaluate("document.getElementById('answers-text').value");

// Installed before the page's own scripts, so it sees every click first. Whatever part of an aimed click lands
// outside its target is cancelled; a press that already missed means the page moved between aiming and clicking.
const CLICK_GUARD = `(() => {
  window.roundTripDescribe = (node) => (node ? [node.tagName.toLowerCase(), ...node.classList].join('.') : 'nothing');
  ['pointerdown', 'mousedown', 'pointerup', 'mouseup', 'click'].forEach((type) => window.addEventListener(type, (event) => {
    const aim = window.roundTripAim;
    if (!aim || aim.area.contains(event.target)) return;
    if (type === 'pointerdown') aim.missedPress = true;
    aim.strayed = aim.strayed || window.roundTripDescribe(event.target);
    event.preventDefault();
    event.stopImmediatePropagation();
  }, true));
})();`;

const aimAt = (selector) => `(async () => {
  const node = document.querySelector(${JSON.stringify(selector)});
  if (!node) return { refused: 'missing' };
  const same = (a, b) => a.top === b.top && a.left === b.left && a.width === b.width && a.height === b.height;
  let rect = null;
  for (let frame = 0, still = 0; still < ${STILL_FRAMES}; frame += 1) {
    if (frame > ${MAX_AIM_FRAMES}) return { refused: 'unstable' };
    node.scrollIntoView({ block: 'center' });
    await new Promise((resolve) => requestAnimationFrame(resolve));
    const next = node.getBoundingClientRect();
    still = rect && same(next, rect) ? still + 1 : 0;
    rect = next;
  }
  if (!rect.width || !rect.height) return { refused: 'hidden' };
  const [x, y] = [rect.left + rect.width / 2, rect.top + rect.height / 2];
  const area = node.closest('label') || node;
  const hit = document.elementFromPoint(x, y);
  if (!area.contains(hit)) return { refused: 'covered', cover: window.roundTripDescribe(hit) };
  window.roundTripAim = { area, strayed: null, missedPress: false };
  return { x, y };
})()`;

const LANDING = '(() => { const { strayed, missedPress } = window.roundTripAim; window.roundTripAim = null; return { strayed, missedPress }; })()';

const refusal = (aim, what) => ({
  missing: `${what} is not on the page`,
  unstable: `${what} kept moving for ${MAX_AIM_FRAMES} frames, so a click cannot aim at it`,
  hidden: `${what} has no size, so it cannot be clicked`,
  covered: `${aim.cover} covers ${what}, so a click there misses it`,
})[aim.refused];

const clickOn = async (page, target, attempt = 1) => {
  const aim = await page.evaluate(aimAt(target.selector));
  if (aim.refused) return [refusal(aim, target.what)];
  await page.click(aim.x, aim.y);
  const { strayed, missedPress } = await page.evaluate(LANDING);
  if (!strayed) return [];
  if (!missedPress) return [`${target.what} moved when pressed, so the click landed on ${strayed}`];
  if (attempt < CLICK_ATTEMPTS) return clickOn(page, target, attempt + 1);
  return [`${target.what} moved between aiming and clicking ${CLICK_ATTEMPTS} times; the last click landed on ${strayed}`];
};

const clickEach = async (page, targets) => {
  for (const target of targets) {
    const blocked = await clickOn(page, target);
    if (blocked.length) return blocked;
  }
  return [];
};

const clickThenType = async (page, target, text) => {
  const blocked = await clickOn(page, target);
  if (!blocked.length) await page.type(text);
  return blocked;
};

const pressEach = async (page, keys) => {
  for (const key of keys) await page.press(key);
  return [];
};

// Steps. Each acts, then names the answers-text fields it should have changed.

const nextStepExpected = { 'the next step': `Next step: ${WRITE_SPEC}` };

const reloadStep = {
  describe: 'reloading the page',
  act: async (page, errors) => {
    await reloadPage(page, errors);
    return [];
  },
  expect: {},
};

const mouseSteps = (entries) => [
  ...entries.flatMap((entry, index) => {
    const { question, number } = entry;
    const picks = question.multiSelect ? [0, question.options.length - 1] : [index % question.options.length];
    const comment = `mouse comment ${number}`;
    return [
      {
        describe: `choosing ${quoted(picks.map((pick) => question.options[pick].label))} in Q${number}`,
        act: (page) => clickEach(page, picks.map((pick) => ({ selector: `#q-${question.id} input[value="${pick}"]`, what: `option ${pick + 1} of Q${number}` }))),
        expect: { [`Q${number}'s answer`]: answerLine(question, picks) },
      },
      {
        describe: `typing a comment in Q${number}`,
        act: (page) => clickThenType(page, { selector: `textarea[name="comment-${question.id}"]`, what: `the comment box of Q${number}` }, comment),
        expect: { [`Q${number}'s comment`]: `Comment: ${comment}` },
      },
    ];
  }),
  {
    describe: 'typing the general comment',
    act: (page) => clickThenType(page, { selector: '#general-comment', what: 'the general comment box' }, 'mouse general comment'),
    expect: { 'the general comment': 'General comment: mouse general comment' },
  },
  {
    describe: `choosing "${WRITE_SPEC}"`,
    act: (page) => clickOn(page, { selector: 'input[name="next-step"][value="write-spec"]', what: `"${WRITE_SPEC}"` }),
    expect: nextStepExpected,
  },
  reloadStep,
];

// Escape first: it leaves the comment box of the question before, which is how a reader moves on.
const keyboardSteps = (entries) => [
  ...entries.flatMap((entry, index) => {
    const { question, number } = entry;
    const digits = (question.multiSelect ? [0, 1] : [(index + 1) % question.options.length]).map((pick) => String(pick + 1));
    const comment = `keyboard comment ${number}`;
    return [
      {
        describe: `pressing Escape, j, ${digits.join(' and ')} in Q${number}`,
        act: (page) => pressEach(page, ['Escape', 'j', ...digits]),
        expect: { [`Q${number}'s answer`]: answerLine(question, digits.map((digit) => Number(digit) - 1)) },
      },
      {
        describe: `pressing c and typing a comment in Q${number}`,
        act: async (page) => { await page.press('c'); await page.type(comment); return []; },
        expect: { [`Q${number}'s comment`]: `Comment: ${comment}` },
      },
    ];
  }),
  {
    describe: `pressing Tab from Q${entries.length}'s comment and typing the general comment`,
    act: async (page) => { await page.press('Tab'); await page.type('keyboard general comment'); return []; },
    expect: { 'the general comment': 'General comment: keyboard general comment' },
  },
  {
    describe: 'pressing Tab and ArrowDown on "After this round"',
    act: (page) => pressEach(page, ['Tab', 'ArrowDown']),
    expect: nextStepExpected,
  },
  reloadStep,
];

const mismatches = (actual, expected) => Object.entries(expected).filter(([field, line]) => actual[field] !== line);

// Reads until the text shows every expected line or the deadline passes, and returns the last read.
const readFields = async (page, entries, expected, deadline = Date.now() + READ_TIMEOUT_MS) => {
  const actual = textFields(await answersText(page), entries);
  if (!mismatches(actual, expected).length || Date.now() > deadline) return actual;
  await pause(POLL_MS);
  return readFields(page, entries, expected, deadline);
};

// Each field is reported once, at the first step after which the text disagrees with it. A blocked step may have
// landed part of its clicks, so the fields it touches are left unchecked for the rest of the pass.
const runPass = async (page, pass, steps, entries, errors) => {
  const problems = [];
  const reported = new Set();
  let expected = {};
  for (const step of steps) {
    const blocked = await step.act(page, errors);
    problems.push(...blocked.map((problem) => `round trip by ${pass}: ${problem}`));
    if (blocked.length) [...Object.keys(step.expect), 'the answered count'].forEach((field) => reported.add(field));
    else expected = withAnsweredCount({ ...expected, ...step.expect }, entries.length);
    const unreported = Object.fromEntries(Object.entries(expected).filter(([field]) => !reported.has(field)));
    const actual = await readFields(page, entries, unreported);
    mismatches(actual, unreported).forEach(([field, line]) => {
      reported.add(field);
      problems.push(`round trip by ${pass}: after ${step.describe}, ${field} is ${JSON.stringify(actual[field])} in the answers text, expected ${JSON.stringify(line)}`);
    });
  }
  return problems;
};

const roundTrip = async (browser, file, data) => {
  const entries = entriesOf(data);
  const errors = [];
  const page = await browser.openPage(pathToFileURL(file).href, { initScript: CLICK_GUARD });
  await waitForPage(page);
  const byMouse = await runPass(page, 'mouse', mouseSteps(entries), entries, errors);
  await page.evaluate('localStorage.clear()');
  await reloadPage(page, errors);
  const byKeyboard = await runPass(page, 'keyboard', keyboardSteps(entries), entries, errors);
  errors.push(...await pageErrors(page));
  return [...byMouse, ...byKeyboard, ...[...new Set(errors)].map((message) => `round trip: the page reported "${message}"`)];
};

export const roundTripProblems = async (file, data) => {
  const chrome = findChrome();
  if (!chrome) return [];
  const browser = launchChrome(chrome);
  try {
    return await roundTrip(browser, file, data);
  } catch (error) {
    return [`round trip: ${error.message}`];
  } finally {
    await browser.close();
  }
};
