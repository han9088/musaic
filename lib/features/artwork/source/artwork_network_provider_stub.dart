// 文件职责：为非 IO 平台提供网络图片加载回退。

import 'package:flutter/widgets.dart';

import '../model/artwork_identity.dart';

/// Web 等非 IO 平台使用 Flutter NetworkImage；平台自身负责运行时资源缓存。
Future<ImageProvider<Object>> networkArtworkProvider(
  String url, {
  required String identity,
  ArtworkVersion? version,
}) async => NetworkImage(url);
