// 文件职责：音乐源、媒体库、播放及切换流程。

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../services/diagnostics/diagnostic_log.dart';
import '../../../services/music/audius_music_provider.dart';
import '../../../services/music/music_provider.dart';
import '../catalog/album_catalog_mapper.dart';

/// 封装或定义专辑播放相关类型与行为，负责音乐源、媒体库、播放及切换流程。
class AlbumPlayback extends ChangeNotifier {
  String? asset;
  String? title;
  bool playing = false;
  VoidCallback? onError;
  MusicProvider? _provider;
  StreamSubscription<MusicPlayback>? _subscription;
  Map<String, ProviderAlbum> _albums = {};
  Map<MusicReference, ({ProviderAlbum album, ProviderSong song})> _tracks = {};
  ProviderAlbum? _playingAudiusAlbum;
  Map<MusicReference, ProviderSong> _playingAudiusTracks = const {};
  MusicPlayback? _playbackState;
  ProviderSong? _currentSong;
  String? _albumArtist;
  bool _busy = false;
  bool _mock = true;

  /// 判断当前状态是否满足指定条件，用于音乐源、媒体库、播放及切换流程。
  bool get supportsPlayback => _mock || _provider != null;
  int _generation = 0;

  String? get currentTitle => _currentSong?.title ?? title;
  MusicReference? get currentTrack => _playbackState?.currentItem;
  String? get currentAlbumId {
    final track = _provider is AudiusMusicProvider
        ? _audiusTrack(currentTrack)
        : _tracks[currentTrack];
    return track == null ? null : albumCatalogId(track.album);
  }

  bool get buffering => _playbackState?.isBuffering ?? false;
  bool get isLoading => switch (_playbackState?.status) {
    MusicPlaybackStatus.loading || MusicPlaybackStatus.buffering => true,
    MusicPlaybackStatus.completed || MusicPlaybackStatus.error => false,
    // Some providers report buffering separately from the transport status.
    _ => buffering,
  };
  Duration? get currentPosition {
    final state = _playbackState;
    return state?.currentItem == null ? null : state?.position;
  }

  String? get currentArtist {
    final name = (_currentSong?.artist ?? _albumArtist)?.trim();
    return switch (name?.toLowerCase()) {
      '' || 'unknown' || '<unknown>' || 'unknown artist' => null,
      _ => name,
    };
  }

  /// 判断当前状态是否满足指定条件，用于音乐源、媒体库、播放及切换流程。
  bool isPlaying(String asset, String title) =>
      this.asset == asset && this.title == title && playing;

  bool isAlbumLoading(String asset, String title) =>
      isLoading &&
      ((this.asset == asset && this.title == title) ||
          (currentTrack != null && _albums[asset]?.reference == currentTrack));

  bool canPlayTrack(ProviderSong track, {String? albumAsset}) {
    if (_provider == null || !track.playable) return false;
    if (_provider is AudiusMusicProvider && albumAsset != null) {
      return _albums[albumAsset]?.tracks?.any(
            (song) => song.reference == track.reference && song.playable,
          ) ??
          false;
    }
    return _tracks.containsKey(track.reference);
  }

  bool isCurrentAlbumTrack(ProviderSong track, String albumAsset) =>
      currentTrack == track.reference &&
      (_provider is! AudiusMusicProvider || asset == albumAsset);

  /// Only remote albums need an on-demand track list.
  Future<List<ProviderSong>>? loadAlbumTracks(String asset) {
    final album = _albums[asset];
    final provider = _provider;
    if (provider is! AudiusMusicProvider || album == null) return null;
    if (album.tracks case final tracks?) return Future.value(tracks);
    return _loadAudiusAlbum(provider, album).then((album) => album.tracks!);
  }

  Future<ProviderAlbum> _loadAudiusAlbum(
    AudiusMusicProvider provider,
    ProviderAlbum album,
  ) async {
    if (album.tracks != null) return album;
    final generation = _generation;
    final detail = await provider.album(album.reference);
    if (generation != _generation) {
      throw StateError('Music source changed while loading tracks.');
    }
    _albums[albumArtworkSource(album)] = detail;
    return detail;
  }

  void _playAudiusAlbum(ProviderAlbum album) {
    _playingAudiusAlbum = album;
    _playingAudiusTracks = {
      for (final track in album.tracks!) track.reference: track,
    };
  }

  ({ProviderAlbum album, ProviderSong song})? _audiusTrack(
    MusicReference? reference,
  ) {
    final album = _playingAudiusAlbum;
    final song = _playingAudiusTracks[reference];
    return album != null && song != null ? (album: album, song: song) : null;
  }

  /// 执行当前模块中的bind操作，用于音乐源、媒体库、播放及切换流程。
  void bind(MusicProvider? provider, List<ProviderAlbum>? albums) {
    _generation++;
    final generation = _generation;
    unawaited(_subscription?.cancel());
    _provider = provider;
    _mock = provider == null && albums == null;
    _albums = {
      for (final album in albums ?? <ProviderAlbum>[])
        albumArtworkSource(album): album,
    };
    _tracks = {
      for (final album in albums ?? <ProviderAlbum>[])
        for (final song in album.tracks ?? <ProviderSong>[])
          song.reference: (album: album, song: song),
    };
    asset = null;
    title = null;
    _playingAudiusAlbum = null;
    _playingAudiusTracks = const {};
    _playbackState = null;
    _currentSong = null;
    _albumArtist = null;
    playing = false;
    _busy = false;
    _subscription = provider?.playback.listen(
      (state) {
        if (generation != _generation) return;
        final trackChanged = currentTrack != state.currentItem;
        final bufferingChanged = buffering != state.isBuffering;
        final wasLoading = isLoading;
        // Keep the seek position current without rebuilding on position ticks.
        _playbackState = state;
        final track = provider is AudiusMusicProvider
            ? _audiusTrack(state.currentItem)
            : _tracks[state.currentItem];
        if (provider is AudiusMusicProvider &&
            state.status == MusicPlaybackStatus.error &&
            !_busy) {
          onError?.call();
        }
        if (!trackChanged &&
            !bufferingChanged &&
            wasLoading == isLoading &&
            _currentSong == track?.song &&
            playing == state.isPlaying) {
          return;
        }
        _currentSong = track?.song;
        if (track case (:final album, song: _)) {
          asset = albumArtworkSource(album);
          title = album.title;
          _albumArtist = album.artist;
        } else {
          asset = null;
          title = null;
          _albumArtist = null;
        }
        playing = state.isPlaying;
        notifyListeners();
      },
      onError: (Object error) {
        if (generation != _generation) return;
        diagnosticLog.record(
          DiagnosticEvent.playbackStreamFailed,
          error: error,
        );
        _playbackState = null;
        playing = false;
        notifyListeners();
        onError?.call();
      },
    );
    notifyListeners();
  }

  /// 应用选择并更新对应状态，用于音乐源、媒体库、播放及切换流程。
  void toggle(String asset, String title, {String? artist}) {
    if (!supportsPlayback) return;
    if (_provider == null) {
      playing = !isPlaying(asset, title);
      this.asset = asset;
      this.title = title;
      _albumArtist = artist;
      notifyListeners();
      return;
    }
    unawaited(
      _runProviderCommand((provider) async {
        final album = _albums[asset];
        if (album == null) throw StateError('Unknown local album');
        if (isPlaying(asset, title)) {
          await provider.pause();
          diagnosticLog.record(DiagnosticEvent.playbackPaused);
        } else if (this.asset == asset) {
          await provider.resume();
          diagnosticLog.record(DiagnosticEvent.playbackResumed);
        } else {
          if (provider is AudiusMusicProvider) {
            final detail = await _loadAudiusAlbum(provider, album);
            if (!detail.tracks!.any((track) => track.playable)) {
              throw StateError('Audius album has no playable tracks.');
            }
            _playAudiusAlbum(detail);
          }
          await provider.play([album.reference]);
          diagnosticLog.record(DiagnosticEvent.playbackStarted);
        }
      }),
    );
  }

  void toggleCurrent() {
    final currentAsset = asset;
    final currentAlbum = title;
    if (currentAsset != null && currentAlbum != null) {
      toggle(currentAsset, currentAlbum, artist: _albumArtist);
    }
  }

  void playTrack(List<ProviderSong> tracks, int index, {String? albumAsset}) {
    if (!canPlayTrack(tracks[index], albumAsset: albumAsset)) return;
    unawaited(
      _runProviderCommand((provider) async {
        final audiusAlbum = provider is AudiusMusicProvider
            ? _albums[albumAsset]
            : null;
        final songs = audiusAlbum?.tracks ?? tracks;
        final position = identical(songs, tracks)
            ? index
            : songs.indexWhere(
                (song) => song.reference == tracks[index].reference,
              );
        if (position < 0) return;
        final queue = <MusicReference>[];
        var startIndex = 0;
        for (final (i, track) in songs.indexed) {
          if (i == position) startIndex = queue.length;
          if (audiusAlbum == null ? canPlayTrack(track) : track.playable) {
            queue.add(track.reference);
          }
        }
        if (audiusAlbum != null) _playAudiusAlbum(audiusAlbum);
        await provider.play(queue, startIndex: startIndex);
        diagnosticLog.record(DiagnosticEvent.playbackStarted);
      }),
    );
  }

  void skip({required bool forward}) {
    if (currentTrack == null) return;
    unawaited(
      _runProviderCommand((provider) async {
        await (forward ? provider.next() : provider.previous());
        diagnosticLog.record(
          forward
              ? DiagnosticEvent.playbackNext
              : DiagnosticEvent.playbackPrevious,
        );
      }),
    );
  }

  void seekStep({required bool forward}) {
    final state = _playbackState;
    if (state == null ||
        state.currentItem == null ||
        state.status == MusicPlaybackStatus.error) {
      return;
    }
    final duration = state.duration ?? _currentSong?.duration;
    var target = state.position + Duration(seconds: forward ? 5 : -5);
    if (target.isNegative) target = Duration.zero;
    if (duration != null && target > duration) target = duration;
    if (target == state.position) return;
    unawaited(
      _runProviderCommand(
        (provider) => provider.seek(target),
        failure: DiagnosticEvent.playbackSeekFailed,
      ),
    );
  }

  Future<void> _runProviderCommand(
    Future<void> Function(MusicProvider provider) command, {
    DiagnosticEvent failure = DiagnosticEvent.playbackCommandFailed,
  }) async {
    final provider = _provider;
    if (provider == null || _busy) return;
    final generation = _generation;
    _busy = true;
    try {
      await command(provider);
    } catch (error, stack) {
      diagnosticLog.record(failure, error: error, stack: stack);
      if (generation == _generation) onError?.call();
    } finally {
      if (generation == _generation) _busy = false;
    }
  }

  @override
  void dispose() {
    _generation++;
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}
