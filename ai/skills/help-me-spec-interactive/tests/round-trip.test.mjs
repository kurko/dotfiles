import { describe, test } from 'node:test';
import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { once } from 'node:events';
import { existsSync, mkdtempSync, readFileSync, writeFileSync } from 'node:fs';
import { createServer } from 'node:http';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { SKILL_DIR, TEMPLATE_PATH, assemblePage } from '../scripts/page.mjs';
import { findChrome, launchChrome } from '../scripts/chrome.mjs';
import { roundTripProblems } from '../scripts/round-trip.mjs';
import { assertThrowawayProfile, pause, processesLeftIn, writeStubbornChrome } from './support/stubborn-chrome.mjs';

const template = readFileSync(TEMPLATE_PATH, 'utf8');
const readSkillFile = (relative) => readFileSync(path.join(SKILL_DIR, relative), 'utf8');

const sampleData = () => ({
  id: 'round-trip-r1',
  title: 'Round trip',
  round: 1,
  summary: 'What was explored.',
  sections: [{
    title: 'Scope',
    questions: [
      { id: 'storage', header: 'Storage', question: 'Where do features live?', options: [{ label: 'Column' }, { label: 'Jsonb' }] },
      { id: 'sides', header: 'Sides', question: 'Which sides are reported?', multiSelect: true, options: [{ label: 'White' }, { label: 'Black' }] },
    ],
  }],
});

const writePage = (parts, engine = (source) => source) => {
  const file = path.join(mkdtempSync(path.join(tmpdir(), 'hmsi-round-trip-')), 'page.html');
  writeFileSync(file, assemblePage(engine(template), parts));
  return file;
};

const missed = (pass, step, field, actual, expected) =>
  `round trip by ${pass}: after ${step}, ${field} is ${JSON.stringify(actual)} in the answers text, expected ${JSON.stringify(expected)}`;

// Serves one script, held back the way a CDN answering slowly under load holds it.
const serveLateScript = async (body, heldMs) => {
  const server = createServer((request, response) => setTimeout(() => {
    response.writeHead(200, { 'Content-Type': 'text/javascript' });
    response.end(body);
  }, heldMs));
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  return { url: `http://127.0.0.1:${server.address().port}/late.js`, close: () => server.close() };
};

const pushQuestionsDown = "document.getElementById('questions').before(Object.assign(document.createElement('div'), { style: 'height: 300px' }))";

// The check aims with elementFromPoint, so this moves the questions right after it has aimed at Q1's first option.
const MOVE_AFTER_AIMING = `<script>
  (() => {
    const find = document.elementFromPoint.bind(document);
    let moved = false;
    document.elementFromPoint = (x, y) => {
      const hit = find(x, y);
      if (!moved && hit?.closest?.('#q-storage .option')) {
        moved = true;
        ${pushQuestionsDown};
      }
      return hit;
    };
  })();
</script>`;

const MOVE_WHEN_PRESSED = `<script>
  addEventListener('pointerdown', (event) => {
    if (event.target.closest?.('#q-storage .option') && !window.moved) {
      window.moved = true;
      ${pushQuestionsDown};
    }
  }, true);
</script>`;

describe('roundTripProblems', { skip: findChrome() ? false : 'no Chrome found' }, () => {
  test('passes the example, whose every answer, comment and wrap-up reach the answers text', async () => {
    const parts = {
      data: JSON.parse(readSkillFile('examples/pins/data.json')),
      visuals: readSkillFile('examples/pins/visuals.html'),
      includes: [readSkillFile('recipes/mermaid.html'), readSkillFile('recipes/chess.html')],
    };

    assert.deepEqual(await roundTripProblems(writePage(parts), parts.data), []);
  });

  test('answers only once the page has loaded, since an include that arrives late moves the questions', async () => {
    const late = await serveLateScript(`window.lateIncludeRan = true; ${pushQuestionsDown};`, 1000);
    const includes = [
      "<script>['pointerdown', 'keydown'].forEach((type) => addEventListener(type, () => { if (!window.lateIncludeRan) window.reportSpecError(`${type} before the page loaded`); }, true));</script>",
      `<script src="${late.url}"></script>`,
    ];

    try {
      assert.deepEqual(await roundTripProblems(writePage({ data: sampleData(), includes }), sampleData()), []);
    } finally {
      late.close();
    }
  });

  test('aims again when the page moves between aiming and clicking, and the stray click changes nothing', async () => {
    const file = writePage({ data: sampleData(), includes: [MOVE_AFTER_AIMING] });

    assert.deepEqual(await roundTripProblems(file, sampleData()), []);
  });

  test('reports an option that moves when pressed, since a reader clicking it misses too', async () => {
    const file = writePage({ data: sampleData(), includes: [MOVE_WHEN_PRESSED] });

    const problems = await roundTripProblems(file, sampleData());

    assert.equal(problems.length, 1, problems.join('\n'));
    assert.match(problems[0], /^round trip by mouse: option 1 of Q1 moved when pressed, so the click landed on \S+$/);
  });

  test('reports a next-step choice that never reaches the answers text', async () => {
    const file = writePage({ data: sampleData() }, (source) => source.replace(
      `nextStep: document.querySelector('input[name="next-step"]:checked')?.value || DEFAULT_NEXT_STEP,`,
      'nextStep: DEFAULT_NEXT_STEP,',
    ));
    const [actual, expected] = ['Next step: Ask follow-up questions if you need to', 'Next step: Stop asking and write the spec'];

    assert.deepEqual(await roundTripProblems(file, sampleData()), [
      missed('mouse', 'choosing "Stop asking and write the spec"', 'the next step', actual, expected),
      missed('keyboard', 'pressing Tab and ArrowDown on "After this round"', 'the next step', actual, expected),
    ]);
  });

  test('reports typed comments that reach the answers text only after another change', async () => {
    const file = writePage({ data: sampleData() }, (source) => source.replace("['input', 'change'].forEach", "['change'].forEach"));

    assert.deepEqual(await roundTripProblems(file, sampleData()), [
      missed('mouse', 'typing a comment in Q1', "Q1's comment", '(no comment)', 'Comment: mouse comment 1'),
      missed('mouse', 'typing a comment in Q2', "Q2's comment", '(no comment)', 'Comment: mouse comment 2'),
      missed('mouse', 'typing the general comment', 'the general comment', '(missing)', 'General comment: mouse general comment'),
      missed('keyboard', 'pressing c and typing a comment in Q1', "Q1's comment", '(no comment)', 'Comment: keyboard comment 1'),
      missed('keyboard', 'pressing c and typing a comment in Q2', "Q2's comment", '(no comment)', 'Comment: keyboard comment 2'),
      missed('keyboard', "pressing Tab from Q2's comment and typing the general comment", 'the general comment', '(missing)', 'General comment: keyboard general comment'),
    ]);
  });

  test('reports an option that something on the page covers, since a click there misses it', async () => {
    const cover = '<style>.options { position: relative; } .options::after { content: ""; position: absolute; inset: 0; }</style>';
    const file = writePage({ data: sampleData(), includes: [cover] });

    assert.deepEqual(await roundTripProblems(file, sampleData()), [
      'round trip by mouse: div.options covers option 1 of Q1, so a click there misses it',
      'round trip by mouse: div.options covers option 1 of Q2, so a click there misses it',
    ]);
  });

  test('reports only the cover when it blocks the second choice of a multi-choice question', async () => {
    const cover = '<style>#q-sides .option:nth-child(2) { position: relative; } #q-sides .option:nth-child(2)::after { content: ""; position: absolute; inset: 0; }</style>';
    const file = writePage({ data: sampleData(), includes: [cover] });

    assert.deepEqual(await roundTripProblems(file, sampleData()), [
      'round trip by mouse: div.option covers option 2 of Q2, so a click there misses it',
    ]);
  });

  test('reports an error the page raised before a reload, once however often it recurs', async () => {
    const thrower = "<script>addEventListener('pointerdown', () => { throw new Error('pointer broke'); });</script>";
    const file = writePage({ data: sampleData(), includes: [thrower] });

    assert.deepEqual(await roundTripProblems(file, sampleData()), ['round trip: the page reported "Uncaught Error: pointer broke"']);
  });

  test('reports keyboard answers that a reload loses', async () => {
    const forget = "<script>addEventListener('keyup', () => localStorage.clear());</script>";
    const file = writePage({ data: sampleData(), includes: [forget] });
    const lost = (field, actual, expected) => missed('keyboard', 'reloading the page', field, actual, expected);

    assert.deepEqual(await roundTripProblems(file, sampleData()), [
      lost("Q1's answer", 'A: (no answer)', 'A: Jsonb'),
      lost('the answered count', 'Answered: 0 of 2', 'Answered: 2 of 2'),
      lost("Q1's comment", '(no comment)', 'Comment: keyboard comment 1'),
      lost("Q2's answer", 'A: (no answer)', 'A: White; Black'),
      lost("Q2's comment", '(no comment)', 'Comment: keyboard comment 2'),
      lost('the general comment', '(missing)', 'General comment: keyboard general comment'),
      lost('the next step', 'Next step: Ask follow-up questions if you need to', 'Next step: Stop asking and write the spec'),
    ]);
  });
});

describe('launchChrome', () => {
  test('closes a browser that ignores both the DevTools close and SIGTERM, helpers included', { timeout: 30_000 }, async () => {
    const dir = mkdtempSync(path.join(tmpdir(), 'hmsi-stubborn-'));
    const stubborn = writeStubbornChrome(dir, 'touch "$0.ready"');
    const browser = launchChrome(stubborn);
    while (!existsSync(`${stubborn}.ready`)) await pause(20);
    const started = Date.now();

    await browser.close();

    assert.ok(Date.now() - started < 15_000, `close took ${Date.now() - started} ms`);
    assert.deepEqual(await processesLeftIn(dir), []);
    assertThrowawayProfile(stubborn);
  });

  test('stops Chrome and removes its profile when the process exits before closing it', { timeout: 30_000 }, async () => {
    const dir = mkdtempSync(path.join(tmpdir(), 'hmsi-stubborn-'));
    const stubborn = writeStubbornChrome(dir, 'touch "$0.ready"');
    const script = [
      `import { existsSync } from 'node:fs';`,
      `import { launchChrome } from ${JSON.stringify(path.join(SKILL_DIR, 'scripts/chrome.mjs'))};`,
      `launchChrome(${JSON.stringify(stubborn)});`,
      `const ready = () => (existsSync(${JSON.stringify(`${stubborn}.ready`)}) ? process.exit(3) : setTimeout(ready, 20));`,
      'ready();',
    ].join('\n');
    const child = spawn(process.execPath, ['--input-type=module', '--eval', script], { stdio: 'ignore' });

    const [code] = await once(child, 'exit');

    assert.equal(code, 3);
    assert.deepEqual(await processesLeftIn(dir), []);
    assertThrowawayProfile(stubborn);
  });
});
