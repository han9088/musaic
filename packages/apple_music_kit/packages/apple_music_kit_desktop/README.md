# apple_music_kit_desktop

Windows and Linux implementation of `apple_music_kit`. Registered automatically
by the main package; applications keep the same Dart API.

This is a **browser companion**, not a native MusicKit SDK or embedded WebView.
`initialize()` opens the default browser and waits for its connection. MusicKit JS
runs there; Flutter controls it over an authenticated loopback WebSocket.
Authorization, catalog/library operations, playlist writes, song queues, playback,
seeking, shuffle/repeat and state events are implemented. Queue removal is not
available in MusicKit JS and returns `unsupportedFeature`.

## Requirements and interaction

- Windows or a Linux desktop with `xdg-open` and a configured default browser.
- A browser capable of Apple Music protected-content playback, with DRM enabled.
  Browser/OS combinations still need real-account acceptance testing.
- A developer token from your backend, supplied with `DeveloperTokenProvider`.
  The page uses `http://127.0.0.1:<ephemeral-port>`; a token restricted to a
  different web origin will not work. Check your token issuer's origin policy.
- An Apple Music subscription for full tracks.
- Keep the companion tab open. Click its sign-in button when the application
  requests authorization. If autoplay is blocked, press its Play button once.
- Requests and connection setup time out after two minutes. A timed-out mutation
  is **not retried**: it may have already reached Apple. Dispose the client,
  close the old tab, and create a new client to reconnect.
- Closing/reloading the tab disconnects the app. `dispose()` releases the bridge
  but leaves browser playback running; `dispose(stopPlayback: true)` requests a
  stop first. The companion retains Play/Pause and Stop controls after disconnect.
  Closing the tab also stops its audio.

The listener binds only to IPv4 loopback. Host, WebSocket Origin and a random
256-bit session credential are checked. The credential is handed to the browser
in a URL fragment, removed immediately, and never placed in HTTP paths. The
user token and audio remain within MusicKit JS. No additional Dart dependency,
DRM component or Apple binary is bundled. The browser owns its sign-in storage.

## Validation

```sh
flutter pub get
flutter test
node --test test/companion_test.cjs
```

Tests cover local connection authentication, RPC, disconnects, timeouts and SDK
command mappings using a fake MusicKit object. These do not validate real Apple
sign-in, DRM playback, or Windows/Linux native builds. CI includes both desktop
build jobs. See the repository's `docs/known-limitations.md`.
