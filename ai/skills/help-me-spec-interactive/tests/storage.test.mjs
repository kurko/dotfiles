import { after, before, describe, test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, readFileSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { pathToFileURL } from 'node:url';
import { TEMPLATE_PATH, assemblePage } from '../scripts/page.mjs';
import { findChrome, launchChrome } from '../scripts/chrome.mjs';

const template = readFileSync(TEMPLATE_PATH, 'utf8');
const PREFIX = 'help-me-spec-interactive:';

// Pages opened from files share one origin, so each test gets an id of its own.
let pages = 0;
const sampleData = (storageOptions = ['Column', 'Jsonb'], id = `storage-${pages += 1}`, sidesMultiSelect = false) => ({
  id,
  title: 'Storage',
  round: 1,
  summary: 'What was explored.',
  sections: [{
    title: 'Scope',
    questions: [
      { id: 'storage', header: 'Storage', question: 'Where do features live?', options: storageOptions.map((label) => ({ label })) },
      { id: 'sides', header: 'Sides', question: 'Which sides are reported?', multiSelect: sidesMultiSelect, options: [{ label: 'White' }, { label: 'Black' }] },
    ],
  }],
});

const writePage = (file, data, includes = []) => writeFileSync(file, assemblePage(template, { data, includes }));

const newFile = () => path.join(mkdtempSync(path.join(tmpdir(), 'hmsi-storage-')), 'page.html');

const chooseOption = (page, questionId, value) => page.evaluate(`document.querySelector('#q-${questionId} input[value="${value}"]').click()`);

const typeComment = (page, questionId, text) => page.evaluate(`(() => {
  const box = document.querySelector('textarea[name="comment-${questionId}"]');
  box.value = ${JSON.stringify(text)};
  box.dispatchEvent(new Event('input', { bubbles: true }));
})()`);

const reload = async (page) => {
  await page.evaluate('window.beforeReload = true');
  await page.reload();
  while (await page.evaluate("window.beforeReload || document.documentElement.getAttribute('data-spec-form') !== 'ready'")) {
    await new Promise((resolve) => setTimeout(resolve, 25));
  }
};

const answersText = (page) => page.evaluate("document.getElementById('answers-text').value");

const warningHidden = (page) => page.evaluate("document.getElementById('storage-warning').hidden");

const ready = async (page) => {
  while (await page.evaluate("document.documentElement.getAttribute('data-spec-form') !== 'ready'")) {
    await new Promise((resolve) => setTimeout(resolve, 25));
  }
};

describe('saved answers in a browser', { skip: findChrome() ? false : 'no Chrome found' }, () => {
  let browser;
  before(() => { browser = launchChrome(findChrome()); });
  after(async () => { await browser.close(); });

  const open = async (file, initScript) => {
    const page = await browser.openPage(pathToFileURL(file).href, { initScript });
    await ready(page);
    return page;
  };

  test('keep an answer and a comment when the same page is rebuilt with an option inserted before the chosen one', async () => {
    const file = newFile();
    writePage(file, sampleData(undefined, 'storage-rebuilt'));
    const page = await open(file);
    await chooseOption(page, 'storage', '1');
    await typeComment(page, 'storage', 'Keep it small');

    writePage(file, sampleData(['File', 'Column', 'Jsonb'], 'storage-rebuilt'));
    await reload(page);

    const text = await answersText(page);
    assert.match(text, /Q1 \[Storage\] Where do features live\?\nA: Jsonb\nComment: Keep it small/);
    assert.equal(await page.evaluate("document.querySelector('#q-storage input:checked').value"), '2');
  });

  test('show the answers of the form when a multi-choice question is rebuilt as single choice', async () => {
    const file = newFile();
    writePage(file, sampleData(undefined, 'storage-narrowed', true));
    const page = await open(file);
    await chooseOption(page, 'sides', '0');
    await chooseOption(page, 'sides', '1');

    writePage(file, sampleData(undefined, 'storage-narrowed', false));
    await reload(page);

    const checked = await page.evaluate("[...document.querySelectorAll('#q-sides input:checked')].map((input) => input.closest('label').querySelector('.option-label').textContent)");
    assert.equal(checked.length, 1);
    assert.match(await answersText(page), new RegExp(`Q2 \\[Sides\\] Which sides are reported\\?\\nA: ${checked[0]}\\n`));
  });

  test('loading the page writes nothing to storage', async () => {
    const file = newFile();
    writePage(file, sampleData());
    const counting = `(() => {
      window.storageWrites = [];
      const setItem = Storage.prototype.setItem;
      Storage.prototype.setItem = function (key, value) {
        if (key.startsWith(${JSON.stringify(PREFIX)}) && !key.endsWith(':probe')) window.storageWrites.push(key);
        return setItem.call(this, key, value);
      };
    })()`;

    const page = await open(file, counting);

    assert.deepEqual(await page.evaluate('window.storageWrites'), []);
  });

  describe('warning', () => {
    const failingStorage = 'Storage.prototype.setItem = () => { throw new DOMException("full", "QuotaExceededError"); };';

    test('shows when the browser refuses to save, at load and after an answer', async () => {
      const file = newFile();
      writePage(file, sampleData());

      const page = await open(file, failingStorage);
      assert.equal(await warningHidden(page), false);

      await chooseOption(page, 'storage', '0');
      assert.equal(await warningHidden(page), false);
    });

    test('stays hidden when the browser saves, before and after an answer', async () => {
      const file = newFile();
      writePage(file, sampleData());
      const page = await open(file);
      assert.equal(await warningHidden(page), true);

      await chooseOption(page, 'storage', '0');

      assert.equal(await warningHidden(page), true);
    });

    test('hides again once a save succeeds', async () => {
      const file = newFile();
      writePage(file, sampleData());
      const page = await open(file);
      await page.evaluate('window.realSetItem = Storage.prototype.setItem; Storage.prototype.setItem = () => { throw new Error("full"); }; 0');
      await chooseOption(page, 'storage', '0');
      assert.equal(await warningHidden(page), false);

      await page.evaluate('Storage.prototype.setItem = window.realSetItem; 0');
      await chooseOption(page, 'storage', '1');

      assert.equal(await warningHidden(page), true);
    });
  });

  test('save an answer even when rendering throws', async () => {
    const file = newFile();
    const breakRendering = "<script>document.getElementById('progress-text').remove();</script>";
    writePage(file, sampleData(), [breakRendering]);
    const page = await open(file);

    await chooseOption(page, 'storage', '1');
    await reload(page);

    assert.equal(await page.evaluate("document.querySelector('#q-storage input:checked')?.value"), '1');
  });
});
