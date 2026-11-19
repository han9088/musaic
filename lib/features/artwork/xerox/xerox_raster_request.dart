// 文件职责：专辑封面来源解析、图片解码、缓存及 Xerox 处理。

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/widgets.dart';

import 'xerox_config.dart';

@immutable
/// 封装或定义Xerox光栅key相关类型与行为，负责专辑封面来源解析、图片解码、缓存及 Xerox 处理。
class XeroxRasterKey {
  const XeroxRasterKey({
    required this.identity,
    required this.sourceKey,
    required this.resolution,
    required this.fit,
    required this.devicePixelRatio,
    required this.config,
  });

  final String identity;
  final String sourceKey;
  final int resolution;
  final BoxFit fit;
  final double devicePixelRatio;
  final XeroxConfig config;

  /// 执行当前模块中的磁盘缓存key操作，用于专辑封面来源解析、图片解码、缓存及 Xerox 处理。
  String get diskCacheKey {
    final value = jsonEncode([
      identity,
      sourceKey,
      resolution,
      fit.name,
      devicePixelRatio,
      config.edge,
      config.contrast,
      config.smooth,
      config.grain,
      config.invert,
      'xerox-raster-v1',
    ]);
    return base64Url.encode(utf8.encode(value)).replaceAll('=', '');
  }

  /// 执行当前模块中的same专辑封面操作，用于专辑封面来源解析、图片解码、缓存及 Xerox 处理。
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
      resolution == other.resolution;

  @override
  /// 判断当前状态是否满足指定条件，用于专辑封面来源解析、图片解码、缓存及 Xerox 处理。
  int get hashCode => Object.hash(
    identity,
    sourceKey,
    resolution,
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
/// 封装或定义Xerox光栅request相关类型与行为，负责专辑封面来源解析、图片解码、缓存及 Xerox 处理。
class XeroxRasterRequest {
  XeroxRasterRequest({
    required this.identity,
    required this.image,
    required this.resolution,
    this.fit = BoxFit.cover,
    this.devicePixelRatio = 1,
    this.config = xeroxConfig,
    String? sourceKey,
  }) : sourceKey = sourceKey ?? image.toString();

  final String identity;
  final ImageProvider<Object> image;
  final int resolution;
  final BoxFit fit;
  final double devicePixelRatio;
  final XeroxConfig config;
  final String sourceKey;

  /// 执行当前模块中的key操作，用于专辑封面来源解析、图片解码、缓存及 Xerox 处理。
  XeroxRasterKey get key => XeroxRasterKey(
    identity: identity,
    sourceKey: sourceKey,
    resolution: resolution,
    fit: fit,
    devicePixelRatio: devicePixelRatio,
    config: config,
  );
}
