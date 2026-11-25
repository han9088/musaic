import 'json_utils.dart';

/// Audius 专辑封面或用户头像的多分辨率图片集合。
class AudiusArtwork {
  const AudiusArtwork({
    this.small,
    this.medium,
    this.large,
  });

  final String? small;
  final String? medium;
  final String? large;

  /// 按中、大、小的顺序返回最适合列表展示的图片。
  String? get best => medium ?? large ?? small;

  factory AudiusArtwork.fromJson(Object? value) {
    if (value is! Map<Object?, Object?>) return const AudiusArtwork();
    final json = requireJsonMap(value, label: 'Audius artwork');
    return AudiusArtwork(
      small: _readString(json, '_150x150') ?? _readString(json, '150x150'),
      medium: _readString(json, '_480x480') ?? _readString(json, '480x480'),
      large: _readString(json, '_1000x1000') ?? _readString(json, '1000x1000'),
    );
  }
}

/// Audius 创作者 / 用户资料。Audius 的 Artist 对应 User。
class AudiusUser {
  const AudiusUser({
    required this.id,
    this.handle,
    this.name,
    this.bio,
    this.location,
    this.website,
    this.isVerified,
    this.isDeactivated,
    this.profilePicture,
    this.coverPhoto,
    this.trackCount,
    this.albumCount,
    this.playlistCount,
    this.followerCount,
    this.followeeCount,
    this.raw = const <String, Object?>{},
  });

  final String id;
  final String? handle;
  final String? name;
  final String? bio;
  final String? location;
  final String? website;
  final bool? isVerified;
  final bool? isDeactivated;
  final AudiusArtwork? profilePicture;
  final AudiusArtwork? coverPhoto;
  final int? trackCount;
  final int? albumCount;
  final int? playlistCount;
  final int? followerCount;
  final int? followeeCount;

  /// 保留 SDK 尚未显式建模的字段，方便上层使用新 API 字段。
  final Map<String, Object?> raw;

  factory AudiusUser.fromJson(Map<String, Object?> json) {
    return AudiusUser(
      id: _readString(json, 'id') ?? '',
      handle: _readString(json, 'handle'),
      name: _readString(json, 'name'),
      bio: _readString(json, 'bio'),
      location: _readString(json, 'location'),
      website: _readString(json, 'website'),
      isVerified: _readBool(json['is_verified'] ?? json['isVerified']),
      isDeactivated: _readBool(
        json['is_deactivated'] ?? json['isDeactivated'],
      ),
      profilePicture: _readArtwork(
        json['profile_picture'] ?? json['profilePicture'],
      ),
      coverPhoto: _readArtwork(json['cover_photo'] ?? json['coverPhoto']),
      trackCount: _readInt(json['track_count'] ?? json['trackCount']),
      albumCount: _readInt(json['album_count'] ?? json['albumCount']),
      playlistCount: _readInt(json['playlist_count'] ?? json['playlistCount']),
      followerCount: _readInt(json['follower_count'] ?? json['followerCount']),
      followeeCount: _readInt(json['followee_count'] ?? json['followeeCount']),
      raw: Map<String, Object?>.unmodifiable(json),
    );
  }
}

/// Audius 音轨元数据。
class AudiusTrack {
  const AudiusTrack({
    required this.id,
    required this.title,
    this.description,
    this.duration,
    this.genre,
    this.mood,
    this.tags = const <String>[],
    this.permalink,
    this.artwork,
    this.user,
    this.playCount,
    this.favoriteCount,
    this.repostCount,
    this.isStreamable,
    this.isDownloadable,
    this.isStreamGated,
    this.releaseDate,
    this.license,
    this.raw = const <String, Object?>{},
  });

  final String id;
  final String title;
  final String? description;
  final num? duration;
  final String? genre;
  final String? mood;
  final List<String> tags;
  final String? permalink;
  final AudiusArtwork? artwork;
  final AudiusUser? user;
  final int? playCount;
  final int? favoriteCount;
  final int? repostCount;
  final bool? isStreamable;
  final bool? isDownloadable;
  final bool? isStreamGated;
  final DateTime? releaseDate;
  final String? license;

  /// 保留原始 JSON，避免 API 新增字段时丢失信息。
  final Map<String, Object?> raw;

  factory AudiusTrack.fromJson(Map<String, Object?> json) {
    final userValue = json['user'];
    final user = userValue is Map<Object?, Object?>
        ? AudiusUser.fromJson(requireJsonMap(userValue, label: 'track user'))
        : null;
    final releaseDate =
        _readString(json, 'release_date') ?? _readString(json, 'releaseDate');

    return AudiusTrack(
      id: _readString(json, 'id') ?? '',
      title: _readString(json, 'title') ?? '',
      description: _readString(json, 'description'),
      duration: _readNum(json['duration']),
      genre: _readString(json, 'genre'),
      mood: _readString(json, 'mood'),
      tags: _readStringList(json['tags']),
      permalink: _readString(json, 'permalink'),
      artwork: _readArtwork(
        json['artwork'] ?? json['cover_art_sizes'] ?? json['coverArtSizes'],
      ),
      user: user,
      playCount: _readInt(json['play_count'] ?? json['playCount']),
      favoriteCount: _readInt(json['favorite_count'] ?? json['favoriteCount']),
      repostCount: _readInt(json['repost_count'] ?? json['repostCount']),
      isStreamable: _readBool(json['is_streamable'] ?? json['isStreamable']),
      isDownloadable: _readBool(
        json['is_downloadable'] ??
            json['downloadable'] ??
            json['isDownloadable'],
      ),
      isStreamGated: _readBool(
        json['is_stream_gated'] ?? json['isStreamGated'],
      ),
      releaseDate: releaseDate == null ? null : DateTime.tryParse(releaseDate),
      license: _readString(json, 'license'),
      raw: Map<String, Object?>.unmodifiable(json),
    );
  }
}

/// Audius 歌单。专辑在 Audius API 中也是 Playlist，isAlbum 为 true。
class AudiusPlaylist {
  const AudiusPlaylist({
    required this.id,
    this.playlistName,
    this.description,
    this.permalink,
    this.artwork,
    this.user,
    this.trackCount,
    this.totalPlayCount,
    this.isAlbum,
    this.tracks = const <AudiusTrack>[],
    this.raw = const <String, Object?>{},
  });

  final String id;
  final String? playlistName;
  final String? description;
  final String? permalink;
  final AudiusArtwork? artwork;
  final AudiusUser? user;
  final int? trackCount;
  final int? totalPlayCount;
  final bool? isAlbum;
  final List<AudiusTrack> tracks;
  final Map<String, Object?> raw;

  factory AudiusPlaylist.fromJson(Map<String, Object?> json) {
    final userValue = json['user'];
    final user = userValue is Map<Object?, Object?>
        ? AudiusUser.fromJson(
            requireJsonMap(userValue, label: 'playlist user'),
          )
        : null;
    final trackValue = json['tracks'];
    final tracks = trackValue is List<Object?>
        ? decodeJsonList(trackValue, AudiusTrack.fromJson, label: 'tracks')
        : const <AudiusTrack>[];

    return AudiusPlaylist(
      id: _readString(json, 'id') ?? '',
      playlistName:
          _readString(json, 'playlist_name') ?? _readString(json, 'playlistName'),
      description: _readString(json, 'description'),
      permalink: _readString(json, 'permalink'),
      artwork: _readArtwork(
        json['artwork'] ??
            json['cover_art_sizes'] ??
            json['coverArtSizes'] ??
            json['cover_art'],
      ),
      user: user,
      trackCount: _readInt(json['track_count'] ?? json['trackCount']),
      totalPlayCount: _readInt(
        json['total_play_count'] ?? json['totalPlayCount'],
      ),
      isAlbum: _readBool(json['is_album'] ?? json['isAlbum']),
      tracks: tracks,
      raw: Map<String, Object?>.unmodifiable(json),
    );
  }
}

enum AudiusResolvedResourceType {
  track,
  playlist,
}

/// resolve API 返回的歌曲或歌单/专辑资源。
class AudiusResolvedResource {
  const AudiusResolvedResource._({
    required this.type,
    this.track,
    this.playlist,
    required this.raw,
  });

  final AudiusResolvedResourceType type;
  final AudiusTrack? track;
  final AudiusPlaylist? playlist;
  final Map<String, Object?> raw;

  factory AudiusResolvedResource.fromJson(Map<String, Object?> json) {
    final isPlaylist = json.containsKey('playlist_name') ||
        json.containsKey('playlistName') ||
        json.containsKey('playlist_contents') ||
        _readBool(json['is_album'] ?? json['isAlbum']) == true;

    if (isPlaylist) {
      return AudiusResolvedResource._(
        type: AudiusResolvedResourceType.playlist,
        playlist: AudiusPlaylist.fromJson(json),
        raw: Map<String, Object?>.unmodifiable(json),
      );
    }

    return AudiusResolvedResource._(
      type: AudiusResolvedResourceType.track,
      track: AudiusTrack.fromJson(json),
      raw: Map<String, Object?>.unmodifiable(json),
    );
  }
}

AudiusArtwork? _readArtwork(Object? value) {
  if (value is Map<Object?, Object?>) {
    return AudiusArtwork.fromJson(value);
  }
  return null;
}

String? _readString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is String) return value;
  if (value is num || value is bool) return value.toString();
  return null;
}

num? _readNum(Object? value) {
  if (value is num) return value;
  if (value is String) return num.tryParse(value);
  return null;
}

int? _readInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.round();
  if (value is String) return int.tryParse(value);
  return null;
}

bool? _readBool(Object? value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    switch (value.toLowerCase()) {
      case 'true':
      case '1':
        return true;
      case 'false':
      case '0':
        return false;
    }
  }
  return null;
}

List<String> _readStringList(Object? value) {
  if (value is List<Object?>) {
    return List<String>.unmodifiable(
      value.whereType<String>().where((item) => item.isNotEmpty),
    );
  }
  if (value is String && value.isNotEmpty) {
    return List<String>.unmodifiable(
      value
          .split(',')
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty),
    );
  }
  return const <String>[];
}
