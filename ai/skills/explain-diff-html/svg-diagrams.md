# Inline SVG diagrams: templates and mechanics

Two templates, a topology graph and a sequence diagram, plus the rules that
keep them legible. Paste the style block once, then one `<svg>` per diagram.
Reuse one topology across the page: later diagrams copy the same node
positions and highlight, dim, or annotate parts of it, so the reader learns a
single shape.

## Mechanics

- `viewBox` plus `width: 100%; height: auto` in CSS, never fixed pixel
  width, so the diagram scales with the column and the phone.
- Text in the page font at 12 to 13 viewBox units; keep labels short and put
  them above the line they describe. If a label does not fit, shorten the
  words, not the font.
- Arrowheads come from one `<marker>` in `<defs>`; `orient="auto-start-reverse"`
  lets the same marker serve both directions. Define the markers once per
  page; ids must be unique across the page.
- One relation type per edge style: solid for a synchronous call or data
  flow, dashed for an asynchronous message or a response, dashed red for a
  message that is expected and never arrives. Any diagram with more than one
  edge style carries the legend group.
- Every `<svg>` has `role="img"` and a `<title>` that states what the nodes
  and edges mean in one sentence; that sentence is also the caption.
- Mark what the reader's own system can observe (a bracket, a highlighted
  node) so they know which steps show up in their logs.
- Animation, when it earns its place, is CSS on the same elements: a
  `stroke-dashoffset` keyframe to draw a path, or an opacity pulse on the
  failing hop. No library.

## Style block

```html
<style>
  /* Paste once per page. Colors come from the page's CSS variables so the
     diagrams follow the page palette. */
  .dg { display: block; width: 100%; height: auto; max-width: 760px;
        font-family: system-ui, -apple-system, "Segoe UI", sans-serif; }
  .dg text { fill: #0b0b0b; font-size: 13px; }
  .dg .muted { fill: #52514e; font-size: 12px; }
  .dg .node rect { fill: #fcfcfb; stroke: #c3c2b7; stroke-width: 1.2; rx: 8; }
  .dg .node.focus rect { stroke: #2a78d6; stroke-width: 2; }
  .dg .edge { stroke: #52514e; stroke-width: 1.6; fill: none; }
  .dg .edge.async { stroke-dasharray: 5 4; }
  .dg .edge.dead { stroke: #d03b3b; stroke-dasharray: 3 4; }
  .dg .life { stroke: #c3c2b7; stroke-width: 1; stroke-dasharray: 4 4; }
  .dg .legend rect { fill: #f0efec; stroke: none; rx: 6; }
</style>
```

## Topology graph

```html
<svg class="dg" viewBox="0 0 760 290" role="img" aria-labelledby="g1-title">
  <title id="g1-title">Topology: client, gateway, service, worker; solid edges are synchronous calls, dashed edges are asynchronous messages</title>
  <defs>
    <marker id="arrow" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="8" markerHeight="8" orient="auto-start-reverse">
      <path d="M0,0 L10,5 L0,10 z" fill="#52514e"/>
    </marker>
    <marker id="arrow-dead" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="8" markerHeight="8" orient="auto-start-reverse">
      <path d="M0,0 L10,5 L0,10 z" fill="#d03b3b"/>
    </marker>
  </defs>
  <!-- nodes: one <g class="node"> per component; add class="focus" to the one the change touches.
       Leave at least 110 viewBox units between nodes so edge labels fit above the line. -->
  <g class="node"><rect x="20" y="60" width="140" height="56"/><text x="90" y="84" text-anchor="middle">Client</text><text x="90" y="102" text-anchor="middle" class="muted">browser</text></g>
  <g class="node focus"><rect x="270" y="60" width="140" height="56"/><text x="340" y="84" text-anchor="middle">Gateway</text><text x="340" y="102" text-anchor="middle" class="muted">changed here</text></g>
  <g class="node"><rect x="520" y="60" width="140" height="56"/><text x="590" y="84" text-anchor="middle">Service</text><text x="590" y="102" text-anchor="middle" class="muted">owns the record</text></g>
  <g class="node"><rect x="520" y="170" width="140" height="56"/><text x="590" y="194" text-anchor="middle">Worker</text><text x="590" y="212" text-anchor="middle" class="muted">async</text></g>
  <!-- edges: solid = synchronous call, dashed = asynchronous message; label sits above the line -->
  <path class="edge" d="M160,88 L270,88" marker-end="url(#arrow)"/><text x="215" y="80" text-anchor="middle" class="muted">POST /orders</text>
  <path class="edge" d="M410,88 L520,88" marker-end="url(#arrow)"/><text x="465" y="80" text-anchor="middle" class="muted">create</text>
  <path class="edge async" d="M590,116 L590,170" marker-end="url(#arrow)"/><text x="602" y="147" class="muted">enqueue</text>
  <path class="edge dead" d="M520,198 C 430,198 340,170 340,116" marker-end="url(#arrow-dead)"/><text x="440" y="222" text-anchor="middle" class="muted">callback (never sent)</text>
  <!-- legend: always present when there is more than one edge style -->
  <g class="legend" transform="translate(20,262)">
    <rect x="0" y="-14" width="520" height="30"/>
    <line x1="10" y1="2" x2="40" y2="2" class="edge"/><text x="48" y="6" class="muted">synchronous call</text>
    <line x1="170" y1="2" x2="200" y2="2" class="edge async"/><text x="208" y="6" class="muted">asynchronous message</text>
    <line x1="370" y1="2" x2="400" y2="2" class="edge dead"/><text x="408" y="6" class="muted">expected, never arrives</text>
  </g>
</svg>
```

## Sequence diagram

```html
<svg class="dg" viewBox="0 0 760 300" role="img" aria-labelledby="s1-title">
  <title id="s1-title">Sequence: client calls gateway, gateway calls service, service replies 200, gateway replies 200; time runs downward</title>
  <!-- participants: one column each; lifeline is a dashed vertical line -->
  <g class="node"><rect x="40" y="16" width="130" height="40"/><text x="105" y="41" text-anchor="middle">Client</text></g>
  <g class="node"><rect x="315" y="16" width="130" height="40"/><text x="380" y="41" text-anchor="middle">Gateway</text></g>
  <g class="node"><rect x="590" y="16" width="130" height="40"/><text x="655" y="41" text-anchor="middle">Service</text></g>
  <line x1="105" y1="56" x2="105" y2="280" class="life"/>
  <line x1="380" y1="56" x2="380" y2="280" class="life"/>
  <line x1="655" y1="56" x2="655" y2="280" class="life"/>
  <!-- messages: solid = request, dashed = response; label above the arrow; step number on the left -->
  <text x="20" y="96" class="muted">1</text>
  <path class="edge" d="M105,100 L380,100" marker-end="url(#arrow)"/><text x="242" y="92" text-anchor="middle" class="muted">POST /orders</text>
  <text x="20" y="146" class="muted">2</text>
  <path class="edge" d="M380,150 L655,150" marker-end="url(#arrow)"/><text x="517" y="142" text-anchor="middle" class="muted">create(order)</text>
  <text x="20" y="196" class="muted">3</text>
  <path class="edge async" d="M655,200 L380,200" marker-end="url(#arrow)"/><text x="517" y="192" text-anchor="middle" class="muted">200 created</text>
  <text x="20" y="246" class="muted">4</text>
  <path class="edge async" d="M380,250 L105,250" marker-end="url(#arrow)"/><text x="242" y="242" text-anchor="middle" class="muted">200 with order id</text>
  <!-- what the reader's own system can see: a bracket on the right -->
  <line x1="740" y1="140" x2="740" y2="210" stroke="#2a78d6" stroke-width="3"/>
  <text x="734" y="172" text-anchor="end" class="muted" transform="rotate(-90 734 172)">logged here</text>
</svg>
```
