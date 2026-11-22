// 文件职责：音乐源、媒体库、播放及切换流程。

import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

import '../diagnostics/diagnostic_log.dart';
import 'local_music_library.dart';
import 'music_provider.dart';

/// 封装或定义本地音乐提供器相关类型与行为，负责音乐源、媒体库、播放及切换流程。
final class LocalMusicProvider implements MusicProvider {
  LocalMusicProvider({LocalMusicLibrary? library})
    : _library = library ?? LocalMusicLibrary();

  final LocalMusicLibrary _library;
  Future<void>? _scan;
  bool _loaded = false;
  AudioPlayer? _player;
  final _subscriptions = <StreamSubscription<dynamic>>[];
  final _events = StreamController<MusicPlayback>.broadcast();
  Future<void> _pending = Future.value();
  Future<void>? _initializing;
  Future<void>? _disposing;
  bool _initialized = false;
  bool _disposed = false;
  List<ProviderSong> _queue = [];
  int _index = 0;
  int _generation = 0;
  MusicPlayback _state = (
    status: MusicPlaybackStatus.idle,
    currentItem: null,
    position: Duration.zero,
    duration: null,
    isPlaying: false,
    isBuffering: false,
    error: null,
  );

  @override
  /// 执行当前模块中的id操作，用于音乐源、媒体库、播放及切换流程。
  String get id => LocalMusicLibrary.providerId;

  @override
  Future<void> initialize() {
    if (_disposed) {
      return Future.error(StateError('Local provider is disposed'));
    }
    if (_initialized) return Future.value();
    return _initializing ??= _initialize();
  }

  /// 执行当前模块中的initialize操作，用于音乐源、媒体库、播放及切换流程。
  Future<void> _initialize() async {
    try {
      await _library.authorizationStatus();
      if (_disposed) throw StateError('Local provider is disposed');
      _initialized = true;
    } finally {
      _initializing = null;
    }
  }

  void _requireReady() {
    if (_disposed || !_initialized) {
      throw StateError(
        _disposed ? 'Local provider is disposed' : 'Call initialize first',
      );
    }
  }

  @override
  Future<MusicAccess> authorizationStatus() async {
    _requireReady();
    return _library.authorizationStatus();
  }

  @override
  Future<MusicAccess> requestAuthorization() async {
    _requireReady();
    return _library.authorizationStatus(request: true);
  }

  Future<void> _ensureLibrary() async {
    _requireReady();
    final access = await _library.authorizationStatus();
    _requireReady();
    if (access != MusicAccess.authorized) {
      _library.clear();
      _loaded = false;
      throw StateError('System music library access: ${access.name}');
    }
    if (_loaded) return;
    await (_scan ??= _load());
    _requireReady();
  }

  /// 读取并恢复所需数据或资源，用于音乐源、媒体库、播放及切换流程。
  Future<void> _load() async {
    try {
      await _library.scan();
      _loaded = true;
    } finally {
      _scan = null;
    }
  }

  /// Call after external library changes; no automatic background scanning.
  Future<void> refreshLibrary() => _command(() async {
    _loaded = false;
    await _ensureLibrary();
  });

  @override
  Future<MusicFeatures> capabilities() async {
    _requireReady();
    final access = await authorizationStatus();
    final feature = (
      supported: access == MusicAccess.authorized,
      reason: access == MusicAccess.authorized
          ? 'available'
          : access == MusicAccess.unavailable
          ? 'unsupportedOnPlatform'
          : 'authorizationRequired',
      detail: null as String?,
    );
    return (playback: feature, library: feature, queue: feature, seek: feature);
  }

  @override
  Future<List<ProviderAlbum>> searchAlbums(
    String query, {
    int limit = 25,
  }) async {
    await _ensureLibrary();
    RangeError.checkValueInInterval(limit, 1, 100, 'limit');
    final term = query.trim().toLowerCase();
    if (term.isEmpty) throw ArgumentError.value(query, 'query');
    return List.unmodifiable(
      _library.albums
          .where((album) => album.title.toLowerCase().contains(term))
          .take(limit),
    );
  }

  @override
  Future<MusicPage<ProviderAlbum>> libraryAlbums({
    int limit = 25,
    String? cursor,
  }) async {
    await _ensureLibrary();
    RangeError.checkValueInInterval(limit, 1, 100, 'limit');
    final offset = cursor == null ? 0 : int.tryParse(cursor);
    if (offset == null || offset < 0 || offset > _library.albums.length) {
      throw ArgumentError.value(cursor, 'cursor');
    }
    final items = List<ProviderAlbum>.unmodifiable(
      _library.albums.skip(offset).take(limit),
    );
    final end = offset + items.length;
    return (
      items: items,
      nextCursor: end < _library.albums.length ? '$end' : null,
    );
  }

  @override
  Future<ProviderAlbum> album(MusicReference reference) async {
    await _ensureLibrary();
    return _library.album(reference);
  }

  @override
  Future<List<MusicAnimatedArtwork>> animatedArtwork(
    MusicReference reference,
  ) async {
    await album(reference);
    return const [];
  }

  @override
  /// 执行当前模块中的播放操作，用于音乐源、媒体库、播放及切换流程。
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

  void _emit({
    MusicPlaybackStatus? status,
    Duration? position,
    Duration? duration,
    Object? error,
    bool reset = false,
  }) {
    if (_disposed) return;
    final next = status ?? _state.status;
    _state = (
      status: next,
      currentItem: _queue.isEmpty ? null : _queue[_index].reference,
      position: position ?? (reset ? Duration.zero : _state.position),
      duration: reset ? null : (duration ?? _state.duration),
      isPlaying: next == MusicPlaybackStatus.playing,
      isBuffering:
          next == MusicPlaybackStatus.loading ||
          next == MusicPlaybackStatus.buffering,
      error: error,
    );
    _events.add(_state);
  }

  Completer<void>? _loadingCancelled;
  bool _needsSource = true;
  Duration? _seekOnStart;

  /// 判断当前状态是否满足指定条件，用于音乐源、媒体库、播放及切换流程。
  Future<void> _cancelLoading() async {
    final cancelled = _loadingCancelled;
    if (cancelled == null || cancelled.isCompleted) return;
    cancelled.complete();
    _needsSource = true;
    _generation++;
    await _player?.stop();
  }

  Future<void> _command(
    Future<void> Function() action, {
    bool interrupt = false,
  }) {
    final cancellation = interrupt ? _cancelLoading() : Future<void>.value();
    final task = Future.wait([_pending, cancellation]).then((_) async {
      _requireReady();
      try {
        await action();
      } catch (error) {
        _emit(status: MusicPlaybackStatus.error, error: error);
        rethrow;
      }
    });
    _pending = task.then<void>((_) {}, onError: (Object _) {});
    return task;
  }

  AudioPlayer _getPlayer() {
    if (_player case final player?) return player;
    final player = _player = AudioPlayer();
    void failed(Object error) {
      diagnosticLog.record(DiagnosticEvent.playbackPlayerFailed, error: error);
      _emit(status: MusicPlaybackStatus.error, error: error);
    }

    _subscriptions.add(
      player.onPositionChanged.listen(
        (value) => _emit(position: value),
        onError: failed,
      ),
    );
    _subscriptions.add(
      player.onDurationChanged.listen(
        (value) => _emit(duration: value),
        onError: failed,
      ),
    );
    _subscriptions.add(
      player.onPlayerStateChanged.listen((value) {
        if (_state.status == MusicPlaybackStatus.loading) return;
        if (value == PlayerState.playing) {
          _emit(status: MusicPlaybackStatus.playing);
        }
        if (value == PlayerState.paused) {
          _emit(status: MusicPlaybackStatus.paused);
        }
      }, onError: failed),
    );
    _subscriptions.add(
      player.onPlayerComplete.listen((_) {
        final generation = _generation;
        unawaited(
          _command(() async {
            if (generation != _generation) return;
            if (_index + 1 < _queue.length) {
              _index++;
              await _start();
            } else {
              _emit(status: MusicPlaybackStatus.completed);
            }
          }).catchError((Object error) {
            diagnosticLog.record(
              DiagnosticEvent.playbackAdvanceFailed,
              error: error,
            );
          }),
        );
      }, onError: failed),
    );
    _subscriptions.add(player.eventStream.listen((_) {}, onError: failed));
    return player;
  }

  /// 控制流程的开始、暂停、取消或结束，用于音乐源、媒体库、播放及切换流程。
  Future<void> _start() async {
    final player = _getPlayer();
    final cancelled = _loadingCancelled = Completer<void>();
    _generation++;
    _needsSource = true;
    Future<bool> step(Future<void> operation) async {
      try {
        await Future.any([operation, cancelled.future]);
      } catch (_) {
        if (!cancelled.isCompleted) rethrow;
      }
      return !cancelled.isCompleted && !_disposed;
    }

    try {
      if (!await step(player.stop())) return;
      _emit(status: MusicPlaybackStatus.loading, reset: true);
      if (!await step(
        player.setAudioContext(
          AudioContext(
            iOS: AudioContextIOS(category: AVAudioSessionCategory.playback),
            android: const AudioContextAndroid(
              audioFocus: AndroidAudioFocus.gain,
              usageType: AndroidUsageType.media,
              contentType: AndroidContentType.music,
            ),
          ),
        ),
      )) {
        return;
      }
      final uri = Uri.parse(_library.source(_queue[_index]));
      if (!await step(
        player.setSource(
          uri.scheme == 'file'
              ? DeviceFileSource(uri.toFilePath())
              : UrlSource(uri.toString()),
        ),
      )) {
        return;
      }
      if (_seekOnStart case final position?) {
        if (!await step(player.seek(position))) return;
        _seekOnStart = null;
      }
      _needsSource = false;
      if (!await step(player.resume())) return;
      _emit(status: MusicPlaybackStatus.playing);
    } finally {
      if (identical(_loadingCancelled, cancelled)) _loadingCancelled = null;
    }
  }

  @override
  Future<void> play(List<MusicReference> items, {int startIndex = 0}) {
    final snapshot = List<MusicReference>.of(items);
    return _command(() async {
      await _ensureLibrary();
      RangeError.checkValidIndex(startIndex, snapshot, 'startIndex');
      // startIndex 对应传入的项目列表索引，计算时尚未将专辑展开为曲目。
      final before = _library
          .resolve(snapshot.take(startIndex).toList())
          .length;
      final songs = _library.resolve(snapshot);
      if (songs.isEmpty) throw ArgumentError('Empty local queue');
      _seekOnStart = null;
      _queue = songs;
      _index = before;
      await _start();
    }, interrupt: true);
  }

  @override
  Future<void> resume() => _command(() async {
    if (_queue.isEmpty) throw StateError('No local playback queue');
    if (_needsSource ||
        _state.status == MusicPlaybackStatus.completed ||
        _state.status == MusicPlaybackStatus.error) {
      await _start();
    } else {
      await _getPlayer().resume();
      _emit(status: MusicPlaybackStatus.playing);
    }
  });

  @override
  Future<void> pause() => _command(() async {
    await _player?.pause();
    if (_queue.isNotEmpty) _emit(status: MusicPlaybackStatus.paused);
  }, interrupt: true);

  @override
  Future<void> seek(Duration position) => _command(() async {
    if (position.isNegative) throw ArgumentError.value(position, 'position');
    if (_queue.isEmpty) throw StateError('No local playback queue');
    if (_needsSource) {
      _seekOnStart = position;
    } else {
      await _getPlayer().seek(position);
    }
    _emit(position: position);
  });

  @override
  Future<void> next() => _command(() async {
    if (_index + 1 < _queue.length) {
      _index++;
      _seekOnStart = null;
      await _start();
    }
  }, interrupt: _index + 1 < _queue.length);

  @override
  Future<void> previous() => _command(() async {
    if (_index > 0) {
      _index--;
      _seekOnStart = null;
      await _start();
    }
  }, interrupt: _index > 0);

  @override
  Future<void> dispose() => _disposing ??= _dispose();

  Future<void> _dispose() async {
    _disposed = true;
    try {
      await _initializing;
    } catch (_) {
      /* Initialization reports its failure. */
    }
    try {
      await _cancelLoading();
    } catch (_) {
      // 即使停止播放失败，释放阶段仍必须销毁原生播放器资源。
    }
    await _pending;
    try {
      await _scan;
    } catch (_) {
      /* Caller receives scan failures. */
    }
    _library.clear();
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    try {
      await _player?.dispose();
    } finally {
      await _events.close();
    }
  }
}
