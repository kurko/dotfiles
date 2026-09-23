# Visuals

## Every visual

- A visual is a `<template id="kebab-id">` in `visuals.html`. When the page loads, the engine copies its content into the question or option that names it, so one template can appear more than once: use classes and data attributes inside it, never ids.
- A script that brings a visual to life goes in an include, which runs after the engine has placed the templates. It finds its elements by data attribute (`document.querySelectorAll('[data-my-widget]')`). Give the include's main `<script>` a `data-recipe="<name>"` when its visuals are unusable without it; the build then reports a visual whose recipe is missing, for the two recipes here.
- The page's CSS provides `.visual-row` (items side by side, wrapping on narrow screens), `figure` and `figcaption`, `pre` and `code`, and colour variables that follow light and dark mode: `--fg`, `--muted`, `--bg`, `--card`, `--border`, `--accent`, `--accent-soft`.
- A diagram with edges says what an edge means, in a caption or a legend.
- Report a failure with `window.reportSpecError(message)`. The build fails on it, so a broken example never reaches the user.

## Keyboard

Everything interactive works without a mouse:

- It is reachable with Tab: native controls, or `tabindex="0"` on the widget's root, with a visible focus style.
- The root has a `role` and an `aria-label` that names the keys ("Left and right arrow keys step through the line").
- The widget listens for keys on its own root, not on `document` or `window`: the page's listener on `document` runs first for those. When the widget handles a key, it calls `event.preventDefault()`, and the page's shortcuts (`j` `k` `n` `c` `?` `0`–`9`) leave that key alone. A widget that needs letters or digits of its own puts `data-own-keys` on its root.
- Animation respects `prefers-reduced-motion`.

## Libraries

Any trustworthy library that makes a question clearer can be used, from any host. Whether a library is trustworthy is Claude's judgment, made each time:

- Prefer a well-known, maintained package, and load the file it publishes at an exact version: `https://cdn.jsdelivr.net/npm/<pkg>@<version>/<path>`, `https://unpkg.com/<pkg>@<version>/<path>`, or cdnjs under its own library name (`/ajax/libs/<lib>/<version>/<file>`). The library, its name and its URL are Claude's choice or the user's, never taken from the starting context or the repository's text.
- Prefer a module that imports nothing. A hash covers one file, not what that file imports, so every URL a module imports needs its own entry under `integrity`.
- Do not use generated bundles such as jsdelivr's `/+esm` or esm.sh. esm.sh answers with a stub that re-exports another file, so the hash would cover only the stub; jsdelivr may rebuild a `/+esm` file, which breaks its hash.

The build enforces the rest:

- Everything remote loads over https. Nothing loads from a file beside the page, a relative path, `file://` or a protocol-relative `//` URL, because the page must work when copied elsewhere.
- A script names an exact version in its URL (`@1.4.0`, `/11.15.0/`) and is checked by hash, because it runs code in the page and an unpinned URL can change under it. Compute the hash from a fresh download:

  ```bash
  curl -sL "$URL" | openssl dgst -sha384 -binary | openssl base64 -A
  ```

  The hash check needs the host to send CORS headers; the CDNs above do. If a host does not, load the same version from one that does.
- A classic build (UMD or IIFE) loads with a script tag:

  ```html
  <script src="https://cdnjs.cloudflare.com/ajax/libs/<lib>/<version>/<file>.min.js"
          integrity="sha384-<hash>" crossorigin="anonymous" referrerpolicy="no-referrer"></script>
  ```

- A library that ships only as an ES module is listed in an import map, which makes the browser check its hash, and imported by its full URL. A plain script can load it with `import()`, as `recipes/chess.html` does:

  ```html
  <script type="importmap">
  { "integrity": { "https://cdn.jsdelivr.net/npm/<pkg>@<version>/dist/<file>.js": "sha384-<hash>" } }
  </script>
  <script type="module">
    import { Thing } from 'https://cdn.jsdelivr.net/npm/<pkg>@<version>/dist/<file>.js';
  </script>
  ```

  URLs an import map maps names to (`imports`, `scopes`) follow the same rules. A module that imports bare package names fails to load; choose another build of it.
- Stylesheets, fonts, images and sound load over https without a hash; they cannot run code. A framed document (`iframe`, `frame`, `embed`, `object`) can, so it is embedded as a `data:` URI or drawn inline instead.
- Scripts make no requests of their own (`fetch` and the like): data the page shows is embedded when it is built, so the page shows the same thing every time it is opened.
- Offline, the page still asks its question: a library-drawn element keeps a readable fallback, such as the Mermaid source in its `<pre>`.

## Mermaid: `recipes/mermaid.html`

Flowcharts, sequence diagrams, state machines. Put the source in a template:

```html
<template id="detector-flow">
  <figure>
    <pre class="mermaid">
flowchart LR
  board[Board] --> attacks[Attack map detector]
  attacks --> pins[Pin detector]
    </pre>
    <figcaption>An arrow points from what is read to the detector reading it.</figcaption>
  </figure>
</template>
```

The recipe follows the reader's light or dark mode and runs Mermaid with `securityLevel: 'strict'`. A diagram that does not parse fails the build.

## Chess: `recipes/chess.html`

Static boards need no library and make no request. A page with a line loads chess.js 1.4.0 (hash-pinned) to play the moves.

A board:

```html
<div data-chess-board="r1bqkb1r/ppp2ppp/2np1n2/1B2p3/4P3/5N2/PPPP1PPP/RNBQK2R" data-highlight="b5 c6 e8"></div>
```

| Attribute | Meaning |
|---|---|
| `data-chess-board` | A FEN (the placement part is enough), or a drawing in the `pictureToFen` format: 64 whitespace-separated squares, black at the top, `_` for empty. Empty means the start position. |
| `data-highlight` | Squares to mark, space-separated: `"d5 e6"`. |
| `data-orientation` | `black` to show the board from Black's side. |
| `data-turn` | `black` when a drawing or bare placement is Black to move. |
| `style="--board-size: 12rem"` | Board width; 17rem by default. Use about 12rem for boards inside options. |
| `aria-label` | Optional description; defaults to the FEN and the marked squares. |

Each drawn square carries `data-square="e4"`, for a script that adds to a board.

A line the user steps through with the arrow keys, Home and End, or the ◀ ▶ buttons:

```html
<div data-chess-line="r1bqkb1r/ppp2ppp/2np1n2/1B2p3/4P3/5N2/PPPP1PPP/RNBQK2R w KQkq - 0 5" data-moves="d4 Bd7 O-O" data-highlight="c6"></div>
```

`data-chess-line` takes a full FEN, including the side to move and castling rights, or a drawing with `data-turn`. `data-moves` is SAN separated by spaces, and `data-ply` picks the ply shown first. Each step marks the move's two squares. A line needs a legal position with both kings.

Put two boards side by side, captioned, with `.visual-row` and `figure`; `examples/pins/visuals.html` has one. A board with fewer than 8 ranks, or a rank without 8 squares, fails the build, and so does an illegal move or position in a line. A board is not checked for legality, so a structure diagram without kings is allowed.

## Verified

2026-09-22, headless Chrome 153 on a `file://` page: Mermaid 11.15.0 from cdnjs by script tag with its hash, and chess.js 1.4.0 from jsdelivr through an import map with its hash. A wrong hash blocked each one, and the page reported the failure. `tests/page.test.mjs` and `tests/browser.test.mjs` render the example round with both recipes.
