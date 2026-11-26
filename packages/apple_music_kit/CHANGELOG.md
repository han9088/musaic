# Changelog

## 0.1.0 — 2026-11-11

Initial development release.

### Added
- Federated plugin structure: app-facing package, platform interface,
  iOS (Swift + MusicKit), Android (Kotlin + Apple MusicKit SDK gated on
  locally provisioned AARs), Web (MusicKit JS v3 via `dart:js_interop`).
- `AppleMusicClient` facade with `authorization`, `subscription`,
  `catalog`, `library`, `capabilities`, and `player` services.
- Player command serialization and a deduplicated,
  seeded state stream.
- Immutable data models derived from Apple Music API JSON shapes.
- `MusicKitException` with 20 stable error codes and user-presentable
  messages.
- `DeveloperTokenProvider` with caching, JWT-exp-aware refresh, and
  concurrent single-flight.
- In-memory mock platform (`installMusicKitMock`) for credential-free
  development and tests.
- Example app with mock/live modes.
- 46 unit tests; iOS/Android/Web example builds verified.
