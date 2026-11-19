// 文件职责：为非 IO 平台提供不依赖本地磁盘缓存的网络图片加载方式。

import 'package:flutter/widgets.dart';

import '../model/artwork_identity.dart';

ImageProvider<Object> networkArtworkProvider(
  String url, {
  required String identity,
  ArtworkVersion? version,
}) => NetworkImage(url);
