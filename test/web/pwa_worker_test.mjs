import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {runInNewContext} from 'node:vm';
const template = await readFile(new URL('../../scripts/pwa_service_worker.js', import.meta.url), 'utf8');

function worker(fail = false) {
  const events = {};
  const scope = 'https://example.test/musaic/';
  const name = `musaic-pwa:${scope}:v2`;
  const storage = new Map([[`musaic-pwa:${scope}:v1`, new Map()], ['another-app', new Map()]]);
  const caches = {
    async open(key) {
      if (!storage.has(key)) storage.set(key, new Map());
      const cache = storage.get(key);
      return {put: async (url, response) => {
        if (fail === 'metadata' && key === name && url.endsWith('__musaic_cache_manifest__')) throw Error('quota exceeded');
        cache.set(url, response);
      }, match: async url => cache.get(url)?.clone()};
    },
    keys: async () => [...storage.keys()], delete: async key => storage.delete(key),
  };
  const requests = [];
  let active = 0;
  let peak = 0;
  runInNewContext(template.replace('__VERSION__', '"v2"').replace('__FILES__', JSON.stringify(['index.html', ...Array.from({length: 20}, (_, i) => `asset${i}`)].map(path => ({path, integrity: 'sha256-test'})))), {
    self: {registration: {scope}, clients: {claim: async () => {throw Error('Must not force claim');}}, addEventListener: (name, fn) => events[name] = fn},
    caches, URL, Request, Response, Headers,
    fetch: async request => {
      assert.equal(request.integrity, 'sha256-test');
      requests.push(request.url);
      active++;
      peak = Math.max(peak, active);
      await new Promise(done => setTimeout(done, 1));
      active--;
      const response = new Response('bundled bytes', {status: fail === true && request.url.endsWith('asset3') ? 500 : 200});
      Object.defineProperty(response, 'url', {value: request.url});
      return response;
    },
  });
  const lifecycle = name => new Promise((resolve, reject) => events[name]({waitUntil: value => value.then(resolve, reject)}));
  return {events, storage, lifecycle, name, requests, peak: () => peak, scope};
}

test('precache is bounded, activation preserves other apps, navigation works in a subpath', async () => {
  const w = worker();
  await w.lifecycle('install');
  assert.ok(w.peak() <= 4);
  await w.lifecycle('activate');
  assert.deepEqual([...w.storage.keys()], ['another-app', w.name]);
  let response;
  w.events.fetch({request: {url: w.scope + 'nested', method: 'GET', mode: 'navigate', headers: new Headers()}, respondWith: value => response = value});
  assert.equal(await (await response).text(), 'bundled bytes');
  response = undefined;
  w.events.fetch({request: new Request('https://music.example/song.mp3'), respondWith: value => response = value});
  assert.equal(response, undefined);
});

test('failed install removes its partial cache and keeps old working cache', async () => {
  const w = worker(true);
  await assert.rejects(w.lifecycle('install'));
  assert.equal(w.storage.has(w.name), false);
  assert.equal(w.storage.has(`musaic-pwa:${w.scope}:v1`), true);
  assert.equal(w.storage.has('another-app'), true);
});

test('offline cached audio supports normal, suffix and unsatisfiable ranges', async () => {
  const w = worker();
  await w.lifecycle('install');
  for (const [range, status, body] of [['bytes=0-3', 206, 'bund'], ['bytes=-5', 206, 'bytes'], ['bytes=99-', 416, ''], ['bytes=-0', 416, '']]) {
    let pending;
    w.events.fetch({request: new Request(w.scope + 'asset0', {headers: {range}}), respondWith: value => pending = value});
    const response = await pending;
    assert.equal(response.status, status);
    assert.equal(await response.text(), body);
  }
});

test('unchanged assets reuse verified old cache and only changed entries download', async () => {
  const w = worker();
  const old = w.storage.get(`musaic-pwa:${w.scope}:v1`);
  const entries = ['index.html', ...Array.from({length: 20}, (_, i) => `asset${i}`)].map(path => [w.scope + path, path === 'asset3' ? 'sha256-old' : 'sha256-test']);
  old.set(w.scope + '__musaic_cache_manifest__', new Response(JSON.stringify(entries)));
  for (const [url] of entries) old.set(url, new Response('old bundle'));
  await w.lifecycle('install');
  assert.deepEqual(w.requests, [w.scope + 'asset3']);
  assert.equal(await w.storage.get(w.name).get(w.scope + 'asset0').clone().text(), 'old bundle');
});

test('cache eviction recovery still validates the expected build', async () => {
  const w = worker();
  await w.lifecycle('install');
  w.storage.get(w.name).delete(w.scope + 'asset0');
  w.requests.length = 0;
  let response;
  w.events.fetch({request: new Request(w.scope + 'asset0'), respondWith: value => response = value});
  assert.equal(await (await response).text(), 'bundled bytes');
  assert.deepEqual(w.requests, [w.scope + 'asset0']);
});

test('quota failure while finalizing manifest rolls back the new cache', async () => {
  const w = worker('metadata');
  await assert.rejects(w.lifecycle('install'), /quota exceeded/);
  assert.equal(w.storage.has(w.name), false);
  assert.equal(w.storage.has(`musaic-pwa:${w.scope}:v1`), true);
});
