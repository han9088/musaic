# Known limitations

Honest status of what has and has not been verified. This document exists
so no one mistakes "compiles" for "works".

## Verified in this repository

- Windows/Linux live-mode Dart bundles compile, including desktop registration
  and companion assets; this does not compile the native C++ runners.
- Existing interface/client unit tests pass. The desktop addition has Dart transport
  tests and Node browser-command tests. The three type-inference warnings in
  `animated_artwork_test.dart` have been fixed with explicit collection types.
- iOS: full `flutter build ios --debug --no-codesign` against the
  iPhoneOS SDK (Xcode 27.2). Swift sources compile against the real
  MusicKit swiftinterface, not remembered APIs.
- Android: SDK-backed APK build verified with MediaPlayback 1.1.4 and MusicKitAuth 1.1.5; real-account runtime acceptance remains outstanding.
- Web: full `flutter build web` (dart2js). No `dart:html` /
  `dart:js_util` / legacy `package:js` anywhere.

## NOT verified (requires external resources)

| Item | What's needed |
|---|---|
| iOS runtime playback/auth | Physical iPhone + Apple ID with Apple Music + MusicKit entitlement on the App ID |
| iOS background audio | Device test with Audio background mode |
| Android full implementation runtime | Apple MusicKit Android AARs (manual download) + Apple Music app + device |
| Android background playback / notification media controls | Device testing with the AARs provisioned |
| Web playback in each browser | HTTPS deployment + developer token with allowed origins |
| Windows/Linux native builds | Corresponding host toolchain; desktop CI jobs added but not executed locally |
| Windows/Linux browser companion auth/playback | Target desktop, DRM-capable default browser, developer token and subscription |
| Music user token flows end-to-end | Apple Music subscription on the test account |
| Charts/catalog real data | Valid developer token |

Until these run, treat platform runtime behavior as **implemented per
official API surface but not runtime-verified**.

## Honest platform caveats

### iOS
- `MusicAuthorization` exposes no change-notification in current MusicKit;
  status changes are surfaced via `MusicSubscription.subscriptionUpdates`
  (account changes) and re-read on subscribe/`requestAuthorization()`.
  A status change made in Settings may not push instantly.
- Structured library requests require iOS 16+, so the plugin's minimum is
  iOS 16.
- Catalog/library results are serialized from MusicKit structures; some
  Apple Music API fields (e.g. `previewUrl` is derived from
  `previewAssets`) map slightly differently.
- Multiple FlutterEngines share `ApplicationMusicPlayer.shared` by design
  (Apple's model); the plugin avoids double-registered listeners per
  stream, not per engine.

### Android
- Apple's Android MusicKit SDK has had years-long update gaps. It may lag
  behind current Android versions; audio focus / media session behavior
  follows whatever the provisioned AARs implement. The plugin does not
  fight the SDK's own focus management.
- Queue editing support depends on the playback AAR version; failures map
  to `unsupportedFeature`, never silent success.
- If Apple's SDK proves unusable on modern Android, a WebView-based
  fallback would be an explicitly separate, clearly-labeled experiment —
  never a silent replacement.

### Web
- `authorize()` requires a real user gesture; browsers block programmatic
  popup-triggered auth.
- Background tabs: browsers suspend audio; `canPlayInBackground` reports
  unsupported.
- Wasm (`flutter build web --wasm`): the JS interop layer uses
  `dart:js_interop` and `package:web` which are wasm-compatible patterns,
  but full wasm runtime validation of MusicKit JS has not been executed
  here; dart2js is the verified target.
- Playlist creation and add-to-playlist go through the raw REST path via
  the SDK-managed `api.music()` call; they require authorization and have not
  been runtime-verified against a real account.
- Storefront resolution defaults to `us` when the storefront API call
  fails rather than throwing, but catalog ids remain storefront-scoped —
  pass explicit `storefront` where it matters.

### Windows / Linux
- Playback runs in the default system browser, not in a native MusicKit SDK.
- Keep the companion tab open; it owns playback and sign-in storage. A page click
  is needed for authorization and may be needed to satisfy autoplay policy.
- Local RPC is unit-tested. Windows/Linux builds, browser launch, account sign-in,
  protected-content playback, library writes and OS media keys remain unverified.
- No automatic browser reconnect or mutation retries. After disconnect/timeout,
  close the old tab and initialize a new client; a timed-out write may have succeeded.
- The ephemeral loopback origin must be compatible with developer-token origin
  restrictions. Linux requires `xdg-open`; sandboxed app distributions may need
  additional integration and are not validated.
- Queue removal and guaranteed background playback report unsupported. Ordinary
  disposal leaves audio in the browser; explicit stop or closing the tab stops it.

## Not implemented anywhere (by design)

- Playing Apple Music videos (models exist; player support not claimed).
- Lyrics/synchronized lyrics (compliance-sensitive; out of scope).
- Volume control on iOS (system-owned).
- Any audio download/extraction (prohibited by Apple terms).

## Review follow-up implementation status

- Android SDK 1.1.4 playback / 1.1.5 authentication are wired to their actual APIs. Catalog and library requests use the Apple Music REST API on a background executor. Real-account authorization and playback still need device acceptance.
- Android queue entries must be songs from a single source (catalog or library). Mixed-source queues are rejected. Tokens remain in native memory for this plugin session; restarting the process requires authorization again.
- Android SDK playback is owned by a media-playback foreground service with a MediaSession and media notification. Playback survives Activity/FlutterEngine teardown; explicit stop releases the session. Real-device lock-screen and headset acceptance remains required.
- Web uses MusicKit v3 `api.music`, property setters for modes, and `playLater` for appending. Public queue removal is unavailable and returns `unsupportedFeature`; `canEditQueue` is false.
- Queue entries are songs; expand an album or playlist to tracks before calling `setQueue`.
- SDK archives stay outside the repository. `MUSICKIT_ANDROID_SDK_DIR` accepts the SDK archive filenames or the older `musickitauth.aar` / `musickitplayback.aar` names.

## Experimental animated album artwork

The on-demand catalog API now requests `extend=editorialVideo` through existing
platform transports. Compatibility of these undocumented fields with ordinary
developer tokens and native MusicDataRequest has not been integration-verified.
An empty result only describes the received response. See
[animated artwork](animated-artwork.md) for exact paths, error semantics,
request-sharing lifecycle, reference source evidence and validation limits.
