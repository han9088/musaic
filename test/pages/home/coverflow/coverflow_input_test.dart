import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musaic/features/coverflow/album_coverflow.dart';

void main() {
  Future<void> mount(WidgetTester tester, ValueChanged<double> changed) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AlbumCoverFlow(
          albums: const [
            {
              'asset': 'assets/albums/0.jpg',
              'artist': 'Artist',
              'title': 'Album',
            },
          ],
          onMotionChanged: (position, _) => changed(position),
        ),
      ),
    );
    await tester.pump();
  }

  for (final nativePan in [false, true]) {
    testWidgets(
      'trackpad preserves short swipe, long swipe and reversal (pan: $nativePan)',
      (tester) async {
        await mount(tester, (_) {});
        double tilt() => tester
            .widget<Transform>(find.byKey(const ValueKey('cover-flow-plane')))
            .transform
            .entry(0, 2);
        final pointer = TestPointer(9, PointerDeviceKind.trackpad);
        const point = Offset(400, 300);
        if (nativePan) {
          await tester.sendEventToBinding(pointer.panZoomStart(point));
        }
        var pan = Offset.zero;
        var time = Duration.zero;
        for (final direction in [-1.0, 1.0]) {
          for (var i = 0; i < 20; i++) {
            time += const Duration(milliseconds: 16);
            pan += Offset(20 * direction, 0);
            await tester.sendEventToBinding(
              nativePan
                  ? pointer.panZoomUpdate(point, pan: pan, timeStamp: time)
                  : PointerScrollEvent(
                      position: point,
                      scrollDelta: Offset(-20 * direction, 0),
                      timeStamp: time,
                    ),
            );
            await tester.pump(const Duration(milliseconds: 16));
            if (direction == -1 && i < 6) {
              expect(tilt(), closeTo(0, .000001));
            }
          }
          expect(tilt() * direction, greaterThan(0.1));
        }
        if (nativePan) {
          await tester.sendEventToBinding(pointer.panZoomEnd(timeStamp: time));
        }
        await tester.pumpAndSettle();
        expect(tilt(), closeTo(0, .000001));
      },
      variant: TargetPlatformVariant.only(TargetPlatform.macOS),
    );
  }

  for (final nativePan in [false, true]) {
    for (final pause in [140, 800]) {
      testWidgets(
        'trackpad short swipe cadence (pan: $nativePan, pause: $pause)',
        (tester) async {
          await mount(tester, (_) {});
          var time = Duration.zero;
          double tilt() => tester
              .widget<Transform>(find.byKey(const ValueKey('cover-flow-plane')))
              .transform
              .entry(0, 2);
          for (var swipe = 0; swipe < 3; swipe++) {
            final pointer = TestPointer(20 + swipe, PointerDeviceKind.trackpad);
            const point = Offset(400, 300);
            if (nativePan) {
              await tester.sendEventToBinding(
                pointer.panZoomStart(point, timeStamp: time),
              );
            }
            for (var frame = 0; frame < 8; frame++) {
              time += const Duration(milliseconds: 16);
              await tester.sendEventToBinding(
                nativePan
                    ? pointer.panZoomUpdate(
                        point,
                        pan: Offset(-12.0 * (frame + 1), 0),
                        timeStamp: time,
                      )
                    : PointerScrollEvent(
                        position: point,
                        scrollDelta: const Offset(12, 0),
                        timeStamp: time,
                      ),
              );
              await tester.pump(const Duration(milliseconds: 16));
            }
            expect(
              tilt().abs(),
              swipe == 2 && pause == 140
                  ? greaterThan(.1)
                  : closeTo(0, .000001),
            );
            if (nativePan) {
              await tester.sendEventToBinding(
                pointer.panZoomEnd(timeStamp: time),
              );
            }
            time += Duration(milliseconds: pause);
            await tester.pump(Duration(milliseconds: pause));
          }
          await tester.pumpAndSettle();
          expect(tilt(), closeTo(0, .000001));
        },
        variant: TargetPlatformVariant.only(TargetPlatform.macOS),
      );
    }
  }

  testWidgets('arrow repeats accumulate and modified shortcuts remain free', (
    tester,
  ) async {
    var position = 0.0;
    await mount(tester, (value) => position = value);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(position, closeTo(2, .001));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pumpAndSettle();
    expect(position, closeTo(2, .001));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(position, closeTo(1, .001));
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets(
    'horizontal wheel follows scroll and settles without a second fling',
    (tester) async {
      var position = 0.0;
      await mount(tester, (value) => position = value);
      const point = Offset(400, 300);
      await tester.sendEventToBinding(
        const PointerScrollEvent(position: point, scrollDelta: Offset(0, 200)),
      );
      await tester.pump(const Duration(milliseconds: 16));
      expect(position, 0);
      await tester.sendEventToBinding(
        const PointerScrollEvent(position: point, scrollDelta: Offset(200, 0)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      final moved = position;
      expect(moved, greaterThan(0));
      await tester.pump(const Duration(milliseconds: 140));
      await tester.pumpAndSettle();
      expect(position, closeTo(moved.roundToDouble(), .001));
      await tester.sendEventToBinding(
        const PointerScrollEvent(position: point, scrollDelta: Offset(20, 0)),
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
  );

  testWidgets('native trackpad pan uses the existing drag recognizer once', (
    tester,
  ) async {
    var position = 0.0;
    await mount(tester, (value) => position = value);
    final pointer = TestPointer(1, PointerDeviceKind.trackpad);
    await tester.sendEventToBinding(
      pointer.panZoomStart(const Offset(400, 300)),
    );
    await tester.sendEventToBinding(
      pointer.panZoomUpdate(
        const Offset(400, 300),
        pan: const Offset(-40, 0),
        timeStamp: const Duration(milliseconds: 16),
      ),
    );
    await tester.sendEventToBinding(
      pointer.panZoomUpdate(
        const Offset(400, 300),
        pan: const Offset(-120, 0),
        timeStamp: const Duration(milliseconds: 32),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    expect(position, greaterThan(0));
    expect(position, lessThan(1.5));
    await tester.sendEventToBinding(
      pointer.panZoomEnd(timeStamp: const Duration(milliseconds: 48)),
    );
    await tester.pumpWidget(const SizedBox());
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
  testWidgets('input cannot interrupt a drag before the next frame', (
    tester,
  ) async {
    var position = 0.0;
    await mount(tester, (value) => position = value);
    final drag = tester
        .widgetList<GestureDetector>(find.byType(GestureDetector))
        .firstWhere((widget) => widget.onHorizontalDragStart != null);
    drag.onHorizontalDragStart!(
      DragStartDetails(sourceTimeStamp: Duration.zero),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendEventToBinding(
      const PointerScrollEvent(
        position: Offset(400, 300),
        scrollDelta: Offset(200, 0),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    expect(position, 0);
    drag.onHorizontalDragCancel!();
    await tester.pumpWidget(const SizedBox());
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('dialog input does not trigger Cover Flow shortcuts', (
    tester,
  ) async {
    var position = 0.0;
    await mount(tester, (value) => position = value);
    final dialog = showDialog<void>(
      context: tester.element(find.byType(AlbumCoverFlow)),
      builder: (_) => const AlertDialog(content: TextField(autofocus: true)),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Music');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(position, 0);
    Navigator.of(tester.element(find.byType(TextField))).pop();
    await dialog;
    await tester.pumpAndSettle();
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets(
    'native mobile input remains touch-only',
    (tester) async {
      var position = 0.0;
      await mount(tester, (value) => position = value);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendEventToBinding(
        const PointerScrollEvent(
          position: Offset(400, 300),
          scrollDelta: Offset(200, 0),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(position, 0);
      await tester.drag(find.byType(AlbumCoverFlow), const Offset(-150, 0));
      await tester.pumpAndSettle();
      expect(position, greaterThan(0));
    },
    variant: const TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.iOS,
    }),
  );
}
