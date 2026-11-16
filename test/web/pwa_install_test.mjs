import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {runInNewContext} from 'node:vm';
const script = await readFile(new URL('../../web/pwa.js', import.meta.url), 'utf8');

test('PWA leaves installation to the browser and registers offline support', async () => {
  const events = {};
  const registrations = [];
  runInNewContext(script, {
    console, URL,
    window: {isSecureContext: true, addEventListener: (name, fn) => events[name] = fn},
    navigator: {serviceWorker: {register: async (url, options) => registrations.push({url, options})}},
    document: {baseURI: 'https://example.com/app/'},
  });
  assert.equal(events.beforeinstallprompt, undefined);
  assert.deepEqual(Object.keys(events), ['load']);
  events.load();
  assert.equal(registrations[0].url.href, 'https://example.com/app/service-worker.js');
  assert.equal(registrations[0].options.updateViaCache, 'none');
});
