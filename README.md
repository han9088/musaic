# Musaic

Where Music Becomes Mosaic.

Flutter app for Android, iOS, macOS, Windows, and Web with the application ID `com.deskbtm.musaic`.

```sh
mise install
mise exec -- flutter pub get
mise exec -- flutter run
```

Settings → Support shares `https://musaic.deskbtm.com` and opens the store
listing for reviews. For iOS and macOS release builds, pass the numeric Apple
ID from App Store Connect as `--dart-define=MUSAIC_APP_STORE_ID=<id>`.

Settings → Troubleshooting exports a local diagnostic report and can attach it
to a feedback email. Set `--dart-define=MUSAIC_FEEDBACK_EMAIL=<address>` to
prefill the recipient in the native mail composer.

## Audius music source

Choose Audius in Settings → Music source to browse trending public albums.
Supply an API key at launch or build time with
`--dart-define=AUDIUS_API_KEY=<public-api-key>`. The SDK can also request
the public catalog without a key.

## Indiebase client

The Dart SDK is pinned to a source revision. Dependency resolution requires
read access to the Indiebase Git repository. To enable the client, supply both
`--dart-define=MUSAIC_INDIEBASE_BASE_URL=<project-runtime-url>` and
`--dart-define=MUSAIC_INDIEBASE_API_KEY=<project-api-key>`. Use the Project
Runtime URL and its client API key. Keep admin credentials server-side.

Musaic creates the client on the first `IndiebaseScope.maybeOf(context)` lookup.
App startup makes no Indiebase requests.

## Android variants

Debug and Release can be installed side by side, following Loive's build-type setup:

| Build | Launcher name | Application ID | Signing |
| --- | --- | --- | --- |
| Debug | Musaic Debug | `com.deskbtm.musaic.debug` | Android debug key |
| Release | Musaic | `com.deskbtm.musaic` | Existing project keystore via `android/key.properties` |

Use `mise exec -- flutter run` for Debug, or `mise exec -- flutter build apk --release`
for the signed release APK. Icon aliases use `${applicationId}` and labels use
`@string/app_name`, so switching either app's icon does not affect the other.
Their app data is separate. The keystore and `android/key.properties` remain local
and Git-ignored; retain backups of both for future release updates.

An older Debug install used the release application ID. If installing Release
over it reports a signing mismatch, preserve any needed data before uninstalling
that old build; the new `.debug` app does not migrate its data automatically.

## macOS

```sh
mise exec -- flutter run -d macos
mise exec -- flutter build macos --release
```

The release app is `build/macos/Build/Products/Release/Musaic.app`. macOS opens the album canvas, including in wide windows. Playback controls
currently simulate playback. macOS keeps album tick sounds but does not use the
mobile haptics plugin or device-tilt sensors.

Choose **Musaic → Set as Wallpaper** in the macOS menu bar to move the current
album view behind Finder’s desktop icons on the same display. The view keeps
rendering while Finder receives desktop clicks. Click Musaic in the Dock to
activate its menu bar, then choose **Musaic → Restore Window** to exit wallpaper mode.

## Windows

Install Flutter as pinned in `mise.toml` and Visual Studio with **Desktop development with C++**. Keep the `apple_music_kit` checkout beside `musaic` to resolve the existing path dependency.

```powershell
flutter pub get
flutter run -d windows
flutter build windows --release
```

Run `musaic.exe` from `build/windows/x64/runner/Release/` together with its bundled DLLs and `data/` directory. Windows uses the sample catalogs and simulated playback.

Open the window menu with **Alt+Space** or by clicking the window icon and choose **Set as Wallpaper**. The album view covers the current display behind the desktop icons. Click the Musaic notification-area icon to open a menu and choose **Restore Window** to return to the app. Explorer and display changes can end wallpaper mode.

## Web

```sh
mise exec -- flutter run -d chrome
python3 scripts/build_pwa.py
```

Deploy `build/web/` to a static web host. For a subdirectory, build with
`python3 scripts/build_pwa.py --base-href /your-path/`. Web uses the sample album catalog and simulated
playback; system music and local directory sources are unavailable. Browser
audio restrictions may require interaction before album tick sounds can play.
Desktop browsers start on the canvas. Enable **Show layout switch button** under
**Settings → Appearance & display** to switch between the canvas and Cover Flow,
including in portrait. In the iOS and Android apps, landscape opens Cover Flow.
Press and hold the layout button to rotate to landscape. Tap the rotate button
to return to the portrait canvas.

PWA builds bundle the rendering engine locally and generate a versioned offline
cache. A [custom Flutter bootstrap](https://docs.flutter.dev/platform-integration/web/initialization)
leaves service-worker registration exclusively to Musaic, avoiding Flutter's legacy
worker replacing the offline cache on later visits. Serve over HTTPS (localhost also works), then use the browser toolbar or menu install action. The app does not add an
Install button or intercept the browser's installation prompt. Safari/iOS uses
Add to Home Screen instead. The first complete cache download requires a connection;
subsequent launches can use the bundled sample catalog offline. New versions take
over after all existing app tabs/windows close, avoiding mixed build assets.
Serve `index.html`, `pwa.js`, and `service-worker.js` with revalidation/no-cache;
deploy the complete output together. Every downloaded asset is checked against its
build SHA-256 integrity; an incomplete/mixed deployment rolls back the new cache.
Upgrades reuse unchanged cached assets instead of downloading the whole bundle.
The worker does not claim already-loading pages; the first fully cached visit makes
subsequent navigations available offline. Cache storage may be evicted by the browser.
The worker caches only this build's files, never external music, API responses or
user files. `flutter run -d chrome` remains a development build without offline setup.

In Cover Flow, horizontal two-finger trackpad scrolling moves the albums; browser
inertia is used directly without adding another fling. macOS native trackpad pans
reuse the existing drag physics. Left/right arrow keys select the previous/next album
while Cover Flow has focus; modified browser shortcuts and dialogs keep their keys.
Web browsers that support fullscreen expose Enter/Exit fullscreen in the existing
bottom menu. Browser fullscreen changes update the label, and unavailable APIs
hide the entry. Native Android/iOS do not include this control.
Click Cover Flow to restore focus after using another control. macOS retains its
canvas default; switch to Cover Flow using the existing layout button.

On iOS and Android, long-press the Cover Flow title to toggle a rear-camera
background. Tap empty space while the camera is active to save a photo containing
the camera view, title, album covers and reflections to Photos/Gallery. Album taps
and swipes keep their existing behavior. Saving combines a camera photo with the
current Flutter overlay at screen resolution; it does not capture system UI.
Camera access is requested on first use and photo-library access when saving.
The camera closes when leaving Cover Flow or putting the app in the background.

### Cloudflare deployment

The assets-only Worker is configured in `cloudflare.config.ts` for
`https://musaic.deskbtm.com` (deployed 2026-11-16). Authenticate with the Cloudflare account that owns
`deskbtm.com`, then deploy:

```sh
npx --yes cf@1.0.0-beta.32 auth login
python3 scripts/build_pwa.py
npx --yes cf@1.0.0-beta.32 deploy build/web --dry-run
npx --yes cf@1.0.0-beta.32 deploy build/web
```

`web/_headers` requires browser cache revalidation. HTML normalization is disabled
so `/index.html` remains a direct response for the offline integrity check.
Deployment configuration files are excluded from the PWA manifest; source maps,
debug symbols and Flutter's legacy worker are excluded from uploads. No backend
or business database is deployed. Account authorization and an active Cloudflare
zone are required to bind the custom domain.

Live verification on 2026-11-16 passed HTTPS, direct `/index.html` responses,
revalidation headers, Chrome installability and the install button, keyboard and
horizontal scroll, and Chrome offline reload. First-time cache population over the
validation network exceeded 90 seconds; the full offline bundle is about 39.5 MiB.
An actual OS installation and mobile hardware were not tested.

### PWA and input validation

```sh
node --test test/web/pwa_install_test.mjs test/web/pwa_worker_test.mjs
python3 -m unittest discover -s test/web -p 'test_*.py'
# Set CHROME_EXECUTABLE to your Chrome executable first:
node test/web/pwa_browser_smoke.mjs
```

The browser check opens a temporary Chrome window against `build/web`,
checks menu fullscreen entry/exit and external state changes, checks installability and the absence of a custom
install button, sends keyboard/horizontal scroll events, rejects a mixed deployment,
verifies an upgrade downloads only its changed asset and preserves the old tab,
then disables the origin and reloads from the offline cache. It does not install an app on your machine.
Bundled audio Range requests are served from the cache. Downloads have four workers;
source maps and debug symbols are excluded (current offline bundle: about 39.5 MiB).

2026-11-16: 176 Flutter tests, ten PWA unit tests, Web/macOS/Android/iOS simulator
builds and Web hot restart passed. Real headless Chrome also passed installability,
install-button, keyboard/scroll, mixed-deployment rejection, old-tab isolation,
upgrade activation and offline-reload checks. With one asset changed, the upgrade
requested only that asset (85 of 86 assets reused, excluding the worker update check).
Native Android/iOS input
is explicitly excluded and covered by touch regression tests. Physical trackpad,
phone hardware and an installed standalone OS window were not verified.

## Code structure

```text
lib/
  main.dart                    # Entry point
  app/                         # App assembly, lifecycle, shared sheet host
  pages/home/
    home_page.dart             # Home orchestration and state ownership
    home_sheet.dart            # Bottom handle and icon picker
    glass_icon_button.dart     # Button shared within the home page
    canvas/                    # Album grid, selection, sensor tilt, snapshots
    coverflow/                # CoverFlow rendering and scroll physics
    playback/                  # Mock playback state and playback button
    layout/                    # Canvas/CoverFlow transitions and switch overlay
  services/                    # Album cache, haptics, tick audio, logging
  ui/                          # Reusable UI and design tokens
    bottom_sheet/              # Sheet engine, controller, presentation widgets
    dialogs/
    theme/
    thinking_orbs/
    widgets/
  l10n/                        # Translations and generated localization code
test/                          # Mirrors the owning source directories
```

Home owns the playback state and passes it to both the canvas and CoverFlow.
Page-specific UI stays with its page; reusable UI has no dependency on pages.
Services do not import pages, UI, or app assembly. iOS and Android share the Dart
implementation; platform integrations stay in the platform projects or services.
App startup and localization tests live in `test/app/`; home interactions live in
`test/pages/home/`, and haptics/cache tests live in `test/services/`.

## App icons

`ios/Runner/musaic.icon` is the primary Icon Composer resource, included in the
Runner resource phase and selected by `ASSETCATALOG_COMPILER_APPICON_NAME` for
Debug, Profile, and Release. Preserve its layers and appearance settings.

Icon switching uses `dynamic_app_icon_flutter_plus`, matching Loive.
`AppIconService.read()` returns `supported` and the current `AppIconChoice`, matching
Loive. `change(AppIconChoice.classic)` restores the primary icon.
Like Loive, reads first discover native icon names with `getAvailableIcons()` and
check every non-primary `AppIconChoice` against that configuration. The snapshot
contains only `supported` and `current`.
The bottom sheet offers the default icon, album collage (`MusaicMosaic`), and vinyl artwork (`MusaicVinyl`).
Both Apple projects include `MusaicMosaic.icon`, preserving the primary Icon Composer
settings. Android supplies a matching adaptive/legacy icon and disabled launcher alias.
To add an iOS alternative, add its `.icon` file to Runner's resources and list its
base name in `ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES` for all three build
configurations, and add its native name to `AppIconChoice`. Xcode generates the
alternate icon metadata consumed by the plugin.

Android retains the supplied adaptive/legacy launcher resources. The default and
mosaic icons use `.MainActivity.default` and `.MainActivity.MusaicMosaic` aliases;
the plugin only toggles aliases, leaving the real activity enabled. Flutter reads
the real activity's MAIN/LAUNCHER filter and launches it explicitly. That filter
requires the `musaic-tooling` URI scheme, so ordinary launcher queries (without
data) only match the icon aliases. This keeps Flutter launches independent of the
currently selected icon, without adding a second desktop icon. Existing installs affected by the old layout
need MainActivity re-enabled once with `adb shell pm enable
com.deskbtm.musaic/.MainActivity`; app data does not need to be cleared.

macOS uses `macos/Runner/musaic.icon` as its primary app icon. Since the mobile
plugin has no macOS implementation, `AppIconPlugin.swift` implements its channel
contract for Finder and Dock icons. It discovers alternate image asset names from a
`MusaicAlternateIcons` dictionary in the macOS Info.plist (icon name → bundled
image asset name). Add the corresponding `AppIconChoice` when supplying an
alternative. Selection is saved in UserDefaults. Startup restoration and explicit
changes share the same Finder/Dock update path; a removed alternate resets both
to the primary icon. Pending or failed startup synchronization is returned as an
error when reading the current icon, rather than reporting an unsynchronized
selection. Restoring the default clears the saved choice. A change first sets the application bundle's Finder custom
icon through NSWorkspace, then updates the Dock and saved selection. Restoring
the default removes the Finder custom icon as well. If direct writing fails,
a system file panel requests access to this exact running application; cancellation
or a failed write is returned as an error without committing the new selection.
The sandbox remains enabled with user-selected read/write access. Finder custom
icons persist independently of the running app; replacing the app during an update
may remove them. `MusaicMosaicPreview` supplies the collage for Finder and Dock.

2026-11-16 update: removed the custom Install overlay; browser installation remains available.
Added fullscreen to the existing Web menu. Analyze, 177 Flutter tests, Web release
build and Web hot restart passed. Native platforms do not display the entry.
