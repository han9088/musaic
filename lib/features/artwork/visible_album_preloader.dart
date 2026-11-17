import 'dart:io';

import 'package:material_ui/material_ui.dart';

import '../../services/music/directory_music_library.dart';
import '../canvas/album_grid_snapshot.dart';

/// Preloads only the cells in the impending source transition, in scene order.
/// A bounded batch avoids serializing network/disk reads and image decodes.
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
      final album = albums[
        gridAlbumIndex(cell.row, cell.column, albums.length)
      ];
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
        for (var i = start; i < end; i++)
          _warmAsset(assets[i], directory, context, isActive),
      ]);
    }
  }

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
          // DirectoryArtwork retains its original placeholder behavior.
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
