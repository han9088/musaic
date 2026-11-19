import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/widgets.dart';

import 'artwork_network_cache_manager.dart';

/// Resolves Demo assets, Apple Music URLs and local-file providers consistently.
class ArtworkImageResolver {
  const ArtworkImageResolver._();

  static ImageProvider<Object>? resolve(String source) {
    final uri = Uri.tryParse(source);
    if (uri != null &&
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.host.isNotEmpty) {
      return CachedNetworkImageProvider(
        source,
        cacheManager: ArtworkNetworkCacheManager.instance,
        cacheKey: source,
      );
    }

    if (source.startsWith('local:') || source.startsWith('directory:')) {
      return null;
    }

    return AssetImage(source);
  }
}
