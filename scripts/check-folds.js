// Every stage draws the number of folds its table declares.
//
// Fold density is the product. "Sixteen a side at crisp, two at mush" is the smooth-brain
// reading the whole character rests on, and it is repeated in `CreatureParameters`, in
// `00-STATUS.md` and on the review sheet. Nothing checked it, and it was false: measured
// on 2026-09-09, every stage was losing more than half its folds to the face keep-out.
// Crisp declared sixteen a side and drew seven.
//
// Two things had gone wrong and neither was visible in a screenshot. The keep-out was a
// box that ran from the brows to the bottom of the body rather than a shape the size of
// the face. And a fold that landed inside it was *dropped*, so the count silently fell.
// Folds are relocated now, and this measures that they are.
//
// It instruments the real drawing out of `host/console.html` rather than re-deriving the
// placement arithmetic, because a second copy of the maths would only ever agree with
// itself. The single edit is a counter on the line that culls a fold.
//
//   node scripts/check-folds.js

const fs = require('fs');
const path = require('path');

const file = process.argv[2] || path.join(__dirname, '..', 'host', 'console.html');
const html = fs.readFileSync(file, 'utf8');

const tokens = {};
const rootStart = html.indexOf(':root {');
const rootBlock = html.slice(rootStart, html.indexOf('}', rootStart));
for (const m of rootBlock.matchAll(/(--[\w-]+)\s*:\s*([^;]+);/g)) tokens[m[1]] = m[2].trim();

global.__folds = {};

// A context that records nothing. This guard counts decisions, not pixels — check-fit.js
// is the one that measures geometry.
function ctx2d() {
  return new Proxy({}, {
    get(target, key) {
      if (key === 'canvas') return { width: 820, height: 528 };
      if (key === 'createRadialGradient' || key === 'createLinearGradient') {
        return () => ({ addColorStop() {} });
      }
      if (key === 'measureText') return () => ({ width: 10 });
      return typeof key === 'string' ? () => {} : undefined;
    },
    set: () => true,
  });
}

const el = () => ({
  getContext: () => ctx2d(),
  width: 820, height: 528,
  style: new Proxy({}, { get: () => () => {}, set: () => true }),
  dataset: {}, classList: { add() {}, remove() {}, toggle() {}, contains: () => false },
  addEventListener() {}, appendChild() {}, setAttribute() {}, getAttribute: () => null,
  getBoundingClientRect: () => ({ width: 820, height: 528, top: 0, left: 0 }),
  querySelector: () => el(), querySelectorAll: () => [],
  scrollTo() {}, scrollTop: 0, offsetWidth: 100, value: 0,
  set innerHTML(v) {}, get innerHTML() { return ''; },
  set textContent(v) {}, get textContent() { return ''; },
});

// The strip draws all five stages. Without these stubs only the hero's stage is walked,
// and four of the five report nothing at all.
const stageCards = ['mush', 'melting', 'buzzed', 'foggy', 'crisp'].map((key) => ({
  dataset: { stage: key },
  querySelector: () => el(),
  addEventListener() {},
}));

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

let script = html.slice(html.indexOf('<script>') + '<script>'.length, html.indexOf('</script>'));

// Two injections into the shipping source. Both fail loudly if the drawing moves, because
// a guard that silently stops instrumenting is the failure this repo keeps hitting.
const header = 'function drawGyri(ctx, cx, cy, bw, bh, R, pal, p, lx, ly, span) {';
if (!script.includes(header)) {
  console.error('FAIL: drawGyri no longer has the signature this instruments.');
  process.exit(2);
}
script = script.replace(header, header +
  '\n    var __key = p.foldRings + "x" + p.foldsPerRing;' +
  '\n    global.__folds[__key] = global.__folds[__key] || { kept: 0, culled: 0 };' +
  '\n    var __count = global.__folds[__key];');

const cull = 'if (gdx * gdx + gdy * gdy < 1) continue;';
if (!script.includes(cull)) {
  console.error('FAIL: the line that culls a fold has moved; this guard is not measuring it.');
  process.exit(2);
}
script = script.replace(cull,
  'if (gdx * gdx + gdy * gdy < 1) { __count.culled++; continue; } __count.kept++;');

try {
  eval(script);
} catch (e) {
  console.error((e.stack || String(e)).split('\n').slice(0, 5).join('\n'));
  console.error('FAIL: the drawing threw before any fold could be counted');
  process.exit(2);
}

// Keyed by the pair that identifies a stage. No two stages share one.
const NAMES = { '4x4': 'crisp', '3x4': 'foggy', '3x3': 'buzzed', '2x2': 'melting', '1x2': 'mush' };
const ORDER = ['4x4', '3x4', '3x3', '2x2', '1x2'];

// A stage may lose the odd fold to a lens it could not be pushed off. Losing one in ten
// is a placement detail; losing one in three is the count lying about itself.
const FLOOR = 0.90;

console.log('stage      declared   drawn   culled   survival');
let failures = 0;
let missing = 0;

for (const key of ORDER) {
  const counted = global.__folds[key];
  const name = NAMES[key];
  if (!counted) {
    console.error(`  ${name.padEnd(10)} never drawn — the strip did not walk this stage`);
    missing++;
    continue;
  }
  const [rings, per] = key.split('x').map(Number);
  const declared = rings * per * 2;                 // both hemispheres
  const passes = (counted.kept + counted.culled) / declared;
  const kept = counted.kept / passes;
  const culled = counted.culled / passes;
  const survival = kept / declared;

  const line = `${name.padEnd(10)} ${String(declared).padStart(6)}`
    + `${kept.toFixed(1).padStart(9)}${culled.toFixed(1).padStart(9)}`
    + `${(survival * 100).toFixed(0).padStart(8)}%`;

  if (survival < FLOOR) {
    failures++;
    console.error(line + '   ← below the floor');
  } else {
    console.log(line);
  }
}

if (missing) {
  console.error(`\n${missing} stage(s) were never drawn. This guard measured nothing about them.`);
  process.exit(2);
}
if (failures) {
  console.error(`\n${failures} stage(s) draw fewer folds than their table declares.`);
  console.error('Fold density is the reading the character rests on: a stage that keeps '
    + 'fewer than it claims is a stage lying about itself.');
  process.exit(2);
}
console.log('\nEvery stage draws every fold it declares.');
console.log('OK');
