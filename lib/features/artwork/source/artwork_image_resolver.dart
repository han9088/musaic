// 文件职责：专辑封面来源解析、图片解码、缓存及 Xerox 处理。

import 'dart:convert';

import 'package:flutter/painting.dart';

import '../../../services/music/directory_music_library.dart';
import '../artwork_file_provider_stub.dart'
    if (dart.library.io) '../artwork_file_provider_io.dart' as file_provider;
import '../artwork_network_provider_stub.dart'
    if (dart.library.io) '../artwork_network_provider_io.dart' as network_provider;
import 'artwork_source.dart';

/// 封装或定义resolved专辑封面相关类型与行为，负责专辑封面来源解析、图片解码、缓存及 Xerox 处理。
class ResolvedArtwork {
  const ResolvedArtwork({
    required this.identity,
    required this.sourceKey,
    required this.image,
  });

  final String identity;
  final String sourceKey;
  final ImageProvider<Object> image;
}

/// 封装或定义专辑封面图片解析器相关类型与行为，负责专辑封面来源解析、图片解码、缓存及 Xerox 处理。
class ArtworkImageResolver {
  const ArtworkImageResolver();

  /// 执行当前模块中的提供器for操作，用于专辑封面来源解析、图片解码、缓存及 Xerox 处理。
  ImageProvider<Object>? providerFor(ArtworkSource source) {
    switch (source.type) {
      case ArtworkSourceType.asset:
        return AssetImage(source.value);
      case ArtworkSourceType.network:
        return network_provider.networkArtworkProvider(source.value);
      case ArtworkSourceType.directory:
      case ArtworkSourceType.placeholder:
        return null;
    }
  }

  /// 解析输入并转换为内部数据，用于专辑封面来源解析、图片解码、缓存及 Xerox 处理。
  Future<ResolvedArtwork?> resolve(
    String reference, {
    required DirectoryMusicLibrary? directories,
  }) async {
    final source = ArtworkSource.parse(reference);
    final provider = providerFor(source);
    if (provider != null) {
      return ResolvedArtwork(
        identity: source.identity,
        sourceKey: provider.toString(),
        image: provider,
      );
    }

    if (!source.isDirectory || directories == null) return null;
    final id = Uri.decodeComponent(source.value);
    final track = directories.track(id);
    if (track == null) return null;

    final uri = await directories.artwork(track);
    if (uri == null || uri.isEmpty) return null;

    final image = file_provider.fileArtworkProvider(uri);
    if (image == null) return null;
    final version = jsonEncode(track.file.data);
    return ResolvedArtwork(
      identity: source.identity,
      sourceKey: '${image.toString()}:$version:$uri',
      image: image,
    );
  }
}
