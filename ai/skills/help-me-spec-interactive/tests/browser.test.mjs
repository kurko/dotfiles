import { after, before, beforeEach, describe, test } from 'node:test';
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { mkdtempSync, readFileSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { pathToFileURL } from 'node:url';
import { SKILL_DIR, TEMPLATE_PATH, assemblePage } from '../scripts/page.mjs';

const SESSION = `hmsi-browser-${process.pid}`;

const agentBrowserMissing = () => {
  try {
    execFileSync('agent-browser', ['--version'], { stdio: 'ignore' });
    return false;
  } catch {
    return 'agent-browser is not installed';
  }
};

const browser = (...args) => execFileSync('agent-browser', ['--session', SESSION, ...args], { encoding: 'utf8', timeout: 60_000 });
const evaluate = (expression) => JSON.parse(browser('eval', '--json', expression)).data.result;
const press = (...keys) => keys.forEach((key) => browser('press', key));

const activeQuestion = () => evaluate("document.activeElement.closest('fieldset.question')?.dataset.question ?? null");
const activeTag = () => evaluate('document.activeElement.tagName');
const checked = (id) => evaluate(`[...document.querySelectorAll('input[name="q-${id}"]:checked')].map((input) => input.value)`);
const answers = () => evaluate("document.getElementById('answers-text').value");
const lineStatus = () => evaluate("document.querySelector('.chess-line-status').textContent");

const read = (relative) => readFileSync(path.join(SKILL_DIR, relative), 'utf8');

const buildPage = (parts) => {
  const file = path.join(mkdtempSync(path.join(tmpdir(), 'hmsi-browser-')), 'page.html');
  writeFileSync(file, assemblePage(readFileSync(TEMPLATE_PATH, 'utf8'), parts));
  return pathToFileURL(file).href;
};

const buildExample = () => buildPage({
  data: JSON.parse(read('examples/pins/data.json')),
  visuals: read('examples/pins/visuals.html'),
  includes: [read('recipes/mermaid.html'), read('recipes/chess.html')],
});

// Two boards from the start position, so every square's piece is known.
const buildBoardsPage = () => buildPage({
  data: {
    id: 'boards-r1',
    title: 'Boards',
    round: 1,
    summary: 'Orientation.',
    sections: [{ title: 'Boards', questions: [{ id: 'boards', header: 'Boards', question: 'Which way up?', visual: 'boards', options: [{ label: 'White' }, { label: 'Black' }] }] }],
  },
  visuals: '<template id="boards"><div class="white-side" data-chess-board=""></div><div class="black-side" data-chess-board="" data-orientation="black"></div></template>',
  includes: [read('recipes/chess.html')],
});

describe('in a browser', { skip: agentBrowserMissing() }, () => {
  let url;

  before(() => { url = buildExample(); });
  beforeEach(() => {
    browser('open', url);
    browser('eval', 'localStorage.clear()');
    browser('open', url);
  });
  after(() => browser('close'));

  test('j moves to the first question and a digit chooses that option', () => {
    press('j');
    assert.equal(activeQuestion(), 'pin-kind');

    press('2');

    assert.deepEqual(checked('pin-kind'), ['1']);
    assert.match(answers(), /Q1 \[Definition\] Which of these knights is pinned\?\nA: A and B\n/);
  });

  test('k moves back and stops at the first question', () => {
    press('j', 'j', 'k', 'k');

    assert.equal(activeQuestion(), 'pin-kind');
  });

  test('c opens the comment, where digits are text, and Escape returns to the options', () => {
    press('j', 'c');
    assert.equal(activeTag(), 'TEXTAREA');

    browser('keyboard', 'type', 'needs 1 pawn');
    assert.deepEqual(checked('pin-kind'), []);
    assert.match(answers(), /A: \(no answer\)\nComment: needs 1 pawn\n/);

    press('Escape');
    assert.equal(activeTag(), 'INPUT');
    assert.equal(activeQuestion(), 'pin-kind');
  });

  test('digits toggle on a multi-choice question and 0 chooses Other', () => {
    press('j', 'j', 'j', 'j', 'j');
    assert.equal(activeQuestion(), 'pinning-pieces');

    press('1', '3', '1', '0');

    assert.deepEqual(checked('pinning-pieces'), ['2', 'other']);
    assert.match(answers(), /Q5 \[Pieces\] Which pinning pieces should be reported\?\nA: Queen; Other\n/);
  });

  test('n jumps to the next unanswered question', () => {
    press('j', '1', 'j', 'j', '2', 'k', 'k');

    press('n');
    assert.equal(activeQuestion(), 'marking');

    press('1', 'n');
    assert.equal(activeQuestion(), 'detector-kind');
  });

  test('answers and comments survive a reload', () => {
    press('j', '2', 'c');
    browser('keyboard', 'type', 'kept');

    browser('open', url);

    assert.deepEqual(checked('pin-kind'), ['1']);
    assert.equal(evaluate("document.querySelector('[name=\"comment-pin-kind\"]').value"), 'kept');
    assert.match(answers(), /^Answered: 1 of 6$/m);
  });

  test('? shows and hides the shortcut list', () => {
    press('?');
    assert.equal(evaluate("document.getElementById('shortcut-help').hidden"), false);

    press('?');
    assert.equal(evaluate("document.getElementById('shortcut-help').hidden"), true);
  });

  test('a chess line steps with the arrow keys, Home and End', () => {
    browser('wait', '--fn', "!document.querySelector('.chess-line-status').textContent.startsWith('Loading')");
    browser('focus', '[data-chess-line]');

    press('ArrowRight', 'ArrowRight');
    assert.equal(lineStatus(), '5… Bd7 (2/3)');

    press('End');
    assert.equal(lineStatus(), '6. O-O (3/3)');

    press('Home');
    assert.equal(lineStatus(), 'Start (0/3)');
    assert.equal(activeQuestion(), 'breakable');
  });

  test('digits do nothing while the focus is outside the questions', () => {
    press('j', 'j', 'j', 'j', 'j', 'j', '1');
    assert.deepEqual(checked('feature-name'), ['0']);

    browser('focus', 'input[name="next-step"][value="write-spec"]');
    press('2');

    assert.deepEqual(checked('feature-name'), ['0']);
    assert.equal(evaluate('document.activeElement.value'), 'write-spec');
    assert.match(answers(), /Next step: Ask follow-up questions if you need to/);
  });

  test('keys inside a widget that owns them or prevents them leave the answers alone', () => {
    evaluate(`(() => {
      const visual = document.querySelector('#q-pin-kind .visual');
      const widget = (className) => Object.assign(document.createElement('div'), { tabIndex: 0, className });
      const owner = widget('test-owner');
      owner.dataset.ownKeys = '';
      const preventer = widget('test-preventer');
      preventer.addEventListener('keydown', (event) => event.preventDefault());
      visual.append(owner, preventer);
      return true;
    })()`);

    browser('focus', '.test-preventer');
    press('2', 'j');
    assert.deepEqual(checked('pin-kind'), []);
    assert.equal(evaluate('document.activeElement.className'), 'test-preventer');

    // agent-browser repeats a key nobody prevents inside such a widget, so these keys are dispatched from the page.
    browser('focus', '.test-owner');
    ['2', 'j'].forEach((key) => evaluate(`document.activeElement.dispatchEvent(new KeyboardEvent('keydown', { key: '${key}', bubbles: true, cancelable: true }))`));
    assert.deepEqual(checked('pin-kind'), []);
    assert.equal(evaluate('document.activeElement.className'), 'test-owner');
  });

  test('a board drawn as a picture gets the placement of its FEN twin', () => {
    const labels = evaluate("[...document.querySelectorAll('#q-pin-kind [data-chess-board]')].map((board) => board.getAttribute('aria-label'))");

    assert.deepEqual(labels, [
      'Chess position r1bqkb1r/ppp2ppp/2np1n2/1B2p3/4P3/5N2/PPPP1PPP/RNBQK2R, marked: b5 c6 e8',
      'Chess position r1bqrbk1/ppp2ppp/2np1n2/1B2p3/4P3/5N2/PPPP1PPP/RNBQK2R, marked: b5 c6 e8',
    ]);
  });

  test('a board seen from Black starts at h1', () => {
    browser('open', buildBoardsPage());
    const corners = (selector) => evaluate(`(() => {
      const squares = document.querySelector('${selector}').children;
      return [squares[0], squares[63]].map((square) => [square.dataset.square, square.querySelector('.chess-piece').textContent[0]]);
    })()`);

    assert.deepEqual(corners('.white-side'), [['a8', '♜'], ['h1', '♖']]);
    assert.deepEqual(corners('.black-side'), [['h1', '♖'], ['a8', '♜']]);
  });

  test('Copy answers reports that it copied', () => {
    press('j', '1');

    browser('click', '.answers [data-copy-answers]');
    browser('wait', '--fn', "document.querySelector('.actions [data-copy-status]').textContent !== ''");

    assert.equal(evaluate("document.querySelector('.actions [data-copy-status]').textContent"), 'Copied. Paste it into the conversation.');
  });

  test('Clear all answers keeps them when dismissed and empties the form when accepted', () => {
    press('j', '1', 'c');
    browser('keyboard', 'type', 'gone soon');

    browser('click', '#clear-answers');
    browser('dialog', 'dismiss');
    assert.deepEqual(checked('pin-kind'), ['0']);

    browser('click', '#clear-answers');
    browser('dialog', 'accept');
    assert.deepEqual(checked('pin-kind'), []);
    assert.equal(evaluate("document.querySelector('[name=\"comment-pin-kind\"]').value"), '');
    assert.match(answers(), /^Answered: 0 of 6$/m);
  });
});
