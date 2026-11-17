import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musaic/features/canvas/canvas_drift.dart';
import 'package:musaic/features/canvas/home_album_layout_state.dart';

void main() {
  test('drift preserves the original 12px/s floor and pauses without moving', () {
    final controller = TransformationController();
    final drift = CanvasDrift(random: math.Random(1));
    final initial = controller.value.clone();

    drift.advance(Duration.zero, controller, enabled: true);
    expect(controller.value, initial);
    drift.advance(const Duration(milliseconds: 16), controller, enabled: false);
    expect(controller.value, initial);
    drift.advance(const Duration(milliseconds: 32), controller, enabled: true);
    expect(drift.velocity.distance, closeTo(12, 1e-9));
    expect(controller.value.entry(0, 3), isNot(0));
    controller.dispose();
  });

  test('layout state resets album placement without changing catalog', () {
    final layout = HomeAlbumLayoutState();
    final catalog = [
      {'asset': 'a', 'title': 'A'},
      {'asset': 'b', 'title': 'B'},
    ];
    final transform = Matrix4.identity();
    layout.prepareExpansion(catalog, const Size(250, 250), transform);
    expect(layout.snapshot, isNotNull);
    expect(layout.flowAlbums, isNotEmpty);
    layout.prepareCollapse(
      catalog,
      const Size(250, 250),
      transform,
      playingAsset: null,
      playingTitle: null,
    );
    expect(layout.gridAlbums, isNotEmpty);
    layout.clear();
    expect(layout.flowAlbums, isNull);
    expect(layout.snapshot, isNull);
    expect(layout.gridAlbums, isEmpty);
    expect(layout.flowPosition, 0);
    expect(layout.flowTilt, 0);
  });
}
