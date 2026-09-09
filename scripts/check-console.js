// Smoke test for a host page that draws the creature.
//
//   node scripts/check-console.js [host/console.html | host/app.html]
//
// It exists because the console shipped twice with an invisible creature. The port of the
// character declared `function css(c, a)` into a scope that already had
// `var css = getComputedStyle(...)` on line 5; the var assignment overwrites the hoisted
// function, so `palette()` called a CSSStyleDeclaration and threw. One exception inside
// `requestAnimationFrame` stops the whole loop, and a canvas nothing ever draws on looks
// exactly like a canvas nothing was meant to be on.
//
// No linter catches that. The syntax is valid, both names are used, and `node --check`
// passes. The only thing that catches it is running the code — so this runs it, against a
// stub DOM and a recording 2D context.
//
// **It exits 2 when the hero canvas is blank.** The first version of this file printed
// the exception and returned 0, which is the same defect as the guard it replaced: a
// check that reports a failure and then reports success is worse than no check, because
// it also removes the suspicion.
//
//   node scripts/check-console.js

const fs = require('fs');
const path = require('path');

// Takes a path so the same smoke test covers every host surface that draws the
// creature. host/app.html is a second one now, spliced from this same renderer, and a
// guard that only ever looks at the page it was written for leaves the new ones unwatched.
const file = process.argv[2] || path.join(__dirname, '..', 'host', 'console.html');
const html = fs.readFileSync(file, 'utf8');

// The CSS custom properties the script reads, straight from the file's own :root block.
const tokens = {};
const start = html.indexOf(':root {');
const rootBlock = html.slice(start, html.indexOf('}', start));
for (const m of rootBlock.matchAll(/(--[\w-]+)\s*:\s*([^;]+);/g)) tokens[m[1]] = m[2].trim();

const calls = [];
function recordingContext(name) {
  return new Proxy({}, {
    get(_, prop) {
      // Recorded like any other call, not silently swallowed. The modelled creature is
      // built out of gradients — key light, occlusion, ground bounce, the iris dish — so
      // a run that creates none of them has lost the entire volume and would otherwise
      // sail past a check that only counts strokes.
      if (prop === 'createRadialGradient' || prop === 'createLinearGradient') {
        return () => {
          calls.push(name + '.' + String(prop));
          return { addColorStop() {} };
        };
      }
      if (prop === 'canvas') return { width: 800, height: 500 };
      return () => { calls.push(name + '.' + String(prop)); };
    },
    set() { return true; }
  });
}

// Every stage card, so all five stages are actually drawn.
//
// The first version of this file returned [] from querySelectorAll, which meant the strip
// never rendered and only the current stage — `foggy`, the one stage with no motifs at
// all — was exercised. The drips, cracks, spiral and sparkles were entirely uncovered by
// the check written to cover them.
const stageCards = ['mush', 'melting', 'buzzed', 'foggy', 'crisp'].map((key) => ({
  dataset: { stage: key },
  querySelector: () => el('stage-' + key),
  addEventListener() {},
}));

// The app mockup reaches its five thumbnails a different way: it writes the rail into
// innerHTML and then asks for `#rail canvas`. A stub that only knows `.stagecard`
// returns nothing for that, the rail never draws, and the guard reports four stages
// missing — which is a fact about the stub, not about the page. Both shapes are answered
// here, and the selectors are matched loosely on purpose: the next surface will invent a
// third way of naming its canvases.
// Built on demand: `el` is declared below and a `const` is not hoisted into its own
// initialiser, so eager construction here throws before the guard reads a single line.
let railCanvases = null;

function matches(sel) {
  if (typeof sel !== 'string') return [];
  if (sel.includes('.stagecard')) return stageCards;
  if (sel.includes('canvas')) {
    if (!railCanvases) {
      railCanvases = ['mush', 'melting', 'buzzed', 'foggy', 'crisp']
        .map((key) => el('rail-' + key));
    }
    return railCanvases;
  }
  return [];
}

const el = (id) => ({
  id,
  getContext: () => recordingContext(id),
  addEventListener() {}, removeEventListener() {},
  classList: { toggle() {}, add() {}, remove() {}, contains: () => false },
  style: new Proxy({}, { get: () => () => {}, set: () => true }),
  dataset: {}, querySelector: () => el('inner'),
  querySelectorAll: matches,
  setAttribute() {}, getAttribute: () => null,
  scrollTo() {}, scrollTop: 0, offsetWidth: 100, value: 0,
  set innerHTML(v) {}, get innerHTML() { return ''; },
  set textContent(v) {}, get textContent() { return ''; },
});

global.document = {
  documentElement: { style: { setProperty() {} } },
  getElementById: el,
  querySelectorAll: matches,
  createElement: el,
};
global.window = { matchMedia: () => ({ matches: false }), addEventListener() {} };
global.getComputedStyle = () => ({ getPropertyValue: (n) => tokens[n] || '' });
global.requestAnimationFrame = () => 0;
global.performance = { now: () => 4321 };
global.setInterval = () => 0;
global.clearInterval = () => {};

function fail(message) {
  console.error('FAIL: ' + message);
  process.exit(2);
}

const script = html.slice(html.indexOf('<script>') + '<script>'.length, html.indexOf('</script>'));

try {
  eval(script);
} catch (e) {
  console.error((e.stack || String(e)).split('\n').slice(0, 5).join('\n'));
  fail(e.constructor.name + ': ' + e.message);
}

const hero = calls.filter((c) => c.startsWith('hero.'));
const used = [...new Set(hero.map((c) => c.split('.')[1]))];

console.log('script ran with no exception');
console.log('  2D calls total: ' + calls.length + ', on the hero canvas: ' + hero.length);
console.log('  hero used: ' + (used.join(', ') || '(nothing)'));

// Every stage, not just whichever one happens to be current. Each of the five has its own
// motifs — drips, cracks, a spiral pupil, sparkles — and each is a separate code path.
for (const key of ['mush', 'melting', 'buzzed', 'foggy', 'crisp']) {
  // `stage-` on the console's strip, `rail-` on the app mockup's ladder. Counting both
  // rather than one: a guard keyed to a single page's element ids reports a missing
  // stage on every other page, and a guard that cries wolf gets switched off.
  const drew = calls.filter(
    (c) => c.startsWith('stage-' + key + '.') || c.startsWith('rail-' + key + '.')
  ).length;
  console.log('  ' + key.padEnd(8) + drew + ' calls');
  if (drew < 50) {
    fail(key + ' drew only ' + drew + ' times; its motifs are not being exercised');
  }
}

if (hero.length < 100) {
  fail('the hero canvas took ' + hero.length + ' drawing calls; the creature needs hundreds');
}

// Each of these is one part of the creature. Present but incomplete is still a bug worth
// a red build: `quadraticCurveTo` is the gyri and the mouth, `bezierCurveTo` is the
// longitudinal fissure, `ellipse` is the shadow, the eyes and the spectacle rings.
// `arc` left the list when the glasses moved to `ellipse`; `createRadialGradient` and
// `createLinearGradient` joined it, because they are the volume. A creature drawn with
// every stroke in place and no gradients is the flat version wearing this one's code.
const required = [
  'ellipse', 'quadraticCurveTo', 'bezierCurveTo', 'stroke', 'fill', 'clip',
  'createRadialGradient', 'createLinearGradient',
];
const missing = required.filter((k) => !used.includes(k));
if (missing.length) {
  fail('the hero canvas never called: ' + missing.join(', '));
}

console.log('OK');
