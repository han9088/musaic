import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:musaic_audio/musaic_audio.dart';

import '../diagnostics/diagnostic_log.dart';
import 'music_provider.dart';

typedef MusicQueueSource = ({Uri uri, Future<void> Function()? close});
typedef _Track = ({int index, MusicQueueSource source});

/// Owns the native playlist and the grants for the files it can still read.
final class MusaicMusicQueue {
  MusaicMusicQueue(this._open);

  final Future<MusicQueueSource> Function(MusicReference) _open;
  final _events = StreamController<MusicPlayback>.broadcast();
  final _subscriptions = <StreamSubscription<dynamic>>[];
  AudioPlayer? _player;
  List<MusicReference> _items = const [];
  List<_Track> _tracks = const [];
  int _index = 0;
  int _generation = 0;
  int? _requestedNext;
  int? _completedIndex;
  bool _disposed = false;
  bool _hasAudioFocus = false;
  bool _trimming = false;
  Completer<void>? _loading;
  Future<void> _pending = Future<void>.value();
  Future<void>? _disposing;
  MusicPlayback _state = (
    status: MusicPlaybackStatus.idle,
    currentItem: null,
    position: Duration.zero,
    duration: null,
    isPlaying: false,
    isBuffering: false,
    error: null,
  );

  Stream<MusicPlayback> get playback => Stream.multi((controller) {
    if (_disposed) {
      controller.closeSync();
      return;
    }
    final subscription = _events.stream.listen(
      controller.addSync,
      onDone: controller.closeSync,
    );
    controller.addSync(_state);
    controller.onCancel = subscription.cancel;
  }, isBroadcast: true);

  bool get hasNext => _index + 1 < _items.length;
  bool get hasPrevious => _index > 0;

  Future<void> _run(Future<void> Function() action) {
    final task = _pending.then((_) async {
      if (_disposed) throw StateError('Music queue is disposed');
      await action();
    });
    _pending = task.then<void>((_) {}, onError: (Object _) {});
    return task;
  }

  AudioPlayer _nativePlayer() {
    if (_player case final player?) return player;
    final player = _player = AudioPlayer(
      useLazyPreparation: false,
      handleAudioSessionActivation: false,
    );
    _subscriptions.add(
      player.playerEventStream.listen((_) {
        if (_disposed || _loading != null || _tracks.isEmpty) return;
        _updateFromPlayer(player);
      }),
    );
    _subscriptions.add(
      player.positionStream.listen((position) {
        if (_disposed ||
            _loading != null ||
            _state.status != MusicPlaybackStatus.playing) {
          return;
        }
        _updateFromPlayer(player);
      }),
    );
    _subscriptions.add(
      player.errorStream.listen((error) {
        if (_disposed || _loading != null || _tracks.isEmpty) return;
        _playerFailed(error, StackTrace.current, _generation);
      }),
    );
    return player;
  }

  void _updateFromPlayer(AudioPlayer player) {
    if (_trimming || _tracks.isEmpty) return;
    final nativeIndex = player.currentIndex;
    if (nativeIndex == null || nativeIndex >= _tracks.length) return;
    final index = _index = _tracks[nativeIndex].index;
    if (player.processingState == ProcessingState.completed) {
      if (!player.playing && _state.status == MusicPlaybackStatus.paused) {
        return;
      }
      _complete(player, index);
      return;
    }
    final status = switch (player.processingState) {
      ProcessingState.idle => MusicPlaybackStatus.idle,
      ProcessingState.loading => MusicPlaybackStatus.loading,
      ProcessingState.buffering => MusicPlaybackStatus.buffering,
      ProcessingState.ready =>
        player.playing
            ? MusicPlaybackStatus.playing
            : MusicPlaybackStatus.paused,
      ProcessingState.completed => MusicPlaybackStatus.completed,
    };
    _completedIndex = null;
    _publish(
      status,
      position: player.position,
      duration: player.duration,
      playing: player.playing,
    );
    if (status == MusicPlaybackStatus.playing) _prefetchNext();
  }

  void _complete(AudioPlayer player, int index) {
    final status = hasNext
        ? MusicPlaybackStatus.buffering
        : MusicPlaybackStatus.completed;
    if (_completedIndex == index) return;
    _completedIndex = index;
    final generation = _generation;
    _publish(
      status,
      position: player.position,
      duration: player.duration,
      playing: hasNext && player.playing,
    );
    unawaited(
      _run(() async {
        if (generation != _generation ||
            _state.status != status ||
            player.processingState != ProcessingState.completed) {
          return;
        }
        if (hasNext) {
          // If a slow source missed preloading, retry it at the queue boundary.
          await _load(index + 1);
        } else {
          await _unload(releaseFocus: true);
        }
      }).catchError(_logError),
    );
  }

  void _prefetchNext() {
    final index = _tracks.last.index + 1;
    if (index > _index + 1 ||
        index >= _items.length ||
        _requestedNext == index) {
      return;
    }
    _requestedNext = index;
    unawaited(_prepareNext(_items[index], index, _generation));
  }

  Future<void> _prepareNext(
    MusicReference item,
    int index,
    int generation,
  ) async {
    MusicQueueSource? pending;
    try {
      pending = await _open(item);
      if (_disposed || generation != _generation) return;
      await _run(() async {
        final player = _player!;
        if (generation != _generation ||
            _tracks.isEmpty ||
            player.processingState == ProcessingState.completed) {
          return;
        }
        final source = pending!;
        try {
          await _trimHistory(player);
          if (_disposed ||
              player.processingState == ProcessingState.completed) {
            return;
          }
          _tracks.add((index: index, source: source));
          pending = null;
          await player.addAudioSource(AudioSource.uri(source.uri));
        } catch (error, stack) {
          _playerFailed(error, stack, generation);
        }
      });
    } catch (error, stack) {
      if (!_disposed && generation == _generation) _logError(error, stack);
    } finally {
      if (pending case final source?) await _closeSource(source);
    }
  }

  Future<void> _trimHistory(AudioPlayer player) async {
    // Hold the previous item for a native seek while bounding open file grants.
    final removeCount = (player.currentIndex ?? 0) - 1;
    if (removeCount <= 0) return;
    final removed = _tracks.sublist(0, removeCount);
    _trimming = true;
    try {
      await player.removeAudioSourceRange(0, removeCount);
      _tracks.removeRange(0, removeCount);
    } finally {
      _trimming = false;
    }
    for (final track in removed) {
      await _closeSource(track.source);
    }
  }

  void _publish(
    MusicPlaybackStatus status, {
    Duration position = Duration.zero,
    Duration? duration,
    Object? error,
    bool? playing,
  }) {
    if (_disposed) return;
    final next = (
      status: status,
      currentItem: _items.isEmpty ? null : _items[_index],
      position: position,
      duration: duration,
      isPlaying: playing ?? status == MusicPlaybackStatus.playing,
      isBuffering:
          status == MusicPlaybackStatus.loading ||
          status == MusicPlaybackStatus.buffering,
      error: error,
    );
    if (next == _state) return;
    _state = next;
    _events.add(next);
  }

  void reportError(Object error) => _publish(
    MusicPlaybackStatus.error,
    position: _state.position,
    duration: _state.duration,
    error: error,
  );

  void _logError(Object error, StackTrace stack) => diagnosticLog.record(
    DiagnosticEvent.playbackPlayerFailed,
    error: error,
    nativeErrorCode: error is PlayerException ? error.code : null,
    stack: stack,
  );

  void _playerFailed(Object error, StackTrace stack, int generation) {
    if (_disposed ||
        generation != _generation ||
        _state.status == MusicPlaybackStatus.error) {
      return;
    }
    _logError(error, stack);
    reportError(error);
    unawaited(
      _run(() async {
        if (generation == _generation &&
            _state.status == MusicPlaybackStatus.error) {
          await _unload(releaseFocus: true);
        }
      }).catchError(_logError),
    );
  }

  void interruptLoad() {
    final loading = _loading;
    if (loading == null || loading.isCompleted) return;
    loading.complete();
  }

  Future<void> play(List<MusicReference> items, int index) => _run(() async {
    RangeError.checkValidIndex(index, items);
    if (_tracks.isNotEmpty &&
        listEquals(items, _items) &&
        _state.status != MusicPlaybackStatus.error &&
        _state.status != MusicPlaybackStatus.completed) {
      final nativeIndex = _tracks.indexWhere((track) => track.index == index);
      if (nativeIndex >= 0) {
        final player = _player!;
        await player.seek(Duration.zero, index: nativeIndex);
        await _playNative(player);
        return;
      }
    }
    _items = List.unmodifiable(items);
    await _load(index);
  });

  Future<void> _load(int index, {Duration position = Duration.zero}) async {
    final cancelled = _loading = Completer<void>();
    MusicQueueSource? pending;
    final player = _nativePlayer();
    _generation++;
    _requestedNext = null;
    _completedIndex = null;
    _index = index;
    _publish(MusicPlaybackStatus.loading, position: position);

    try {
      await _unload();
      if (cancelled.isCompleted || _disposed) return;
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
      if (cancelled.isCompleted || _disposed) return;
      await Future.any([
        _open(_items[index]).then((source) async {
          if (cancelled.isCompleted || _disposed) {
            await _closeSource(source);
          } else {
            pending = source;
          }
        }),
        cancelled.future,
      ]);
      if (cancelled.isCompleted || _disposed) return;
      final source = pending!;
      _tracks = [(index: index, source: source)];
      pending = null;
      _prefetchNext();
      await Future.any<void>([
        player
            .setAudioSources([
              AudioSource.uri(source.uri),
            ], initialPosition: position)
            .then<void>((_) {}),
        cancelled.future,
      ]);
      if (cancelled.isCompleted || _disposed) {
        await _unload(releaseFocus: true);
        return;
      }
      await _playNative(player, cancelled: cancelled);
      _loading = null;
      if (cancelled.isCompleted || _disposed) {
        await _unload(releaseFocus: true);
      } else {
        _updateFromPlayer(player);
      }
    } catch (error, stack) {
      await _unload(releaseFocus: true);
      if (!cancelled.isCompleted) {
        _logError(error, stack);
        reportError(error);
        rethrow;
      }
    } finally {
      _loading = null;
      if (pending case final source?) await _closeSource(source);
    }
  }

  Future<void> _playNative(
    AudioPlayer player, {
    Completer<void>? cancelled,
  }) async {
    final generation = _generation;
    if (!player.playing) {
      try {
        final session = await AudioSession.instance;
        if (!await session.setActive(true)) {
          throw StateError('Audio session activation denied');
        }
        _hasAudioFocus = true;
      } catch (error, stack) {
        if (cancelled == null) _playerFailed(error, stack, generation);
        rethrow;
      }
    }
    if (_disposed || cancelled?.isCompleted == true) return;
    // play() completes at pause, stop, or end of media, so it cannot gate commands.
    unawaited(
      player.play().catchError((Object error, StackTrace stack) {
        _playerFailed(error, stack, generation);
      }),
    );
    if (_loading == null) _updateFromPlayer(player);
  }

  Future<void> resume() => _run(() async {
    if (_items.isEmpty) throw StateError('No music queue');
    if (_tracks.isEmpty ||
        _state.status == MusicPlaybackStatus.completed ||
        _state.status == MusicPlaybackStatus.error) {
      await _load(
        _index,
        position: _state.status == MusicPlaybackStatus.paused
            ? _state.position
            : Duration.zero,
      );
    } else {
      await _playNative(_player!);
    }
  });

  Future<void> pause() => _run(() async {
    if (_state.status == MusicPlaybackStatus.completed ||
        _state.status == MusicPlaybackStatus.error ||
        _state.status == MusicPlaybackStatus.idle) {
      return;
    }
    await _player?.pause();
    await _releaseFocus();
    if (_items.isNotEmpty) {
      _publish(
        MusicPlaybackStatus.paused,
        position: _state.position,
        duration: _state.duration,
      );
    }
  });

  Future<void> seek(Duration position) => _run(() async {
    if (position.isNegative) throw ArgumentError.value(position, 'position');
    if (_items.isEmpty) throw StateError('No music queue');
    if (_tracks.isNotEmpty) await _player!.seek(position);
    _publish(
      _state.status,
      position: position,
      duration: _state.duration,
      playing: _state.isPlaying,
    );
  });

  Future<void> next() => _skip(1);
  Future<void> previous() => _skip(-1);

  Future<void> _skip(int direction) => _run(() async {
    final index = _index + direction;
    if (index < 0 || index >= _items.length) return;
    final nativeIndex = _tracks.indexWhere((track) => track.index == index);
    if (nativeIndex < 0) {
      await _load(index);
    } else {
      final player = _player!;
      await player.seek(Duration.zero, index: nativeIndex);
      await _playNative(player);
    }
  });

  Future<void> _unload({bool releaseFocus = false}) async {
    final tracks = _tracks;
    _tracks = const [];
    try {
      await _player?.stop();
    } finally {
      for (final track in tracks) {
        await _closeSource(track.source);
      }
      if (releaseFocus) await _releaseFocus();
    }
  }

  Future<void> _releaseFocus() async {
    if (!_hasAudioFocus) return;
    _hasAudioFocus = false;
    try {
      await (await AudioSession.instance).setActive(false);
    } catch (error, stack) {
      _logError(error, stack);
    }
  }

  Future<void> _closeSource(MusicQueueSource source) async {
    try {
      await source.close?.call();
    } catch (error, stack) {
      _logError(error, stack);
    }
  }

  Future<void> dispose() => _disposing ??= _dispose();

  Future<void> _dispose() async {
    _disposed = true;
    interruptLoad();
    await _pending;
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    try {
      await _player?.dispose();
    } finally {
      for (final track in _tracks) {
        await _closeSource(track.source);
      }
      await _releaseFocus();
      _tracks = const [];
      unawaited(_events.close());
    }
  }
}
