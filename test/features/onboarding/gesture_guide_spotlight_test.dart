import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musaic/features/onboarding/gesture_guide_spotlight.dart';

void main() {
  testWidgets('the light contracts into a soft capsule then stays in place', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(
      () =>
          ui.FragmentProgram.fromAsset('shaders/gesture_guide_spotlight.frag'),
    );
    const boundaryKey = ValueKey('spotlight-capture');
    final scene = ValueNotifier((
      position: Offset.zero,
      color: const Color(0xFFFFFFFF),
    ));
    final focus = AnimationController(vsync: tester);
    addTearDown(scene.dispose);
    addTearDown(focus.dispose);
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundaryKey,
        child: WidgetsApp(
          color: const Color(0xFFFFFFFF),
          onGenerateRoute: (_) => PageRouteBuilder<void>(
            pageBuilder: (_, _, _) => ValueListenableBuilder(
              valueListenable: scene,
              builder: (_, value, child) => ColoredBox(
                color: value.color,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 45),
                    child: Transform.translate(
                      offset: value.position,
                      child: child,
                    ),
                  ),
                ),
              ),
              child: GestureGuideSpotlight(
                opacity: const AlwaysStoppedAnimation(1.0),
                focus: focus,
                padding: const EdgeInsets.symmetric(
                  horizontal: 26,
                  vertical: 3,
                ),
                child: const SizedBox(width: 146, height: 38),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    Future<List<int>> lightAt(List<Offset> points) => tester
        .runAsync(() async {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(boundaryKey),
          );
          final image = boundary.toImageSync();
          try {
            final pixels = (await image.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            ))!;
            return [
              for (final point in points)
                pixels.getUint8(
                  (point.dy.toInt() * image.width + point.dx.toInt()) * 4,
                ),
            ];
          } finally {
            image.dispose();
          }
        })
        .then((samples) => samples!);

    const center = Offset(201, 810);
    const above = Offset(201, 550);
    expect(await lightAt([above]), [255]);
    focus.value = 0.6;
    await tester.pump();
    expect((await lightAt([above])).single, inExclusiveRange(40, 240));
    focus.value = 1;
    await tester.pump();
    expect(await lightAt([above]), [0]);

    final [
      inner,
      topCenter,
      topCap,
      bottomCap,
      rightCap,
      diagonalCap,
      corner,
      nearEdge,
      outer,
      bottom,
    ] = await lightAt([
      center,
      center + const Offset(0, -38),
      center + const Offset(77, -38),
      center + const Offset(77, 37),
      center + const Offset(114, 0),
      center + const Offset(104, -27),
      center + const Offset(116, -38),
      center + const Offset(123, 0),
      center + const Offset(132, 0),
      const Offset(201, 873),
    ]);
    expect(inner, 255);
    expect(topCenter, inExclusiveRange(80, 180));
    expect(topCap, closeTo(topCenter, 2));
    expect(bottomCap, closeTo(topCap, 2));
    expect(rightCap, closeTo(topCap, 2));
    expect(diagonalCap, closeTo(topCap, 8));
    expect(corner, 0);
    expect(nearEdge, inExclusiveRange(0, topCap));
    expect(outer, 0);
    expect(bottom, 0);

    const move = Offset(150, 0);
    final beforeMove = await lightAt([center, center + move]);
    scene.value = (position: move, color: scene.value.color);
    await tester.pumpAndSettle();
    expect(await lightAt([center, center + move]), beforeMove);

    scene.value = (position: move, color: const Color(0xFF000000));
    await tester.pumpAndSettle();
    expect(await lightAt([center, center + move]), [0, 0]);
  });
}
