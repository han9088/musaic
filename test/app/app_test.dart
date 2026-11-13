import 'package:flutter_test/flutter_test.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musaic/main.dart' as app;
import 'package:musaic/pages/home/album_cover_flow.dart';
import 'package:musaic/pages/home/portrait_tilt.dart';
import 'package:musaic/pages/home/selected_album.dart';

void main() {
  testWidgets('Musaic starts with its own app title', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    app.main();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    final context = tester.element(find.byType(Scaffold));
    expect(materialApp.onGenerateTitle!(context), 'Musaic');
    expect(find.byType(Image), findsWidgets);
    final controller = tester
        .widget<InteractiveViewer>(find.byType(InteractiveViewer))
        .transformationController!;
    expect(controller.value.entry(0, 0), 1);
    expect(controller.value.entry(1, 1), 1);
    final hold = await tester.startGesture(
      tester.getCenter(find.byType(InteractiveViewer)),
    );
    final heldPosition = controller.value.clone();
    await tester.pump(const Duration(milliseconds: 200));
    expect(
      controller.value,
      heldPosition,
      reason: 'Pointer down must pause automatic drift before drag recognition',
    );
    await hold.moveBy(const Offset(60, 20));
    await tester.pump();
    final draggedPosition = controller.value.clone();
    await tester.pump(const Duration(milliseconds: 200));
    expect(
      controller.value,
      draggedPosition,
      reason: 'Holding a drag must not keep moving the canvas',
    );
    await hold.up();
    await tester.tapAt(const Offset(150, 250));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.byType(SelectedAlbum), findsOneWidget);
    final selectedPosition = controller.value.clone();
    await tester.pump(const Duration(milliseconds: 200));
    expect(controller.value, selectedPosition);
    await tester.tap(
      find.descendant(
        of: find.byType(SelectedAlbum),
        matching: find.byType(GestureDetector),
      ),
    );
    await tester.pump();
    expect(find.byIcon(PhosphorIcons.pauseFill), findsOneWidget);
    await tester.drag(find.byType(InteractiveViewer), const Offset(80, 0));
    await tester.pump();
    expect(find.byType(SelectedAlbum), findsOneWidget);
    expect(find.byIcon(PhosphorIcons.pauseFill), findsOneWidget);
    final initial = controller.value.clone();
    await tester.pump(const Duration(milliseconds: 100));
    expect(controller.value, isNot(initial));
    await tester.drag(find.byType(InteractiveViewer), const Offset(1500, 900));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(Image), findsWidgets);
    final position = controller.value.entry(0, 3);
    await tester.pump(const Duration(milliseconds: 50));
    expect(controller.value.entry(0, 3), greaterThan(position));
    expect(tester.takeException(), isNull);
    final viewer = find.byType(InteractiveViewer);
    for (final offset in [
      const Offset(2400, 1800),
      const Offset(-2400, -1800),
    ]) {
      controller.value = Matrix4.identity()
        ..translateByDouble(offset.dx, offset.dy, 0, 1);
      await tester.pump();
      const tap = Offset(150, 250);
      final scene = controller.toScene(tap);
      await tester.tapAt(tap);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(
        find.byKey(
          ValueKey((
            'selected',
            ((scene.dy / 100).floor(), (scene.dx / 100).floor()),
          )),
        ),
        findsOneWidget,
      );
      final button = find.descendant(
        of: find.byType(SelectedAlbum),
        matching: find.byType(GestureDetector),
      );
      await tester.tap(button);
      await tester.pump();
      expect(find.byIcon(PhosphorIcons.pauseFill), findsOneWidget);
    }
    for (final scale in [0.4, 1.0, 2.5]) {
      controller.value = Matrix4.diagonal3Values(scale, scale, 1);
      await tester.pump();
      expect(tester.widget<InteractiveViewer>(viewer).clipBehavior, Clip.none);
      final covers = tester
          .widgetList<Positioned>(
            find.descendant(of: viewer, matching: find.byType(Positioned)),
          )
          .where((cell) => cell.width == 100)
          .toList();
      final margin = PortraitTilt.overscan(const Size(400, 800));
      final translation = controller.value.getTranslation();
      expect(
        covers
            .map((cell) => cell.left! * scale + translation.x)
            .reduce((a, b) => a < b ? a : b),
        lessThanOrEqualTo(-margin),
      );
      expect(
        covers
            .map((cell) => (cell.left! + 100) * scale + translation.x)
            .reduce((a, b) => a > b ? a : b),
        greaterThanOrEqualTo(400 + margin),
      );
      expect(
        covers
            .map((cell) => cell.top! * scale + translation.y)
            .reduce((a, b) => a < b ? a : b),
        lessThanOrEqualTo(-margin),
      );
      expect(
        covers
            .map((cell) => (cell.top! + 100) * scale + translation.y)
            .reduce((a, b) => a > b ? a : b),
        greaterThanOrEqualTo(800 + margin),
      );
      await tester.fling(viewer, const Offset(30, 0), 1800);
      final start = controller.value.entry(0, 3);
      var previousX = start;
      for (var frame = 0; frame < 60; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        final nextX = controller.value.entry(0, 3);
        expect(
          nextX,
          greaterThanOrEqualTo(previousX - 0.001),
          reason:
              'Release must not pull the canvas backwards at frame $frame, scale $scale',
        );
        previousX = nextX;
      }
      final travel = controller.value.entry(0, 3) - start;
      expect(travel, greaterThanOrEqualTo(0));
      expect(travel, greaterThan(150));
      expect(travel, lessThan(1100));
      expect(tester.takeException(), isNull);
    }
    tester.view.physicalSize = const Size(850, 400);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 550));
    await tester.pump();
    expect(find.byType(InteractiveViewer), findsNothing);
    await tester.pump();
    final center = tester
        .widget<AlbumCoverFlow>(find.byType(AlbumCoverFlow))
        .initialPosition
        .round();
    final active = tester.getRect(find.byKey(ValueKey('cover-$center')));
    final next = tester.getRect(find.byKey(ValueKey('cover-${center + 1}')));
    final further = tester.getRect(find.byKey(ValueKey('cover-${center + 2}')));
    expect(active.width, greaterThan(next.width));
    expect(next.width, closeTo(further.width, 0.01));
    expect(active.right, lessThan(next.left));
    expect(next.right, lessThan(further.left));
    expect(find.byType(Image), findsWidgets);
    await tester.fling(find.byType(Scaffold), const Offset(-500, 0), 1600);
    await tester.pump(const Duration(milliseconds: 80));
    final plane = find.byKey(const ValueKey('cover-flow-plane'));
    expect(
      tester.widget<Transform>(plane).transform.entry(2, 0),
      greaterThan(0),
    );
    await tester.fling(find.byType(Scaffold), const Offset(500, 0), 1600);
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(tester.widget<Transform>(plane).transform.entry(2, 0), lessThan(0));
    for (var i = 0; i < 300; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(
      tester.widget<Transform>(plane).transform.entry(2, 0),
      closeTo(0, 0.001),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
    expect(tester.binding.hasScheduledFrame, isFalse);
    tester.view.physicalSize = const Size(400, 800);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 550));
    expect(find.byType(InteractiveViewer), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
