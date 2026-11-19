import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Shared persistent cache for original network artwork.
///
/// The URL is also the cache key for now. When Apple Music catalog mapping
/// exposes a stable artwork revision, include that revision in this key.
/// Owns the disk cache for downloaded original artwork, separate from Xerox
/// raster storage. Keep this as a singleton: CacheManager keys identify dirs.
class ArtworkNetworkCacheManager extends CacheManager {
  ArtworkNetworkCacheManager._()
    : super(
        Config(
          'musaic_original_artwork_v1',
          stalePeriod: const Duration(days: 45),
          maxNrOfCacheObjects: 600,
        ),
      );

  /// Shared manager prevents multiple instances racing over the same cache.
  static final instance = ArtworkNetworkCacheManager._();
}
