#!/usr/bin/env node

// Checks which browser finicky/finicky.js picks for a URL. Run with:
//   node --test test/finicky_config_test.mjs

import { test } from 'node:test';
import assert from 'node:assert/strict';

import config from '../finicky/finicky.js';

// Mirrors Finicky's openUrl: the first handler whose matcher accepts the URL
// wins, otherwise defaultBrowser. Finicky passes matchers a URL subclass.
// Only function matchers are supported, because Finicky's wildcard strings
// have their own semantics that this helper would have to copy.
const browserFor = (href) => {
  const url = new URL(href);
  const handler = config.handlers.find(({ match }) => matches(match, url));
  return handler ? handler.browser : config.defaultBrowser;
};

const matches = (match, url) => {
  assert.equal(typeof match, 'function', 'handlers must use function matchers');
  return match(url, { opener: null });
};

test('opens .test domains in Chrome', () => {
  assert.equal(browserFor('http://app.test/'), 'Google Chrome');
});

test('opens .test domains with a port in Chrome', () => {
  assert.equal(browserFor('http://app.test:3000/orders'), 'Google Chrome');
});

test('opens .test subdomains in Chrome', () => {
  assert.equal(browserFor('https://api.app.test/products?page=2'), 'Google Chrome');
});

test('opens other domains in Safari', () => {
  assert.equal(browserFor('https://example.com/'), 'Safari');
});

test('does not match .test in the path', () => {
  assert.equal(browserFor('https://example.com/docs.test/page'), 'Safari');
});

test('does not match hosts that only contain "test"', () => {
  assert.equal(browserFor('https://test.com/'), 'Safari');
  assert.equal(browserFor('https://example.testing.com/'), 'Safari');
  assert.equal(browserFor('http://latest/'), 'Safari');
});
