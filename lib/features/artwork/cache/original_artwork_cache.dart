// 文件职责：管理网络原始封面的持久化文件缓存。

import 'dart:convert';
import 'dart:io';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import '../model/artwork_identity.dart';

/// 只缓存网络原图，不保存 Xerox 处理结果。
///
/// 缓存过期、HTTP 校验、下载和文件清理交给 flutter_cache_manager；
/// 上层只通过 getArtworkFile 获取可供 FileImage 使用的文件。
class OriginalArtworkCache extends CacheManager {
  OriginalArtworkCache._()
    : super(
        Config(
          'musaic_original_artwork_v2',
          stalePeriod: const Duration(days: 45),
          maxNrOfCacheObjects: 600,
        ),
      );

  static final instance = OriginalArtworkCache._();

  Future<File> getArtworkFile(
    String url, {
    required String identity,
    ArtworkVersion? version,
  }) async {
    final key = cacheKeyFor(url: url, identity: identity, version: version);
    try {
      return await getSingleFile(url, key: key);
    } catch (_) {
      // 网络刷新失败时允许继续使用过期原图，避免离线状态下封面直接消失。
      try {
        final stale = await getFileFromCache(key);
        if (stale != null) return stale.file;
      } catch (_) {
        // 缓存文件也不可用时，继续抛出原始下载错误。
      }
      rethrow;
    }
  }

  /// 资源身份或版本变化时使用不同缓存项，避免旧图污染新内容。
  static String cacheKeyFor({
    required String url,
    required String identity,
    ArtworkVersion? version,
  }) {
    if (identity == url && version == null) return url;
    var source = url;
    if (identity.startsWith('audius:catalog:')) {
      final uri = Uri.tryParse(url);
      if (uri != null &&
          uri.scheme == 'https' &&
          uri.hasAuthority &&
          _audiusCoverPath.hasMatch(uri.path)) {
        // Audius serves the same content ID and rendition from multiple nodes.
        source = 'audius:${uri.path}${uri.hasQuery ? '?${uri.query}' : ''}';
      }
    }
    final value = jsonEncode([identity, version?.value, source]);
    return base64Url.encode(utf8.encode(value)).replaceAll('=', '');
  }

  static final _audiusCoverPath = RegExp(
    r'^/content/b[a-z2-7]+/[0-9]+x[0-9]+[.][a-zA-Z0-9]+$',
  );
}
