// 文件职责：专辑封面来源解析、图片解码、缓存及 Xerox 处理。

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/widgets.dart';

import 'artwork_network_cache_manager.dart';

/// 执行当前模块中的网络封面图提供器操作，用于专辑封面来源解析、图片解码、缓存及 Xerox 处理。
ImageProvider<Object> networkArtworkProvider(String url) =>
    CachedNetworkImageProvider(
      url,
      cacheManager: ArtworkNetworkCacheManager.instance,
      cacheKey: url,
    );
