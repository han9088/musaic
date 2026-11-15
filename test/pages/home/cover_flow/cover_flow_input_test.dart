import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musaic/pages/home/cover_flow/album_cover_flow.dart';

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
