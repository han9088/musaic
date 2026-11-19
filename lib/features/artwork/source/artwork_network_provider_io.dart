// 文件职责：在 IO 平台创建带独立磁盘缓存的网络封面提供器。

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/widgets.dart';

import '../cache/artwork_network_cache_manager.dart';
import '../model/artwork_identity.dart';

ImageProvider<Object> networkArtworkProvider(
  String url, {
  required String identity,
  ArtworkVersion? version,
}) => CachedNetworkImageProvider(
  url,
  cacheManager: ArtworkNetworkCacheManager.instance,
  cacheKey: ArtworkNetworkCacheManager.cacheKeyFor(
    url: url,
    identity: identity,
    version: version,
  ),
);
