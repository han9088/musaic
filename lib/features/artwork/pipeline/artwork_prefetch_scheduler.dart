// 文件职责：按调用方提供的 ArtworkRequest 预热原图资源。

import 'package:flutter/widgets.dart';

import '../../../services/music/directory_music_library.dart';
import '../model/artwork_request.dart';
import 'artwork_lod_manager.dart';
import 'artwork_pipeline.dart';

/// 只负责有限并发预热，不计算视口、不映射专辑目录，也不实现缓存。
class ArtworkPrefetchScheduler {
  const ArtworkPrefetchScheduler({this.maxConcurrent = 4})
    : assert(maxConcurrent > 0);

  final int maxConcurrent;

  List<ArtworkRequest> deduplicate(Iterable<ArtworkRequest> requests) {
    final seen = <ArtworkRequest>{};
    final result = <ArtworkRequest>[];
    for (final request in requests) {
      if (request.source.startsWith('local:') &&
          ArtworkPipeline.instance.customArtworkRevision(request) == null) {
        continue;
      }
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
      if (!context.mounted || !isActive()) return;
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

  /// 预热已解析 Provider，供关闭 Xerox 模式前复用原图解码结果。
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
      if (!context.mounted || (isActive != null && !isActive())) return;
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
        policy: ResizeImagePolicy.fit,
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
      final resource = await ArtworkPipeline.instance.resolve(
        request,
        directories: directory,
      );
      if (!context.mounted || !isActive() || resource == null) return;

      final physicalExtent = targetSize.longestSide * request.devicePixelRatio;
      final resolution =
          request.fixedResolution ?? selectArtworkResolution(physicalExtent);
      await precacheImage(
        ResizeImage(
          resource.image,
          width: resolution,
          height: resolution,
          policy: ResizeImagePolicy.fit,
        ),
        context,
        size: targetSize,
        onError: (error, stackTrace) {},
      );
    } catch (_) {
      // 预热失败只影响缓存命中率，不应阻断音乐源切换。
    }
  }
}
