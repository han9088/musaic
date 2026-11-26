/// Copyright (c) 2026, deskbtm. BSD-3-Clause.
library;

import 'page.dart';
import 'resource_models.dart';

/// Chart types supported by the Apple Music `getCharts` endpoints.
enum MusicChartKind {
  /// Most-played songs.
  songs,

  /// Most-played albums.
  albums,

  /// Most-played music videos.
  musicVideos;
}

/// The result of a catalog search.
///
/// Each requested resource type gets its own page of results, mirroring the
/// Apple Music API response shape.
final class MusicSearchResult {
  /// Creates a search result bundle.
  const MusicSearchResult(
      {this.songs, this.albums, this.artists, this.playlists});

  /// Song results.
  final MusicPage<MusicSong>? songs;

  /// Album results.
  final MusicPage<MusicAlbum>? albums;

  /// Artist results.
  final MusicPage<MusicArtist>? artists;

  /// Playlist results.
  final MusicPage<MusicPlaylist>? playlists;
}

/// Storefront info for the current user.
final class MusicStorefront {
  /// Creates a storefront model.
  const MusicStorefront(
      {required this.id, required this.name, this.defaultLanguageTag});

  /// Deserializes from an Apple Music API storefront resource.
  factory MusicStorefront.fromApiJson(Map<String, dynamic> json) {
    final attrs = (json['attributes'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};
    return MusicStorefront(
      id: json['id'] as String? ?? '',
      name: attrs['name'] as String? ?? '',
      defaultLanguageTag: attrs['defaultLanguageTag'] as String?,
    );
  }

  /// The storefront id, an ISO 3166-1 alpha-2 code like `US`.
  final String id;

  /// Localized storefront display name.
  final String name;

  /// Default language tag like `en-US`.
  final String? defaultLanguageTag;

  @override
  bool operator ==(Object other) => other is MusicStorefront && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// The charts of one [MusicChartKind].
final class MusicChart {
  /// Creates a chart.
  const MusicChart(
      {required this.kind, required this.name, this.songs, this.albums});

  /// Which chart kind this is.
  final MusicChartKind kind;

  /// Chart display name (e.g. "Top Songs").
  final String name;

  /// Songs on the chart, for [MusicChartKind.songs].
  final MusicPage<MusicSong>? songs;

  /// Albums on the chart, for [MusicChartKind.albums].
  final MusicPage<MusicAlbum>? albums;
}
