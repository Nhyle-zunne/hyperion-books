import { readFileSync } from 'node:fs';
import { runInNewContext } from 'node:vm';
import assert from 'node:assert/strict';

const html = readFileSync('web/index.html', 'utf8');
const manifest = JSON.parse(readFileSync('web/manifest.json', 'utf8'));
const script = html.match(
  /<script id="hyperion-books-install-controller">([\\s\\S]*?)<\\/script>/,
)?.[1];
assert.ok(script, 'Install controller must run before Flutter starts');
assert.ok(html.indexOf('hyperion-books-install-controller') <
  html.indexOf('flutter_bootstrap.js'), 'Install capture must precede Flutter');

function setup(userAgent, options = {}) {
  const listeners = new Map();
  const win = {
    matchMedia: () => ({ matches: options.standalone ?? false }),
    addEventListener: (event, handler) => {
      const entries = listeners.get(event) || [];
      entries.push(handler);
      listeners.set(event, entries);
    },
    dispatchEvent: event => {
      for (const handler of listeners.get(event.type) || []) handler(event);
    },
  };
  const nav = {
    userAgent,
    platform: options.platform || '',
    maxTouchPoints: options.touchPoints ?? 0,
    standalone: options.appleStandalone ?? false,
  };
  class Event { constructor(type) { this.type = type; } }
  runInNewContext(script, { window: win, navigator: nav, Event });
  const emit = (name, event) => {
    for (const handler of listeners.get(name) || []) handler(event);
  };
  return {
    api: win.hyperionBooksInstall,
    emit,
    read: () => JSON.parse(win.hyperionBooksInstall.status()),
  };
}

const android = setup('Mozilla/5.0 (Linux; Android 17) AppleWebKit Chrome/142');
assert.equal(android.read().platform, 'android');
assert.equal(android.read().canPrompt, false);
let prevented = false;
let prompts = 0;
android.emit('beforeinstallprompt', {
  preventDefault: () => { prevented = true; },
  prompt: () => { prompts++; return Promise.resolve(); },
  userChoice: Promise.resolve({ outcome: 'accepted' }),
});
assert.ok(prevented, 'Browser install event must be captured');
assert.equal(android.read().canPrompt, true);
assert.equal(await android.api.prompt(), 'accepted');
assert.equal(prompts, 1);
assert.equal(android.read().canPrompt, false);
assert.equal(await android.api.prompt(), 'unavailable',
  'Prompt is one-time-use; never replay it');
android.emit('appinstalled', {});
assert.equal(android.read().installed, true);
assert.equal(await android.api.prompt(), 'installed');

const ios = setup('Mozilla/5.0 (iPhone; CPU iPhone OS 27_0) AppleWebKit Safari');
assert.equal(ios.read().platform, 'ios');
assert.equal(ios.read().canPrompt, false);
const ipad = setup('Mozilla/5.0 (Macintosh; Intel Mac OS X) AppleWebKit Safari',
  { platform: 'MacIntel', touchPoints: 5 });
assert.equal(ipad.read().platform, 'ios');
const desktop = setup('Mozilla/5.0 (Windows NT 10.0) AppleWebKit Chrome/142',
  { standalone: true });
assert.equal(desktop.read().platform, 'desktop');
assert.equal(desktop.read().installed, true);

assert.equal(manifest.display, 'standalone');
assert.equal(manifest.start_url, '.');
assert.equal(manifest.scope, '.');
assert.equal(manifest.id, './');
for (const iconSize of ['192x192', '512x512']) {
  assert.ok(manifest.icons.some(icon => icon.sizes === iconSize),
    `Missing PWA icon ${iconSize}`);
}
assert.match(html, /serviceWorker\\.register\('\.\/sw\.js'\)/,
  'App shell worker registration missing');
console.log('Install prompt capture, browser fallback, manifest and SW tests passed.');
