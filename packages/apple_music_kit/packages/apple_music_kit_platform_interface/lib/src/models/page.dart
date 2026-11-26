/// Copyright (c) 2026, deskbtm. BSD-3-Clause.
library;

/// A page of results from an Apple Music API list response.
///
/// The Apple Music API paginates with a `next` offset link; [nextOffset]
/// is the parse of that link's `offset` query parameter, when present.
final class MusicPage<T> {
  /// Creates a page.
  const MusicPage({required this.items, this.nextOffset});

  /// A page with no items and no continuation.
  const MusicPage.empty()
      : items = const [],
        nextOffset = null;

  /// The items on this page.
  final List<T> items;

  /// The `offset` query value of the API `next` link, or null when there is
  /// no next page.
  ///
  /// Feed this back to the originating call to fetch the next page.
  final int? nextOffset;

  /// Whether more pages exist.
  bool get hasMore => nextOffset != null;

  /// Parses `data` + `next` from an Apple Music API document.
  static MusicPage<T> fromApiJson<T>(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) convert,
  ) {
    final data = ((json['data'] as List<dynamic>?) ?? const [])
        .cast<Map<String, dynamic>>();
    return MusicPage<T>(
      items: data.map(convert).toList(growable: false),
      nextOffset: _nextOffset(json['next'] as String?),
    );
  }

  static int? _nextOffset(String? next) {
    if (next == null) return null;
    final offset = Uri.parse(next).queryParameters['offset'];
    return offset == null ? null : int.tryParse(offset);
  }

  @override
  String toString() =>
      'MusicPage(${items.length} items, nextOffset: $nextOffset)';
}
