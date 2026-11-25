// 文件职责：音乐源、媒体库、播放及切换流程。

/// 封装或定义音乐access相关类型与行为，负责音乐源、媒体库、播放及切换流程。
enum MusicAccess { notDetermined, authorized, denied, restricted, unavailable }

/// 封装或定义音乐来源相关类型与行为，负责音乐源、媒体库、播放及切换流程。
enum MusicSource { catalog, library }

/// 封装或定义音乐kind相关类型与行为，负责音乐源、媒体库、播放及切换流程。
enum MusicKind { song, album, artist, playlist, station }

/// 封装或定义音乐专辑封面布局相关类型与行为，负责音乐源、媒体库、播放及切换流程。
enum MusicArtworkLayout { square, portrait, unknown }

/// 封装或定义音乐animated专辑封面相关类型与行为，负责音乐源、媒体库、播放及切换流程。
typedef MusicAnimatedArtwork = ({MusicArtworkLayout layout, String videoUrl});

/// 封装或定义音乐播放status相关类型与行为，负责音乐源、媒体库、播放及切换流程。
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

/// 封装或定义音乐reference相关类型与行为，负责音乐源、媒体库、播放及切换流程。
typedef MusicReference = ({
  String provider,
  String id,
  MusicKind kind,
  MusicSource source,
  String? storefront,
});

/// 封装或定义音乐feature相关类型与行为，负责音乐源、媒体库、播放及切换流程。
typedef MusicFeature = ({bool supported, String reason, String? detail});

/// 封装或定义音乐features相关类型与行为，负责音乐源、媒体库、播放及切换流程。
typedef MusicFeatures = ({
  MusicFeature playback,
  MusicFeature library,
  MusicFeature queue,
  MusicFeature seek,
});

/// 封装或定义音乐page相关类型与行为，负责音乐源、媒体库、播放及切换流程。
typedef MusicPage<T> = ({List<T> items, String? nextCursor});

/// 封装或定义提供器song相关类型与行为，负责音乐源、媒体库、播放及切换流程。
typedef ProviderSong = ({
  MusicReference reference,
  String title,
  String? artist,
  String? artworkUrl,
  Duration? duration,
  bool playable,
});

/// 封装或定义提供器专辑相关类型与行为，负责音乐源、媒体库、播放及切换流程。
typedef ProviderAlbum = ({
  MusicReference reference,
  String title,
  String? artist,
  String? artworkUrl,
  int? trackCount,
  // null 表示曲目尚未加载完成，并不代表专辑没有曲目。
  List<ProviderSong>? tracks,
});

/// 封装或定义音乐播放相关类型与行为，负责音乐源、媒体库、播放及切换流程。
typedef MusicPlayback = ({
  MusicPlaybackStatus status,
  MusicReference? currentItem,
  Duration position,
  Duration? duration,
  bool isPlaying,
  bool isBuffering,
  Object? error,
});
