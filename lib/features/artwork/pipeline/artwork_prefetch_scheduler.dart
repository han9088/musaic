// 文件职责：按当前视口预热原始封面，避免音乐源切换时临时等待图片加载。

import 'package:flutter/widgets.dart';

import '../../../services/music/directory_music_library.dart';
import '../../canvas/album_grid_snapshot.dart';
import '../model/artwork_identity.dart';
import '../model/artwork_request.dart';
import '../source/artwork_resolver.dart';
import 'artwork_decode_policy.dart';

/// 只预热已进入视口的原图，不扫描或请求无限画布远处的图片。
class ArtworkPrefetchScheduler {
  const ArtworkPrefetchScheduler({this.maxConcurrent = 4})
    : assert(maxConcurrent > 0);

  final int maxConcurrent;

  /// 根据网格快照生成有序且去重的可见封面引用，保留音乐源提供的稳定身份。
  List<({String source, ArtworkIdentity? identity})> visibleArtwork(
    List<Map<String, dynamic>> albums,
    List<({int row, int column, Rect rect})> cells,
  ) {
    if (albums.isEmpty) return const [];
    final seen = <({String source, ArtworkIdentity? identity})>{};
    final sources = <({String source, ArtworkIdentity? identity})>[];
    for (final cell in cells) {
      final album = albums[gridAlbumIndex(cell.row, cell.column, albums.length)];
      final source = album['asset'] as String;
      if (source.startsWith('local:')) continue;
      final rawIdentity = album['id'] as String?;
      final request = (
        source: source,
        identity: rawIdentity == null ? null : ArtworkIdentity(rawIdentity),
      );
      if (seen.add(request)) sources.add(request);
    }
    return sources;
  }

  /// 分批解析并预热可见原图；网络、Asset 与本地目录统一经过 ArtworkResolver。
  Future<void> warm({
    required List<Map<String, dynamic>> albums,
    required List<({int row, int column, Rect rect})> cells,
    required DirectoryMusicLibrary? directory,
    required BuildContext context,
    required bool Function() isActive,
    double scale = 1,
  }) async {
    final sources = visibleArtwork(albums, cells);
    for (var start = 0; start < sources.length; start += maxConcurrent) {
      if (!isActive()) return;
      final end = (start + maxConcurrent).clamp(0, sources.length);
      await Future.wait([
        for (var index = start; index < end; index++)
          _warmSource(
            sources[index].source,
            identity: sources[index].identity,
            directory: directory,
            context: context,
            isActive: isActive,
            scale: scale,
          ),
      ]);
    }
  }

  Future<void> _warmSource(
    String reference, {
    required ArtworkIdentity? identity,
    required DirectoryMusicLibrary? directory,
    required BuildContext context,
    required bool Function() isActive,
    required double scale,
  }) async {
    try {
      final dpr = MediaQuery.devicePixelRatioOf(context);
      final request = ArtworkRequest(
        source: reference,
        identity: identity,
        targetSize: Size.square(albumGridExtent * scale),
        devicePixelRatio: dpr,
        fit: BoxFit.cover,
      );
      final resolved = await const ArtworkResolver().resolveRequest(
        request,
        directories: directory,
      );
      if (!isActive() || resolved == null) return;

      final resolution = artworkDecodeResolution(
        request.targetSize!.longestSide * request.devicePixelRatio,
      );
      final provider = ResizeImage(
        resolved.image,
        width: resolution,
        height: resolution,
      );
      await precacheImage(
        provider,
        context,
        size: request.targetSize,
        onError: (error, stackTrace) {},
      );
    } catch (_) {
      // 预热失败只影响切换时的缓存命中率，不应阻断音乐源切换。
    }
  }
}
