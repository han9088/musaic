import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:musaic/features/transitions/source_tile_motion.dart';

void main() {
  const viewport = Size(400, 800);
  final cells = [
    (row: 4, column: 0, rect: const Rect.fromLTWH(0, 700, 100, 100)),
    (row: 5, column: 3, rect: const Rect.fromLTWH(300, 700, 100, 100)),
  ];

  test('exit staggers bottom rows and right side before left', () {
    final exit = SourceTileMotion.exit(cells, viewport);

    expect(exit.tiles[(5, 3)]!.startMs, 0);
    expect(exit.tiles[(4, 0)]!.startMs, 101);
    expect(exit.durationMs, 186);
  });

  test('exit holds opacity until the final 30 percent', () {
    final motion = SourceTileMotion.exit([
      cells.first,
    ], viewport).tiles[(4, 0)]!;

    expect(
      motion
          .exitTransform(
            elapsedMs: motion.startMs + 59.5,
            viewport: viewport,
            scale: 1,
            tileSize: 100,
          )
          .alpha,
      1,
    );
    expect(
      motion
          .exitTransform(
            elapsedMs: motion.startMs + 85,
            viewport: viewport,
            scale: 1,
            tileSize: 100,
          )
          .alpha,
      0,
    );
  });

  test('entrance staggers rows by 28ms and settles in place', () {
    final enter = SourceTileMotion.enter(cells);
    final first = enter.tiles[(4, 0)]!;
    final second = enter.tiles[(5, 3)]!;
    final initial = first.enterTransform(
      elapsedMs: 0,
      viewport: viewport,
      scale: 1,
      tileSize: 100,
    );
    final settled = first.enterTransform(
      elapsedMs: first.startMs + 190,
      viewport: viewport,
      scale: 1,
      tileSize: 100,
    );

    expect(second.startMs - first.startMs, 28);
    expect(enter.durationMs, 278);
    expect(initial.alpha, 0);
    expect(settled.alpha, closeTo(1, 1e-9));
    expect(settled.transform.entry(0, 3), closeTo(0, 1e-9));
    expect(settled.transform.entry(1, 3), closeTo(0, 1e-9));
  });
}
