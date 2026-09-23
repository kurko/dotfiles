#!/usr/bin/env node
// Builds a help-me-spec-interactive page from a round's parts and checks it. Exits 1 when a check fails.
import { readFileSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import { parseArgs } from 'node:util';
import { TEMPLATE_PATH, assemblePage, checkPage } from './page.mjs';

const USAGE = `usage:
  build-page.mjs --data data.json [--visuals visuals.html] [--include part.html]... --out page.html [--no-browser]
  build-page.mjs --check page.html [--no-browser]`;

const readJson = (file) => {
  try {
    return JSON.parse(readFileSync(file, 'utf8'));
  } catch (error) {
    throw new Error(`${file}: ${error.message}`);
  }
};

const build = ({ data, visuals, include = [], out }) => {
  if (!data || !out) throw new Error(USAGE);
  const html = assemblePage(readFileSync(TEMPLATE_PATH, 'utf8'), {
    data: readJson(data),
    visuals: visuals ? readFileSync(visuals, 'utf8') : '',
    includes: include.map((file) => readFileSync(file, 'utf8')),
  });
  writeFileSync(out, html);
  console.log(`build-page: wrote ${path.resolve(out)}`);
  return out;
};

const report = (file, { problems, questions, browserChecked, skipped }) => {
  if (problems.length) {
    console.log(`build-page: ${problems.length} problem(s) in ${path.resolve(file)}`);
    problems.forEach((problem) => console.log(`  - ${problem}`));
    return;
  }
  const browser = browserChecked ? 'rendered in headless Chrome without errors' : `browser check skipped${skipped ? ` (${skipped})` : ''}`;
  console.log(`build-page: ok, ${questions} questions, ${browser}`);
};

const main = () => {
  const { values } = parseArgs({
    options: {
      data: { type: 'string' },
      visuals: { type: 'string' },
      include: { type: 'string', multiple: true },
      out: { type: 'string' },
      check: { type: 'string' },
      'no-browser': { type: 'boolean' },
    },
  });
  const file = values.check ?? build(values);
  const result = checkPage(file, { browser: !values['no-browser'] });
  report(file, result);
  process.exitCode = result.problems.length ? 1 : 0;
};

try {
  main();
} catch (error) {
  console.error(`build-page: ${error.message}`);
  process.exitCode = 1;
}
