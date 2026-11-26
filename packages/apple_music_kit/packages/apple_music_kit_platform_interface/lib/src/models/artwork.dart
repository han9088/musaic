/// Copyright (c) 2026, deskbtm. BSD-3-Clause.
library;

import 'dart:math' as math;

/// Raw Apple Music artwork descriptor returned by the catalog/library APIs.
///
/// The Apple Music API returns artwork as a URL template containing a
/// `{w}` and `{h}` placeholder, e.g.
/// `https://is1-ssz.mzstatic.com/image/.../{w}x{h}bb.jpg`.
/// Callers materialize concrete sizes via [url].
final class MusicArtwork {
  /// Creates an artwork descriptor.
  const MusicArtwork({
    required this.templateUrl,
    this.width,
    this.height,
    this.primaryColorHex,
  });

  /// The raw artwork URL template containing `{w}` and `{h}` placeholders.
  ///
  /// May be empty when a resource has no artwork; [url] then returns null.
  final String templateUrl;

  /// Native width of the source artwork in pixels, when reported.
  final int? width;

  /// Native height of the source artwork in pixels, when reported.
  final int? height;

  /// Primary dominant color as a hex string like `#A1B2C3`, when reported.
  final String? primaryColorHex;

  /// Builds a concrete artwork URL for [size] x [size] pixels, or null when
  /// the resource has no artwork.
  ///
  /// Apple requires square dimensions for the template substitution; the
  /// returned URL uses the `{w}x{h}bb.jpg` convention where `bb` keeps the
  /// image inside the requested bounds.
  String? url({int size = 512}) => templateUrl.isEmpty
      ? null
      : templateUrl.replaceFirst('{w}', '$size').replaceFirst('{h}', '$size');

  /// Builds an artwork URL fitting inside [maxWidth] x [maxHeight].
  String? urlFitted({required int maxWidth, required int maxHeight}) {
    if (templateUrl.isEmpty) return null;
    // Preserve aspect ratio within the bounding box.
    final w = width;
    final h = height;
    int outW = maxWidth;
    int outH = maxHeight;
    if (w != null && h != null && w > 0 && h > 0) {
      final scale = math.min(maxWidth / w, maxHeight / h);
      outW = math.max(1, (w * scale).round());
      outH = math.max(1, (h * scale).round());
    }
    return templateUrl
        .replaceFirst('{w}', '$outW')
        .replaceFirst('{h}', '$outH');
  }

  /// Deserializes from the Apple Music API `attributes.artwork` object.
  static MusicArtwork? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final url = json['url'] as String?;
    if (url == null) return null;
    return MusicArtwork(
      templateUrl: url,
      width: json['width'] as int?,
      height: json['height'] as int?,
      primaryColorHex: json['bgColor'] as String?,
    );
  }

  /// Serializes for platform-channel transport.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'url': templateUrl,
        if (width != null) 'width': width,
        if (height != null) 'height': height,
        if (primaryColorHex != null) 'bgColor': primaryColorHex,
      };

  @override
  bool operator ==(Object other) =>
      other is MusicArtwork &&
      other.templateUrl == templateUrl &&
      other.width == width &&
      other.height == height;

  @override
  int get hashCode => Object.hash(templateUrl, width, height);

  @override
  String toString() => 'MusicArtwork($templateUrl)';
}
