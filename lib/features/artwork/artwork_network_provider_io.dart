import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/widgets.dart';

import 'artwork_network_cache_manager.dart';

/// Uses the shared disk cache for network artwork on dart:io platforms.
ImageProvider<Object> networkArtworkProvider(String url) =>
    CachedNetworkImageProvider(
      url,
      cacheManager: ArtworkNetworkCacheManager.instance,
      cacheKey: url,
    );
