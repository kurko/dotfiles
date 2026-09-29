// Answers every question of a built page in headless Chrome, once by mouse and once by keyboard. After each step it
// reads the answers text and the answers saved in the browser, so an answer that reaches either late, or never, fails
// the check, and a reload at the end of each pass proves every answer, comment and wrap-up choice comes back. It also
// reports form controls the page neither saves nor sends.
import { pathToFileURL } from 'node:url';
import { findChrome, launchChrome } from './chrome.mjs';

const READY_TIMEOUT_MS = 30_000;
const READ_TIMEOUT_MS = 2_000;
const POLL_MS = 25;
const STILL_FRAMES = 3;
const MAX_AIM_FRAMES = 120;
const CLICK_ATTEMPTS = 5;
const WRITE_SPEC = 'Stop asking and write the spec';
const BUILD = 'Stop asking and start building';
const FOLLOW_UP = 'Ask follow-up questions if you need to';

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

const nextStepExpected = (label) => ({ 'the next step': `Next step: ${label}` });

const nextStepClick = (value, label) => ({
  describe: `choosing "${label}"`,
  act: (page) => clickOn(page, { selector: `input[name="next-step"][value="${value}"]`, what: `"${label}"` }),
  expect: nextStepExpected(label),
});

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
  nextStepClick('build', BUILD),
  nextStepClick('follow-up', FOLLOW_UP),
  nextStepClick('write-spec', WRITE_SPEC),
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
    expect: nextStepExpected(WRITE_SPEC),
  },
  ...[BUILD, FOLLOW_UP, WRITE_SPEC].map((label) => ({
    describe: `pressing ArrowDown again on "After this round", to reach "${label}"`,
    act: (page) => pressEach(page, ['ArrowDown']),
    expect: nextStepExpected(label),
  })),
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

// What a reload would bring back: the saved copy read as the page reads it, printed as the page prints it. A page
// nothing has been entered on saves nothing, and that is right.
const SAVED_COPY = `(() => {
  const data = JSON.parse(document.getElementById('spec-data').textContent);
  const shown = document.getElementById('answers-text').value;
  const raw = localStorage.getItem(SpecForm.storageKey(data));
  const untouched = SpecForm.formatAnswers(data, SpecForm.stateFromStorage(data, null)) === shown;
  if (raw === null) return untouched ? 'same' : 'nothing';
  try {
    return SpecForm.formatAnswers(data, SpecForm.stateFromStorage(data, JSON.parse(raw))) === shown ? 'same' : 'different';
  } catch {
    return 'different';
  }
})()`;

const SAVED_COPY_PROBLEMS = {
  nothing: 'nothing is saved in the browser, so a reload then would lose every answer',
  different: 'the answers saved in the browser differ from the answers text, so a reload then would lose the difference',
};

// Each field is reported once, at the first step after which the text disagrees with it. A blocked step may have
// landed part of its clicks, so the fields it touches are left unchecked for the rest of the pass.
const runPass = async (page, pass, steps, entries, errors) => {
  const problems = [];
  const reported = new Set();
  let expected = {};
  let savedCopyReported = false;
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
    const savedCopy = await page.evaluate(SAVED_COPY);
    if (savedCopy !== 'same' && !savedCopyReported) {
      savedCopyReported = true;
      problems.push(`round trip by ${pass}: after ${step.describe}, ${SAVED_COPY_PROBLEMS[savedCopy]}`);
    }
  }
  return problems;
};

const ENGINE_OWNED = [
  'fieldset.question > .options > .option > label > input',
  'fieldset.question > .comment > textarea',
  '#general-comment',
  'input[name="next-step"]',
  '#answers-text',
].join(', ');

const EDITABLE = '[contenteditable]:not([contenteditable="false"])';

const CONTROLS = `input:not([type=button]):not([type=submit]):not([type=reset]):not([type=range]):not([type=hidden]), select, textarea, ${EDITABLE}`;

const UNOWNED_CONTROLS = `(() => {
  const label = (node) => {
    if (node.matches(${JSON.stringify(EDITABLE)})) return node.tagName.toLowerCase() + '[contenteditable]';
    return node instanceof HTMLInputElement ? 'input[type=' + node.type + ']' : node.tagName.toLowerCase();
  };
  const questions = [...document.querySelectorAll('fieldset.question')];
  return [...document.querySelectorAll(${JSON.stringify(CONTROLS)})]
    .filter((node) => !node.matches(${JSON.stringify(ENGINE_OWNED)}))
    .map((node) => ({ control: label(node), question: questions.indexOf(node.closest('fieldset.question')) + 1 }));
})()`;

const unownedControlProblems = async (page) => (await page.evaluate(UNOWNED_CONTROLS)).map(({ control, question }) =>
  `round trip: the page has ${control} ${question ? `in Q${question}'s visual` : 'outside the questions'}, which takes input the page neither saves nor sends; ask through the options or the comment box instead`);

const roundTrip = async (browser, file, data) => {
  const entries = entriesOf(data);
  const errors = [];
  const page = await browser.openPage(pathToFileURL(file).href, { initScript: CLICK_GUARD });
  await waitForPage(page);
  const unowned = await unownedControlProblems(page);
  const byMouse = await runPass(page, 'mouse', mouseSteps(entries), entries, errors);
  await page.evaluate('localStorage.clear()');
  await reloadPage(page, errors);
  const byKeyboard = await runPass(page, 'keyboard', keyboardSteps(entries), entries, errors);
  errors.push(...await pageErrors(page));
  return [...unowned, ...byMouse, ...byKeyboard, ...[...new Set(errors)].map((message) => `round trip: the page reported "${message}"`)];
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
