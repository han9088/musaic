/* MusicKit remains in the browser: no audio or user tokens cross the bridge. */
(() => {
  'use strict';
  const secret = location.hash.slice(1);
  history.replaceState(null, '', '/');
  const status = document.getElementById('status');
  const authorize = document.getElementById('authorize');
  const play = document.getElementById('play');
  const stop = document.getElementById('stop');
  if (!secret) { status.textContent = 'Open this page from the desktop app.'; return; }
  const socket = new WebSocket(`ws://${location.host}/bridge`, ['musickit', secret]);
  let kit;
  let refs = new Map();
  let pendingAuthorization;
  const fail = code => { throw Object.assign(new Error(code), { code }); };
  const send = data => { if (socket.readyState === WebSocket.OPEN) socket.send(JSON.stringify(data)); };
  const authStatus = () => kit.isAuthorized ? 'authorized' : 'notDetermined';
  const authEvent = () => send({ event: 'authorization', value: authStatus() });
  const itemRef = item => {
    if (!item) return null;
    const source = item.type.startsWith('library-') ? 'library' : 'catalog';
    return refs.get(`${source}:${item.id}`) || { id: item.id, type: item.type.replace(/^library-/, ''), source };
  };
  const state = () => {
    const index = kit.queue.position;
    const value = kit.playbackState;
    const states = MusicKit.PlaybackStates;
    const statusName = Object.keys(states).find(key => states[key] === value);
    const buffering = ['loading', 'seeking', 'waiting', 'stalled'].includes(statusName);
    send({ event: 'state', value: {
      status: ({ none: 'idle', loading: 'loading', playing: 'playing', paused: 'paused', stopped: 'stopped', ended: 'completed', completed: 'completed', seeking: 'buffering', waiting: 'buffering', stalled: 'buffering' })[statusName] || 'idle',
      currentItem: itemRef(kit.nowPlayingItem), currentIndex: index >= 0 ? index : null,
      positionMillis: Math.round((kit.currentPlaybackTime || 0) * 1000),
      durationMillis: Number.isFinite(kit.currentPlaybackDuration) ? Math.round(kit.currentPlaybackDuration * 1000) : null,
      queueLength: kit.queue.items.length, shuffleMode: kit.shuffleMode === 1 ? 'on' : 'off',
      repeatMode: ['off', 'one', 'all'][kit.repeatMode] || 'off',
      isPlaying: statusName === 'playing', isBuffering: buffering,
    }});
  };
  const sdk = new Promise((resolve, reject) => {
    const script = document.createElement('script');
    script.src = 'https://js-cdn.music.apple.com/musickit/v3/musickit.js';
    script.onload = resolve;
    script.onerror = () => reject(Object.assign(new Error(), { code: 'sdkUnavailable' }));
    document.head.appendChild(script);
  });
  // Attach a handler immediately, including when the desktop disconnects early.
  sdk.catch(() => { status.textContent = 'MusicKit could not load. Check your connection and restart the app.'; });
  const segment = value => {
    if (typeof value !== 'string' || !value || /[/\\?#&]/.test(value) || value === '.' || value === '..') fail('resourceNotFound');
    return encodeURIComponent(value);
  };
  const api = async (path, parameters = {}, options = {}) => {
    if (options.fetchOptions?.body) options.fetchOptions.headers = { 'Content-Type': 'application/json' };
    const response = await kit.api.music(path, parameters, options);
    if (options.fetchOptions?.method === 'POST' && !response?.data) return {};
    if (!response || !response.data || typeof response.data !== 'object') fail('unknown');
    return response.data;
  };
  const storefront = async explicit => explicit ? segment(explicit) : segment((await api('v1/me/storefront')).data?.[0]?.id || 'us');
  const first = response => response.data?.[0] || fail('resourceNotFound');
  const tracks = items => items.map(ref => ({ id: ref.id, type: ref.source === 'library' ? `library-${ref.type}` : ref.type }));
  const queueItems = async items => {
    if (!Array.isArray(items) || items.some(ref => ref.type !== 'songs')) fail('unsupportedFeature');
    const result = [];
    let defaultStorefront;
    for (const ref of items) {
      if (ref.source !== 'library' && !ref.storefront && !defaultStorefront) defaultStorefront = await storefront();
      const path = ref.source === 'library' ? `v1/me/library/songs/${segment(ref.id)}` :
        `v1/catalog/${ref.storefront ? segment(ref.storefront) : defaultStorefront}/songs/${segment(ref.id)}`;
      result.push(first(await api(path)));
    }
    return { items: result };
  };
  const librarySearch = results => Object.fromEntries(Object.entries(results).map(([key, value]) => [key.replace(/^library-/, ''), value]));
  const unsupported = { supported: false, reason: 'unsupportedOnPlatform' };
  const supported = { supported: true, reason: 'available' };
  async function dispatch(method, a) {
    if (method === 'initialize') {
      await sdk;
      kit = await MusicKit.configure({ developerToken: a.developerToken, app: { name: a.appName, build: a.appBuild } });
      for (const event of ['playbackStateDidChange', 'playbackTimeDidChange', 'nowPlayingItemDidChange', 'queueItemsDidChange', 'shuffleModeDidChange', 'repeatModeDidChange']) kit.addEventListener(event, state);
      kit.addEventListener('authorizationStatusDidChange', authEvent);
      authorize.disabled = play.disabled = stop.disabled = false;
      status.textContent = 'Connected. Sign in here when requested by the app.';
      authEvent(); state(); return null;
    }
    if (!kit) fail('notInitialized');
    switch (method) {
      case 'getAuthorizationStatus': return authStatus();
      case 'requestAuthorization':
        if (kit.isAuthorized) return 'authorized';
        if (pendingAuthorization) fail('authorizationCancelled');
        status.textContent = 'Click “Sign in to Apple Music” here to continue.';
        authorize.focus();
        return new Promise((resolve, reject) => { pendingAuthorization = { resolve, reject }; });
      case 'getSubscription': {
        const subscribed = await kit.hasMusicSubscription();
        return { status: subscribed ? 'subscribed' : 'notSubscribed', canPlayCatalogContent: subscribed };
      }
      case 'getCapabilities': {
        const library = kit.isAuthorized ? supported : { supported: false, reason: 'authorizationRequired' };
        const subscribed = kit.isAuthorized && await kit.hasMusicSubscription();
        return { canPlayCatalog: subscribed ? supported : { supported: false, reason: kit.isAuthorized ? 'subscriptionRequired' : 'authorizationRequired' },
          canAccessLibrary: library, canSeek: supported, canSetQueue: supported,
          canEditQueue: unsupported, canShuffle: supported, canRepeat: supported,
          canControlVolume: unsupported, canPlayInBackground: { ...unsupported, detail: 'Playback depends on the browser tab remaining open and the browser lifecycle.' }, canCreatePlaylist: library };
      }
      case 'searchCatalog': return (await api(`v1/catalog/${await storefront(a.storefront)}/search`, { term: a.term, types: a.types.join(','), limit: a.limit })).results || {};
      case 'getCatalogSong': case 'getCatalogAlbum': case 'getCatalogArtist': case 'getCatalogPlaylist': {
        const type = { getCatalogSong: 'songs', getCatalogAlbum: 'albums', getCatalogArtist: 'artists', getCatalogPlaylist: 'playlists' }[method];
        return first(await api(`v1/catalog/${await storefront(a.storefront)}/${type}/${segment(a.id)}`, a.includeTracks ? { include: 'tracks' } : {}));
      }
      case 'getAlbumAnimatedArtwork': return api(`v1/catalog/${await storefront(a.storefront)}/albums/${segment(a.id)}`, { extend: 'editorialVideo' });
      case 'getCurrentStorefront': return first(await api('v1/me/storefront'));
      case 'getCharts': {
        const type = a.kind === 'musicVideos' ? 'music-videos' : a.kind;
        const response = await api(`v1/catalog/${await storefront(a.storefront)}/charts`, { types: type, limit: a.limit });
        return (response.results?.[type] || []).map(chart => ({ name: chart.name, [type]: { data: chart.data } }));
      }
      case 'getLibrarySongs': case 'getLibraryAlbums': case 'getLibraryPlaylists': {
        const type = { getLibrarySongs: 'songs', getLibraryAlbums: 'albums', getLibraryPlaylists: 'playlists' }[method];
        return api(`v1/me/library/${type}`, { limit: a.limit, ...(a.offset == null ? {} : { offset: a.offset }) });
      }
      case 'searchLibrary': return librarySearch((await api('v1/me/library/search', { term: a.term, types: a.types.map(type => `library-${type}`).join(','), limit: a.limit })).results || {});
      case 'addToLibrary':
        if (a.songs.some(ref => ref.source !== 'catalog' || ref.type !== 'songs')) fail('unsupportedFeature');
        if (a.songs.length) await api('v1/me/library', { 'ids[songs]': a.songs.map(ref => ref.id).join(',') }, { fetchOptions: { method: 'POST' } });
        return null;
      case 'createPlaylist': {
        const body = { attributes: { name: a.name, ...(a.description == null ? {} : { description: a.description }) },
          ...(a.tracks?.length ? { relationships: { tracks: { data: tracks(a.tracks) } } } : {}) };
        const created = first(await api('v1/me/library/playlists', {}, { fetchOptions: { method: 'POST', body: JSON.stringify(body) } }));
        return { id: created.id, name: created.attributes?.name || a.name, description: created.attributes?.description?.standard };
      }
      case 'addToPlaylist':
        if (a.tracks.length) await api(`v1/me/library/playlists/${segment(a.playlistId)}/tracks`, {}, { fetchOptions: { method: 'POST', body: JSON.stringify({ data: tracks(a.tracks) }) } });
        return { playlistId: a.playlistId, added: a.tracks };
      case 'setQueue':
        if (!a.items?.length || !Number.isInteger(a.startIndex) || a.startIndex < 0 || a.startIndex >= a.items.length) fail('resourceUnavailable');
        await kit.setQueue(await queueItems(a.items));
        refs = new Map(a.items.map(ref => [`${ref.source}:${ref.id}`, ref]));
        // Shuffle may reorder the SDK queue during setQueue. Select by identity.
        const start = a.items[a.startIndex];
        const matchesStart = ref => ref.id === start.id && ref.source === start.source;
        let occurrence = a.items.slice(0, a.startIndex).filter(matchesStart).length;
        const position = kit.queue.items.findIndex(item => {
          if (!matchesStart(itemRef(item))) return false;
          if (occurrence === 0) return true;
          occurrence--;
          return false;
        });
        if (position < 0) fail('resourceUnavailable');
        kit.queue.position = position;
        state(); if (a.autoplay) await kit.play(); return null;
      case 'appendToQueue':
        if (a.items.length) { await kit.playLater(await queueItems(a.items)); for (const ref of a.items) refs.set(`${ref.source}:${ref.id}`, ref); state(); } return null;
      case 'getQueue': return { entries: kit.queue.items.map(item => ({ ref: itemRef(item) })), currentIndex: kit.queue.position >= 0 ? kit.queue.position : null };
      case 'removeFromQueue': fail('unsupportedFeature'); break;
      case 'play': await kit.play(); return null;
      case 'pause': await kit.pause(); return null;
      case 'stop': await kit.stop(); return null;
      case 'togglePlayPause': await (kit.playbackState === 2 ? kit.pause() : kit.play()); return null;
      case 'seekTo':
        if (!Number.isFinite(a.positionMillis) || a.positionMillis < 0) fail('resourceUnavailable');
        await kit.seekToTime(a.positionMillis / 1000); return null;
      case 'skipToNext': await kit.skipToNextItem(); return null;
      case 'skipToPrevious': await kit.skipToPreviousItem(); return null;
      case 'setShuffleMode': kit.shuffleMode = a.mode === 'on' ? 1 : 0; state(); return null;
      case 'setRepeatMode': kit.repeatMode = { off: 0, one: 1, all: 2 }[a.mode]; state(); return null;
      default: fail('unsupportedFeature');
    }
  }
  const errorCode = (error, method) => {
    const known = ['sdkUnavailable', 'notInitialized', 'resourceNotFound', 'resourceUnavailable', 'unsupportedFeature', 'authorizationCancelled', 'unknown'];
    if (known.includes(error?.code)) return error.code;
    if (error?.status >= 500 && error?.status <= 599) return 'networkError';
    const fallback = /^(get|search|add|create)/.test(method) ? 'networkError' : 'playbackFailed';
    return ({ 401: 'authenticationFailed', 403: 'authorizationDenied', 404: 'resourceNotFound', 408: 'requestTimeout', 409: 'resourceUnavailable', 410: 'resourceUnavailable', 429: 'rateLimited' })[error?.status] || fallback;
  };
  socket.onopen = () => send({ event: 'ready' });
  socket.onmessage = async event => {
    let request;
    try {
      request = JSON.parse(event.data);
      const result = await dispatch(request.method, request.args);
      send({ id: request.id, result: result ?? null });
    } catch (error) {
      send({ id: request?.id, error: { code: errorCode(error, request?.method) } });
      status.textContent = 'The request failed. Check sign-in, subscription and browser playback permissions.';
    }
  };
  socket.onclose = () => {
    status.textContent = 'App disconnected. Playback may continue; use Stop here or close this page to stop.';
    pendingAuthorization?.reject({ code: 'authorizationCancelled' }); pendingAuthorization = null;
  };
  socket.onerror = () => { status.textContent = 'Cannot connect to the app. Reopen playback from the app.'; };
  authorize.onclick = async () => {
    authorize.disabled = true;
    try {
      await kit.authorize();
      authEvent(); pendingAuthorization?.resolve(authStatus());
      status.textContent = 'Signed in. Return to the desktop app.';
    } catch (_) {
      pendingAuthorization?.reject({ code: 'authorizationCancelled' });
      status.textContent = 'Sign-in was cancelled or failed. You can try again.';
    } finally { pendingAuthorization = null; authorize.disabled = false; }
  };
  play.onclick = async () => {
    try { await (kit.playbackState === 2 ? kit.pause() : kit.play()); }
    catch (_) { status.textContent = 'Playback failed. Check your subscription and protected-content settings.'; }
  };
  stop.onclick = async () => {
    try { await kit.stop(); } catch (_) { status.textContent = 'Could not stop playback. Close this page to stop.'; }
  };
})();
