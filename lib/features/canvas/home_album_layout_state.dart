import 'package:material_ui/material_ui.dart';

import 'album_grid_snapshot.dart';

/// State shared by the grid and Cover Flow presentations.
/// The owning page controls when mutations trigger a rebuild.
class HomeAlbumLayoutState {
  AlbumGridSnapshot? snapshot;
  List<Map<String, dynamic>>? flowAlbums;
  final gridAlbums = <(int, int), Map<String, dynamic>>{};
  double flowPosition = 0;
  double flowTilt = 0;
  int gridOffset = 0;
  (int, int)? selectedAlbum;

  Map<String, dynamic> albumAt(
    int row,
    int column,
    List<Map<String, dynamic>> albums,
  ) =>
      gridAlbums[(row, column)] ??
      albums[gridAlbumIndex(row, column, albums.length)];

  void clear() {
    flowAlbums = null;
    gridAlbums.clear();
    snapshot = null;
    selectedAlbum = null;
    flowPosition = 0;
    flowTilt = 0;
    gridOffset = 0;
  }

  void prepareExpansion(
    List<Map<String, dynamic>>? albums,
    Size? size,
    Matrix4 transform,
  ) {
    if (albums == null || albums.isEmpty || size == null) return;
    final next = AlbumGridSnapshot.capture(size, transform);
    if (next.cells.isEmpty) return;
    snapshot = next;
    final visible = [
      for (final cell in next.cells)
        albumAt(cell.row, cell.column, albums),
    ];
    final visibleAlbums = visible.toSet();
    flowAlbums = [
      ...visible,
      ...albums.where((album) => !visibleAlbums.contains(album)),
    ];
    flowPosition = next.focus.toDouble();
    flowTilt = 0;
    gridOffset = 0;
  }

  void prepareCollapse(
    List<Map<String, dynamic>>? catalog,
    Size viewport,
    Matrix4 transform, {
    required String? playingAsset,
    required String? playingTitle,
  }) {
    final albums = flowAlbums ?? catalog;
    if (albums == null || albums.isEmpty) return;
    snapshot ??= AlbumGridSnapshot.capture(viewport, transform);
    final captured = snapshot!;
    gridOffset = flowPosition.round() - captured.focus;
    gridAlbums.clear();
    selectedAlbum = null;
    for (var i = 0; i < captured.cells.length; i++) {
      final cell = captured.cells[i];
      final album = albums[(i + gridOffset) % albums.length];
      gridAlbums[(cell.row, cell.column)] = album;
      if (album['asset'] == playingAsset && album['title'] == playingTitle) {
        selectedAlbum = (cell.row, cell.column);
      }
    }
  }
}
