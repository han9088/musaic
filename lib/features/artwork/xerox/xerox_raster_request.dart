// 文件职责：描述 Xerox Raster 输入资源、原图解码 LOD、输出 LOD 和处理优先级。

import 'dart:convert';

import 'package:flutter/widgets.dart';

import 'xerox_config.dart';

/// 优先级只影响任务排队顺序，不参与缓存身份。
enum XeroxRasterPriority { background, overscan, visible, selected }

@immutable
class XeroxRasterKey {
  const XeroxRasterKey({
    required this.identity,
    required this.sourceKey,
    required this.resolution,
    required this.originalDecodeResolution,
    required this.fit,
    required this.devicePixelRatio,
    required this.config,
  });

  final String identity;
  final String sourceKey;
  final int resolution;
  final int originalDecodeResolution;
  final BoxFit fit;
  final double devicePixelRatio;
  final XeroxConfig config;

  /// 磁盘缓存身份包含输入和输出分辨率，避免不同原图 LOD 互相命中。
  String get diskCacheKey {
    final value = jsonEncode([
      identity,
      sourceKey,
      originalDecodeResolution,
      resolution,
      fit.name,
      devicePixelRatio,
      config.edge,
      config.contrast,
      config.smooth,
      config.grain,
      config.invert,
      'xerox-raster-v3',
    ]);
    return base64Url.encode(utf8.encode(value)).replaceAll('=', '');
  }

  /// 比较同一封面、同一原图解码档位和处理参数；输出 LOD 可以不同。
  bool sameArtwork(XeroxRasterKey other) =>
      identity == other.identity &&
      sourceKey == other.sourceKey &&
      fit == other.fit &&
      devicePixelRatio == other.devicePixelRatio &&
      config.edge == other.config.edge &&
      config.contrast == other.config.contrast &&
      config.smooth == other.config.smooth &&
      config.grain == other.config.grain &&
      config.invert == other.config.invert;

  @override
  bool operator ==(Object other) =>
      other is XeroxRasterKey &&
      sameArtwork(other) &&
      resolution == other.resolution &&
      originalDecodeResolution == other.originalDecodeResolution;

  @override
  int get hashCode => Object.hash(
    identity,
    sourceKey,
    resolution,
    originalDecodeResolution,
    fit,
    devicePixelRatio,
    config.edge,
    config.contrast,
    config.smooth,
    config.grain,
    config.invert,
  );
}

@immutable
class XeroxRasterRequest {
  XeroxRasterRequest({
    required this.identity,
    required this.image,
    required this.resolution,
    int? originalDecodeResolution,
    this.fit = BoxFit.cover,
    this.devicePixelRatio = 1,
    this.config = xeroxConfig,
    this.priority = XeroxRasterPriority.background,
    String? sourceKey,
  }) : originalDecodeResolution = originalDecodeResolution ?? resolution,
       sourceKey = sourceKey ?? image.toString();

  final String identity;
  final ImageProvider<Object> image;
  final int resolution;
  final int originalDecodeResolution;
  final BoxFit fit;
  final double devicePixelRatio;
  final XeroxConfig config;
  final String sourceKey;
  final XeroxRasterPriority priority;

  XeroxRasterKey get key => XeroxRasterKey(
    identity: identity,
    sourceKey: sourceKey,
    resolution: resolution,
    originalDecodeResolution: originalDecodeResolution,
    fit: fit,
    devicePixelRatio: devicePixelRatio,
    config: config,
  );
}
