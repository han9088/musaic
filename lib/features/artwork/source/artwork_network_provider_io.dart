// 文件职责：通过磁盘缓存加载网络封面，并为解码后的图片提供稳定的缓存键。

import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../cache/original_artwork_cache.dart';
import '../model/artwork_identity.dart';

Future<ImageProvider<Object>> networkArtworkProvider(
  String url, {
  required String identity,
  ArtworkVersion? version,
}) => SynchronousFuture(_CachedNetworkArtwork(url, identity, version));

class _CachedNetworkArtwork extends ImageProvider<_CachedNetworkArtwork> {
  _CachedNetworkArtwork(this.url, this.identity, this.version)
    : _cacheKey = OriginalArtworkCache.cacheKeyFor(
        url: url,
        identity: identity,
        version: version,
      );

  final String url;
  final String identity;
  final ArtworkVersion? version;
  final String _cacheKey;

  @override
  Future<_CachedNetworkArtwork> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(
    _CachedNetworkArtwork key,
    ImageDecoderCallback decode,
  ) => MultiFrameImageStreamCompleter(codec: key._decode(decode), scale: 1);

  Future<ui.Codec> _decode(ImageDecoderCallback decode) async {
    // An already decoded cover can paint on the first frame without disk I/O.
    final file = await OriginalArtworkCache.instance.getArtworkFile(
      url,
      identity: identity,
      version: version,
    );
    return decode(await ui.ImmutableBuffer.fromFilePath(file.path));
  }

  @override
  bool operator ==(Object other) =>
      other is _CachedNetworkArtwork && other._cacheKey == _cacheKey;

  @override
  int get hashCode => _cacheKey.hashCode;
}
