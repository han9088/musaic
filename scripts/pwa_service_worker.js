/* Generated with an exact build manifest; never cache music URLs or API data. */
const VERSION = __VERSION__;
const FILES = __FILES__;
const PREFIX = `musaic-pwa:${self.registration.scope}:`;
const CACHE = PREFIX + VERSION;
const assets = new Map(FILES.map(({path, integrity}) => [new URL(path, self.registration.scope).href, integrity]));
const urls = [...assets.keys()];
const manifestKey = new URL('__musaic_cache_manifest__', self.registration.scope).href;

async function download(url) {
  const response = await fetch(new Request(url, {cache: 'reload', integrity: assets.get(url)}));
  if (!response.ok || response.redirected) throw new Error(`Cannot cache ${url}`);
  return response;
}

self.addEventListener('install', event => {
  event.waitUntil((async () => {
    try {
      const cache = await caches.open(CACHE);
      const previous = [];
      for (const key of await caches.keys()) {
        if (!key.startsWith(PREFIX) || key === CACHE) continue;
        const old = await caches.open(key);
        const manifest = await old.match(manifestKey);
        if (manifest) previous.push({cache: old, assets: new Map(await manifest.json())});
      }
      let next = 0;
      // Bound concurrent downloads; a failed install leaves the old app intact.
      const results = await Promise.allSettled(Array.from({length: 4}, async () => {
        while (next < urls.length) {
          const url = urls[next++];
          let response;
          for (const old of previous) {
            if (old.assets.get(url) === assets.get(url)) response = await old.cache.match(url);
            if (response) break;
          }
          await cache.put(url, response || await download(url));
        }
      }));
      const failure = results.find(result => result.status === 'rejected');
      if (failure) {
        throw failure.reason;
      }
      await cache.put(manifestKey, new Response(JSON.stringify([...assets])));
      // Do not skipWaiting: existing tabs must finish using their current build.
    } catch (error) {
      await caches.delete(CACHE);
      throw error;
    }
  })());
});

self.addEventListener('activate', event => {
  event.waitUntil((async () => {
    for (const key of await caches.keys()) {
      if (key.startsWith(PREFIX) && key !== CACHE) await caches.delete(key);
    }
    // Never claim an already-loading page: it may still be using the old build.
  })());
});

self.addEventListener('fetch', event => {
  const request = event.request;
  if (request.method !== 'GET') return;
  const url = new URL(request.url);
  if (!url.href.startsWith(self.registration.scope)) return;
  const key = request.mode === 'navigate'
    ? new URL('index.html', self.registration.scope).href
    : url.href;
  if (!assets.has(key)) return;
  event.respondWith((async () => {
    const cache = await caches.open(CACHE);
    const response = (await cache.match(key)) || await download(key);
    const range = request.headers.get('range');
    if (!range) return response;
    // Browser audio elements request ranges even for tiny bundled tick sounds.
    const match = /^bytes=(\d*)-(\d*)$/.exec(range);
    const blob = await response.blob();
    const size = blob.size;
    const start = match?.[1] ? Number(match[1]) : Math.max(0, size - Number(match?.[2]));
    const end = match?.[1] && match[2] ? Math.min(Number(match[2]), size - 1) : size - 1;
    if (!match || (!match[1] && !match[2]) || !Number.isSafeInteger(start) ||
        !Number.isSafeInteger(end) || start > end || start >= size) {
      return new Response(null, {status: 416, headers: {'Content-Range': `bytes */${size}`}});
    }
    const headers = new Headers(response.headers);
    headers.delete('Content-Encoding'); // blob() contains decoded bytes.
    headers.set('Content-Range', `bytes ${start}-${end}/${size}`);
    headers.set('Content-Length', String(end - start + 1));
    headers.set('Accept-Ranges', 'bytes');
    return new Response(blob.slice(start, end + 1), {status: 206, headers});
  })());
});
