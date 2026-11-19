import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musaic/features/canvas/album_grid_snapshot.dart';

void main() {
  test('snapshot can include the sensor-tilt overscan without changing focus', () {
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
  });
}
