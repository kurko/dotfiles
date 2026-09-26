// Finicky is the macOS default browser and sends each link to a real browser.
// Docs: https://github.com/johnste/finicky/wiki/Configuration-(v4)
// Tests: test/finicky_config_test.mjs
//
// Finicky reloads in-place edits, but stops watching this file once it is
// replaced (e.g. a git pull or checkout that changes it). Restart Finicky then.

export default {
  defaultBrowser: 'Safari',
  handlers: [
    {
      // Local apps served by puma-dev. A '*.test/*' wildcard string would not
      // work: Finicky matches wildcards against the full href, so it misses
      // URLs with a port (app.test:3000/) and matches paths with ".test/".
      match: (url) => url.hostname.endsWith('.test'),
      browser: 'Google Chrome',
    },
  ],
};
