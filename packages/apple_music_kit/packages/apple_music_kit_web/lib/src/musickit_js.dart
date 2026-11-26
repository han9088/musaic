/// Copyright (c) 2026, deskbtm. BSD-3-Clause.
///
/// Static JS interop bindings for MusicKit JS v3.
/// Reference: https://js-cdn.music.apple.com/musickit/v3/docs/
library;

import 'dart:js_interop';

/// The `MusicKit` global object available after the SDK script loads and
/// the `musickitloaded` event fires.
@JS('MusicKit')
extension type MusicKitGlobal._(JSObject _) implements JSObject {
  /// Configures and returns the singleton MusicKitInstance.
  external JSPromise<MusicKitInstance> configure(MusicKitConfiguration config);
}

/// Configuration passed to [MusicKitGlobal.configure].
extension type MusicKitConfiguration._(JSObject _) implements JSObject {
  external factory MusicKitConfiguration({
    String developerToken,
    MusicKitAppConfiguration app,
  });
}

/// App metadata for attribution.
extension type MusicKitAppConfiguration._(JSObject _) implements JSObject {
  external factory MusicKitAppConfiguration({String name, String build});
}

/// The configured MusicKit player instance.
extension type MusicKitInstance._(JSObject _) implements JSObject {
  // ---- auth ----

  /// Authorization status code. MusicKit JS uses 3 = authorized.
  @JS('authorizationStatus')
  external int get authorizationStatusValue;

  /// Opens the Apple Music auth flow; must be user-gesture initiated.
  external JSPromise<JSAny?> authorize();

  // ---- subscription ----

  external JSPromise<JSBoolean> hasMusicSubscription();

  // ---- api ----

  /// Performs an authenticated Apple Music API request; the SDK manages
  /// both developer and user tokens. [query] and [body] are optional
  /// JS objects (use `.jsify()` on Dart maps).
  @JS('api')
  external MusicKitApi get musicApi;

  JSPromise<JSAny?> api(JSString method, JSString path,
          [JSAny? query, JSAny? body]) =>
      musicApi.music(
          path,
          query,
          {
            'fetchOptions': {
              'method': method.toDart,
              if (body != null) 'body': _stringify(body),
              if (body != null) 'headers': {'Content-Type': 'application/json'}
            }
          }.jsify());

  // ---- playback ----

  external JSPromise<JSAny?> play();
  external JSPromise<JSAny?> pause();
  external JSPromise<JSAny?> stop();
  @JS('skipToNextItem')
  external JSPromise<JSAny?> skipToNext();
  @JS('skipToPreviousItem')
  external JSPromise<JSAny?> skipToPrevious();
  external JSPromise<JSAny?> seekToTime(JSNumber time);

  @JS('playbackState')
  external int get playbackStateValue;

  @JS('currentPlaybackTime')
  external double get currentPlaybackTimeValue;

  external int get shuffleMode;
  external set shuffleMode(int value);
  bool get shuffleEnabledValue => shuffleMode != 0;
  @JS('repeatMode')
  external int get repeatModeValue;
  @JS('repeatMode')
  external set repeatModeValue(int value);
  external MusicKitQueue get queue;
  int? get currentPlayerItemIndexValue =>
      queue.position < 0 ? null : queue.position;

  @JS('nowPlayingItem')
  external MusicKitMediaItem? get currentPlayerItem;

  // ---- queue ----

  @JS('setQueue')
  external JSPromise<JSAny?> setQueue(MusicKitQueueOptions options);

  @JS('playLater')
  external JSPromise<JSAny?> queueAppend(MusicKitQueueOptions options);

  // ---- events ----

  external void addEventListener(JSString name, JSAny? handler);
  external void removeEventListener(JSString name, JSAny? handler);
}

/// A media item in the player/queue.
extension type MusicKitMediaItem._(JSObject _) implements JSObject {
  /// The resource id.
  @JS('id')
  external String get idValue;

  /// The resource type string, e.g. 'song', 'album'.
  @JS('type')
  external String get typeValue;

  /// The item's attributes (name, artistName, durationInMillis, ...).
  @JS('attributes')
  external JSObject? get attributes;
}

/// Options for setQueue / queue.append.
extension type MusicKitQueueOptions._(JSObject _) implements JSObject {
  external factory MusicKitQueueOptions({JSArray<MusicKitQueueItem> items});
}

/// One item in a queue options list.
extension type MusicKitQueueItem._(JSObject _) implements JSObject {
  external factory MusicKitQueueItem({String id, String type, String source});
}

/// Deep-converts a JS value to its Dart equivalent.
Object? jsDartify(JSAny? value) {
  if (value == null) return null;
  if (value.isA<JSString>()) return (value as JSString).toDart;
  if (value.isA<JSNumber>()) return (value as JSNumber).toDartDouble;
  if (value.isA<JSBoolean>()) return (value as JSBoolean).toDart;
  if (value.isA<JSArray>()) {
    final array = value as JSArray;
    return [for (var i = 0; i < array.length; i++) jsDartify(array[i])];
  }
  if (value.isA<JSObject>()) {
    final obj = value as JSObject;
    final keys = _objectKeys(obj).toDart;
    final map = <String, dynamic>{};
    for (final key in keys) {
      map[key.toDart] = jsDartify(jsReflectGet(obj, key));
    }
    return map;
  }
  return value;
}

/// Object.keys(obj) via a small @JS binding.
@JS('Object.keys')
external JSArray<JSString> _objectKeys(JSObject obj);

/// Reflect.get(obj, key); the single binding shared across the web
/// implementation (music_kit_web.dart re-exports it via this library).
@JS('Reflect.get')
external JSAny? jsReflectGet(JSObject obj, JSString key);

@JS('JSON.stringify')
external String _stringify(JSAny value);
extension type MusicKitApi._(JSObject _) implements JSObject {
  external JSPromise<JSAny?> music(JSString path,
      [JSAny? parameters, JSAny? options]);
}

extension type MusicKitQueue._(JSObject _) implements JSObject {
  external int get position;
  external set position(int value);
}
