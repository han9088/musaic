import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musaic/features/canvas/album_grid_snapshot.dart';

void main() {
  test(
    'entrance prefetch caps distinct covers and starts with the top row',
    () {
      final snapshot = AlbumGridSnapshot.capture(
        const Size(400, 600),
        Matrix4.identity(),
      );
      final leading = snapshot.leadingArtworkCells(albumCount: 24, limit: 4);
      expect(leading, hasLength(4));
      expect(leading.take(3).map((cell) => cell.row), everyElement(0));
      expect(leading.first.column, anyOf(1, 2));
      expect(
        leading
            .map((cell) => gridAlbumIndex(cell.row, cell.column, 24))
            .toSet(),
        hasLength(4),
      );
      expect(
        snapshot.leadingArtworkCells(albumCount: 1, limit: 4),
        hasLength(1),
      );
    },
  );

  test(
    'snapshot can include the sensor-tilt overscan without changing focus',
    () {
      final transform = Matrix4.identity();
      const viewport = Size(200, 200);
      final visible = AlbumGridSnapshot.capture(viewport, transform);
      final expanded = AlbumGridSnapshot.capture(
        viewport,
        transform,
        overscan: 120,
      );

      expect(expanded.cells.length, greaterThan(visible.cells.length));
      expect(expanded.cells.any((cell) => cell.rect.left < 0), isTrue);
      expect(expanded.cells.any((cell) => cell.rect.top < 0), isTrue);
      expect(expanded.cells[expanded.focus].rect.center, Offset(50, 50));
    },
  );
}
