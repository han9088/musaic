import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../services/music/music_provider.dart';

class AlbumPlayback extends ChangeNotifier {
  String? asset;
  String? title;
  bool playing = false;
  VoidCallback? onError;
  MusicProvider? _provider;
  StreamSubscription<MusicPlayback>? _subscription;
  Map<String, ProviderAlbum> _albums = {};
  Map<String, ProviderAlbum> _songAlbums = {};
  bool _busy = false;
  bool _mock = true;
  bool get supportsPlayback => _mock || _provider != null;
  int _generation = 0;

  bool isPlaying(String asset, String title) =>
      this.asset == asset && this.title == title && playing;

  void bind(MusicProvider? provider, List<ProviderAlbum>? albums) {
    _generation++;
    final generation = _generation;
    unawaited(_subscription?.cancel());
    _provider = provider;
    _mock = provider == null && albums == null;
    _albums = {
      for (final album in albums ?? <ProviderAlbum>[])
        'local:${album.reference.id}': album,
    };
    _songAlbums = {
      for (final album in albums ?? <ProviderAlbum>[])
        for (final song in album.tracks ?? <ProviderSong>[])
          song.reference.id: album,
    };
    asset = null;
    title = null;
    playing = false;
    _busy = false;
    _subscription = provider?.playback.listen(
      (state) {
        if (generation != _generation) return;
        final album = _songAlbums[state.currentItem?.id];
        if (album != null) {
          asset = 'local:${album.reference.id}';
          title = album.title;
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

  void toggle(String asset, String title) {
    if (!supportsPlayback) return;
    if (_provider == null) {
      playing = !isPlaying(asset, title);
      this.asset = asset;
      this.title = title;
      notifyListeners();
      return;
    }
    if (!_busy) unawaited(_toggleLocal(asset, title));
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
