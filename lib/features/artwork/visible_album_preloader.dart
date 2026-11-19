// 文件职责：专辑封面来源解析、图片解码、缓存及 Xerox 处理。

import 'dart:io';

import 'package:material_ui/material_ui.dart';

import '../../services/music/directory_music_library.dart';
import '../canvas/album_grid_snapshot.dart';

/// 封装或定义visible专辑预加载器相关类型与行为，负责专辑封面来源解析、图片解码、缓存及 Xerox 处理。
class VisibleAlbumPreloader {
  const VisibleAlbumPreloader({this.maxConcurrent = 4})
      : assert(maxConcurrent > 0);

  final int maxConcurrent;

  /// 执行当前模块中的visibleassets操作，用于专辑封面来源解析、图片解码、缓存及 Xerox 处理。
  List<String> visibleAssets(
    List<Map<String, dynamic>> albums,
    List<({int row, int column, Rect rect})> cells,
  ) {
    if (albums.isEmpty) return const [];
    final prepared = <String>{};
    final assets = <String>[];
    for (final cell in cells) {
      final album = albums[
        gridAlbumIndex(cell.row, cell.column, albums.length)
      ];
      final asset = album['asset'] as String;
      if (!prepared.add(asset) || asset.startsWith('local:')) continue;
      assets.add(asset);
    }
    return assets;
  }

  /// 准备并调度后续任务，用于专辑封面来源解析、图片解码、缓存及 Xerox 处理。
  Future<void> warm({
    required List<Map<String, dynamic>> albums,
    required List<({int row, int column, Rect rect})> cells,
    required DirectoryMusicLibrary? directory,
    required BuildContext context,
    required bool Function() isActive,
  }) async {
    final assets = visibleAssets(albums, cells);
    for (var start = 0; start < assets.length; start += maxConcurrent) {
      if (!isActive()) return;
      final end = (start + maxConcurrent).clamp(0, assets.length);
      await Future.wait([
        for (var i = start; i < end; i++)
          _warmAsset(assets[i], directory, context, isActive),
      ]);
    }
  }

  /// 准备并调度后续任务，用于专辑封面来源解析、图片解码、缓存及 Xerox 处理。
  Future<void> _warmAsset(
    String asset,
    DirectoryMusicLibrary? directory,
    BuildContext context,
    bool Function() isActive,
  ) async {
    ImageProvider? image;
    if (asset.startsWith('directory:')) {
      final id = Uri.decodeComponent(asset.substring('directory:'.length));
      final track = directory?.track(id);
      if (directory != null && track != null) {
        try {
          final uri = await directory.artwork(track);
          if (uri != null) image = FileImage(File.fromUri(Uri.parse(uri)));
        } catch (_) {
          // 本地封面解析失败时，继续沿用 DirectoryArtwork 原有的占位展示逻辑。
        }
      }
    } else {
      image = AssetImage(asset);
    }

    if (!isActive()) return;
    if (image != null) {
      await precacheImage(
        image,
        context,
        size: const Size(albumGridExtent, albumGridExtent),
        onError: (error, stackTrace) {},
      );
    }
  }
}
