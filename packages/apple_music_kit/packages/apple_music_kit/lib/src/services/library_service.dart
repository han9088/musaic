/// Copyright (c) 2026, deskbtm. BSD-3-Clause.
library;

import 'package:apple_music_kit_platform_interface/apple_music_kit_platform_interface.dart';

/// Library facade: the signed-in user's iCloud Music Library.
///
/// All methods require authorization; unauthorized calls surface
/// `MusicKitException(authorizationDenied)` from the platform layer.
final class MusicLibraryService {
  /// Creates the facade over [platform].
  MusicLibraryService(this._platform, {void Function()? onUse})
      : _onUse = onUse;

  final MusicKitPlatform _platform;
  final void Function()? _onUse;

  /// Lists the user's library songs, newest first (platform-dependent).
  Future<MusicPage<MusicSong>> getSongs({int limit = 25, int? offset}) {
    _onUse?.call();
    return _platform.getLibrarySongs(limit: limit, offset: offset);
  }

  /// Lists the user's library albums.
  Future<MusicPage<MusicAlbum>> getAlbums({int limit = 25, int? offset}) {
    _onUse?.call();
    return _platform.getLibraryAlbums(limit: limit, offset: offset);
  }

  /// Lists the user's library playlists.
  Future<MusicPage<MusicPlaylist>> getPlaylists({int limit = 25, int? offset}) {
    _onUse?.call();
    return _platform.getLibraryPlaylists(limit: limit, offset: offset);
  }

  /// Searches the user's library.
  Future<MusicSearchResult> search(
    String term, {
    Set<MusicResourceType> types = const {MusicResourceType.song},
    int limit = 25,
  }) {
    _onUse?.call();
    return _platform.searchLibrary(term, types: types, limit: limit);
  }

  /// Adds catalog songs to the user's library ("Add to Library").
  Future<void> addSongs(List<MusicItemRef> songs) {
    _onUse?.call();
    return _platform.addToLibrary(songs);
  }

  /// Creates a playlist in the user's library.
  Future<MusicCreatedPlaylist> createPlaylist(
    String name, {
    String? description,
    List<MusicItemRef>? tracks,
  }) {
    _onUse?.call();
    return _platform.createPlaylist(name,
        description: description, tracks: tracks);
  }

  /// Appends tracks to a library playlist.
  Future<MusicAddToPlaylistResult> addToPlaylist(
    String playlistLibraryId,
    List<MusicItemRef> tracks,
  ) {
    _onUse?.call();
    return _platform.addToPlaylist(playlistLibraryId, tracks);
  }
}
