import 'dart:ui';

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musaic/ui/transitions/source_tile_motion.dart';

void main() {
  testWidgets('tile opacity matches Flutter through layer changes', (
    tester,
  ) async {
    final standardKey = GlobalKey();
    final tileKey = GlobalKey();
    Widget layers() => const Stack(
      children: [
        SizedBox(
          width: 16,
          height: 16,
          child: ColoredBox(color: Color(0xffff8800)),
        ),
        Positioned(
          left: 5,
          child: SizedBox(
            width: 11,
            height: 16,
            child: ColoredBox(color: Color(0xff0088ff)),
          ),
        ),
      ],
    );
    Future<List<int>> pixels(GlobalKey key) async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = boundary.toImageSync();
      try {
        final bytes = await image.toByteData(format: ImageByteFormat.rawRgba);
        return bytes!.buffer.asUint8List();
      } finally {
        image.dispose();
      }
    }

    for (final alpha in [1.0, 0.45, 0.0, 1.0]) {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Row(
            children: [
              RepaintBoundary(
                key: standardKey,
                child: Opacity(opacity: alpha, child: layers()),
              ),
              RepaintBoundary(
                key: tileKey,
                child: SourceTileMotion.wrap(
                  timeline: const AlwaysStoppedAnimation(0),
                  frame: (_) => (transform: Matrix4.identity(), alpha: alpha),
                  child: layers(),
                ),
              ),
            ],
          ),
        ),
      );
      final rendered = await tester.runAsync(
        () => Future.wait([pixels(tileKey), pixels(standardKey)]),
      );
      expect(rendered![0], rendered[1]);
      final opacities = tester.allRenderObjects
          .whereType<RenderOpacity>()
          .toList();
      expect(opacities.last.isRepaintBoundary, alpha > 0 && alpha < 1);
    }
  });

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
