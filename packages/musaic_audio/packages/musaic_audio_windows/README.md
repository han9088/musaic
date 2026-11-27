# musaic_audio_windows

The Windows implementation of `musaic_audio`. Flutter selects this package automatically when an app depends on `musaic_audio`.

This package is forked from [bdlukaa/just_audio_windows at 8231455](https://github.com/bdlukaa/just_audio_windows/tree/82314554ca96a1b872e8388a8c9e951366ccb399/just_audio_windows). The upstream [MIT license](LICENSE), native player, plugin registration, platform-thread dispatcher and URI tests are included here.

WinRT `MediaPlayer` and `MediaPlaybackList` provide decoding and native playlist transitions. The Musaic adapter preserves Dart sequence indices when playing nested playlists, repeating sources, shuffling or editing the queue. It uses the standard Musaic player channels. The Dart HTTP proxy handles byte streams, progressive request headers and ICY radio metadata. WinRT handles adaptive request headers and peak bitrate limits for HLS and DASH.

See the [Musaic audio platform matrix](../musaic_audio/README.md#platform-support) for supported features and Windows limitations.

From the sibling `musaic_audio/example` directory, run the native playback tests on Windows with:

```sh
flutter test integration_test/windows_playback_test.dart -d windows
```

The upstream native URI tests can be enabled with the CMake option `include_musaic_audio_windows_tests`.
