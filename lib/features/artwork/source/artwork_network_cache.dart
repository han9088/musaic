import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// One shared disk cache for original network artwork.
///
/// Keep this manager singleton-scoped: CacheManager instances with the same
/// key must never be created independently.
class ArtworkNetworkCache {
  ArtworkNetworkCache._();

  static const cacheKey = 'musaic_original_artwork_v1';

  static final CacheManager instance = CacheManager(
    Config(
      cacheKey,
      stalePeriod: const Duration(days: 30),
      maxNrOfCacheObjects: 1200,
    ),
  );
}
