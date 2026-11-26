/// Copyright (c) 2026, deskbtm. BSD-3-Clause.
library;

import 'dart:async';

import 'package:apple_music_kit_platform_interface/apple_music_kit_platform_interface.dart';

/// The unified Apple Music player facade.
///
/// Commands are serialized through a single pending chain so that rapid
/// sequences like `setQueue(A); play(); setQueue(B); play()` always end
/// with B playing — an older async operation can never overwrite a newer
/// user intent.
///
/// [states] is a broadcast stream that replays the latest snapshot to new
/// subscribers and never emits after [dispose] of the owning client.
final class AppleMusicPlayer {
  /// Creates the player facade over [platform].
  AppleMusicPlayer(this._platform, {void Function()? onUse}) : _onUse = onUse;

  bool _closed = false;

  void start() {
    if (_closed) return;
    _tracker ??= _platform.playerStates.distinct().listen(
      (state) {
        if (_closed) return;
        _lastState = state;
        _events.add(state);
      },
      onError: (Object error, StackTrace stack) {
        if (!_closed) _events.addError(error, stack);
      },
    );
  }

  final MusicKitPlatform _platform;
  final void Function()? _onUse;

  final _events = StreamController<MusicPlayerState>.broadcast();
  StreamSubscription<MusicPlayerState>? _tracker;

  MusicPlayerState _lastState = const MusicPlayerState.initial();

  /// The state stream.
  ///
  /// New subscribers immediately receive the most recent snapshot.
  Stream<MusicPlayerState> get states => Stream.multi((controller) {
        if (_closed) {
          controller.closeSync();
          return;
        }
        final subscription = _events.stream.listen(controller.addSync,
            onError: controller.addErrorSync, onDone: controller.closeSync);
        controller.addSync(_lastState);
        controller.onCancel = subscription.cancel;
      }, isBroadcast: true);

  /// The most recent snapshot without subscribing.
  MusicPlayerState get currentState => _lastState;

  // ---------------- command serialization ----------------

  Future<void> _pending = Future.value();

  /// Runs [action] after all previously issued commands complete.
  ///
  /// Errors are propagated to the caller but never jam the chain, so a
  /// failed command cannot block later user intents.
  Future<void> _enqueue(Future<void> Function() action) {
    _onUse?.call();
    final run = _pending.then((_) {
      _onUse?.call();
      return action();
    });
    _pending = run.then<void>((_) {}, onError: (_) {});
    return run;
  }

  // ---------------- queue ----------------

  /// Replaces the queue with [items] and optionally starts playback at
  /// [startIndex].
  Future<void> setQueue(
    List<MusicItemRef> items, {
    int startIndex = 0,
    bool autoplay = true,
  }) =>
      _enqueue(() => _platform.setQueue(items,
          startIndex: startIndex, autoplay: autoplay));

  /// Convenience: replaces the queue with a single item and plays it.
  Future<void> playItem(MusicItemRef item) => setQueue([item], autoplay: true);

  /// Appends [items] to the current queue.
  ///
  /// Throws `MusicKitException(unsupportedFeature)` on platforms without
  /// queue editing.
  Future<void> append(List<MusicItemRef> items) =>
      _enqueue(() => _platform.appendToQueue(items));

  /// Removes the queue entry at [index].
  Future<void> removeAt(int index) =>
      _enqueue(() => _platform.removeFromQueue(index));

  /// The current queue snapshot.
  Future<MusicQueue> getQueue() {
    _onUse?.call();
    return _platform.getQueue();
  }

  // ---------------- transport ----------------

  /// Plays (or resumes).
  Future<void> play() => _enqueue(() => _platform.play());

  /// Pauses.
  Future<void> pause() => _enqueue(() => _platform.pause());

  /// Stops playback.
  Future<void> stop() => _enqueue(() => _platform.stop());

  /// Toggles play/pause.
  Future<void> togglePlayPause() => _enqueue(() => _platform.togglePlayPause());

  /// Seeks to [position] within the current item.
  Future<void> seekTo(Duration position) =>
      _enqueue(() => _platform.seekTo(position));

  /// Next queue item.
  Future<void> skipToNext() => _enqueue(() => _platform.skipToNext());

  /// Previous queue item.
  Future<void> skipToPrevious() => _enqueue(() => _platform.skipToPrevious());

  // ---------------- modes ----------------

  /// Sets shuffle mode.
  Future<void> setShuffleMode(MusicShuffleMode mode) =>
      _enqueue(() => _platform.setShuffleMode(mode));

  /// Sets repeat mode.
  Future<void> setRepeatMode(MusicRepeatMode mode) =>
      _enqueue(() => _platform.setRepeatMode(mode));

  // ---------------- position sampling ----------------

  // Position sampling is driven by the platform stream itself; platforms
  // that require polling refresh position on their own cadence.

  /// Stops the internal state tracker. Called by the owning client's
  /// dispose.
  Future<void> shutdown() async {
    _closed = true;
    await _pending;
    await _tracker?.cancel();
    _tracker = null;
    unawaited(_events.close());
  }
}
