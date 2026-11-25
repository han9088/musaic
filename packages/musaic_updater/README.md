# musaic_updater

MUSAIC-owned, UI-independent update checking package, vendored and adapted from upgrader 14.0.0.

## Included capabilities

- Apple App Store Lookup API version and release-notes lookup.
- Google Play public listing version and release-notes parsing, including localized notes and regional-version fallbacks.
- Sparkle Appcast RSS/XML parsing, all parsed items, platform/OS compatibility filtering, best/critical item selection, minimum update version and EdSignature field parsing.
- Semantic version comparison and a unified result model.
- Injectable HTTP client, headers, platform and store controller.
- Optional app-resume checking, ignored-version persistence, reminder cooldown and update-offer policy.

## Deliberately excluded

All dialogs, cards, widgets, display strings, UI state, navigation and URL-launching behavior. The package only retrieves and evaluates update metadata. The host application owns presentation, media rendering and opening the store/download URL.

## Basic usage

```dart
final checker = MusaicUpdateChecker();
final result = await checker.initialize();
if (result.updateAvailable) {
  print(result.latestVersion);
  print(result.releaseNotesRaw);
  print(result.storeUrl);
}
```

For self-distributed desktop builds, configure an Appcast source:

```dart
final checker = MusaicUpdateChecker(
  storeController: MusaicUpdateChecker.appcastController(
    appcastUrl: 'https://updates.example.com/appcast.xml',
    operatingSystemVersion: '14.0.0',
  ),
);
final result = await checker.check();
```

The host can use shouldOfferUpdate(), ignoreCurrentVersion() and recordUpdatePromptShown() to apply the non-UI update policy. Call dispose() when the checker is no longer needed.

releaseNotesRaw is not sanitized or rendered by this package. Appcast HTML descriptions are retained as supplied by the feed. EdSignature is parsed and exposed by the upstream Appcast model; parsing is not cryptographic signature verification.

## Upstream and license

- Upstream project: https://github.com/larryaasen/upgrader
- Migrated upstream version: 14.0.0
- Upstream source commit: dc830c58106b30f26d79747e9d10733f7e5d90b4
- Upstream license: MIT; see LICENSE.upstream.
