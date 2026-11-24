# Upgrader 14.0.0 migration record

- Upstream: https://github.com/larryaasen/upgrader
- Upstream package version: 14.0.0
- Upstream commit inspected: dc830c58106b30f26d79747e9d10733f7e5d90b4
- Migration date: 2026-11-24
- License: MIT; original notices retained in migrated source files and LICENSE.upstream.

## Migrated source areas

- App Store lookup API and result extraction.
- Google Play page lookup, localized release notes, HTML parsing and regional version fallbacks.
- Sparkle Appcast RSS/XML parsing and item selection/filtering.
- OS detection and platform-specific OS metadata.
- Store abstraction and platform store controller.
- Version information model and Semantic Versioning comparisons.
- UI-independent check lifecycle, update policy, ignored-version and reminder persistence.

## Intentionally excluded

- UpgradeAlert, UpgradeCard, dialog/card widgets and all presentation code.
- Localized UI copy and display-message formatting.
- BuildContext-based locale lookup.
- URL launching and UI navigation.

## Adaptations

- Renamed Upgrader-prefixed core types to MUSAIC-owned names.
- Replaced the UI-coupled UpgraderState with UpdateCheckContext.
- Added a small public MusaicUpdateChecker facade and UpdateCheckResult.
- Appcast descriptions are retained as source strings. EdSignature is parsed but is not cryptographically verified by this package.
