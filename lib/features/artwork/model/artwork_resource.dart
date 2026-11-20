// 文件职责：描述 Artwork Pipeline 已解析、可供渲染层消费的图片资源。

import 'package:flutter/painting.dart';

/// 已解析的图片资源。渲染层只接收该对象，不再关心 URL、目录或缓存实现。
class ArtworkResource {
  const ArtworkResource({
    required this.identity,
    required this.sourceKey,
    required this.image,
  });

  /// 逻辑专辑封面的稳定身份。
  final String identity;

  /// 内容来源及版本身份；用于区分 Xerox 处理结果。
  final String sourceKey;

  /// 已经解析完成的图片提供器。
  final ImageProvider<Object> image;
}
