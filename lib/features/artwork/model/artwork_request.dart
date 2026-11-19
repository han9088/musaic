// 文件职责：描述一次专辑封面资源请求及其显示约束。

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'artwork_identity.dart';

/// Artwork 各层共享的请求对象，避免来源、身份、版本和显示参数分散传递。
@immutable
class ArtworkRequest {
  const ArtworkRequest({
    required this.source,
    this.identity,
    this.version,
    this.targetSize,
    this.devicePixelRatio = 1,
    this.fit = BoxFit.cover,
  });

  /// Asset 路径、网络 URL 或 directory: 曲目引用。
  final String source;

  /// 同一逻辑封面在不同布局中的稳定身份。
  final ArtworkIdentity? identity;

  /// 上游可提供时，用于使原图与 Xerox 缓存主动失效的版本标记。
  final ArtworkVersion? version;

  /// 目标逻辑尺寸；解码层会结合 DPR 选择离散 LOD。
  final Size? targetSize;

  final double devicePixelRatio;
  final BoxFit fit;
}
