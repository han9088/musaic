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
    this.fixedResolution,
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

  /// 固定解码和 Xerox 位图的像素尺寸，适用于可连续缩放的专辑墙。
  final int? fixedResolution;

  final double devicePixelRatio;
  final BoxFit fit;

  @override
  bool operator ==(Object other) =>
      other is ArtworkRequest &&
      source == other.source &&
      identity == other.identity &&
      version == other.version &&
      targetSize == other.targetSize &&
      fixedResolution == other.fixedResolution &&
      devicePixelRatio == other.devicePixelRatio &&
      fit == other.fit;

  @override
  int get hashCode => Object.hash(
    source,
    identity,
    version,
    targetSize,
    fixedResolution,
    devicePixelRatio,
    fit,
  );
}
