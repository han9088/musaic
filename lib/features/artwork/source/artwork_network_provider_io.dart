// 文件职责：在 IO 平台将网络封面解析为原图缓存文件。

import 'package:flutter/painting.dart';

import '../cache/original_artwork_cache.dart';
import '../model/artwork_identity.dart';

/// 先通过统一原图缓存下载或读取文件，再交给 Flutter FileImage 解码。
Future<ImageProvider<Object>> networkArtworkProvider(
  String url, {
  required String identity,
  ArtworkVersion? version,
}) async {
  final file = await OriginalArtworkCache.instance.getArtworkFile(
    url,
    identity: identity,
    version: version,
  );
  return FileImage(file);
}
