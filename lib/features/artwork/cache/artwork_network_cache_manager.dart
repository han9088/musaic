// 文件职责：管理网络原始专辑封面的独立磁盘缓存。

import 'dart:convert';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import '../model/artwork_identity.dart';

/// 网络原图缓存与 Xerox 处理结果缓存相互独立，避免两类资源共用缓存空间。
class ArtworkNetworkCacheManager extends CacheManager {
  ArtworkNetworkCacheManager._()
    : super(
        Config(
          'musaic_original_artwork_v2',
          stalePeriod: const Duration(days: 45),
          maxNrOfCacheObjects: 600,
        ),
      );

  static final instance = ArtworkNetworkCacheManager._();

  /// 生成稳定的网络缓存键；提供版本信息时，版本变化会自然产生新的缓存项。
  ///
  /// 未提供独立身份和版本时沿用 URL 作为缓存键，兼容已有网络缓存。
  static String cacheKeyFor({
    required String url,
    required String identity,
    ArtworkVersion? version,
  }) {
    if (identity == url && version == null) return url;
    final value = jsonEncode([identity, version?.value, url]);
    return base64Url.encode(utf8.encode(value)).replaceAll('=', '');
  }
}
