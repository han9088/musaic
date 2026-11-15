import 'music_models.dart';

export 'music_models.dart';

/// Providers are opt-in: construction must not request access or start playback.
abstract interface class MusicProvider {
  String get id;
  Future<void> initialize();
  Future<MusicAccess> authorizationStatus();
  Future<MusicAccess> requestAuthorization();
  Future<MusicFeatures> capabilities();
  Future<List<ProviderAlbum>> searchAlbums(String query, {int limit = 25});
  Future<MusicPage<ProviderAlbum>> libraryAlbums({
    int limit = 25,
    String? cursor,
  });

  /// Catalog details. Library details may be unsupported by a provider.
  Future<ProviderAlbum> album(MusicReference reference);

  /// On demand only. Empty means no artwork; unsupported and request errors throw.
  Future<List<MusicAnimatedArtwork>> animatedArtwork(MusicReference reference);
  Stream<MusicPlayback> get playback;
  Future<void> play(List<MusicReference> items, {int startIndex = 0});
  Future<void> resume();
  Future<void> pause();
  Future<void> seek(Duration position);
  Future<void> next();
  Future<void> previous();
  Future<void> dispose();
}
