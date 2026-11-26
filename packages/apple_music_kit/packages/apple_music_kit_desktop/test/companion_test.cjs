const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const source = fs.readFileSync(`${__dirname}/../assets/companion.js`, 'utf8');

async function fixture() {
  const elements = Object.fromEntries(['status', 'authorize', 'play', 'stop'].map(id => [id, { focus() {} }]));
  const messages = [];
  const calls = [];
  const handlers = {};
  let socket;
  const kit = {
    isAuthorized: false, playbackState: 0, queue: { position: -1, items: [] }, shuffleMode: 0, repeatMode: 0,
    get nowPlayingItem() { return kit.queue.items[kit.queue.position]; },
    addEventListener(name, callback) { handlers[name] = callback; }, async hasMusicSubscription() { return true; },
    async authorize() { kit.isAuthorized = true; },
    api: { async music(path, params, options) {
      calls.push({ path, params, options });
      if (path === 'v1/me/storefront') return { data: { data: [{ id: 'us', attributes: { name: 'United States' } }] } };
      if (path.includes('/search')) return { data: { results: { 'library-songs': { data: [] } } } };
      if (options.fetchOptions?.method === 'POST') return { data: {} };
      return { data: { data: [{ id: path.split('/').pop(), type: path.includes('/library/') ? 'library-songs' : 'songs' }] } };
    } },
    async setQueue(options) { calls.push({ queue: options }); kit.queue.items = [...options.items]; kit.queue.position = 0; },
    async playLater(options) { calls.push({ append: options }); kit.queue.items.push(...options.items); },
    async play() { kit.playbackState = 2; }, async pause() { kit.playbackState = 3; },
    async stop() { kit.playbackState = 4; }, async seekToTime(seconds) { calls.push({ seconds }); },
    async skipToNextItem() { kit.queue.position++; }, async skipToPreviousItem() { kit.queue.position--; },
  };
  class WebSocket {
    static OPEN = 1;
    readyState = 1;
    constructor(url, protocols) { socket = this; assert.equal(protocols[1], 'secret'); }
    send(json) { messages.push(JSON.parse(json)); }
  }
  const context = {
    location: { hash: '#secret', host: '127.0.0.1:12345' }, history: { replaceState() {} },
    document: { getElementById: id => elements[id], createElement: () => ({}), head: { appendChild: script => queueMicrotask(() => script.onload()) } },
    WebSocket, MusicKit: { PlaybackStates: { none: 0, loading: 1, playing: 2, paused: 3, stopped: 4, ended: 5, seeking: 6, waiting: 8, stalled: 9, completed: 10 }, async configure(config) { assert.equal(config.developerToken, 'token'); return kit; } },
  };
  vm.runInNewContext(source, context);
  let id = 0;
  const request = async (method, args = {}) => {
    const current = ++id;
    await socket.onmessage({ data: JSON.stringify({ id: current, method, args }) });
    return messages.find(m => m.id === current);
  };
  await request('initialize', { developerToken: 'token', appName: 'Test', appBuild: '1' });
  return { request, kit, elements, calls, messages, socket, handlers };
}

test('authorization waits for a real page click and capabilities reflect subscription', async () => {
  const f = await fixture();
  assert.equal((await f.request('getCapabilities')).result.canPlayCatalog.supported, false);
  const pending = f.request('requestAuthorization');
  await Promise.resolve();
  assert.match(f.elements.status.textContent, /Sign in/);
  await f.elements.authorize.onclick();
  assert.equal((await pending).result, 'authorized');
  assert.equal((await f.request('getCapabilities')).result.canPlayCatalog.supported, true);
  assert.equal((await f.request('getCapabilities')).result.canEditQueue.supported, false);
});

test('queue resolves library/catalog refs, uses SDK queue position and public skip methods', async () => {
  const f = await fixture();
  const refs = [{ id: '1', type: 'songs', source: 'catalog', storefront: 'us' }, { id: 'i.2', type: 'songs', source: 'library' }];
  assert.equal((await f.request('setQueue', { items: refs, startIndex: 1, autoplay: false })).error, undefined);
  assert.equal((await f.request('getQueue')).result.currentIndex, 1);
  assert.deepEqual((await f.request('getQueue')).result.entries.map(e => e.ref), refs);
  assert.ok(f.calls.some(c => c.path === 'v1/me/library/songs/i.2'));
  await f.request('skipToPrevious');
  assert.equal(f.kit.queue.position, 0);
  await f.request('skipToNext');
  assert.equal(f.kit.queue.position, 1);
  await f.request('seekTo', { positionMillis: 1250 });
  assert.ok(f.calls.some(c => c.seconds === 1.25));
  await f.request('appendToQueue', { items: [refs[0]] });
  assert.equal((await f.request('getQueue')).result.entries.length, 3);
  assert.equal((await f.request('removeFromQueue', { index: 0 })).error.code, 'unsupportedFeature');
  const before = f.calls.length;
  assert.equal((await f.request('setQueue', { items: refs, startIndex: 3 })).error.code, 'resourceUnavailable');
  assert.equal(f.calls.length, before);
});

test('API mapping encodes ids, handles library search and POST empty responses', async () => {
  const f = await fixture();
  await f.request('getCatalogSong', { id: '../bad', storefront: 'us' });
  assert.equal(f.calls.length, 0);
  assert.equal((await f.request('getCatalogSong', { id: '..', storefront: 'us' })).error.code, 'resourceNotFound');
  await f.request('getCatalogAlbum', { id: 'a b', storefront: 'us', includeTracks: true });
  assert.equal(f.calls.at(-1).path, 'v1/catalog/us/albums/a%20b');
  assert.equal(f.calls.at(-1).params.include, 'tracks');
  assert.ok((await f.request('searchLibrary', { term: 'a', types: ['songs'], limit: 25 })).result.songs);
  const tracks = [{ id: '1', type: 'songs', source: 'catalog' }];
  assert.equal((await f.request('addToPlaylist', { playlistId: 'p.1', tracks })).error, undefined);
  assert.equal(f.calls.at(-1).options.fetchOptions.headers['Content-Type'], 'application/json');
  assert.deepEqual(JSON.parse(f.calls.at(-1).options.fetchOptions.body), { data: [{ id: '1', type: 'songs' }] });
});

test('failures do not leak SDK errors and disconnect leaves explicit browser stop control', async () => {
  const f = await fixture();
  f.kit.play = async () => { throw { status: 403, message: 'secret-token' }; };
  const reply = await f.request('play');
  assert.deepEqual(reply.error, { code: 'authorizationDenied' });
  const pending = f.request('requestAuthorization');
  await Promise.resolve();
  f.socket.onclose();
  assert.equal((await pending).error.code, 'authorizationCancelled');
  await f.elements.stop.onclick();
  assert.equal(f.kit.playbackState, 4);
});


test('player events map waiting and completion without confusing them with errors', async () => {
  const f = await fixture();
  f.kit.playbackState = 8;
  f.handlers.playbackStateDidChange();
  assert.equal(f.messages.at(-1).value.status, 'buffering');
  assert.equal(f.messages.at(-1).value.isBuffering, true);
  f.kit.playbackState = 10;
  f.handlers.playbackStateDidChange();
  assert.equal(f.messages.at(-1).value.status, 'completed');
  assert.equal(f.messages.at(-1).value.isBuffering, false);
});

test('playlist creation, charts and catalog errors preserve the transport contract', async () => {
  const f = await fixture();
  f.kit.api.music = async (path, params, options) => {
    f.calls.push({ path, params, options });
    if (path.endsWith('/charts')) return { data: { results: { albums: [{ name: 'Top Albums', data: [{ id: '1' }] }] } } };
    return { data: { data: [{ id: 'p.new', attributes: { name: 'New', description: { standard: 'Description' } } }] } };
  };
  const reply = await f.request('createPlaylist', { name: 'New', description: 'Description', tracks: [{ id: 'i.1', type: 'songs', source: 'library' }] });
  assert.deepEqual(reply.result, { id: 'p.new', name: 'New', description: 'Description' });
  const body = JSON.parse(f.calls.at(-1).options.fetchOptions.body);
  assert.equal(body.relationships.tracks.data[0].type, 'library-songs');
  const charts = await f.request('getCharts', { kind: 'albums', storefront: 'us', limit: 20 });
  assert.deepEqual(charts.result, [{ name: 'Top Albums', albums: { data: [{ id: '1' }] } }]);
  f.kit.api.music = async () => { throw { status: 429 }; };
  assert.equal((await f.request('getCatalogSong', { id: '1', storefront: 'us' })).error.code, 'rateLimited');
  f.kit.api.music = async () => { throw new TypeError('network error with secret'); };
  assert.equal((await f.request('getCatalogSong', { id: '1', storefront: 'us' })).error.code, 'networkError');
});


test('queue resolves the default storefront once and respects explicit storefronts', async () => {
  const f = await fixture();
  const items = [
    { id: '1', type: 'songs', source: 'catalog' },
    { id: '2', type: 'songs', source: 'catalog' },
    { id: '3', type: 'songs', source: 'catalog', storefront: 'jp' },
    { id: 'i.4', type: 'songs', source: 'library' },
  ];
  assert.equal((await f.request('setQueue', { items, startIndex: 0, autoplay: false })).error, undefined);
  assert.equal(f.calls.filter(call => call.path === 'v1/me/storefront').length, 1);
  assert.ok(f.calls.some(call => call.path === 'v1/catalog/us/songs/2'));
  assert.ok(f.calls.some(call => call.path === 'v1/catalog/jp/songs/3'));
});


test('shuffled queue reports actual SDK order and retains library identity and storefront', async () => {
  const f = await fixture();
  const items = [
    { id: '1', type: 'songs', source: 'catalog', storefront: 'us' },
    { id: 'i.2', type: 'songs', source: 'library' },
    { id: '3', type: 'songs', source: 'catalog', storefront: 'jp' },
  ];
  await f.request('setQueue', { items, startIndex: 1, autoplay: false });
  // MusicKit keeps the playing item first when it shuffles the remaining queue.
  const [a, b, c] = f.kit.queue.items;
  f.kit.queue.items = [b, c, a];
  f.kit.queue.position = 0;
  f.handlers.shuffleModeDidChange();
  assert.deepEqual(f.messages.at(-1).value.currentItem, items[1]);
  const queue = (await f.request('getQueue')).result;
  assert.deepEqual(queue.entries.map(entry => entry.ref), [items[1], items[2], items[0]]);
  assert.equal(queue.currentIndex, 0);
  await f.request('skipToNext');
  f.handlers.nowPlayingItemDidChange();
  assert.deepEqual(f.messages.at(-1).value.currentItem, items[2]);
});


test('setQueue selects the requested song even when the SDK reorders on load', async () => {
  const f = await fixture();
  const items = [
    { id: '1', type: 'songs', source: 'catalog', storefront: 'us' },
    { id: 'i.2', type: 'songs', source: 'library' },
    { id: '3', type: 'songs', source: 'catalog', storefront: 'us' },
  ];
  const setQueue = f.kit.setQueue;
  f.kit.setQueue = async options => {
    await setQueue(options);
    const [a, b, c] = f.kit.queue.items;
    f.kit.queue.items = [b, c, a];
  };
  await f.request('setShuffleMode', { mode: 'on' });
  const reply = await f.request('setQueue', { items, startIndex: 1, autoplay: true });
  assert.equal(reply.error, undefined);
  assert.equal(f.kit.queue.position, 0);
  assert.deepEqual(f.messages.findLast(message => message.event === 'state').value.currentItem, items[1]);
});


test('setQueue preserves the requested occurrence of a repeated song', async () => {
  const f = await fixture();
  const a = { id: '1', type: 'songs', source: 'catalog', storefront: 'us' };
  const b = { id: '2', type: 'songs', source: 'catalog', storefront: 'us' };
  const items = [a, b, a];
  assert.equal((await f.request('setQueue', { items, startIndex: 2, autoplay: false })).error, undefined);
  assert.equal(f.kit.queue.position, 2);
  const setQueue = f.kit.setQueue;
  f.kit.setQueue = async options => {
    await setQueue(options);
    const [first, second, third] = f.kit.queue.items;
    f.kit.queue.items = [first, third, second];
  };
  await f.request('setShuffleMode', { mode: 'on' });
  assert.equal((await f.request('setQueue', { items, startIndex: 2, autoplay: false })).error, undefined);
  assert.equal(f.kit.queue.position, 1);
});
