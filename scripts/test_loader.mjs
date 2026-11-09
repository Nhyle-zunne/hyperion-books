import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { runInNewContext } from 'node:vm';

const html = readFileSync(new URL('../web/index.html', import.meta.url), 'utf8');
assert(html.includes('href="logo.png?v=3"'), 'Browser tab must use the same logo.png as hyperion-pwa');
for (const face of ['front','back','right','left','top','bottom']) {
  assert(html.includes(`hyperion-top-loader__face--${face}`), `Missing cube face ${face}`);
}
assert(html.includes('rotateY(315deg)') && html.includes('2.4s linear infinite'), 'Loader rotation does not match Hyperion PWA');
assert(html.includes('prefers-reduced-motion'), 'Reduced motion support required');

// Run the actual inline loader controller with a lightweight simulated browser.
const open = html.indexOf('<script>\n    (() => {');
const close = html.indexOf('</script>', open);
assert(open > 0 && close > open, 'Operation-loader controller script missing');
const source = html.slice(open + '<script>'.length, close);
let now = 0;
let id = 0;
const timers = new Map();
const setTimeout = (fn, delay = 0) => {
  const token = ++id;
  timers.set(token, { time: now + delay, fn });
  return token;
};
const clearTimeout = (token) => timers.delete(token);
function advance(ms) {
  const until = now + ms;
  for (let guard = 0; guard < 1000; guard++) {
    const next = [...timers].sort((a,b) => a[1].time - b[1].time)[0];
    if (!next || next[1].time > until) break;
    now = next[1].time;
    timers.delete(next[0]);
    next[1].fn();
  }
  now = until;
}
class El {
  constructor() { this.attributes = {}; this.isRemoved = false; this.classes = new Set();
    this.classList = { add: n => this.classes.add(n), remove: n => this.classes.delete(n), contains: n => this.classes.has(n) }; }
  setAttribute(name, value) { this.attributes[name] = value; }
  querySelector() { return message; }
  remove() { this.isRemoved = true; }
}
const startup = new El(), overlay = new El(), message = new El();
const events = new Map();
const window = { addEventListener: (name, listener) => events.set(name, listener) };
const document = {getElementById: name => name === 'startup' ? startup : name === 'hyperion-operation-loader' ? overlay : null};
runInNewContext(source, {window, document, setTimeout, clearTimeout, Math});
const loader = window.hyperionBooksLoader;
assert(loader && typeof loader.start === 'function');
const first = loader.start('Saving entry');
advance(90);
assert(!overlay.classList.contains('is-visible'), 'Startup should hide operation overlay');
events.get('flutter-first-frame')();
assert(startup.isRemoved, 'Startup must disappear on Flutter first frame');
advance(75);
assert(overlay.classList.contains('is-visible'), 'Overlay should show during a task');
assert.equal(overlay.attributes['aria-label'], 'Saving entry');
const second = loader.start('Exporting Excel books');
loader.stop(first);
advance(80);
assert(overlay.classList.contains('is-visible'), 'Overlapping tasks must retain indicator');
assert.equal(overlay.attributes['aria-label'], 'Exporting Excel books');
loader.stop(second);
advance(185);
assert(!overlay.classList.contains('is-visible'), 'Overlay must hide after final task');
loader.pulse('Loading books',480);
advance(80);
assert(overlay.classList.contains('is-visible'), 'Route pulse should show cube');
advance(600);
assert(!overlay.classList.contains('is-visible'), 'Route pulse should end without leaking tasks');
assert.equal(overlay.attributes['aria-hidden'], 'true');
console.log('PASS: Hyperion PWA-style cube markup, startup, overlapping loading tasks, route pulse, and reduced motion markers.');
