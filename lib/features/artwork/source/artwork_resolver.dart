// 文件职责：将 Asset、Network、Directory 来源解析为统一 ArtworkResource。

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../../../services/music/directory_music_library.dart';
import '../../../services/music/local_music_library.dart';
import '../model/artwork_identity.dart';
import '../model/artwork_request.dart';
import '../model/artwork_resource.dart';
import '../model/artwork_source.dart';
import 'artwork_file_provider_stub.dart'
    if (dart.library.io) 'artwork_file_provider_io.dart'
    as file_provider;
import 'artwork_network_provider_stub.dart'
    if (dart.library.io) 'artwork_network_provider_io.dart'
    as network_provider;

/// 兼容现有调用方的类型名称；新代码统一使用 ArtworkResource。
typedef ResolvedArtwork = ArtworkResource;

/// 只负责把不同来源解析为统一图片资源，不负责 Widget、LOD 或 Xerox 处理。
class ArtworkResolver {
  const ArtworkResolver();

  Future<ArtworkResource?> resolve(
    String reference, {
    required DirectoryMusicLibrary? directories,
    ArtworkIdentity? identity,
    ArtworkVersion? version,
  }) => resolveRequest(
    ArtworkRequest(source: reference, identity: identity, version: version),
    directories: directories,
  );

  Future<ArtworkResource?> resolveRequest(
    ArtworkRequest request, {
    required DirectoryMusicLibrary? directories,
  }) {
    if (request.source.startsWith('local:')) {
      return SynchronousFuture(null);
    }

    final source = ArtworkSource.parse(
      request.source,
      identity: request.identity,
      version: request.version,
    );

    switch (source.type) {
      case ArtworkSourceType.asset:
        final provider = AssetImage(source.value);
        return SynchronousFuture(_resource(source, provider));

      case ArtworkSourceType.network:
        return network_provider
            .networkArtworkProvider(
              source.value,
              identity: source.identity,
              version: source.version,
            )
            .then((provider) => _resource(source, provider));

      case ArtworkSourceType.directory:
        return _resolveDirectory(source, request.version, directories);

      case ArtworkSourceType.mediaStore:
        return _resolveMediaStore(source);
    }
  }

  ArtworkResource _resource(
    ArtworkSource source,
    ImageProvider<Object> provider,
  ) => ArtworkResource(
    identity: source.identity,
    sourceKey: jsonEncode([source.cacheKey, provider.toString()]),
    image: provider,
  );

  Future<ArtworkResource?> _resolveMediaStore(ArtworkSource source) async {
    final id = int.tryParse(source.value);
    if (id == null || id < 0) return null;
    final bytes = await LocalMusicLibrary.trackArtwork(id);
    if (bytes == null || bytes.isEmpty) return null;
    return ArtworkResource(
      identity: source.identity,
      sourceKey: source.cacheKey,
      image: MemoryImage(bytes),
    );
  }

  Future<ArtworkResource?> _resolveDirectory(
    ArtworkSource source,
    ArtworkVersion? requestedVersion,
    DirectoryMusicLibrary? directories,
  ) async {
    if (directories == null) return null;

    final id = Uri.decodeComponent(source.value);
    final track = directories.track(id);
    if (track == null) return null;

    final uri = await directories.artwork(track);
    if (uri == null || uri.isEmpty) return null;

    final provider = file_provider.fileArtworkProvider(uri);
    if (provider == null) return null;

    // 文件元数据和路径参与资源身份，媒体库内容变化时会使下游处理缓存失效。
    final fileVersion = jsonEncode([track.file.data, requestedVersion?.value]);
    return ArtworkResource(
      identity: source.identity,
      sourceKey: jsonEncode([
        source.cacheKey,
        provider.toString(),
        fileVersion,
        uri,
      ]),
      image: provider,
    );
  }
}
