// Nothing the creature draws may fall outside its canvas.
//
// This is the third guard against one bug. Twice the drawing has been clipped — once
// when a glove grew past a hardcoded fraction, once when the fit arithmetic was redone
// for `crisp` and never rechecked against `mush`, which spreads 16% wider and pushed the
// fingertips to 2.18 x radius against a 2.00 budget. Both times the answer was "derive
// `Reach` from the constants the drawing actually uses". Both times the derivation itself
// was done by hand, and a hand-derived guarantee is a claim, not a check.
//
// So this measures instead. It runs the real drawing code from host/console.html against
// a context that records every coordinate, applies the transform stack, honours clipping,
// and pads stroked paths by half their line width. Then it compares the bounding box of
// what was drawn against the canvas it was drawn on, for all five stages.
//
// Clipped drawing is skipped on purpose: the gyri, the specular and the cracks all live
// inside `clip(bodyPath)`, so their raw coordinates can and do run past the silhouette —
// the silhouette is what bounds them, and the silhouette is measured.
//
//   node scripts/check-fit.js

const fs = require('fs');
const path = require('path');

const html = fs.readFileSync(path.join(__dirname, '..', 'host', 'console.html'), 'utf8');

const tokens = {};
const start = html.indexOf(':root {');
const rootBlock = html.slice(start, html.indexOf('}', start));
for (const m of rootBlock.matchAll(/(--[\w-]+)\s*:\s*([^;]+);/g)) tokens[m[1]] = m[2].trim();

// One record per canvas: the extent of everything drawn, plus the canvas size, which the
// drawing code announces itself by clearing the full rect before each frame.
const surfaces = new Map();

function surface(name) {
  if (!surfaces.has(name)) {
    surfaces.set(name, {
      minX: Infinity, minY: Infinity, maxX: -Infinity, maxY: -Infinity,
      width: 0, height: 0, points: 0,
    });
  }
  return surfaces.get(name);
}

// A 2D affine matrix, because `drawBrows` rotates and its local coordinates are negative.
// Without the transform stack a brow at x = -bw/2 reads as forty points off the left edge.
const identity = () => ({ a: 1, b: 0, c: 0, d: 1, e: 0, f: 0 });

function geometryContext(name) {
  const s = surface(name);
  let m = identity();
  const stack = [];
  let clipped = false;
  let lineWidth = 1;
  let pending = [];               // points of the path under construction

  const apply = (x, y) => [m.a * x + m.c * y + m.e, m.b * x + m.d * y + m.f];

  const push = (x, y) => {
    if (clipped) return;
    if (!Number.isFinite(x) || !Number.isFinite(y)) {
      console.error('FAIL: ' + name + ' produced a non-finite coordinate: ' + x + ', ' + y);
      process.exit(2);
    }
    pending.push(apply(x, y));
  };

  const commit = (pad) => {
    if (clipped) { pending = []; return; }
    for (const [x, y] of pending) {
      s.minX = Math.min(s.minX, x - pad); s.maxX = Math.max(s.maxX, x + pad);
      s.minY = Math.min(s.minY, y - pad); s.maxY = Math.max(s.maxY, y + pad);
      s.points++;
    }
    // A path can be filled and then stroked. Keep it until the next beginPath.
  };

  const api = {
    get canvas() { return { width: s.width, height: s.height }; },
    set lineWidth(v) { lineWidth = v; },
    get lineWidth() { return lineWidth; },

    save() { stack.push({ m: { ...m }, clipped }); },
    restore() { const p = stack.pop(); if (p) { m = p.m; clipped = p.clipped; } },
    translate(x, y) { m.e += m.a * x + m.c * y; m.f += m.b * x + m.d * y; },
    rotate(r) {
      const cos = Math.cos(r), sin = Math.sin(r);
      const { a, b, c, d } = m;
      m.a = a * cos + c * sin; m.b = b * cos + d * sin;
      m.c = c * cos - a * sin; m.d = d * cos - b * sin;
    },
    // Everything drawn after a clip is bounded by the clip path, which was itself
    // measured on its way to becoming one.
    clip() { clipped = true; },

    beginPath() { pending = []; },
    closePath() {},
    moveTo(x, y) { push(x, y); },
    lineTo(x, y) { push(x, y); },
    // A quadratic or cubic curve stays inside the convex hull of its control points, so
    // recording all of them is conservative and exact enough for a bounding box.
    quadraticCurveTo(cx, cy, x, y) { push(cx, cy); push(x, y); },
    bezierCurveTo(c1x, c1y, c2x, c2y, x, y) { push(c1x, c1y); push(c2x, c2y); push(x, y); },
    ellipse(x, y, rx, ry) { push(x - rx, y - ry); push(x + rx, y + ry); },
    arc(x, y, r) { push(x - r, y - r); push(x + r, y + r); },
    rect(x, y, w, h) { push(x, y); push(x + w, y + h); },

    fill() { commit(0); },
    stroke() { commit(lineWidth / 2); },
    fillRect(x, y, w, h) {
      // The hero glow is a full-canvas wash and the eyelid is a clipped rectangle.
      // Neither is part of the creature's silhouette, so neither belongs in the extent.
    },
    strokeRect() {},
    clearRect(x, y, w, h) { s.width = w; s.height = h; },

    createRadialGradient() { return { addColorStop() {} }; },
    createLinearGradient() { return { addColorStop() {} }; },
  };

  // Everything the drawing sets and this does not model — fillStyle, strokeStyle,
  // lineCap, filter — is accepted and ignored.
  return new Proxy(api, {
    get(target, prop) {
      if (prop in target) return target[prop];
      return () => {};
    },
    set(target, prop, value) {
      if (prop === 'lineWidth') { target.lineWidth = value; return true; }
      return true;
    },
  });
}

const stageCards = ['mush', 'melting', 'buzzed', 'foggy', 'crisp'].map((key) => ({
  dataset: { stage: key },
  querySelector: () => el('stage-' + key),
  addEventListener() {},
}));

const el = (id) => ({
  id,
  getContext: () => geometryContext(id),
  addEventListener() {}, removeEventListener() {},
  classList: { toggle() {}, add() {}, remove() {}, contains: () => false },
  style: new Proxy({}, { get: () => () => {}, set: () => true }),
  dataset: {}, querySelector: () => el('inner'),
  querySelectorAll: (sel) => (sel === '.stagecard' ? stageCards : []),
  setAttribute() {}, getAttribute: () => null,
  scrollTo() {}, scrollTop: 0, offsetWidth: 100, value: 0,
  set innerHTML(v) {}, get innerHTML() { return ''; },
  set textContent(v) {}, get textContent() { return ''; },
});

global.document = {
  documentElement: { style: { setProperty() {} } },
  getElementById: el,
  querySelectorAll: (sel) => (sel === '.stagecard' ? stageCards : []),
  createElement: el,
};
global.window = { matchMedia: () => ({ matches: false }), addEventListener() {} };
global.getComputedStyle = () => ({ getPropertyValue: (n) => tokens[n] || '' });
global.requestAnimationFrame = () => 0;
global.performance = { now: () => 4321 };
global.setInterval = () => 0;
global.clearInterval = () => {};

const script = html.slice(html.indexOf('<script>') + '<script>'.length, html.indexOf('</script>'));
try {
  eval(script);
} catch (e) {
  console.error((e.stack || String(e)).split('\n').slice(0, 5).join('\n'));
  console.error('FAIL: the drawing threw before it could be measured');
  process.exit(2);
}

// Sub-pixel slack. Anti-aliasing puts a fraction of a stroke's alpha outside its
// geometric edge whatever the fit says, and failing a build over a third of a pixel is
// how a guard gets switched off.
const SLACK = 0.75;

let worst = null;
let failures = 0;

for (const [name, s] of [...surfaces].sort()) {
  if (!s.points || !s.width) continue;
  const margins = {
    left: s.minX, top: s.minY,
    right: s.width - s.maxX, bottom: s.height - s.maxY,
  };
  const tightest = Math.min(...Object.values(margins));
  const side = Object.keys(margins).find((k) => margins[k] === tightest);
  const line = '  ' + name.padEnd(14) + s.width + 'x' + s.height
    + '  drawn ' + s.minX.toFixed(1) + ',' + s.minY.toFixed(1)
    + ' → ' + s.maxX.toFixed(1) + ',' + s.maxY.toFixed(1)
    + '   tightest ' + tightest.toFixed(1) + 'px (' + side + ')';

  if (tightest < -SLACK) {
    failures++;
    console.error('CLIPPED' + line);
  } else {
    console.log(line);
  }
  if (!worst || tightest < worst.margin) worst = { name, margin: tightest, side };
}

if (!surfaces.size) {
  console.error('FAIL: nothing was drawn — the recorder saw no canvases');
  process.exit(2);
}

console.log('\ntightest fit anywhere: ' + worst.margin.toFixed(1) + 'px on the '
  + worst.side + ' of ' + worst.name);

if (failures) {
  console.error('\n' + failures + ' surface(s) draw outside their canvas. Reach is wrong.');
  process.exit(2);
}
console.log('OK');
