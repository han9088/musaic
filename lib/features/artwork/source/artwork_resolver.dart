// 文件职责：将 Asset、Network、Directory 来源统一解析为图片提供器。

import 'dart:convert';

import 'package:flutter/painting.dart';

import '../../../services/music/directory_music_library.dart';
import '../model/artwork_identity.dart';
import '../model/artwork_request.dart';
import '../model/artwork_source.dart';
import 'artwork_file_provider_stub.dart'
    if (dart.library.io) 'artwork_file_provider_io.dart' as file_provider;
import 'artwork_network_provider_stub.dart'
    if (dart.library.io) 'artwork_network_provider_io.dart' as network_provider;

/// 来源解析后的图片资源，以及用于下游缓存失效的身份和版本键。
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

/// 统一解析图片来源；目录封面需要查询媒体库，因此 resolveRequest 为异步方法。
class ArtworkResolver {
  const ArtworkResolver();

  /// 解析可同步创建的 Asset / Network 提供器。
  ImageProvider<Object>? providerFor(ArtworkSource source) {
    switch (source.type) {
      case ArtworkSourceType.asset:
        return AssetImage(source.value);
      case ArtworkSourceType.network:
        return network_provider.networkArtworkProvider(
          source.value,
          identity: source.identity,
          version: source.version,
        );
      case ArtworkSourceType.directory:
        return null;
    }
  }

  /// 为已解析的同步来源生成包含身份和版本信息的缓存键。
  String sourceKeyFor(ArtworkSource source, ImageProvider<Object> provider) =>
      jsonEncode([
        source.identity,
        source.version?.value,
        provider.toString(),
      ]);

  /// 兼容简洁调用形式；新管线可以直接传递完整的 ArtworkRequest。
  Future<ResolvedArtwork?> resolve(
    String reference, {
    required DirectoryMusicLibrary? directories,
    ArtworkIdentity? identity,
    ArtworkVersion? version,
  }) => resolveRequest(
    ArtworkRequest(
      source: reference,
      identity: identity,
      version: version,
    ),
    directories: directories,
  );

  /// 占位引用由展示层处理，不允许进入图片解析、下载或解码流程。
  Future<ResolvedArtwork?> resolveRequest(
    ArtworkRequest request, {
    required DirectoryMusicLibrary? directories,
  }) async {
    if (request.source.startsWith('local:')) return null;

    final source = ArtworkSource.parse(
      request.source,
      identity: request.identity,
      version: request.version,
    );
    final provider = providerFor(source);
    if (provider != null) {
      return ResolvedArtwork(
        identity: source.identity,
        sourceKey: sourceKeyFor(source, provider),
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

    // 本地文件元数据参与版本键，文件或目录记录变化后不会继续命中旧 Xerox 结果。
    final fileVersion = jsonEncode([track.file.data, source.version?.value]);
    return ResolvedArtwork(
      identity: source.identity,
      sourceKey: jsonEncode([image.toString(), fileVersion, uri]),
      image: image,
    );
  }
}

/// 兼容只需要 ImageProvider 的调用方；新代码优先使用 [ArtworkResolver.resolveRequest]。
Future<ImageProvider<Object>?> resolveArtworkImageProvider(
  String reference, {
  DirectoryMusicLibrary? directories,
}) async {
  final resolved = await const ArtworkResolver().resolve(
    reference,
    directories: directories,
  );
  return resolved?.image;
}
