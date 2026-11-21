// 文件职责：音乐源、媒体库、播放及切换流程。

import 'dart:async';

import 'package:flutter/foundation.dart';

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
  ProviderSong? _currentSong;
  String? _albumArtist;
  bool _busy = false;
  bool _mock = true;

  /// 判断当前状态是否满足指定条件，用于音乐源、媒体库、播放及切换流程。
  bool get supportsPlayback => _mock || _provider != null;
  int _generation = 0;

  String? get currentTitle => _currentSong?.title ?? title;
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
    _currentSong = null;
    _albumArtist = null;
    playing = false;
    _busy = false;
    _subscription = provider?.playback.listen(
      (state) {
        if (generation != _generation) return;
        final track = _tracks[state.currentItem];
        if (_currentSong == track?.song && playing == state.isPlaying) return;
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
      onError: (Object _) {
        if (generation != _generation) return;
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
    if (!_busy) unawaited(_toggleLocal(asset, title));
  }

  void toggleCurrent() {
    final currentAsset = asset;
    final currentAlbum = title;
    if (currentAsset != null && currentAlbum != null) {
      toggle(currentAsset, currentAlbum, artist: _albumArtist);
    }
  }

  Future<void> _toggleLocal(String asset, String title) async {
    final provider = _provider!;
    final generation = _generation;
    _busy = true;
    try {
      final album = _albums[asset];
      if (album == null) throw StateError('Unknown local album');
      if (isPlaying(asset, title)) {
        await provider.pause();
      } else if (this.asset == asset) {
        await provider.resume();
      } else {
        await provider.play([album.reference]);
      }
    } catch (_) {
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
