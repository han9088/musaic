/// Copyright (c) 2026, deskbtm. BSD-3-Clause.
library;

/// Identifies which Apple Music space a resource belongs to.
///
/// Catalog IDs and library IDs are **not** interchangeable: a song in the
/// global catalog (`i.abcdef`) and the user's personal library copy
/// (`i.abcdef` with a library id like `p.XYZ`) use distinct identifiers.
enum MusicItemSource {
  /// The global Apple Music catalog for a storefront.
  catalog,

  /// The signed-in user's personal iCloud Music Library.
  library;

  /// Deserializes from the transport representation.
  static MusicItemSource fromName(String name) =>
      name == 'library' ? MusicItemSource.library : MusicItemSource.catalog;

  /// Serializes for the transport representation.
  String get name => this == MusicItemSource.library ? 'library' : 'catalog';
}

/// The Apple Music resource types the plugin understands.
enum MusicResourceType {
  song('songs'),
  album('albums'),
  artist('artists'),
  playlist('playlists'),
  station('stations');

  const MusicResourceType(this.wireName);

  /// The name used by the Apple Music API URL path, e.g. `songs`.
  final String wireName;

  /// Deserializes from an Apple Music API `type` string.
  static MusicResourceType? fromWireName(String? name) {
    if (name == null) return null;
    for (final t in MusicResourceType.values) {
      if (t.wireName == name) return t;
    }
    return null;
  }
}

/// A stable, lightweight reference to an Apple Music resource.
///
/// Use this to build player queues and request detail fetches without
/// carrying full model objects around. Always include the [source] so the
/// correct API surface (catalog vs library) is used.
final class MusicItemRef {
  /// Creates a resource reference.
  const MusicItemRef({
    required this.id,
    required this.type,
    this.source = MusicItemSource.catalog,
    this.storefront,
  });

  /// Parses an Apple Music API `href` (e.g.
  /// `https://api.music.apple.com/v1/catalog/us/songs/1440843637`) into a ref.
  ///
  /// Returns a ref with an empty [id] when the URL cannot be understood.
  factory MusicItemRef.fromUrl(String url) {
    final segments = Uri.parse(url).pathSegments;
    if (segments.length < 2) {
      return const MusicItemRef(id: '', type: MusicResourceType.song);
    }
    final id = segments.last;
    final type = MusicResourceType.fromWireName(segments[segments.length - 2]);
    if (type == null || id.isEmpty) {
      return const MusicItemRef(id: '', type: MusicResourceType.song);
    }
    // /v1/catalog/{storefront}/{type}/{id} or /v1/me/{type}/{id} (library).
    final isLibrary = segments.contains('library') ||
        (segments.length >= 2 && segments[segments.length - 3] == 'me');
    String? storefront;
    final catalogIndex = segments.indexOf('catalog');
    if (catalogIndex >= 0 && catalogIndex + 1 < segments.length - 2) {
      storefront = segments[catalogIndex + 1];
    }
    return MusicItemRef(
      id: id,
      type: type,
      source: isLibrary ? MusicItemSource.library : MusicItemSource.catalog,
      storefront: storefront,
    );
  }

  /// The resource identifier within [source].
  final String id;

  /// The resource type.
  final MusicResourceType type;

  /// Whether the id addresses the catalog or the user's library.
  final MusicItemSource source;

  /// The storefront (ISO code like `us`) this id was obtained from, if known.
  ///
  /// Apple Music catalog ids are storefront-scoped; the same catalog track
  /// may have different ids in different storefronts.
  final String? storefront;

  /// Serializes for transport.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'type': type.wireName,
        'source': source.name,
        if (storefront != null) 'storefront': storefront,
      };

  /// Deserializes from transport.
  static MusicItemRef fromJson(Map<String, dynamic> json) => MusicItemRef(
        id: json['id'] as String? ?? '',
        type: MusicResourceType.fromWireName(json['type'] as String?) ??
            MusicResourceType.song,
        source:
            MusicItemSource.fromName(json['source'] as String? ?? 'catalog'),
        storefront: json['storefront'] as String?,
      );

  @override
  bool operator ==(Object other) =>
      other is MusicItemRef &&
      other.id == id &&
      other.type == type &&
      other.source == source;

  @override
  int get hashCode => Object.hash(id, type, source);

  @override
  String toString() => 'MusicItemRef($source/${type.wireName}/$id)';
}
