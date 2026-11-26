# apple_music_kit

Apple MusicKit for Flutter — authorization, catalog search, user library,
and playback across **iOS**, **Android**, **Web**, **Windows**, and **Linux**,
using Apple SDKs and MusicKit JS. Desktop playback runs in a browser companion.

- **iOS** — Swift + Apple MusicKit (`MusicAuthorization`,
  `ApplicationMusicPlayer`, `MusicCatalogSearchRequest`,
  `MusicLibraryRequest`, `MusicDataRequest`)
- **Android** — Apple's official MusicKit Android SDK (authentication +
  playback AARs; you provision them locally — see
  [Android setup](#android))
- **Web** — MusicKit JS v3 via the official CDN with modern
  `dart:js_interop` + `package:web`

- **Windows / Linux** — native Flutter UI with MusicKit JS in the system browser;
  keep the companion tab open ([desktop setup](#windows--linux)).

> **This is a third-party open-source project. It is not affiliated with
> or endorsed by Apple.** "Apple Music", "MusicKit", and related marks are
> trademarks of Apple Inc. All usage is subject to the Apple Developer
> Program License Agreement, the MusicKit documentation, and the App Store
> Review Guidelines.

## Status

| Area                                       | State                                                                                                  |
| ------------------------------------------ | ------------------------------------------------------------------------------------------------------ |
| Dart API (client, services, player facade) | ✅ Complete, tested                                                                                    |
| Mock platform (no credentials needed)      | ✅ Complete, tested                                                                                    |
| iOS implementation                         | ✅ Compiles (Xcode 27, iPhoneOS SDK). Runtime playback needs a real device + Apple Music account       |
| Android implementation                     | ⚠️ Builds a fallback stub without the Apple AARs; full implementation gated on locally-provisioned SDK |
| Web implementation                         | ✅ Compiles (dart2js). Runtime needs HTTPS + developer token                                           |
| Windows / Linux implementation              | ⚠️ Browser companion implemented and unit-tested; native builds and real-account playback not locally verified |
| Integration tests on real devices          | ❌ Not yet executed — see [docs/known-limitations.md](docs/known-limitations.md)                       |

## Installation

Add the packages (until published on pub.dev, use path/Git references):

```yaml
dependencies:
  apple_music_kit:
    git:
      url: https://github.com/han9088/apple_music_kit.git
      path: packages/apple_music_kit
```

The platform packages are resolved automatically via the default-package
federated plugin wiring. For Android you must also provision the Apple SDK
(see below).

## Usage

Every snippet in this section is compiled against the current API in
[`example/lib/usage_snippets.dart`](example/lib/usage_snippets.dart)
(`dart analyze` clean) — the docs never drift from the code.

Jump to: [Client](#client) · [Tokens](#tokens) ·
[Authorization](#authorization) · [Catalog](#catalog) ·
[Pagination](#pagination) · [Library](#library) · [Player](#player) ·
[State stream](#state-stream) · [Capabilities](#capabilities) ·
[Errors](#errors) · [Refs & artwork](#refs--artwork) ·
[Mock mode](#mock-mode-no-apple-credentials)

### Client

```dart
final music = AppleMusicClient(
  config: AppleMusicConfig(
    appName: 'My Music',
    appBuild: '1.0.0',
    developerTokenProvider: _ServerTokenProvider(), // see Tokens
  ),
);

await music.initialize();   // idempotent; concurrent calls share one run
// ... use it ...
await music.dispose();      // idempotent; does NOT stop shared playback
```

Rules the client enforces:

- `initialize()` is idempotent and single-flighted; a failed
  initialization is not cached and can be retried.
- Platform methods before `initialize()` throw
  `MusicKitException(notInitialized)`.
- Using a disposed client throws `MusicKitException(alreadyDisposed)`.
- `dispose()` releases **Dart** listeners only; the shared native player
  keeps playing unless you pass `dispose(stopPlayback: true)`.

### Tokens

Developer tokens (JWT) must come from **your server** — the .p8 key never
ships in the app. Wrap your fetch in a `DeveloperTokenProvider`; the
bundled `CachingDeveloperTokenProvider` adds caching, JWT-`exp`-aware
refresh, and concurrent single-flight:

```dart
final provider = CachingDeveloperTokenProvider(
  delegate: _ServerTokenProvider(),
  leadTime: const Duration(minutes: 5),   // refresh 5 min before exp
  fallbackTtl: const Duration(minutes: 30),
);

final music = AppleMusicClient(
  config: AppleMusicConfig(developerTokenProvider: provider),
);
await music.initialize();

provider.invalidate(); // force refetch on next use (e.g. after a 401)
```

- **iOS**: omit the provider entirely — MusicKit manages both tokens.
- **Android / Web / Windows / Linux**: required; `initialize()` fails fast with
  `developerTokenMissing` if it can't produce a token.
- Music user tokens are handled by each platform SDK and never exposed.

### Authorization

```dart
final status = await music.authorization.getStatus(); // no prompt
final result = await music.authorization.request();   // prompts once

music.authorization.statusChanges.listen((s) {
  print('auth: ${s.name}');
});

// Subscription is INDEPENDENT of authorization:
final subscription = await music.subscription.status;
print(subscription.canPlayCatalogContent);
```

- Statuses: `notDetermined`, `authorized`, `denied`, `restricted`,
  `unavailable`.
- After `denied`, re-requesting won't re-prompt — guide the user to
  Settings (iOS) or the browser flow (Web).
- **Web**: `request()` must run inside a real user gesture (button tap);
  browsers block programmatic auth popups.

### Catalog

```dart
final result = await music.catalog.search(
  'Taylor Swift',
  types: {MusicResourceType.song, MusicResourceType.album},
  limit: 25,
  storefront: 'us', // optional; defaults to the user's storefront
);
final songs = result.songs?.items ?? const <MusicSong>[];

final song = await music.catalog.getSong('1440843637');
final album = await music.catalog.getAlbum(id, includeTracks: true);
final artist = await music.catalog.getArtist(id);
final playlist = await music.catalog.getPlaylist(id);

final charts = await music.catalog.getCharts(MusicChartKind.songs);
final storefront = await music.catalog.getCurrentStorefront();
```

⚠️ Catalog ids are **storefront-scoped**: the same track has different ids
in different storefronts. Pass `storefront` explicitly when it matters.

### Pagination

List endpoints return `MusicPage<T>` with an offset-based continuation:

```dart
var page = await music.library.getSongs(limit: 50);
final all = [...page.items];
while (page.hasMore) {
  page = await music.library.getSongs(limit: 50, offset: page.nextOffset);
  all.addAll(page.items);
}
```

### Library

All library calls require authorization; otherwise they throw
`MusicKitException(authorizationDenied)`.

```dart
final songs = await music.library.getSongs(limit: 25);
final albums = await music.library.getAlbums();
final playlists = await music.library.getPlaylists();

final found = await music.library.search(
  'road trip',
  types: {MusicResourceType.song, MusicResourceType.playlist},
);

await music.library.addSongs([songRef]); // "Add to Library"

final created = await music.library.createPlaylist(
  'Road Trip',
  description: 'Highway anthems',
  tracks: songs.items.take(5).map((s) => s.ref).toList(),
);

await music.library.addToPlaylist(created.id, [anotherRef]);
```

### Player

```dart
final player = music.player;

await player.setQueue([ref1, ref2], startIndex: 0, autoplay: true);
await player.playItem(ref);          // single-item convenience

await player.play();
await player.pause();
await player.togglePlayPause();
await player.seekTo(const Duration(seconds: 42));
await player.skipToNext();
await player.skipToPrevious();
await player.stop();

await player.append([ref3]);         // throws unsupportedFeature where
await player.removeAt(0);            // queue editing is unavailable
final queue = await player.getQueue();

await player.setShuffleMode(MusicShuffleMode.on);
await player.setRepeatMode(MusicRepeatMode.one);
```

Commands are **serialized through a single pending chain**: rapid
`setQueue(A); play(); setQueue(B); play()` always ends with B playing —
an older async completion can never override a newer user intent. A
failed command never blocks later commands.

### State stream

```dart
music.player.states.listen((state) {
  print('${state.status.name} item=${state.currentItem?.id} '
        'pos=${state.position} dur=${state.duration}');
});
```

Guarantees:

- New subscribers immediately receive the latest snapshot.
- Identical consecutive states are deduplicated.
- Ordering is preserved; no competing streams to merge.
- Nothing is emitted after `dispose()`.
- One-off read: `music.player.currentState`.

In widgets:

```dart
StreamBuilder<MusicPlayerState>(
  stream: music.player.states,
  initialData: music.player.currentState,
  builder: (context, snapshot) { /* render */ },
)
```

`position` is a UI sampling of progress (≈400 ms while playing), not a
substitute for platform playback state. `duration` is `null` when
unknown — never faked as zero.

### Capabilities

```dart
final caps = await music.capabilities.get();

if (caps.canSeek.supported) {
  await music.player.seekTo(const Duration(seconds: 10));
} else {
  print(caps.canSeek.reason.name); // WHY it's unavailable
  print(caps.canSeek.detail ?? '');
}
```

Reasons distinguish: `unsupportedOnPlatform` (structural), `sdkMissing`
(Android AARs not provisioned), `authorizationRequired`,
`subscriptionRequired`, `restrictedBySystem`. Use them to disable UI
honestly instead of letting calls fail.

### Errors

Every failure is a `MusicKitException` with a stable `code`:

```dart
try {
  await music.player.play();
} on MusicKitException catch (e) {
  switch (e.code) {
    case MusicKitErrorCode.authorizationDenied:  // -> Settings guidance
    case MusicKitErrorCode.subscriptionRequired: // -> upsell
    case MusicKitErrorCode.sdkUnavailable:       // -> Android setup help
    case MusicKitErrorCode.rateLimited:          // -> e.retryAfter
    default: print('${e.code}: ${e.message}');
  }
  showSnackBar(e.userMessage); // user-presentable text
}
```

Full code list: `notInitialized`, `alreadyDisposed`,
`authorizationDenied`, `authorizationCancelled`, `authenticationFailed`,
`developerTokenMissing`, `developerTokenExpired`, `userTokenInvalid`,
`subscriptionRequired`, `storefrontUnavailable`, `resourceNotFound`,
`resourceUnavailable`, `playbackFailed`, `networkError`, `requestTimeout`,
`rateLimited`, `unsupportedFeature`, `sdkUnavailable`,
`platformUnavailable`, `unknown`.

### Refs & artwork

```dart
final ref = song.ref; // id + type + source + storefront

// Parse an API href:
final parsed = MusicItemRef.fromUrl(
  'https://api.music.apple.com/v1/catalog/us/songs/1440843637');

// Catalog vs library ids are NOT interchangeable:
const catalogRef = MusicItemRef(
    id: '1440843637', type: MusicResourceType.song,
    source: MusicItemSource.catalog);
const libraryRef = MusicItemRef(
    id: 'i.abc123', type: MusicResourceType.song,
    source: MusicItemSource.library);

// Artwork: concrete URLs from the {w}x{h} template:
final square = song.artwork?.url(size: 300);            // 300x300
final banner = song.artwork?.urlFitted(maxWidth: 640, maxHeight: 320);
```

### Mock mode (no Apple credentials)

For UI development and tests without any Apple account:

```dart
import 'package:apple_music_kit/mock.dart';

void main() {
  if (kDebugMode) installMusicKitMock();
  // or, to test the denied-authorization UI:
  // installMusicKitMock(autoGrantAuthorization: false);
  runApp(const MyApp());
}
```

The mock implements the full platform contract in memory (including a
playback ticker) and is loudly labeled — it never pretends to be real
MusicKit.

## Platform setup

### iOS

1. In your App ID / entitlements, enable the **MusicKit** App Service.
2. Add the usage description to `Info.plist`:

   ```xml
   <key>NSAppleMusicUsageDescription</key>
   <string>We use Apple Music to play your library and search.</string>
   ```

3. For background playback enable the **Audio** background mode
   (Background Modes → Audio, AirPlay, and Picture in Picture).
   The plugin never modifies your Xcode project itself.
4. Minimum deployment target: **iOS 16.0** (Apple's structured
   `MusicLibraryRequest` requires iOS 16).

**Playback behavior:** the plugin uses `ApplicationMusicPlayer.shared`, the
third-party-app-scoped player. It does **not** hijack the system Music
app's queue. Now-playing / lock-screen controls and audio focus follow
system MusicKit behavior.

**Verification note:** building for the iOS _simulator_ proves compilation
only. Real playback and authorization require a physical device signed
into an Apple Music account. The plugin makes no claim of simulator
playback validation.

### Android

Apple's MusicKit Android SDK is not distributed through Maven; download it
yourself and wire it locally:

1. Download from
   [https://developer.apple.com/download/all/](https://developer.apple.com/download/all/)
   (search **MusicKit**; an Apple Developer account is required). You need
   `musickitauth.aar` and `musickitplayback.aar`.
2. Place both AARs in a local directory, e.g. `~/sdks/musickit-android/`.
3. Point the build at them, either via environment variable:

   ```bash
   export MUSICKIT_ANDROID_SDK_DIR=~/sdks/musickit-android
   flutter build apk
   ```

   or `android/gradle.properties` of your app:

   ```properties
   MUSICKIT_ANDROID_SDK_DIR=/absolute/path/to/musickit-android
   ```

4. Rebuild. Gradle logs which mode was enabled.

**Without the SDK the app still builds and runs**, but every MusicKit call
fails fast with `MusicKitException(sdkUnavailable)` including these setup
instructions — never fake success.

Notes:

- Apple's Android SDK has had long gaps between updates. Compatibility is
  honestly reported through `capabilities` rather than assumed.
- The AARs are Apple proprietary; this plugin never re-distributes them.
- `minSdk 23`, `compileSdk 35`.

### Web

1. Serve over **HTTPS** (MusicKit JS and browser autoplay policy require a
   secure context; `localhost` counts).
2. The plugin auto-loads MusicKit JS v3 from
   `https://js-cdn.music.apple.com/musickit/v3/musickit.js` — no
   `index.html` edits needed. If your CSP blocks it, allow that origin.
3. `authorize()` must be called from a real user gesture (a button tap);
   calling it during build/startup will be blocked by the browser.
4. Configure your developer token's allowed origins when generating it.

### Windows / Linux

No application API changes are required. The desktop implementation registers
through the main package and uses the same developer token provider.

`initialize()` opens a browser companion. Keep that tab open while listening;
click its **Sign in to Apple Music** button when prompted. Flutter controls
playback and receives state events. If autoplay is blocked, press **Play** in the
browser once. Linux requires `xdg-open` and a configured browser. The browser must
support Apple Music DRM playback; no DRM component is bundled.

The companion origin is `http://127.0.0.1:<ephemeral-port>`. Ensure your developer
token's origin restrictions allow this setup. A token locked to your website's
origin cannot be reused unchanged. Tokens must still come from your backend.

Connection setup and requests time out after two minutes. Closing/reloading the
tab disconnects the bridge; dispose the client, close the old tab, and create a
new client to reconnect. Playlist writes are never retried automatically.
`dispose()` leaves playback running in the browser; use
`dispose(stopPlayback: true)`, the companion's Stop button, or close the tab to
stop it. Queue removal, app-owned system media controls, and guaranteed
background playback are not supported.

Run the example on the target OS:

```sh
cd example
flutter run -d windows  # Windows host
flutter run -d linux    # Linux host
```

The example defaults to mock mode. For Apple Music, add
`--dart-define=USE_MOCK=false` and
`--dart-define=TOKEN_ENDPOINT=https://your-server/developer-token` to the run command. Desktop native builds and real-account authorization/playback still
need target-machine acceptance. See
[desktop implementation](packages/apple_music_kit_desktop/README.md).

## Developer token & security

- Developer tokens (JWT) are signed with your **.p8 Team Key — keep it on
  your server, never in the app**.
- Provide tokens through `DeveloperTokenProvider`. The plugin ships
  `CachingDeveloperTokenProvider` which caches, refreshes ahead of JWT
  `exp`, and single-flights concurrent requests.
- iOS: omit the provider and MusicKit manages tokens automatically.
- Music user tokens are handled by each platform's SDK; the plugin never
  exposes them.
- No tokens are ever logged or included in error details.

## Feature capability matrix

| Capability                   | iOS                              | Android (with SDK)                        | Web                        |
| ---------------------------- | -------------------------------- | ----------------------------------------- | -------------------------- |
| Authorization request/status | ✅                               | ✅                                        | ✅ (user gesture required) |
| Subscription status          | ✅                               | ⚠️ Implemented; device validation pending | ✅                         |
| Catalog search               | ✅                               | ⚠️ Implemented; device validation pending | ✅                         |
| Catalog resource fetch       | ✅                               | ⚠️ Implemented; device validation pending | ✅                         |
| Charts                       | ✅                               | ⚠️ Implemented; device validation pending | ✅                         |
| Storefront                   | ✅                               | ⚠️ Implemented; device validation pending | ✅                         |
| Library list/search          | ✅ (iOS 16+)                     | ⚠️ Implemented; device validation pending | ✅ (auth required)         |
| Add to library               | ✅                               | ⚠️ Implemented; device validation pending | ✅                         |
| Create playlist              | ✅                               | ⚠️ Implemented; device validation pending | ✅ (auth required)         |
| Add to playlist              | ✅                               | ⚠️ Implemented; device validation pending | ✅                         |
| Play/pause/stop/seek         | ✅                               | ⚠️ Implemented; device validation pending | ✅                         |
| Skip next/previous           | ✅                               | ⚠️ Implemented; device validation pending | ✅                         |
| Queue set/append/remove      | ✅                               | ⚠️ Implemented; device validation pending | ⚠️ set/append only         |
| Shuffle/repeat               | ✅                               | ⚠️ Implemented; device validation pending | ✅                         |
| Volume control               | ❌ (not exposed; system/browser) | ⚠️ Implemented; device validation pending | ❌ (not exposed)           |
| Background playback          | ✅ (Audio BG mode)               | ⚠️ Implemented; device validation pending | ❌ (browser suspends)      |

Windows/Linux implement the Web feature set through the companion, with the
limitations above. Real-account desktop behavior has not been verified.

## Architecture

Federated plugin (Flutter best practice):

```
apple_music_kit/                  (repo root)
  packages/
    apple_music_kit               end-user facade (AppleMusicClient, player, services)
    apple_music_kit_platform_interface  contracts, models, errors, tokens
    apple_music_kit_ios           Swift + MusicKit
    apple_music_kit_android       Kotlin + Apple MusicKit Android SDK (local AARs)
    apple_music_kit_web           MusicKit JS v3 (dart:js_interop)
    apple_music_kit_desktop       Windows/Linux browser companion
  example/                          full example app (mock + live modes)
```

- `AppleMusicClient` → `authorization` / `subscription` / `catalog` /
  `library` / `capabilities` / `player` facades.
- Player commands are serialized through a single pending chain: rapid
  `setQueue(A); play(); setQueue(B); play()` always ends with B playing.
- `player.states` is a deduplicated broadcast stream that replays the
  latest snapshot to new subscribers and stops after dispose.
- No UI, no state-management framework dependency.

## Testing

```bash
# All Dart packages
cd packages/apple_music_kit_platform_interface && flutter test
cd packages/apple_music_kit && flutter test

# Analyzers (run per package)
dart analyze

# Builds
cd example
flutter build ios --debug --no-codesign
flutter build apk --debug
flutter build web
```

49 unit tests cover initialization, config, token caching/single-flight,
state transitions, dedup, queue ops, pagination, model parsing, error
mapping, capabilities, and the mock.

Integration tests on real devices/browsers require an Apple Developer
account, a valid developer token, and an Apple Music subscription. Those
are **not** executed in this repo's CI; see
`docs/known-limitations.md`.

## Compliance

- No DRM circumvention, no audio extraction/redistribution, no
  unauthorized lyric syncing.
- Apple's SDKs and content are used only through officially supported
  surfaces.
- No re-distribution of Apple proprietary SDK binaries.

## License

BSD-3-Clause. See [LICENSE](LICENSE).

## Review follow-up implementation status

- Android SDK 1.1.4 playback / 1.1.5 authentication are wired to their actual APIs. Catalog and library requests use the Apple Music REST API on a background executor. Real-account authorization and playback still need device acceptance.
- Android queue entries must be songs from a single source (catalog or library). Mixed-source queues are rejected. Tokens remain in native memory for this plugin session; restarting the process requires authorization again.
- Android SDK playback is owned by a media-playback foreground service with a MediaSession and media notification. Playback survives Activity/FlutterEngine teardown; explicit stop releases the session. Real-device lock-screen and headset acceptance remains required.
- Web uses MusicKit v3 `api.music`, property setters for modes, and `playLater` for appending. Public queue removal is unavailable and returns `unsupportedFeature`; `canEditQueue` is false.
- Queue entries are songs; expand an album or playlist to tracks before calling `setQueue`.
- SDK archives stay outside the repository. `MUSICKIT_ANDROID_SDK_DIR` accepts the SDK archive filenames or the older `musickitauth.aar` / `musickitplayback.aar` names.

## Album animated artwork (experimental)

Fetch variants explicitly without changing catalog search or static artwork:

```dart
final variants = await music.catalog.getAlbumAnimatedArtwork(
  '1234567890',
  storefront: 'us',
);
```

Returns original HLS URLs and supplied metadata. Concurrent identical requests
are merged; completed results are not cached. This uses undocumented Apple
fields whose compatibility with the existing token paths is not yet verified.
See [animated artwork](docs/animated-artwork.md) for platform paths, lifecycle,
error semantics, source references and limitations.
