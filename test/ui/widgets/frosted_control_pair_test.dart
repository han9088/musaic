import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musaic/ui/widgets/frosted_control_surface.dart';

void main() {
  testWidgets('holding connects the glass and keeps the primary tap', (
    tester,
  ) async {
    const primaryKey = ValueKey('primary');
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: FrostedControlPair(
            primaryVisible: true,
            companionVisible: true,
            primary: FrostedControlSurface(
              key: primaryKey,
              visible: true,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => taps++,
                child: const SizedBox(width: 146, height: 38),
              ),
            ),
            companion: const FrostedControlSurface(
              visible: true,
              child: SizedBox.expand(),
            ),
          ),
        ),
      ),
    );
    final primary = find.byKey(primaryKey);
    int paintedSurfaces() => tester
        .widgetList<BackdropFilter>(find.byType(BackdropFilter))
        .where((filter) => filter.enabled)
        .length;

    final width = tester.getRect(primary).width;
    expect(paintedSurfaces(), 2);
    final press = await tester.startGesture(tester.getCenter(primary));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 65));
    expect(tester.getRect(primary).width, lessThan(width));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 220));
    expect(tester.getRect(primary).width, greaterThan(width));
    expect(paintedSurfaces(), 1);
    await press.up();
    expect(taps, 1);
    await tester.pumpAndSettle();
    expect(tester.getRect(primary).width, closeTo(width, 0.05));
    expect(paintedSurfaces(), 2);

    final origin = tester.getCenter(primary);
    final drag = await tester.startGesture(origin);
    await drag.moveTo(origin + const Offset(48, 20));
    await tester.pump();
    final forward = tester.getCenter(primary) - origin;
    expect(forward.dx, greaterThan(12));
    expect(forward.dy, greaterThan(4));
    expect(paintedSurfaces(), 1);

    await drag.moveTo(origin + const Offset(-78, -26));
    await tester.pump();
    final backward = tester.getCenter(primary) - origin;
    expect(backward.dx, lessThan(-12));
    expect(backward.dy, lessThan(-4));
    expect(paintedSurfaces(), 2);
    await drag.up();
    await tester.pumpAndSettle();
    expect(tester.getCenter(primary), origin);
    expect(taps, 1);

    final backdropClip = find.byWidgetPredicate(
      (widget) => widget is ClipPath && widget.child is BackdropFilter,
    );
    for (final anchorX in [-27.0, 27.0]) {
      final pressPoint = origin + Offset(anchorX, 0);
      final lift = await tester.startGesture(pressPoint);
      await tester.pump(const Duration(milliseconds: 105));
      await tester.pumpAndSettle();
      expect(paintedSurfaces(), 1);
      await lift.moveBy(const Offset(0, -16));
      await tester.pump();
      expect(paintedSurfaces(), 2);
      await lift.moveBy(const Offset(0, -104));
      await tester.pumpAndSettle();
      expect(paintedSurfaces(), 2);

      final clipBounds = tester.getRect(backdropClip);
      final clip = tester.widget<ClipPath>(backdropClip);
      final path = clip.clipper!.getClip(clipBounds.size);
      final tipY = path.getBounds().top;
      final primaryBounds = tester.getRect(primary);
      expect(clipBounds.top + tipY, lessThan(primaryBounds.top - 20));
      expect(
        path.contains(Offset(pressPoint.dx - clipBounds.left, tipY + 6)),
        isTrue,
      );
      expect(
        path.contains(Offset(origin.dx - anchorX - clipBounds.left, tipY + 6)),
        isFalse,
      );
      final shoulder = Offset(
        pressPoint.dx - anchorX.sign * 40,
        primaryBounds.top - 3,
      );
      expect(path.contains(shoulder - clipBounds.topLeft), isTrue);
      final contour = path.computeMetrics().single;
      for (final direction in [-1, 1]) {
        final samples = Iterable<int>.generate(
          (contour.length / 4).floor() - 3,
        );
        expect(
          samples.any((sample) {
            final start = contour.getTangentForOffset(sample * 4)!;
            final end = contour.getTangentForOffset(sample * 4 + 12)!;
            return start.vector.dx > 0 &&
                start.vector.dy * direction > 0.15 &&
                (start.vector - end.vector).distance < 0.001;
          }),
          isTrue,
        );
      }
      await lift.up();
      await tester.pumpAndSettle();
      expect(backdropClip, findsNothing);
    }
  });
}
