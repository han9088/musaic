import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/widgets.dart';

import 'xerox_config.dart';

const xeroxAlgorithmVersion = 'xerox-v1';

@immutable
class XeroxRasterKey {
  const XeroxRasterKey({
    required this.identity,
    required this.sourceKey,
    required this.resolution,
    required this.fit,
    required this.devicePixelRatio,
    required this.config,
    this.algorithmVersion = xeroxAlgorithmVersion,
  });

  final String identity;
  final String sourceKey;
  final int resolution;
  final BoxFit fit;
  final double devicePixelRatio;
  final XeroxConfig config;
  final String algorithmVersion;

  bool sameArtwork(XeroxRasterKey other) =>
      identity == other.identity &&
      sourceKey == other.sourceKey &&
      fit == other.fit &&
      devicePixelRatio == other.devicePixelRatio &&
      algorithmVersion == other.algorithmVersion &&
      config.edge == other.config.edge &&
      config.contrast == other.config.contrast &&
      config.smooth == other.config.smooth &&
      config.grain == other.config.grain &&
      config.invert == other.config.invert;

  XeroxRasterKey withResolution(int value) => XeroxRasterKey(
    identity: identity,
    sourceKey: sourceKey,
    resolution: value,
    fit: fit,
    devicePixelRatio: devicePixelRatio,
    config: config,
    algorithmVersion: algorithmVersion,
  );

  /// Stable across app launches and Dart processes; do not use hashCode for
  /// persistent cache keys because Object.hash is not a storage contract.
  String get cacheKey {
    final canonical = jsonEncode([
      algorithmVersion,
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
    ]);
    return 'xerox_${sha256.convert(utf8.encode(canonical))}';
  }

  @override
  bool operator ==(Object other) =>
      other is XeroxRasterKey &&
      sameArtwork(other) &&
      resolution == other.resolution;

  @override
  int get hashCode => Object.hash(
    identity,
    sourceKey,
    resolution,
    fit,
    devicePixelRatio,
    algorithmVersion,
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
    this.fit = BoxFit.cover,
    this.devicePixelRatio = 1,
    this.config = xeroxConfig,
    this.algorithmVersion = xeroxAlgorithmVersion,
    String? sourceKey,
  }) : sourceKey = sourceKey ?? image.toString();

  final String identity;
  final ImageProvider<Object> image;
  final int resolution;
  final BoxFit fit;
  final double devicePixelRatio;
  final XeroxConfig config;
  final String algorithmVersion;
  final String sourceKey;

  XeroxRasterKey get key => XeroxRasterKey(
    identity: identity,
    sourceKey: sourceKey,
    resolution: resolution,
    fit: fit,
    devicePixelRatio: devicePixelRatio,
    config: config,
    algorithmVersion: algorithmVersion,
  );
}
