import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:audius_sdk/audius_sdk.dart';

import 'music_provider.dart';

final class AudiusMusicProvider implements MusicProvider {
  AudiusMusicProvider({
    required this._sdk,
    AudioPlayer Function()? createPlayer,
  }) : _createPlayer = createPlayer ?? AudioPlayer.new;

  static const providerId = 'audius';
  static const _available = (
    supported: true,
    reason: 'available',
    detail: null,
  );

  final AudiusSdk _sdk;
  final AudioPlayer Function() _createPlayer;
  final _summaries = <String, ProviderAlbum>{};
  final _details = <MusicReference, Future<ProviderAlbum>>{};
  final _events = StreamController<MusicPlayback>.broadcast();
  final _subscriptions = <StreamSubscription<dynamic>>[];
  Future<void> _pending = Future.value();
  Future<void>? _disposing;
  Completer<void>? _cancelCommand;
  AudioPlayer? _player;
  bool _audioContextConfigured = false;
  bool _disposed = false;
  List<MusicReference> _queue = const [];
  int _index = 0;
  int _revision = 0;
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
  String get id => providerId;

  // Public catalog access needs no user session or permissions.
  @override
  Future<void> initialize() async => _ensureOpen();

  @override
  Future<MusicAccess> authorizationStatus() async => MusicAccess.authorized;

  @override
  Future<MusicAccess> requestAuthorization() => authorizationStatus();

  @override
  Future<MusicFeatures> capabilities() async => (
    playback: _available,
    library: _available,
    queue: _available,
    seek: _available,
  );

  @override
  Future<MusicPage<ProviderAlbum>> libraryAlbums({
    int limit = 25,
    String? cursor,
  }) async {
    _ensureOpen();
    RangeError.checkValueInInterval(limit, 1, 100, 'limit');
    final offset = cursor == null ? 0 : int.tryParse(cursor);
    if (offset == null || offset < 0) {
      throw ArgumentError.value(cursor, 'cursor');
    }
    final result = await _sdk.playlists.getTrendingPlaylists(
      type: 'album',
      offset: offset,
      limit: limit,
    );
    _ensureOpen();
    return (
      items: _mapAlbums(result.data),
      nextCursor: result.data.length < limit
          ? null
          : (offset + result.data.length).toString(),
    );
  }

  @override
  Future<List<ProviderAlbum>> searchAlbums(
    String query, {
    int limit = 25,
  }) async {
    _ensureOpen();
    RangeError.checkValueInInterval(limit, 1, 100, 'limit');
    final result = await _sdk.playlists.searchAlbums(
      query: query,
      limit: limit,
    );
    _ensureOpen();
    return _mapAlbums(result.data);
  }

  List<ProviderAlbum> _mapAlbums(List<AudiusPlaylist> items) {
    final albums = <String, ProviderAlbum>{};
    for (final item in items) {
      if (item.isAlbum != true || item.id.isEmpty) continue;
      final album = _mapCollection(item, MusicKind.album);
      _summaries[item.id] = album;
      albums[item.id] = album;
    }
    return List<ProviderAlbum>.unmodifiable(albums.values);
  }

  @override
  Future<ProviderAlbum> album(MusicReference reference) {
    _validate(reference, MusicKind.album);
    return _collection(reference);
  }

  Future<ProviderAlbum> playlist(MusicReference reference) {
    _validate(reference, MusicKind.playlist);
    return _collection(reference);
  }

  Future<AudiusUser> artist(MusicReference reference) async {
    _validate(reference, MusicKind.artist);
    return (await _sdk.users.getUser(id: reference.id)).data;
  }

  Future<ProviderAlbum> _collection(MusicReference reference) =>
      _details.putIfAbsent(reference, () async {
        try {
          final album = _summaries[reference.id];
          if (reference.kind == MusicKind.album && album != null) {
            if (album.tracks != null) return album;
            final tracks = await _sdk.albums.getAlbumTracks(
              albumId: reference.id,
            );
            _ensureOpen();
            final songs = _mapSongs(tracks.data);
            return (
              reference: reference,
              title: album.title,
              artist: album.artist,
              artworkUrl: album.artworkUrl,
              trackCount: songs.length,
              tracks: songs,
            );
          }
          final response = await _sdk.playlists.getPlaylist(
            playlistId: reference.id,
          );
          final item = response.data;
          if (item.id != reference.id ||
              (item.isAlbum == true) != (reference.kind == MusicKind.album)) {
            throw StateError('Unexpected Audius collection.');
          }
          final tracks = _hasFullTrackList(item)
              ? item.tracks
              : (await _sdk.playlists.getPlaylistTracks(playlistId: item.id))
                    .data;
          _ensureOpen();
          return _mapCollection(item, reference.kind, tracks: tracks);
        } catch (_) {
          _details.remove(reference);
          rethrow;
        }
      });

  ProviderAlbum _mapCollection(
    AudiusPlaylist item,
    MusicKind kind, {
    List<AudiusTrack>? tracks,
  }) {
    final artwork = Uri.tryParse(item.artwork?.best ?? '');
    final songs = tracks != null || _hasFullTrackList(item)
        ? _mapSongs(tracks ?? item.tracks)
        : null;
    return (
      reference: _reference(item.id, kind),
      title: item.playlistName ?? item.id,
      artist: item.user?.name ?? item.user?.handle,
      // The existing playback UI identifies covers by asset. Distinguish shared
      // artwork without changing the HTTP request URL.
      artworkUrl:
          artwork != null &&
              artwork.scheme == 'https' &&
              artwork.host.isNotEmpty
          ? artwork.replace(fragment: 'audius-${item.id}').toString()
          : null,
      trackCount: songs?.length ?? item.trackCount,
      tracks: songs,
    );
  }

  bool _hasFullTrackList(AudiusPlaylist item) =>
      item.tracks.isNotEmpty &&
      (item.trackCount == null || item.tracks.length == item.trackCount);

  List<ProviderSong> _mapSongs(List<AudiusTrack> tracks) =>
      List<ProviderSong>.unmodifiable([
        for (final track in tracks)
          if (track.id.isNotEmpty)
            (
              reference: _reference(track.id, MusicKind.song),
              title: track.title,
              artist: track.user?.name ?? track.user?.handle,
              artworkUrl: track.artwork?.best,
              duration: switch (track.duration) {
                final seconds? when seconds.isFinite && seconds >= 0 =>
                  Duration(milliseconds: (seconds * 1000).round()),
                _ => null,
              },
              playable:
                  track.isStreamable != false &&
                  track.hasStreamAccess != false &&
                  track.isStreamGated != true,
            ),
      ]);

  MusicReference _reference(String id, MusicKind kind) => (
    provider: providerId,
    id: id,
    kind: kind,
    source: MusicSource.catalog,
    storefront: null,
  );

  void _validate(MusicReference reference, MusicKind kind) {
    _ensureOpen();
    if (reference.id.trim().isEmpty ||
        reference != _reference(reference.id, kind)) {
      throw ArgumentError.value(
        reference,
        'reference',
        'Invalid Audius reference',
      );
    }
  }

  @override
  Future<List<MusicAnimatedArtwork>> animatedArtwork(
    MusicReference reference,
  ) async {
    _validate(reference, MusicKind.album);
    return const [];
  }

  @override
  Stream<MusicPlayback> get playback => _events.stream;

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
      currentItem: _queue.isEmpty ? null : _queue[_index],
      position: position ?? (reset ? Duration.zero : _state.position),
      duration: duration ?? (reset ? null : _state.duration),
      isPlaying: next == MusicPlaybackStatus.playing,
      isBuffering:
          next == MusicPlaybackStatus.loading ||
          next == MusicPlaybackStatus.buffering,
      error: error ?? (status == null ? _state.error : null),
    );
    _events.add(_state);
  }

  void _ensureOpen() {
    if (_disposed) throw StateError('Audius provider is disposed.');
  }

  Future<void> _command(Future<void> Function() action) {
    final task = _pending.then((_) async {
      _ensureOpen();
      final cancelled = _cancelCommand = Completer<void>();
      try {
        await Future.any([action(), cancelled.future]);
      } finally {
        _cancelCommand = null;
      }
    });
    _pending = task.then<void>((_) {}, onError: (Object _) {});
    return task;
  }

  AudioPlayer _audioPlayer() {
    if (_player case final existing?) return existing;
    final player = _player = _createPlayer();
    _subscriptions.add(
      player.onPositionChanged.listen((position) {
        if (_state.status == MusicPlaybackStatus.playing) {
          _emit(position: position);
        }
      }),
    );
    _subscriptions.add(
      player.eventStream.listen(
        (event) {
          switch (event.eventType) {
            case AudioEventType.duration:
              if (_state.status != MusicPlaybackStatus.loading) {
                _emit(duration: event.duration);
              }
            case AudioEventType.complete:
              final revision = _revision;
              if (_state.status != MusicPlaybackStatus.playing) return;
              unawaited(
                _command(() async {
                  if (revision != _revision ||
                      _state.status != MusicPlaybackStatus.playing) {
                    return;
                  }
                  if (_index + 1 < _queue.length) {
                    _index++;
                    await _start();
                  } else {
                    _emit(
                      status: MusicPlaybackStatus.completed,
                      position: _state.duration,
                    );
                  }
                }).catchError((Object error) {
                  if (!_disposed &&
                      _state.status != MusicPlaybackStatus.error) {
                    _emit(status: MusicPlaybackStatus.error, error: error);
                  }
                }),
              );
            default:
              break;
          }
        },
        onError: (Object error) {
          if (_state.status == MusicPlaybackStatus.playing) {
            _emit(status: MusicPlaybackStatus.error, error: error);
          }
        },
      ),
    );
    return player;
  }

  Future<void> _start() async {
    _revision++;
    _emit(status: MusicPlaybackStatus.loading, reset: true);
    try {
      final player = _audioPlayer();
      if (!_audioContextConfigured) {
        await player.setAudioContext(
          AudioContext(
            iOS: AudioContextIOS(category: AVAudioSessionCategory.playback),
            android: const AudioContextAndroid(
              audioFocus: AndroidAudioFocus.gain,
              usageType: AndroidUsageType.media,
              contentType: AndroidContentType.music,
            ),
          ),
        );
        _audioContextConfigured = true;
      }
      _ensureOpen();
      await player.stop();
      _ensureOpen();
      final stream = _sdk.tracks.getTrackStream(trackId: _queue[_index].id);
      final uri = await _sdk.tracks.resolveTrackStream(stream);
      _ensureOpen();
      _emit(status: MusicPlaybackStatus.buffering);
      await player.setSource(UrlSource(uri.toString()));
      _ensureOpen();
      await player.resume();
      _emit(status: MusicPlaybackStatus.playing);
    } catch (error) {
      _emit(status: MusicPlaybackStatus.error, error: error);
      rethrow;
    }
  }

  @override
  Future<void> play(List<MusicReference> items, {int startIndex = 0}) {
    final snapshot = List<MusicReference>.of(items);
    return _command(() async {
      RangeError.checkValidIndex(startIndex, snapshot, 'startIndex');
      final queue = <MusicReference>[];
      var index = 0;
      for (final (position, reference) in snapshot.indexed) {
        if (position == startIndex) index = queue.length;
        if (reference.kind == MusicKind.song) {
          _validate(reference, MusicKind.song);
          queue.add(reference);
        } else {
          final collection = await (reference.kind == MusicKind.album
              ? album(reference)
              : playlist(reference));
          final tracks = collection.tracks!.where((song) => song.playable);
          if (tracks.isEmpty && position == startIndex) {
            throw StateError('Audius collection has no playable tracks.');
          }
          queue.addAll(tracks.map((song) => song.reference));
        }
      }
      _ensureOpen();
      _queue = queue;
      _index = index;
      await _start();
    });
  }

  @override
  Future<void> resume() => _command(() async {
    if (_queue.isEmpty) throw StateError('No Audius playback queue.');
    if (_state.status == MusicPlaybackStatus.error ||
        _state.status == MusicPlaybackStatus.completed) {
      await _start();
    } else {
      await _player!.resume();
      _emit(status: MusicPlaybackStatus.playing);
    }
  });

  @override
  Future<void> pause() => _command(() async {
    if (_state.status != MusicPlaybackStatus.playing) return;
    await _player!.pause();
    _emit(status: MusicPlaybackStatus.paused);
  });

  @override
  Future<void> seek(Duration position) => _command(() async {
    if (position.isNegative) throw ArgumentError.value(position, 'position');
    if (_state.status != MusicPlaybackStatus.playing &&
        _state.status != MusicPlaybackStatus.paused) {
      return;
    }
    final duration = _state.duration;
    final target = duration != null && position > duration
        ? duration
        : position;
    await _player!.seek(target);
    _emit(position: target);
  });

  @override
  Future<void> next() => _command(() async {
    if (_index + 1 >= _queue.length) return;
    _index++;
    await _start();
  });

  @override
  Future<void> previous() => _command(() async {
    if (_index == 0) return;
    _index--;
    await _start();
  });

  @override
  Future<void> dispose() => _disposing ??= _dispose();

  Future<void> _dispose() async {
    _disposed = true;
    _sdk.close();
    _cancelCommand?.complete();
    await _pending;
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _details.clear();
    _summaries.clear();
    try {
      await _player?.dispose();
    } finally {
      unawaited(_events.close());
    }
  }
}
