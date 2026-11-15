enum MusicAccess { notDetermined, authorized, denied, restricted, unavailable }

enum MusicSource { catalog, library }

enum MusicKind { song, album, artist, playlist, station }

enum MusicArtworkLayout { square, portrait, unknown }

/// Original stream URLs; dimensions and encoding are not inferred from names.
typedef MusicAnimatedArtwork = ({MusicArtworkLayout layout, String videoUrl});

enum MusicPlaybackStatus {
  idle,
  loading,
  buffering,
  ready,
  playing,
  paused,
  stopped,
  completed,
  error,
}

/// IDs are only meaningful within their provider, source and storefront.
typedef MusicReference = ({
  String provider,
  String id,
  MusicKind kind,
  MusicSource source,
  String? storefront,
});

typedef MusicFeature = ({bool supported, String reason, String? detail});
typedef MusicFeatures = ({
  MusicFeature playback,
  MusicFeature library,
  MusicFeature queue,
  MusicFeature seek,
});

typedef MusicPage<T> = ({List<T> items, String? nextCursor});
typedef ProviderSong = ({
  MusicReference reference,
  String title,
  String? artist,
  String? artworkUrl,
  Duration? duration,
  bool playable,
});
typedef ProviderAlbum = ({
  MusicReference reference,
  String title,
  String? artist,
  String? artworkUrl,
  int? trackCount,
  // Null means tracks were not loaded, not that the album is empty.
  List<ProviderSong>? tracks,
});
typedef MusicPlayback = ({
  MusicPlaybackStatus status,
  MusicReference? currentItem,
  Duration position,
  Duration? duration,
  bool isPlaying,
  bool isBuffering,
  Object? error,
});
