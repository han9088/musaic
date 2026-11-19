import 'package:flutter/painting.dart';
import 'package:flutter/widgets.dart';

import '../../services/music/directory_music_library.dart';
import '../canvas/album_grid_snapshot.dart';
import 'artwork_image_provider.dart';
import 'pipeline/artwork_decode_policy.dart';

/// Preloads only the cells in an impending source transition, in scene order.
/// The resolver handles Asset, Network and directory artwork uniformly.
class VisibleAlbumPreloader {
  const VisibleAlbumPreloader({this.maxConcurrent = 4})
    : assert(maxConcurrent > 0);

  final int maxConcurrent;

  List<String> visibleAssets(
    List<Map<String, dynamic>> albums,
    List<({int row, int column, Rect rect})> cells,
  ) {
    if (albums.isEmpty) return const [];
    final prepared = <String>{};
    final assets = <String>[];
    for (final cell in cells) {
      final album = albums[gridAlbumIndex(cell.row, cell.column, albums.length)];
      final asset = album['asset'] as String;
      if (!prepared.add(asset) || asset.startsWith('local:')) continue;
      assets.add(asset);
    }
    return assets;
  }

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
        for (final asset in assets.sublist(start, end))
          _warmAsset(asset, directory, context, isActive),
      ]);
    }
  }

  Future<void> _warmAsset(
    String asset,
    DirectoryMusicLibrary? directory,
    BuildContext context,
    bool Function() isActive,
  ) async {
    final image = await resolveArtworkImageProvider(
      asset,
      directories: directory,
    );
    if (!isActive() || image == null) return;

    final dpr = MediaQuery.devicePixelRatioOf(context);
    final decodeSize = artworkDecodeResolution(albumGridExtent * dpr);
    await precacheImage(
      ResizeImage(image, width: decodeSize, height: decodeSize),
      context,
      size: const Size(albumGridExtent, albumGridExtent),
      onError: (error, stackTrace) {},
    );
  }
}
