import { describe, test } from 'node:test';
import assert from 'node:assert/strict';
import vm from 'node:vm';
import { mkdtempSync, readFileSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import {
  SKILL_DIR,
  TEMPLATE_PATH,
  assemblePage,
  checkPage,
  dataProblems,
  engineSource,
  extractData,
  findChrome,
  staticProblems,
} from '../scripts/page.mjs';

const template = readFileSync(TEMPLATE_PATH, 'utf8');
const readSkillFile = (relative) => readFileSync(path.join(SKILL_DIR, relative), 'utf8');

const loadEngine = () => {
  const context = {};
  vm.runInNewContext(engineSource(template), context);
  return context.SpecForm;
};

const sampleData = () => ({
  id: 'demo-r1',
  title: 'Demo',
  round: 1,
  summary: 'What was explored.',
  sections: [
    {
      title: 'Scope',
      questions: [
        {
          id: 'storage',
          header: 'Storage',
          question: 'Where do features live?',
          options: [{ label: 'Column' }, { label: 'Jsonb', recommended: true }],
        },
        {
          id: 'sides',
          header: 'Sides',
          question: 'Which sides are reported?',
          multiSelect: true,
          options: [{ label: 'White' }, { label: 'Black' }],
        },
      ],
    },
    {
      title: 'Naming',
      questions: [
        {
          id: 'naming',
          header: 'Naming',
          question: 'Name it outpost?',
          options: [{ label: 'Yes' }, { label: 'No' }],
        },
      ],
    },
  ],
});

const emptyState = () => ({ choices: {}, comments: {}, general: '', nextStep: 'follow-up' });

const writeTemp = (name, content) => {
  const file = path.join(mkdtempSync(path.join(tmpdir(), 'hmsi-')), name);
  writeFileSync(file, content);
  return file;
};

const buildExample = () => assemblePage(template, {
  data: JSON.parse(readSkillFile('examples/pins/data.json')),
  visuals: readSkillFile('examples/pins/visuals.html'),
  includes: [readSkillFile('recipes/mermaid.html'), readSkillFile('recipes/chess.html')],
});

describe('answers text', () => {
  test('lists every question, marking the unanswered ones', () => {
    const text = loadEngine().formatAnswers(sampleData(), emptyState());

    assert.equal(text, [
      'help-me-spec-interactive answers',
      'Page: demo-r1 (round 1)',
      'Answered: 0 of 3',
      '',
      '## Scope',
      '',
      'Q1 [Storage] Where do features live?',
      'A: (no answer)',
      '',
      'Q2 [Sides] Which sides are reported?',
      'A: (no answer)',
      '',
      '## Naming',
      '',
      'Q3 [Naming] Name it outpost?',
      'A: (no answer)',
      '',
      '## Wrap-up',
      '',
      'Next step: Ask follow-up questions if you need to',
      '',
    ].join('\n'));
  });

  test('prints choices, Other, multi-line comments and the wrap-up', () => {
    const state = {
      choices: { storage: [1], sides: [0, 'other'] },
      comments: { storage: 'Keep it small\nlike weak squares', sides: '  also none  ' },
      general: 'Ship the smallest version\nfirst',
      nextStep: 'write-spec',
    };

    const text = loadEngine().formatAnswers(sampleData(), state);

    assert.equal(text, [
      'help-me-spec-interactive answers',
      'Page: demo-r1 (round 1)',
      'Answered: 2 of 3',
      '',
      '## Scope',
      '',
      'Q1 [Storage] Where do features live?',
      'A: Jsonb',
      'Comment: Keep it small',
      '  like weak squares',
      '',
      'Q2 [Sides] Which sides are reported?',
      'A: White; Other',
      'Comment: also none',
      '',
      '## Naming',
      '',
      'Q3 [Naming] Name it outpost?',
      'A: (no answer)',
      '',
      '## Wrap-up',
      '',
      'Next step: Stop asking and write the spec',
      'General comment: Ship the smallest version',
      '  first',
      '',
    ].join('\n'));
  });

  test('counts a question with only a comment as unanswered', () => {
    const state = { ...emptyState(), comments: { naming: 'not sure' } };

    const text = loadEngine().formatAnswers(sampleData(), state);

    assert.match(text, /^Answered: 0 of 3$/m);
    assert.match(text, /Q3 \[Naming\] Name it outpost\?\nA: \(no answer\)\nComment: not sure/);
  });
});

describe('storageKey', () => {
  test('stays the same when only wording outside the options changes', () => {
    const data = sampleData();
    const edited = { ...sampleData(), summary: 'Reworded.' };
    edited.sections[0].questions[0].context = 'Added context.';

    assert.equal(loadEngine().storageKey(edited), loadEngine().storageKey(data));
  });

  test('changes when options move, so saved indexes never land on another option', () => {
    const data = sampleData();
    const reordered = sampleData();
    reordered.sections[0].questions[0].options.reverse();

    assert.match(loadEngine().storageKey(data), /^help-me-spec-interactive:demo-r1:[0-9a-z]+$/);
    assert.notEqual(loadEngine().storageKey(reordered), loadEngine().storageKey(data));
  });
});

describe('dataProblems', () => {
  test('accepts a well-formed page', () => {
    assert.deepEqual(dataProblems(sampleData()), []);
  });

  test('accepts the example page', () => {
    assert.deepEqual(dataProblems(JSON.parse(readSkillFile('examples/pins/data.json'))), []);
  });

  test('names unknown keys, so help-me-spec spellings are caught', () => {
    const data = sampleData();
    data.sections[0].questions[1].multi_select = true;
    delete data.sections[0].questions[1].multiSelect;

    assert.deepEqual(dataProblems(data), ['question "sides": unknown key "multi_select"']);
  });

  test('rejects duplicate ids, missing question marks and too few options', () => {
    const data = sampleData();
    data.sections[1].questions[0].id = 'storage';
    data.sections[1].questions[0].question = 'Name it outpost';
    data.sections[1].questions[0].options = [{ label: 'Yes' }];

    assert.deepEqual(dataProblems(data), [
      'question "storage": the id is used twice',
      'question "storage": the question should end with "?"',
      'question "storage": needs 2 to 6 options (the page adds "Other" itself), has 1',
    ]);
  });

  test('rejects a second recommended option on a single-choice question', () => {
    const data = sampleData();
    data.sections[0].questions[0].options[0].recommended = true;

    assert.deepEqual(dataProblems(data), ['question "storage": recommends 2 options but takes one answer']);
  });

  test('requires a recommended option under a Defaults section, since silence accepts it', () => {
    const data = sampleData();
    data.sections[1].title = "Defaults I'll use unless you object";

    assert.deepEqual(dataProblems(data), ['question "naming": sits under "Defaults…", so it needs a recommended option for silence to accept']);
  });

  test('rejects an Other option written by hand', () => {
    const data = sampleData();
    data.sections[1].questions[0].options.push({ label: 'Other' });

    assert.deepEqual(dataProblems(data), ['question "naming": drop the "Other" option; the page adds one to every question']);
  });

  test('checks the page fields', () => {
    const data = { ...sampleData(), id: 'Demo Round', round: 0, sections: [] };

    assert.deepEqual(dataProblems(data), [
      'page: "id" must be kebab-case, got "Demo Round"',
      'page: "round" must be a whole number from 1, got 0',
      'page: "sections" needs at least one section',
    ]);
  });
});

describe('assemblePage', () => {
  test('embeds data that survives script-closing text and replacement patterns', () => {
    const data = sampleData();
    data.summary = 'Ends with </script><!-- and $& and $1';

    const html = assemblePage(template, { data });

    assert.deepEqual(extractData(html), data);
    assert.equal((html.match(/<\/script>/g) || []).length, (template.match(/<\/script>/g) || []).length);
  });

  test('sets an escaped title', () => {
    const data = { ...sampleData(), title: 'Pawns & <holes>' };

    assert.match(assemblePage(template, { data }), /<title>Pawns &amp; &lt;holes&gt; · spec questions, round 1<\/title>/);
  });

  test('fails on a template without its markers', () => {
    assert.throws(() => assemblePage('<html></html>', { data: sampleData() }), /missing markers: title, visuals, data, includes/);
  });

  test('uses each template marker exactly once', () => {
    ['title', 'visuals', 'data', 'includes'].forEach((name) => {
      assert.equal(template.split(`<!-- @${name} -->`).length, 2, name);
    });
  });
});

describe('staticProblems', () => {
  const pageWith = ({ data = sampleData(), visuals = '', includes = [] } = {}) =>
    assemblePage(template, { data, visuals, includes });

  test('passes a plain page and the example with both recipes', () => {
    assert.deepEqual(staticProblems(pageWith(), template), []);
    assert.deepEqual(staticProblems(buildExample(), template), []);
  });

  test('reports missing and unused visuals', () => {
    const data = sampleData();
    data.sections[0].questions[0].visual = 'storage-diagram';

    const problems = staticProblems(pageWith({ data, visuals: '<template id="spare"><p>x</p></template>' }), template);

    assert.deepEqual(problems, [
      'visual "storage-diagram" has no <template id="storage-diagram">',
      '<template id="spare"> is not used by any question or option',
    ]);
  });

  test('reports an engine that differs from the template', () => {
    const edited = pageWith().replace("const OTHER = 'other';", "const OTHER = 'else';");

    assert.deepEqual(staticProblems(edited, template), ['the engine script differs from form-template.html; rebuild the page']);
  });

  test('requires scripts from any host to use https, an exact version and a hash', () => {
    const includes = [
      '<script src="https://unpkg.com/d3@7.9.0/dist/d3.min.js" integrity="sha384-x" crossorigin="anonymous"></script>',
      '<script src="https://cdnjs.cloudflare.com/ajax/libs/lodash.js/4.17.21/lodash.min.js"></script>',
      '<script src="https://cdn.jsdelivr.net/npm/d3/dist/d3.min.js" integrity="sha384-x" crossorigin="anonymous"></script>',
      '<script src="http://cdn.example.com/x@1.0.0/x.js" integrity="sha384-x" crossorigin="anonymous"></script>',
      '<script src="./helpers.js"></script>',
      '<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Inter">',
      '<link rel="modulepreload" href="https://cdn.jsdelivr.net/npm/d3@7.9.0/dist/d3.min.js">',
    ];

    assert.deepEqual(staticProblems(pageWith({ includes }), template), [
      'https://cdnjs.cloudflare.com/ajax/libs/lodash.js/4.17.21/lodash.min.js: add integrity="sha384-…" and crossorigin="anonymous"',
      'https://cdn.jsdelivr.net/npm/d3/dist/d3.min.js: pin an exact version (x.y.z) in the URL',
      'http://cdn.example.com/x@1.0.0/x.js: load it over https',
      './helpers.js: a copied page would lose it; load it over https or inline it',
      'https://cdn.jsdelivr.net/npm/d3@7.9.0/dist/d3.min.js: only stylesheets may be linked',
    ]);
  });

  test('takes the version from the package in the path, not from anything version-shaped', () => {
    const hashed = (url) => `<script src="${url}" integrity="sha384-x" crossorigin="anonymous"></script>`;
    const urls = [
      'https://cdn.jsdelivr.net/npm/a@7/dist/a.js',
      'https://cdn.jsdelivr.net/npm/b@^1.4.0/dist/b.js',
      'https://cdn.jsdelivr.net/npm/c@latest/dist/1.0.0/c.js',
      'https://cdn.example.com/d/dist/d.js?deps=react@18.2.0',
      'https://cdn.jsdelivr.net/npm/@scope/e@1.0.0+build.5/dist/e.js',
      'https://cdnjs.cloudflare.com/ajax/libs/f.js/2.0.1/f.min.js',
    ];

    assert.deepEqual(staticProblems(pageWith({ includes: urls.map(hashed) }), template), urls.slice(0, 4).map((url) => `${url}: pin an exact version (x.y.z) in the URL`));
  });

  test('reads library tags however their attributes are quoted or cased', () => {
    const includes = [
      "<script src='https://unpkg.com/a@1.0.0/a.js'></script>",
      '<script src=https://unpkg.com/b@1.0.0/b.js></script>',
      '<SCRIPT SRC="https://unpkg.com/c@1.0.0/c.js"></SCRIPT>',
      '<script src = "https://unpkg.com/d@1.0.0/d.js"></script>',
      "<link rel='stylesheet' href='./local.css'>",
    ];
    const unhashed = (url) => `${url}: add integrity="sha384-…" and crossorigin="anonymous"`;

    assert.deepEqual(staticProblems(pageWith({ includes }), template), [
      unhashed('https://unpkg.com/a@1.0.0/a.js'),
      unhashed('https://unpkg.com/b@1.0.0/b.js'),
      unhashed('https://unpkg.com/c@1.0.0/c.js'),
      unhashed('https://unpkg.com/d@1.0.0/d.js'),
      './local.css: a copied page would lose it; load it over https or inline it',
    ]);
  });

  test('requires module imports to pin a version and be listed in an import map with a hash', () => {
    const url = 'https://cdn.jsdelivr.net/npm/chess.js@1.4.0/dist/esm/chess.js';
    const includes = [`<script type="module">import { Chess } from '${url}'; import { x } from 'https://cdn.jsdelivr.net/npm/x/dist/x.js';</script>`];

    assert.deepEqual(staticProblems(pageWith({ includes }), template), [
      `${url}: list it under "integrity" in a <script type="importmap"> so the browser checks its hash`,
      'https://cdn.jsdelivr.net/npm/x/dist/x.js: pin an exact version (x.y.z) in the URL',
    ]);
  });

  test('checks the URLs an import map maps names to', () => {
    const pinned = 'https://cdn.jsdelivr.net/npm/nanoid@5.1.5/index.browser.js';
    const includes = [
      `<script type="importmap">{ "imports": { "nanoid": "https://cdn.jsdelivr.net/npm/nanoid/+esm" }, "scopes": { "/": { "id": "${pinned}" } } }</script>`,
      '<script type="importmap">{ "imports": </script>',
    ];

    assert.deepEqual(staticProblems(pageWith({ includes }), template), [
      'https://cdn.jsdelivr.net/npm/nanoid/+esm: pin an exact version (x.y.z) in the URL',
      `${pinned}: list it under "integrity" in a <script type="importmap"> so the browser checks its hash`,
      'an import map is not valid JSON',
    ]);
  });

  test('rejects media and CSS files a copied page would lose, allowing https, data: URIs and #fragments', () => {
    const includes = [
      '<img src="./board.png" alt="">',
      '<img src="https://example.com/board.png" alt="">',
      '<svg><image href="//example.com/piece.png"/><use href="#piece"/></svg>',
      '<iframe src="https://example.com/page.html"></iframe>',
      '<frame src="https://example.com/frame.html">',
      '<embed src="https://example.com/plugin.swf">',
      '<object data="https://example.com/doc.pdf"></object>',
      '<iframe src="data:text/html,<p>inline</p>"></iframe>',
      '<video poster="file:///tmp/poster.png"></video>',
      '<img src="http://example.com/board.png" alt="">',
      '<img src="data:image/png;base64,AAAA" alt="">',
      '<div style="background: url(./board.png)"></div>',
      '<style>@import url("https://fonts.googleapis.com/css2?family=Inter"); .x { background: url(https://example.com/a.png) }</style>',
      '<svg><defs><linearGradient id="g"/></defs><rect fill="url(#g)"/></svg>',
    ];
    const local = (url) => `${url}: a copied page would lose it; load it over https or inline it`;

    const framed = (url) => `${url}: a framed document runs its own code; embed it as a data: URI or draw it inline`;

    assert.deepEqual(staticProblems(pageWith({ includes }), template), [
      local('./board.png'),
      local('//example.com/piece.png'),
      framed('https://example.com/page.html'),
      framed('https://example.com/frame.html'),
      framed('https://example.com/plugin.swf'),
      framed('https://example.com/doc.pdf'),
      local('file:///tmp/poster.png'),
      'http://example.com/board.png: load it over https',
      local('./board.png'),
    ]);
  });

  test('rejects requests from scripts', () => {
    const includes = ['<script>fetch("/api");</script>'];

    assert.deepEqual(staticProblems(pageWith({ includes }), template), [
      'an inline script makes a network request (fetch); embed the data in the page when it is built',
    ]);
  });

  test('reports a chess or Mermaid visual whose recipe is not included', () => {
    const data = sampleData();
    data.sections[0].questions[0].visual = 'board';
    data.sections[0].questions[1].visual = 'flow';
    const visuals = '<template id="board"><div data-chess-board=""></div></template>\n<template id="flow"><pre class="mermaid">flowchart LR\n  a --> b</pre></template>';

    assert.deepEqual(staticProblems(pageWith({ data, visuals }), template), [
      'a visual uses data-chess-board or data-chess-line; add --include recipes/chess.html',
      'a visual uses class="mermaid"; add --include recipes/mermaid.html',
    ]);
    assert.deepEqual(staticProblems(pageWith({
      data,
      visuals,
      includes: [readSkillFile('recipes/chess.html'), readSkillFile('recipes/mermaid.html')],
    }), template), []);
  });

  test('reports data that is not valid JSON', () => {
    const broken = pageWith().replace('"id": "demo-r1"', '"id": demo');

    assert.match(staticProblems(broken, template)[0], /^the spec-data block is not valid JSON: /);
  });
});

describe('checkPage in a browser', { skip: findChrome() ? false : 'no Chrome found' }, () => {
  test('renders the example with both recipes and no errors', () => {
    const report = checkPage(writeTemp('example.html', buildExample()));

    assert.deepEqual(report.problems, []);
    assert.equal(report.browserChecked, true);
  });

  test('reports an error thrown by an include', () => {
    const html = assemblePage(template, { data: sampleData(), includes: ['<script>throw new Error("visual broke");</script>'] });

    const report = checkPage(writeTemp('throws.html', html));

    assert.deepEqual(report.problems, ['browser: Uncaught Error: visual broke']);
  });

  test('reports an illegal move in a chess line', () => {
    const data = sampleData();
    data.sections[0].questions[0].visual = 'line';
    const visuals = '<template id="line"><div data-chess-line="" data-moves="e4 e5 Ke3"></div></template>';
    const html = assemblePage(template, { data, visuals, includes: [readSkillFile('recipes/chess.html')] });

    const [problem, ...rest] = checkPage(writeTemp('illegal.html', html)).problems;

    assert.match(problem, /^browser: chess line "e4 e5 Ke3": .*Ke3/);
    assert.deepEqual(rest, []);
  });

  test('reports a malformed board', () => {
    const data = sampleData();
    data.sections[0].questions[0].visual = 'board';
    const visuals = '<template id="board"><div data-chess-board="8/8/8/8/8/8/8"></div></template>';
    const html = assemblePage(template, { data, visuals, includes: [readSkillFile('recipes/chess.html')] });

    assert.deepEqual(checkPage(writeTemp('malformed.html', html)).problems, [
      'browser: chess board "8/8/8/8/8/8/8": "8/8/8/8/8/8/8" does not have 8 ranks',
    ]);
  });

  test('reports a Mermaid diagram that does not parse', () => {
    const data = sampleData();
    data.sections[0].questions[0].visual = 'flow';
    const visuals = '<template id="flow"><pre class="mermaid">flowchart LR\n  a[unclosed --> b</pre></template>';
    const html = assemblePage(template, { data, visuals, includes: [readSkillFile('recipes/mermaid.html')] });

    const [problem, ...rest] = checkPage(writeTemp('mermaid-parse.html', html)).problems;

    assert.match(problem, /^browser: mermaid: Parse error/);
    assert.deepEqual(rest, []);
  });

  test('reports a Mermaid script that fails its hash', () => {
    const recipe = readSkillFile('recipes/mermaid.html').replace('sha384-yQ4', 'sha384-xQ4');
    const html = assemblePage(template, { data: sampleData(), includes: [recipe] });

    assert.deepEqual(checkPage(writeTemp('mermaid-hash.html', html)).problems, [
      'browser: failed to load https://cdnjs.cloudflare.com/ajax/libs/mermaid/11.15.0/mermaid.min.js',
    ]);
  });

  test('reports chess.js failing its hash when a line needs it', () => {
    const data = sampleData();
    data.sections[0].questions[0].visual = 'line';
    const visuals = '<template id="line"><div data-chess-line="" data-moves="e4 e5"></div></template>';
    const recipe = readSkillFile('recipes/chess.html').replace('sha384-A9K', 'sha384-B9K');
    const html = assemblePage(template, { data, visuals, includes: [recipe] });

    const [problem, ...rest] = checkPage(writeTemp('chess-hash.html', html)).problems;

    assert.match(problem, /^browser: chess\.js did not load: /);
    assert.deepEqual(rest, []);
  });
});
