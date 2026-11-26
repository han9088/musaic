/// Copyright (c) 2026, deskbtm. BSD-3-Clause.
library;

import 'music_item_ref.dart';

/// Result of adding a track to a library playlist.
final class MusicAddToPlaylistResult {
  /// Creates a result.
  const MusicAddToPlaylistResult(
      {required this.playlistId, required this.addedRefs});

  /// The playlist that was modified.
  final String playlistId;

  /// The tracks that were added (as reported by the API).
  final List<MusicItemRef> addedRefs;
}

/// A created library playlist.
final class MusicCreatedPlaylist {
  /// Creates a result.
  const MusicCreatedPlaylist({
    required this.id,
    required this.name,
    this.description,
  });

  /// The new playlist's library id (starts with `p.`).
  final String id;

  /// The playlist name.
  final String name;

  /// The playlist description, if set.
  final String? description;
}
