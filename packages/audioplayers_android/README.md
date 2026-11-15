# Musaic Android playback patch

Vendored from audioplayers_android 5.3.0 (MIT); see LICENSE. Only Android is
replaced through the app dependency_overrides. No global pub-cache edits.

Content URIs are opened with ContentResolver on a bounded single-worker queue.
ContentUriSource retains the returned AssetFileDescriptor, passes its descriptor,
offset and length to the existing MediaPlayer, and closes it on source replacement
or release. Unknown length uses the descriptor overload. No `_data` lookup,
whole-file copy, byte buffer or local HTTP proxy is involved.

New sources, stop, release, dispose and engine detach cancel pending opens.
Late results are closed rather than published. Provider cancellation is best effort;
a provider ignoring cancellation can delay later opens, but cannot block Flutter's
platform thread. SoundPool mode is explicitly unsupported for content sources.

URL/file/byte routing stays upstream. Shared cleanup also closes sources if
preparation or release throws, releases MediaPlayer even if reset throws, ignores
callbacks after release, and serializes error details safely. Content changes
release the previous source before opening the next one. The 17-request bound
includes completed opens awaiting platform-thread delivery. Native tests use a ContentProvider
without a file-path query, including offsets, unknown lengths, missing permissions,
missing resources and cancellation. These are Robolectric tests, not device playback.

Reference: https://developer.android.com/reference/android/media/MediaPlayer#setDataSource(java.io.FileDescriptor,long,long)
