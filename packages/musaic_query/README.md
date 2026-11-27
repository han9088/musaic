# Musaic Query

Local audio query packages for Musaic.
Original copyright notices and each package's LICENSE are retained.

Packages: `musaic_query`, `musaic_query_android`, `musaic_query_ios`,
`musaic_query_macos`, `musaic_query_windows`, their shared
`musaic_query_desktop` implementation, `musaic_query_web`, and
`musaic_query_platform_interface`.
Public entry point: `package:musaic_query/musaic_query.dart`, class `MusaicQuery`.
Android namespace and native method channel: `com.deskbtm.muasic.query`.
All inter-package dependencies resolve locally. Packages are not published.

To use from the application root:

```yaml
dependencies:
  musaic_query:
    path: packages/musaic_query/packages/musaic_query
```

## Implementation and validation

- macOS and Windows expose [local audio directories](DIRECTORIES.md), including
  folder selection, metadata, art, and file URLs for playback.
- macOS uses `iTunesLibrary` for `querySongs` and `queryAlbums`. The host app
  needs `NSAppleMusicUsageDescription` and the sandbox entitlement
  `com.apple.security.assets.music.read-only`. Call `permissionsRequest` to
  open the library. `permissionsStatus` reports access in the current process
  without opening the library or prompting. Queries return songs with local
  file locations. Use `openSongPlayback` to keep a track's file accessible until
  the player releases it.

- Android keeps each request independent. Queries and playlist writes run off
  the platform thread; playlist writes are serialized per plugin instance.
  Pending permission and directory-picker requests survive Activity recreation.
  They complete with an error when the Activity is permanently detached.
- Android 13+ needs `READ_MEDIA_AUDIO`, Android 12 and older needs
  `READ_EXTERNAL_STORAGE`. The permission API requests read access only. Legacy
  playlist mutations on Android 9 and older additionally need
  `WRITE_EXTERNAL_STORAGE`, declared and granted separately by the host.
- iOS needs `NSAppleMusicUsageDescription`. Authorization and playlist additions
  finish only after the system callback. The package queries the device media
  library; inaccessible cloud/DRM items are excluded.
- Web queries bundled MP3 assets, not arbitrary files on the user's device.
  Metadata is indexed once per controller. IDs are unique within an asset
  manifest and must not be persisted across asset changes. Use the asset path
  for persistent identity. Artwork retains its embedded format and dimensions
  on Web; `format`, `size`, and `quality` do not transcode it. The artwork cache
  is bounded to 8 MiB and 128 entries; concurrent requests for one asset share work.
- Artwork requests accept sizes 1–4096 and quality 0–100. Invalid values fail
  before calling native code. `QueryArtworkWidget` reloads only when its query
  parameters change.

Run `flutter analyze` and `flutter test` inside `packages/musaic_query` and
`packages/musaic_query_web`. Android regression tests live under
`packages/musaic_query_android/android/src/test`; run
`:musaic_query_android:testDebugUnitTest` from a host app's Gradle project.
The iOS plugin supports Swift Package Manager and CocoaPods. iOS sorting
regression tests are provided by the pod's `Tests` test spec.
Native build checks use a separate host app with a local dependency on this package.
Real-device permission prompts, media-library writes and memory/frame profiling
remain necessary before release; unit tests do not establish those results.

### Verified on 2026-11-15

All five packages pass `flutter analyze`. The main package's 6 Dart/widget tests,
7 directory-interface tests, 5 Web controller tests on the VM, 1 Web browser
integration test, and 17 Android JVM regression tests (Robolectric/API 36) pass.
The iOS simulator native self-check passes using actual WAV/AAC and cover files,
including live stamp changes, cover deletion, cache clearing, paging and cancellation.
The iOS sorting test sources remain available; they were not rerun in this review.
The application Android debug build and iOS simulator host build pass. Web release
is checked using the separate host; these results do not represent real-device grants.
These builds emitted Flutter migration notices for Android KGP and iOS CocoaPods.

## 本地音频目录

新增授权目录、分页枚举、文件标签读取、封面回退和有界原生封面缓存。
接口、完整示例、筛选语义和平台限制见 [DIRECTORIES.md](DIRECTORIES.md)。
插件不维护业务数据库；Musaic 应用层维护 SQLite 音乐索引。
