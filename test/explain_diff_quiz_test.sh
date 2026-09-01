#!/usr/bin/env bash
#
# Tests the quiz mechanics and delivery checks shipped with the explain-diff
# skills:
#
# - ai/skills/explain-diff-html/quiz-template.html: the page-side seeded
#   shuffle (deterministic per page, spread per question and per page) and the
#   click feedback behaviour, run under node with a small fake DOM.
# - ai/skills/explain-diff-html/SKILL.md: the delivery grep that flags external
#   references, checked against known vectors and against the template.
# - ai/skills/explain-diff-notion/SKILL.md: the jq command that picks the
#   option order, extracted from the skill text so the documented command is
#   the one being tested.

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
template="$repo_root/ai/skills/explain-diff-html/quiz-template.html"
html_skill="$repo_root/ai/skills/explain-diff-html/SKILL.md"
notion_skill="$repo_root/ai/skills/explain-diff-notion/SKILL.md"
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

# Extracts the command between <!-- <name>-start --> and <!-- <name>-end -->
# markers in a skill file, dropping the code fence lines.
extract_command() {
  local file="$1"
  local name="$2"
  awk -v start="$name-start" -v end="$name-end" \
    'index($0, start){flag=1; next} index($0, end){flag=0} flag' "$file" \
    | sed '/^[[:space:]]*```/d'
}

command -v node >/dev/null || fail "node is required"
command -v jq >/dev/null || fail "jq is required"
[ -f "$template" ] || fail "missing $template"
[ -f "$html_skill" ] || fail "missing $html_skill"
[ -f "$notion_skill" ] || fail "missing $notion_skill"

# --- HTML quiz template ------------------------------------------------------

# The data block is <script id="quiz-data" type="application/json">; the
# engine is the bare <script> block.
awk '/^<script>$/{flag=1; next} /^<\/script>$/{flag=0} flag' "$template" > "$tmpdir/engine.js"
[ -s "$tmpdir/engine.js" ] || fail "could not extract the quiz engine from $template"

cat > "$tmpdir/harness.js" <<'JS'
const fs = require('fs');
const assert = require('assert');
const engine = fs.readFileSync(process.argv[2], 'utf8');

function sampleQuiz(questionSuffix = '') {
  return [1, 2, 3, 4, 5].map((q) => ({
    question: `Question ${q}?${questionSuffix}`,
    options: [0, 1, 2, 3].map((o) => ({ text: `Q${q}O${o}`, explanation: `E${q}${o}` })),
  }));
}

function fakeNode(tag) {
  const node = {
    tagName: tag,
    className: '',
    textContent: '',
    children: [],
    disabled: false,
    hidden: false,
    listeners: {},
    attributes: {},
    classList: {
      add(name) { node.className = `${node.className} ${name}`.trim(); },
      contains(name) { return node.className.split(' ').includes(name); },
    },
    appendChild(child) { node.children.push(child); return child; },
    setAttribute(key, value) { node.attributes[key] = value; },
    addEventListener(type, handler) { node.listeners[type] = handler; },
    click() { node.listeners.click(); },
  };
  return node;
}

function render(title, data) {
  const root = fakeNode('div');
  const score = fakeNode('p');
  const dataNode = fakeNode('script');
  dataNode.textContent = JSON.stringify(data);
  const byId = { 'quiz-root': root, 'quiz-score': score, 'quiz-data': dataNode };
  global.document = { title, createElement: fakeNode, getElementById: (id) => byId[id] };
  new Function(engine)();
  return { root, score };
}

// Question container children: [heading, option list, feedback].
const optionButtons = (question) => question.children[1].children.map((item) => item.children[0]);
const displayedTexts = (question) => optionButtons(question).map((b) => b.textContent.replace(/^[A-D]\. /, ''));
const correctPosition = (question, q) => displayedTexts(question).indexOf(`Q${q}O0`);
const orders = (page) => [0, 1, 2, 3, 4].map((i) => JSON.stringify(displayedTexts(page.root.children[i])));
const ordersDiffer = (a, b) => orders(a).some((order, i) => order !== orders(b)[i]);

const data = sampleQuiz();
const first = render('Page A', data);
const again = render('Page A', data);
const other = render('Page B', data);

assert.strictEqual(first.root.children.length, 5, 'renders five questions');

for (let i = 0; i < 5; i++) {
  const shown = displayedTexts(first.root.children[i]);
  assert.deepStrictEqual([...shown].sort(), [0, 1, 2, 3].map((o) => `Q${i + 1}O${o}`), 'each question shows all four options once');
  assert.deepStrictEqual(shown, displayedTexts(again.root.children[i]), 'same title and data give the same order');
}

assert.ok(ordersDiffer(first, other), 'a different title gives a different order');

// A forgotten <title> must not collapse every page onto one order.
const untitled = render('', data);
const untitledOther = render('', sampleQuiz(' (variant)'));
assert.ok(ordersDiffer(untitled, untitledOther), 'with an empty title, different quiz data still gives a different order');

// Spread per question (each slot about a quarter of the time) and per page
// (all five correct answers in one slot about 1 page in 128).
const counts = [0, 0, 0, 0];
let sameSlotPages = 0;
for (let t = 0; t < 400; t++) {
  const page = render(`Title ${t}`, data);
  const positions = [0, 1, 2, 3, 4].map((q) => correctPosition(page.root.children[q], q + 1));
  positions.forEach((position) => { counts[position] += 1; });
  if (new Set(positions).size === 1) sameSlotPages += 1;
}
counts.forEach((count, position) => {
  assert.ok(count >= 400 && count <= 600, `correct answer lands in position ${position} about a quarter of the time (got ${count}/2000)`);
});
assert.ok(sameSlotPages <= 8, `pages with every correct answer in the same slot: ${sameSlotPages}/400 (expected about 3)`);

const page = render('Click page', data);
const q1 = page.root.children[0];
const q1Buttons = optionButtons(q1);
const q1Correct = q1Buttons[correctPosition(q1, 1)];
const q1Wrong = q1Buttons.find((b) => b !== q1Correct);
q1Wrong.click();
assert.ok(q1Wrong.classList.contains('is-incorrect'), 'wrong pick is marked incorrect');
assert.ok(q1Correct.classList.contains('is-correct'), 'correct option is revealed after a wrong pick');
assert.ok(q1Buttons.every((b) => b.disabled), 'all options lock after answering');
const q1Feedback = q1.children[2];
assert.strictEqual(q1Feedback.hidden, false, 'feedback is shown');
assert.ok(q1Feedback.textContent.startsWith('Not quite.'), 'feedback says the pick was wrong');
assert.ok(q1Feedback.textContent.includes('E10'), 'feedback includes the correct explanation');
assert.strictEqual(page.score.textContent, 'Score: 0 / 1 answered');

const q2 = page.root.children[1];
optionButtons(q2)[correctPosition(q2, 2)].click();
assert.ok(q2.children[2].textContent.startsWith('Correct.'), 'feedback says the pick was right');
assert.strictEqual(page.score.textContent, 'Score: 1 / 2 answered');

console.log('quiz template: ok');
JS

node "$tmpdir/harness.js" "$tmpdir/engine.js" || fail "quiz template checks failed"

# --- Delivery grep for external references ----------------------------------

extract_command "$html_skill" "delivery-grep" > "$tmpdir/delivery-grep.sh"
[ -s "$tmpdir/delivery-grep.sh" ] || fail "could not extract the delivery grep from $html_skill"

delivery_grep() {
  sed "s|<file>|$1|" "$tmpdir/delivery-grep.sh" | bash
}

# Lines 1-20 are things a tricked model might write and must all be flagged.
# The lines after are legitimate page content and must not be.
cat > "$tmpdir/probe.html" <<'HTML'
<script src="https://cdn.example/x.js"></script>
<link rel="stylesheet" href="style.css">
<img src="pixel.gif">
<a href="javascript:alert(1)">x</a>
<a href="data:text/html,hi">x</a>
<div style="background:url(//host/x.png)"></div>
<iframe srcdoc="hi"></iframe>
<meta http-equiv="refresh" content="0;url=x">
<form action="/submit">
<base href="/">
<video src="v.mp4"></video>
<script type="module">
fetch('/x')
new WebSocket('ws://h')
navigator.sendBeacon('/x')
<button onclick="go()">
<svg><image href="x.svg"/></svg>
<IMG SRC="x.png">
<a href="https://github.com/org/repo/pull/1">PR</a>
import('./mod.js')
<a href="#background">Background</a>
<pre><code>import os</code></pre>
<p>The handler runs on every request.</p>
<code>version=2</code>
<p>Toy data set with 3 orders.</p>
HTML

flagged="$(delivery_grep "$tmpdir/probe.html" | cut -d: -f1 | tr '\n' ' ')"
expected="$(seq 1 20 | tr '\n' ' ')"
[ "$flagged" = "$expected" ] || fail "delivery grep flagged lines [$flagged], expected [$expected]"

if delivery_grep "$template" >/dev/null; then
  fail "the delivery grep found hits in the quiz template; the template must stay free of external references"
fi

echo "delivery grep: ok"

# --- Notion option-order command --------------------------------------------

extract_command "$notion_skill" "quiz-order" > "$tmpdir/order.sh"
[ -s "$tmpdir/order.sh" ] || fail "could not extract the quiz-order command from $notion_skill"

quiz_order() {
  sed "s/<page-slug>/$1/" "$tmpdir/order.sh" | bash
}

expected_sorted='["correct","distractor-1","distractor-2","distractor-3"]'
quiz_order "sample-page" > "$tmpdir/order-a.json"
[ "$(jq -c 'length' "$tmpdir/order-a.json")" = "5" ] || fail "quiz order should cover five questions"
[ "$(jq -c 'map(sort) | unique' "$tmpdir/order-a.json")" = "[$expected_sorted]" ] ||
  fail "every question should be a permutation of the four labels"

quiz_order "sample-page" > "$tmpdir/order-a2.json"
diff "$tmpdir/order-a.json" "$tmpdir/order-a2.json" >/dev/null || fail "same seed should give the same order"

quiz_order "other-page" > "$tmpdir/order-b.json"
if diff "$tmpdir/order-a.json" "$tmpdir/order-b.json" >/dev/null; then
  fail "different seeds should give different orders"
fi

# Spread per question and per page over a fixed seed list, as for the template.
: > "$tmpdir/orders.jsonl"
for n in $(seq 1 200); do
  quiz_order "seed-$n" | jq -c 'map(index("correct"))' >> "$tmpdir/orders.jsonl"
done
for position in 0 1 2 3; do
  count="$(jq -s --argjson p "$position" 'flatten | map(select(. == $p)) | length' "$tmpdir/orders.jsonl")"
  [ "$count" -ge 200 ] && [ "$count" -le 300 ] ||
    fail "correct answer landed in position $position $count times out of 1000; expected about 250"
done
same_slot_pages="$(jq -s 'map(select(unique | length == 1)) | length' "$tmpdir/orders.jsonl")"
[ "$same_slot_pages" -le 4 ] ||
  fail "$same_slot_pages of 200 pages put every correct answer in the same slot; expected about 1"

echo "notion quiz order: ok"
echo "PASS: explain_diff_quiz_test.sh"
