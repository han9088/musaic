/// Copyright (c) 2026, deskbtm. BSD-3-Clause.
library;

import 'artwork.dart';
import 'music_item_ref.dart';

/// A song in the Apple Music catalog or the user's library.
final class MusicSong {
  /// Creates a song model.
  const MusicSong({
    required this.id,
    required this.title,
    this.artistName,
    this.artistId,
    this.albumTitle,
    this.albumId,
    this.artwork,
    this.duration,
    this.trackNumber,
    this.discNumber,
    this.isExplicit = false,
    this.isPlayable = false,
    this.url,
    this.previewUrl,
    this.genreNames = const [],
    this.releaseDate,
    this.composerName,
    this.isrc,
    this.source = MusicItemSource.catalog,
    this.storefront,
    this.raw,
  });

  /// Deserializes from an Apple Music API song resource (attributes merged).
  factory MusicSong.fromApiJson(Map<String, dynamic> json,
      {MusicItemSource source = MusicItemSource.catalog}) {
    final attrs = (json['attributes'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};
    final durationMs = attrs['durationInMillis'] as int?;
    return MusicSong(
      id: json['id'] as String? ?? '',
      title: attrs['name'] as String? ?? '',
      artistName: attrs['artistName'] as String?,
      artistId: _idFromHref(attrs['artistUrl'] as String?),
      albumTitle: attrs['albumName'] as String?,
      albumId: _idFromHref(attrs['albumUrl'] as String?),
      artwork: MusicArtwork.fromJson(attrs['artwork'] as Map<String, dynamic>?),
      duration: durationMs == null ? null : Duration(milliseconds: durationMs),
      trackNumber: attrs['trackNumber'] as int?,
      discNumber: attrs['discNumber'] as int?,
      isExplicit: attrs['contentRating'] == 'explicit',
      isPlayable: attrs['playParams'] != null,
      url: attrs['url'] as String?,
      previewUrl: (attrs['previews'] as List<dynamic>?)
          ?.cast<Map<String, dynamic>>()
          .firstOrNull?['url'] as String?,
      genreNames:
          ((attrs['genreNames'] as List<dynamic>?) ?? const []).cast<String>(),
      releaseDate: attrs['releaseDate'] as String?,
      composerName: attrs['composerName'] as String?,
      isrc: attrs['isrc'] as String?,
      source: source,
      storefront: _storefrontFromHref(json['href'] as String?),
      raw: json,
    );
  }

  static String? _idFromHref(String? href) {
    if (href == null) return null;
    final segs = Uri.parse(href).pathSegments;
    return segs.isEmpty ? null : segs.last;
  }

  static String? _storefrontFromHref(String? href) {
    if (href == null) return null;
    final segs = Uri.parse(href).pathSegments;
    final i = segs.indexOf('catalog');
    return (i >= 0 && i + 1 < segs.length) ? segs[i + 1] : null;
  }

  /// The resource id within [source].
  final String id;

  /// Localized track title.
  final String title;

  /// Primary artist display name.
  final String? artistName;

  /// Catalog artist id, when derivable.
  final String? artistId;

  /// Album title.
  final String? albumTitle;

  /// Album id, when derivable.
  final String? albumId;

  /// Cover artwork.
  final MusicArtwork? artwork;

  /// Total duration; null when unknown (do not fake zero).
  final Duration? duration;

  /// 1-based track number on its disc.
  final int? trackNumber;

  /// 1-based disc number.
  final int? discNumber;

  /// Whether the content is rated explicit.
  final bool isExplicit;

  /// Whether the song exposes playback parameters (playable for this user).
  final bool isPlayable;

  /// Apple Music web URL.
  final String? url;

  /// Preview-only stream URL (30s clip), when exposed.
  final String? previewUrl;

  /// Genre names as localized strings.
  final List<String> genreNames;

  /// ISO-8601 release date, when reported.
  final String? releaseDate;

  /// Composer name, when reported.
  final String? composerName;

  /// International Standard Recording Code, when reported.
  final String? isrc;

  /// Whether [id] addresses the catalog or the user library.
  final MusicItemSource source;

  /// Storefront this resource was fetched from, when known.
  final String? storefront;

  /// The original API resource, retained for forward compatibility.
  final Map<String, dynamic>? raw;

  /// A lightweight reference to this song.
  MusicItemRef get ref => MusicItemRef(
      id: id,
      type: MusicResourceType.song,
      source: source,
      storefront: storefront);

  @override
  bool operator ==(Object other) =>
      other is MusicSong && other.id == id && other.source == source;

  @override
  int get hashCode => Object.hash(id, source);

  @override
  String toString() => 'MusicSong($id, $title)';
}

/// An album in the Apple Music catalog or the user's library.
final class MusicAlbum {
  /// Creates an album model.
  const MusicAlbum({
    required this.id,
    required this.title,
    this.artistName,
    this.artistId,
    this.artwork,
    this.trackCount,
    this.releaseDate,
    this.genreNames = const [],
    this.isMaster = true,
    this.isComplete,
    this.copyright,
    this.recordLabel,
    this.playable,
    this.url,
    this.source = MusicItemSource.catalog,
    this.storefront,
    this.tracks,
  });

  /// Deserializes from an Apple Music API album resource.
  factory MusicAlbum.fromApiJson(Map<String, dynamic> json,
      {MusicItemSource source = MusicItemSource.catalog}) {
    final attrs = (json['attributes'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};
    return MusicAlbum(
      id: json['id'] as String? ?? '',
      title: attrs['name'] as String? ?? '',
      artistName: attrs['artistName'] as String?,
      artistId: _idFromHref(attrs['artistUrl'] as String?),
      artwork: MusicArtwork.fromJson(attrs['artwork'] as Map<String, dynamic>?),
      trackCount: attrs['trackCount'] as int?,
      releaseDate: attrs['releaseDate'] as String?,
      genreNames:
          ((attrs['genreNames'] as List<dynamic>?) ?? const []).cast<String>(),
      isMaster: attrs['isMaster'] != false,
      isComplete: attrs['isComplete'] as bool?,
      copyright: attrs['copyright'] as String?,
      recordLabel: attrs['recordLabel'] as String?,
      playable: attrs['playParams'] != null,
      url: attrs['url'] as String?,
      source: source,
      tracks: _tracksFromJson(
          (json['relationships'] as Map?)?['tracks'] ?? json['tracks']),
    );
  }

  /// Parses `relationships.tracks.data` into song models, when present.
  static List<MusicSong>? _tracksFromJson(Object? tracks) {
    if (tracks is! Map<String, dynamic>) return null;
    final data = tracks['data'] as List<dynamic>?;
    if (data == null) return null;
    return data
        .cast<Map<String, dynamic>>()
        .map(MusicSong.fromApiJson)
        .toList(growable: false);
  }

  static String? _idFromHref(String? href) {
    if (href == null) return null;
    final segs = Uri.parse(href).pathSegments;
    return segs.isEmpty ? null : segs.last;
  }

  /// The resource id within [source].
  final String id;

  /// Localized album title.
  final String title;

  /// Primary artist display name.
  final String? artistName;

  /// Artist catalog id, when derivable.
  final String? artistId;

  /// Cover artwork.
  final MusicArtwork? artwork;

  /// Number of tracks, when reported.
  final int? trackCount;

  /// ISO-8601 release date.
  final String? releaseDate;

  /// Genre names.
  final List<String> genreNames;

  /// Whether this is the "master" release vs a rerelease.
  final bool isMaster;

  /// Whether the album is complete (not a partial "single" extraction).
  final bool? isComplete;

  /// Copyright line.
  final String? copyright;

  /// Record label.
  final String? recordLabel;

  /// Whether the album is playable for this user.
  final bool? playable;

  /// Apple Music web URL.
  final String? url;

  /// Whether [id] addresses the catalog or the user library.
  final MusicItemSource source;

  /// Storefront this resource was fetched from.
  final String? storefront;

  /// The album's tracks, when requested via `includeTracks`.
  final List<MusicSong>? tracks;

  /// A lightweight reference to this album.
  MusicItemRef get ref => MusicItemRef(
      id: id,
      type: MusicResourceType.album,
      source: source,
      storefront: storefront);

  @override
  bool operator ==(Object other) =>
      other is MusicAlbum && other.id == id && other.source == source;

  @override
  int get hashCode => Object.hash(id, source);

  @override
  String toString() => 'MusicAlbum($id, $title)';
}

/// An artist in the Apple Music catalog.
final class MusicArtist {
  /// Creates an artist model.
  const MusicArtist({
    required this.id,
    required this.name,
    this.genreNames = const [],
    this.url,
    this.artwork,
    this.editorialNotes,
  });

  /// Deserializes from an Apple Music API artist resource.
  factory MusicArtist.fromApiJson(Map<String, dynamic> json) {
    final attrs = (json['attributes'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};
    return MusicArtist(
      id: json['id'] as String? ?? '',
      name: attrs['name'] as String? ?? '',
      genreNames:
          ((attrs['genreNames'] as List<dynamic>?) ?? const []).cast<String>(),
      url: attrs['url'] as String?,
      artwork: MusicArtwork.fromJson(attrs['artwork'] as Map<String, dynamic>?),
      editorialNotes: (attrs['editorialNotes']
          as Map<String, dynamic>?)?['standard'] as String?,
    );
  }

  /// The catalog artist id.
  final String id;

  /// Display name.
  final String name;

  /// Genre names.
  final List<String> genreNames;

  /// Apple Music web URL.
  final String? url;

  /// Artist artwork, when present.
  final MusicArtwork? artwork;

  /// Editorial note text, when present.
  final String? editorialNotes;

  /// A lightweight reference to this artist.
  MusicItemRef get ref => MusicItemRef(id: id, type: MusicResourceType.artist);

  @override
  bool operator ==(Object other) => other is MusicArtist && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'MusicArtist($id, $name)';
}

/// A playlist — catalog (featured) or user library owned.
final class MusicPlaylist {
  /// Creates a playlist model.
  const MusicPlaylist({
    required this.id,
    required this.name,
    this.curatorName,
    this.artwork,
    this.trackCount,
    this.lastModifiedDate,
    this.playlists,
    this.url,
    this.description,
    this.isChart = false,
    this.source = MusicItemSource.catalog,
    this.tracks,
  });

  /// Deserializes from an Apple Music API playlist resource.
  factory MusicPlaylist.fromApiJson(Map<String, dynamic> json,
      {MusicItemSource source = MusicItemSource.catalog}) {
    final attrs = (json['attributes'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};
    return MusicPlaylist(
      id: json['id'] as String? ?? '',
      name: attrs['name'] as String? ?? '',
      curatorName: attrs['curatorName'] as String?,
      artwork: MusicArtwork.fromJson(attrs['artwork'] as Map<String, dynamic>?),
      trackCount: (attrs['trackTypes'] as List<dynamic>?)?.length,
      lastModifiedDate: attrs['lastModifiedDate'] as String?,
      playlists: attrs['playlists'] as String?,
      url: attrs['url'] as String?,
      description: (attrs['description'] as Map<String, dynamic>?)?['standard']
          as String?,
      isChart: json['type'] == 'charts',
      source: source,
      tracks: _tracksFromJson(
          (json['relationships'] as Map?)?['tracks'] ?? json['tracks']),
    );
  }

  /// Parses `relationships.tracks.data` into song models, when present.
  static List<MusicSong>? _tracksFromJson(Object? tracks) {
    if (tracks is! Map<String, dynamic>) return null;
    final data = tracks['data'] as List<dynamic>?;
    if (data == null) return null;
    return data
        .cast<Map<String, dynamic>>()
        .map(MusicSong.fromApiJson)
        .toList(growable: false);
  }

  /// The resource id within [source].
  final String id;

  /// Playlist name / title.
  final String name;

  /// Curator display name.
  final String? curatorName;

  /// Cover artwork.
  final MusicArtwork? artwork;

  /// Number of tracks, when derivable.
  final int? trackCount;

  /// ISO-8601 last modification date (library playlists).
  final String? lastModifiedDate;

  /// `playlists` attribute string (chart playlists).
  final String? playlists;

  /// Apple Music web URL.
  final String? url;

  /// Standard description text.
  final String? description;

  /// Whether this resource is a chart (returned by getCharts).
  final bool isChart;

  /// Whether [id] addresses the catalog or the user library.
  final MusicItemSource source;

  /// The playlist's tracks, when requested via `includeTracks`.
  final List<MusicSong>? tracks;

  /// A lightweight reference to this playlist.
  MusicItemRef get ref =>
      MusicItemRef(id: id, type: MusicResourceType.playlist, source: source);

  @override
  bool operator ==(Object other) =>
      other is MusicPlaylist && other.id == id && other.source == source;

  @override
  int get hashCode => Object.hash(id, source);

  @override
  String toString() => 'MusicPlaylist($id, $name)';
}
