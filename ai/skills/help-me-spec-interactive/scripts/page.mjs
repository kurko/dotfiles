// Assembles help-me-spec-interactive pages and checks them. build-page.mjs is the command line; the tests import this.
import { execFileSync } from 'node:child_process';
import { existsSync, readFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

export const SKILL_DIR = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
export const TEMPLATE_PATH = path.join(SKILL_DIR, 'form-template.html');

const MARKERS = ['title', 'visuals', 'data', 'includes'];
const KEBAB = /^[a-z0-9]+(?:-[a-z0-9]+)*$/;
const PAGE_KEYS = ['id', 'title', 'round', 'summary', 'sections'];
const SECTION_KEYS = ['title', 'intro', 'questions'];
const QUESTION_KEYS = ['id', 'header', 'question', 'context', 'visual', 'multiSelect', 'options'];
const OPTION_KEYS = ['label', 'description', 'recommended', 'visual'];
const PINNED_LIBRARY = [
  /^https:\/\/cdnjs\.cloudflare\.com\/ajax\/libs\/[^/]+\/\d+\.\d+\.\d+[^/]*\//,
  /^https:\/\/cdn\.jsdelivr\.net\/npm\/(?:@[^/]+\/)?[^/@]+@\d+\.\d+\.\d+[^/]*\//,
];
const NOT_PINNED = 'not a pinned library URL (cdnjs.cloudflare.com/ajax/libs/<lib>/<x.y.z>/ or cdn.jsdelivr.net/npm/<pkg>@<x.y.z>/)';
const CHROME_CANDIDATES = [
  process.env.CHROME_BIN,
  '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
  '/Applications/Chromium.app/Contents/MacOS/Chromium',
  '/usr/bin/google-chrome',
  '/usr/bin/chromium',
];

const marker = (name) => `<!-- @${name} -->`;

const escapeHtml = (text) => String(text).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');

// JSON only has "<" inside strings, where < means the same; no "</script>" or "<!--" can reach the HTML parser.
const serializeData = (data) => JSON.stringify(data, null, 2).replace(/</g, '\\u003c');

export const assemblePage = (template, { data, visuals = '', includes = [] }) => {
  const missing = MARKERS.filter((name) => !template.includes(marker(name)));
  if (missing.length) throw new Error(`template is missing markers: ${missing.join(', ')}`);
  const parts = {
    title: escapeHtml(`${data.title} · spec questions, round ${data.round}`),
    visuals: visuals.trim(),
    data: serializeData(data),
    includes: includes.map((part) => part.trim()).join('\n\n'),
  };
  return MARKERS.reduce((html, name) => html.replace(marker(name), () => parts[name]), template);
};

const scriptById = (html, id) => html.match(new RegExp(`<script id="${id}"[^>]*>([\\s\\S]*?)</script>`))?.[1];

export const extractData = (html) => JSON.parse(scriptById(html, 'spec-data') ?? '');

export const engineSource = (html) => scriptById(html, 'spec-engine') ?? '';

// Data schema

const isText = (value) => typeof value === 'string' && value.trim() !== '';

const unknownKeys = (object, allowed, where) => Object.keys(object)
  .filter((key) => !allowed.includes(key))
  .map((key) => `${where}: unknown key "${key}"`);

const optionProblems = (question, where) => {
  const options = Array.isArray(question.options) ? question.options : [];
  const count = options.length;
  const recommended = options.filter((option) => option.recommended === true).length;
  return [
    ...(count < 2 || count > 6 ? [`${where}: needs 2 to 6 options (the page adds "Other" itself), has ${count}`] : []),
    ...(options.some((option) => /^other\b/i.test(option.label ?? '')) ? [`${where}: drop the "Other" option; the page adds one to every question`] : []),
    ...(!question.multiSelect && recommended > 1 ? [`${where}: recommends ${recommended} options but takes one answer`] : []),
    ...options.flatMap((option, index) => [
      ...unknownKeys(option, OPTION_KEYS, `${where} option ${index + 1}`),
      ...(isText(option.label) ? [] : [`${where} option ${index + 1}: needs a label`]),
    ]),
  ];
};

const questionProblems = (question, seenIds) => {
  const where = `question "${question.id}"`;
  const duplicate = seenIds.has(question.id);
  seenIds.add(question.id);
  return [
    ...unknownKeys(question, QUESTION_KEYS, where),
    ...(typeof question.id === 'string' && KEBAB.test(question.id) ? [] : [`${where}: "id" must be kebab-case`]),
    ...(duplicate ? [`${where}: the id is used twice`] : []),
    ...(isText(question.header) ? [] : [`${where}: needs a "header"`]),
    ...(isText(question.question) && question.question.trim().endsWith('?') ? [] : [`${where}: the question should end with "?"`]),
    ...optionProblems(question, where),
  ];
};

const defaultsProblems = (section, questions) => (/^defaults\b/i.test(section.title ?? '') ? questions : [])
  .filter((question) => !(question.options ?? []).some((option) => option.recommended === true))
  .map((question) => `question "${question.id}": sits under "Defaults…", so it needs a recommended option for silence to accept`);

const sectionProblems = (section, index, seenIds) => {
  const where = `section ${index + 1}`;
  const questions = Array.isArray(section.questions) ? section.questions : [];
  return [
    ...unknownKeys(section, SECTION_KEYS, where),
    ...(isText(section.title) ? [] : [`${where}: needs a "title"`]),
    ...(questions.length ? [] : [`${where}: needs at least one question`]),
    ...questions.flatMap((question) => questionProblems(question, seenIds)),
    ...defaultsProblems(section, questions),
  ];
};

export const dataProblems = (data) => {
  const sections = Array.isArray(data.sections) ? data.sections : [];
  const seenIds = new Set();
  return [
    ...unknownKeys(data, PAGE_KEYS, 'page'),
    ...(typeof data.id === 'string' && KEBAB.test(data.id) ? [] : [`page: "id" must be kebab-case, got ${JSON.stringify(data.id)}`]),
    ...(isText(data.title) ? [] : ['page: needs a "title"']),
    ...(Number.isInteger(data.round) && data.round >= 1 ? [] : [`page: "round" must be a whole number from 1, got ${JSON.stringify(data.round)}`]),
    ...(isText(data.summary) ? [] : ['page: needs a "summary" of what was explored']),
    ...(sections.length ? [] : ['page: "sections" needs at least one section']),
    ...sections.flatMap((section, index) => sectionProblems(section, index, seenIds)),
  ];
};

const questionsOf = (data) => data.sections.flatMap((section) => section.questions);

// Visuals

const visualReferences = (data) => questionsOf(data).flatMap((question) => [
  question.visual,
  ...question.options.map((option) => option.visual),
]).filter(Boolean);

const withoutScripts = (html) => html.replace(/<script\b[^>]*>[\s\S]*?<\/script>/gi, '');

const templateIds = (html) => [...withoutScripts(html).matchAll(/<template\b[^>]*\bid="([^"]+)"/g)].map((match) => match[1]);

const visualProblems = (html, data) => {
  const references = visualReferences(data);
  const defined = templateIds(html);
  return [
    ...[...new Set(references)].filter((id) => !defined.includes(id)).map((id) => `visual "${id}" has no <template id="${id}">`),
    ...defined.filter((id) => !references.includes(id)).map((id) => `<template id="${id}"> is not used by any question or option`),
  ];
};

// Recipes: a visual that needs one is inert without it

const RECIPES = [
  { name: 'chess', uses: /\sdata-chess-(?:board|line)\s*=/i, label: 'data-chess-board or data-chess-line' },
  { name: 'mermaid', uses: /\sclass\s*=\s*["']?[^"'>]*\bmermaid\b/i, label: 'class="mermaid"' },
];

const recipeIncluded = (html, name) => new RegExp(`<script\\b[^>]*\\sdata-recipe\\s*=\\s*["']?${name}\\b`, 'i').test(html);

const recipeProblems = (html) => {
  const markup = withoutScripts(html);
  return RECIPES
    .filter((recipe) => recipe.uses.test(markup) && !recipeIncluded(html, recipe.name))
    .map((recipe) => `a visual uses ${recipe.label}; add --include recipes/${recipe.name}.html`);
};

// Network and files: pinned, hash-checked libraries from two CDNs; everything else is inline, so a copied page still works

const attribute = (tag, name) => {
  const match = tag.match(new RegExp(`\\s${name}\\s*=\\s*(?:"([^"]*)"|'([^']*)'|([^\\s"'=<>\`]+))`, 'i'));
  return match ? (match[1] ?? match[2] ?? match[3]) : undefined;
};

const standsAlone = (url) => /^(?:data:|#)/i.test(url.trim());

const withoutData = (html) => html.replace(/<script id="spec-data"[^>]*>[\s\S]*?<\/script>/, '');

const inlineScripts = (html) => [...withoutData(html).matchAll(/<script\b([^>]*)>([\s\S]*?)<\/script>/gi)]
  .filter(([, attributes]) => attribute(attributes, 'src') === undefined)
  .map(([, attributes, body]) => ({ type: (attribute(attributes, 'type') ?? '').toLowerCase(), body }));

const importMapIntegrity = (html) => inlineScripts(html)
  .filter((script) => script.type === 'importmap')
  .flatMap((script) => {
    try { return Object.keys(JSON.parse(script.body).integrity ?? {}); } catch { return []; }
  });

const libraryTagProblems = (html) => [...html.matchAll(/<(script|link)\b[^>]*>/gi)].flatMap(([tag, name]) => {
  const url = attribute(tag, name.toLowerCase() === 'script' ? 'src' : 'href');
  if (!url) return [];
  if (!PINNED_LIBRARY.some((pattern) => pattern.test(url))) return [`${url}: ${NOT_PINNED}`];
  if (name.toLowerCase() === 'link' && attribute(tag, 'rel')?.toLowerCase() !== 'stylesheet') return [`${url}: only stylesheets may be linked`];
  const hashed = /^sha(256|384|512)-/.test(attribute(tag, 'integrity') ?? '') && attribute(tag, 'crossorigin') === 'anonymous';
  return hashed ? [] : [`${url}: add integrity="sha384-…" and crossorigin="anonymous"`];
});

const MEDIA_TAGS = /<(?:img|iframe|frame|audio|video|source|embed|object|track|image|use|feimage|input)\b[^>]*>/gi;
const MEDIA_ATTRIBUTES = ['src', 'srcset', 'data', 'href', 'xlink:href', 'poster'];

const mediaUrls = (tag) => MEDIA_ATTRIBUTES.flatMap((name) => {
  const value = attribute(tag, name);
  if (value === undefined) return [];
  return name === 'srcset' && !/^data:/i.test(value) ? value.split(',').map((candidate) => candidate.trim().split(/\s+/)[0]) : [value];
});

const mediaProblems = (html) => [...html.matchAll(MEDIA_TAGS)]
  .flatMap(([tag]) => mediaUrls(tag))
  .filter((url) => !standsAlone(url))
  .map((url) => `${url}: the page must stand alone; inline media as SVG or a data: URI`);

const cssUrlProblems = (markup) => [
  ...[...markup.matchAll(/url\(\s*['"]?([^'")\s]+)/gi)]
    .map(([, url]) => url)
    .filter((url) => !standsAlone(url))
    .map((url) => `${url}: the page must stand alone; CSS may only use data: URIs and #fragments`),
  ...[...markup.matchAll(/@import\s+(?:url\()?\s*['"]?([^'");\s]+)/gi)].map(([, url]) => `${url}: stylesheets may not import files`),
];

const scriptUrlProblems = (html) => {
  const hashed = importMapIntegrity(html);
  const scripts = inlineScripts(html).filter((script) => script.type !== 'importmap' && script.type !== 'application/json');
  const urls = scripts.flatMap((script) => [...script.body.matchAll(/['"`](https?:\/\/[^'"`\s]+)['"`]/g)].map((match) => match[1]));
  return [...new Set(urls)].flatMap((url) => {
    if (!PINNED_LIBRARY.some((pattern) => pattern.test(url))) return [`${url}: ${NOT_PINNED}`];
    return hashed.includes(url) ? [] : [`${url}: list it under "integrity" in a <script type="importmap"> so the browser checks its hash`];
  });
};

const requestProblems = (html) => inlineScripts(html)
  .flatMap((script) => [...script.body.matchAll(/\b(fetch|XMLHttpRequest|WebSocket|EventSource|sendBeacon)\s*\(/g)].map((match) => match[1]))
  .map((call) => `an inline script makes a network request (${call}); the page may only load pinned libraries`);

const networkProblems = (html) => {
  const scanned = withoutData(html);
  return [
    ...libraryTagProblems(scanned),
    ...mediaProblems(scanned),
    ...cssUrlProblems(withoutScripts(scanned)),
    ...scriptUrlProblems(html),
    ...requestProblems(html),
  ];
};

// Whole page

const parsedData = (html) => {
  try {
    return { data: extractData(html) };
  } catch (error) {
    return { error: `the spec-data block is not valid JSON: ${error.message}` };
  }
};

export const staticProblems = (html, template) => {
  const { data, error } = parsedData(html);
  if (error) return [error];
  const schema = dataProblems(data);
  return [
    ...schema,
    ...(schema.length ? [] : visualProblems(html, data)),
    ...recipeProblems(html),
    ...(engineSource(html) === engineSource(template) ? [] : ['the engine script differs from form-template.html; rebuild the page']),
    ...networkProblems(html),
  ];
};

// Browser: headless Chrome runs the page and reads what the page recorded on <html>

export const findChrome = () => CHROME_CANDIDATES.find((candidate) => candidate && existsSync(candidate));

const decodeEntities = (text) => text
  .replace(/&quot;/g, '"').replace(/&#39;/g, "'").replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&amp;/g, '&');

// No --user-data-dir: headless already uses a throwaway profile, and a fresh one kept Chrome alive for a minute after the dump.
const renderedDom = (chrome, file) => execFileSync(chrome, [
  '--headless', '--disable-gpu', '--no-first-run', '--virtual-time-budget=15000', '--dump-dom', pathToFileURL(file).href,
], { encoding: 'utf8', timeout: 60_000, maxBuffer: 256 * 1024 * 1024, stdio: ['ignore', 'pipe', 'ignore'] });

const renderedState = (dom) => {
  const tag = dom.match(/<html\b[^>]*>/)?.[0] ?? '';
  const read = (name) => {
    const value = attribute(tag, name);
    return value === undefined ? undefined : decodeEntities(value);
  };
  return { ready: read('data-spec-form') === 'ready', questions: Number(read('data-spec-questions')), errors: JSON.parse(read('data-spec-errors') ?? '[]') };
};

export const browserProblems = (file, expectedQuestions) => {
  const chrome = findChrome();
  if (!chrome) return { problems: [], skipped: 'no Chrome found; set CHROME_BIN to run the browser check' };
  const state = renderedState(renderedDom(chrome, file));
  const problems = state.errors.map((message) => `browser: ${message}`);
  if (!state.ready) problems.push('browser: the form never finished rendering');
  else if (state.questions !== expectedQuestions) problems.push(`browser: rendered ${state.questions} questions, the data has ${expectedQuestions}`);
  return { problems };
};

export const checkPage = (file, { browser = true } = {}) => {
  const html = readFileSync(file, 'utf8');
  const problems = staticProblems(html, readFileSync(TEMPLATE_PATH, 'utf8'));
  if (problems.length) return { problems, browserChecked: false };
  const questions = questionsOf(extractData(html)).length;
  if (!browser) return { problems, questions, browserChecked: false };
  const rendered = browserProblems(file, questions);
  return { problems: rendered.problems, questions, browserChecked: !rendered.skipped, skipped: rendered.skipped };
};
