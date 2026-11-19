import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Shared persistent cache for original network artwork.
///
/// The URL is also the cache key for now. When Apple Music catalog mapping
/// exposes a stable artwork revision, include that revision in this key.
class ArtworkNetworkCacheManager extends CacheManager {
  ArtworkNetworkCacheManager._()
    : super(
        Config(
          'musaic_original_artwork_v1',
          stalePeriod: const Duration(days: 45),
          maxNrOfCacheObjects: 600,
        ),
      );

  static final instance = ArtworkNetworkCacheManager._();
}
