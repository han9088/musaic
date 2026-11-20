// 文件职责：统一预热 Artwork 原图资源，不负责视口计算或专辑目录映射。

import 'package:flutter/widgets.dart';

import '../../../services/music/directory_music_library.dart';
import '../model/artwork_request.dart';
import '../source/artwork_resolver.dart';
import 'artwork_decode_policy.dart';

/// 只接收完整的 ArtworkRequest；视口筛选和专辑数据转换由调用方负责。
class ArtworkPrefetchScheduler {
  const ArtworkPrefetchScheduler({this.maxConcurrent = 4})
    : assert(maxConcurrent > 0);

  final int maxConcurrent;

  List<ArtworkRequest> deduplicate(Iterable<ArtworkRequest> requests) {
    final seen = <ArtworkRequest>{};
    final result = <ArtworkRequest>[];
    for (final request in requests) {
      if (request.source.startsWith('local:')) continue;
      if (seen.add(request)) result.add(request);
    }
    return result;
  }

  Future<void> warm({
    required Iterable<ArtworkRequest> requests,
    required DirectoryMusicLibrary? directory,
    required BuildContext context,
    required bool Function() isActive,
  }) async {
    final unique = deduplicate(requests);
    for (var start = 0; start < unique.length; start += maxConcurrent) {
      if (!isActive()) return;
      final end = (start + maxConcurrent).clamp(0, unique.length);
      await Future.wait([
        for (var index = start; index < end; index++)
          _warmRequest(
            unique[index],
            directory: directory,
            context: context,
            isActive: isActive,
          ),
      ]);
    }
  }

  /// 预热已解析的 Provider，供关闭 Xerox 模式前复用原图解码结果。
  Future<void> warmProviders(
    Iterable<
      ({ImageProvider<Object> image, String sourceKey, int decodeResolution})
    >
    sources,
    BuildContext context, {
    bool Function()? isActive,
  }) async {
    final unique =
        <
          String,
          ({
            ImageProvider<Object> image,
            String sourceKey,
            int decodeResolution,
          })
        >{};
    for (final source in sources) {
      unique.putIfAbsent(
        '${source.sourceKey}:${source.decodeResolution}',
        () => source,
      );
    }
    final values = unique.values.toList(growable: false);
    for (var start = 0; start < values.length; start += maxConcurrent) {
      if (isActive != null && !isActive()) return;
      final end = (start + maxConcurrent).clamp(0, values.length);
      await Future.wait([
        for (final source in values.sublist(start, end))
          _precacheProvider(source, context),
      ]);
    }
  }

  Future<void> _precacheProvider(
    ({ImageProvider<Object> image, String sourceKey, int decodeResolution})
    source,
    BuildContext context,
  ) async {
    try {
      final provider = ResizeImage(
        source.image,
        width: source.decodeResolution,
        height: source.decodeResolution,
      );
      await precacheImage(
        provider,
        context,
        size: Size.square(source.decodeResolution.toDouble()),
        onError: (error, stackTrace) {},
      );
    } catch (_) {
      // 预热失败不应阻断模式切换或音乐源切换。
    }
  }

  Future<void> _warmRequest(
    ArtworkRequest request, {
    required DirectoryMusicLibrary? directory,
    required BuildContext context,
    required bool Function() isActive,
  }) async {
    final targetSize = request.targetSize;
    if (targetSize == null) return;
    try {
      final resolved = await const ArtworkResolver().resolveRequest(
        request,
        directories: directory,
      );
      if (!context.mounted || !isActive() || resolved == null) return;
      final resolution = artworkDecodeResolution(
        targetSize.longestSide * request.devicePixelRatio,
      );
      await precacheImage(
        ResizeImage(resolved.image, width: resolution, height: resolution),
        context,
        size: targetSize,
        onError: (error, stackTrace) {},
      );
    } catch (_) {
      // 预热失败只影响缓存命中率，不应阻断音乐源切换。
    }
  }
}
