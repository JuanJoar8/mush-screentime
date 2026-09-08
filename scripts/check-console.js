// Smoke test for host/console.html — the live progress page.
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

const file = path.join(__dirname, '..', 'host', 'console.html');
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
      if (prop === 'createRadialGradient' || prop === 'createLinearGradient') {
        return () => ({ addColorStop() {} });
      }
      if (prop === 'canvas') return { width: 800, height: 500 };
      return () => { calls.push(name + '.' + String(prop)); };
    },
    set() { return true; }
  });
}

const el = (id) => ({
  id,
  getContext: () => recordingContext(id),
  addEventListener() {}, removeEventListener() {},
  classList: { toggle() {}, add() {}, remove() {}, contains: () => false },
  style: new Proxy({}, { get: () => () => {}, set: () => true }),
  dataset: {}, querySelector: () => el('inner'), querySelectorAll: () => [],
  setAttribute() {}, getAttribute: () => null,
  scrollTo() {}, scrollTop: 0, offsetWidth: 100, value: 0,
  set innerHTML(v) {}, get innerHTML() { return ''; },
  set textContent(v) {}, get textContent() { return ''; },
});

global.document = {
  documentElement: { style: { setProperty() {} } },
  getElementById: el,
  querySelectorAll: () => [],
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

if (hero.length < 100) {
  fail('the hero canvas took ' + hero.length + ' drawing calls; the creature needs hundreds');
}

// Each of these is one part of the creature. Present but incomplete is still a bug worth
// a red build: `arc` is the spectacle rings, `quadraticCurveTo` is the folds and the
// mouth, `ellipse` is the shadow and the eyes.
const required = ['ellipse', 'quadraticCurveTo', 'arc', 'stroke', 'fill', 'clip'];
const missing = required.filter((k) => !used.includes(k));
if (missing.length) {
  fail('the hero canvas never called: ' + missing.join(', '));
}

console.log('OK');
