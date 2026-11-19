// 文件职责：专辑封面来源解析、图片解码、缓存及 Xerox 处理。

import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// 封装或定义封面图网络缓存管理器相关类型与行为，负责专辑封面来源解析、图片解码、缓存及 Xerox 处理。
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
