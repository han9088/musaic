/// Copyright (c) 2026, deskbtm. BSD-3-Clause.
library;

import '../errors/music_kit_error.dart';

/// One variant from the undocumented Apple Music `editorialVideo` attribute.
final class MusicAnimatedArtwork {
  MusicAnimatedArtwork._(this.type, this.videoUrl, this.metadata);

  /// Original variant key, e.g. `motionDetailSquare` or `motionDetailTall`.
  /// Unknown variants are retained rather than assigned a guessed aspect ratio.
  final String type;

  /// Original video URL, normally an HLS master playlist. Never downloaded.
  final String videoUrl;

  /// All supplied variant fields, including any preview/dimension metadata.
  /// No preview URL, dimensions or MIME type are inferred from the variant name.
  final Map<String, dynamic> metadata;

  /// Parses a complete catalog album response. Missing optional video fields
  /// mean no variant; malformed fields throw [MusicKitException].
  static List<MusicAnimatedArtwork> fromApiResponse(Object? response) {
    Never malformed() => throw const MusicKitException(
          MusicKitErrorCode.unknown,
          message: 'Malformed album animated artwork response.',
          details: {'reason': 'invalidResponse'},
        );
    if (response is! Map || response['errors'] != null) malformed();
    final data = response['data'];
    if (data is! List) malformed();
    if (data.isEmpty) {
      throw const MusicKitException(MusicKitErrorCode.resourceNotFound,
          message: 'Catalog album not found.');
    }
    if (data.length != 1 || data.first is! Map) malformed();
    final album = data.first as Map;
    if (album['type'] != 'albums' || album['attributes'] is! Map) malformed();
    final editorial = (album['attributes'] as Map)['editorialVideo'];
    if (editorial == null) return const [];
    if (editorial is! Map) malformed();
    final variants = <MusicAnimatedArtwork>[];
    for (final entry in editorial.entries) {
      if (entry.key is! String) malformed();
      if (entry.value == null) continue;
      if (entry.value is! Map) malformed();
      final fields = entry.value as Map;
      final video = fields['video'];
      if (video == null) continue;
      if (video is! String) malformed();
      final uri = Uri.tryParse(video);
      if (uri == null ||
          uri.scheme != 'https' ||
          uri.host.isEmpty ||
          uri.userInfo.isNotEmpty) {
        malformed();
      }
      variants.add(MusicAnimatedArtwork._(entry.key as String, video,
          _freeze(fields) as Map<String, dynamic>));
    }
    return List.unmodifiable(variants);
  }

  static Object? _freeze(Object? value) {
    if (value is Map) {
      if (value.keys.any((key) => key is! String)) {
        throw const MusicKitException(MusicKitErrorCode.unknown,
            message: 'Malformed animated artwork metadata.',
            details: {'reason': 'invalidResponse'});
      }
      return Map<String, dynamic>.unmodifiable(value.map(
          (key, value) => MapEntry(key as String, _freeze(value))));
    }
    if (value is List) return List<Object?>.unmodifiable(value.map(_freeze));
    return value;
  }
}
