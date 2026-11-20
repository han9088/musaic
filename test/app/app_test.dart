import 'package:flutter_test/flutter_test.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musaic/main.dart' as app;
import 'package:musaic/features/coverflow/album_coverflow.dart';
import 'package:musaic/features/canvas/album_canvas.dart';
import 'package:musaic/features/canvas/portrait_tilt.dart';
import 'package:musaic/features/canvas/selected_album.dart';
import 'package:musaic/features/music/playback/album_play_button.dart';

void main() {
  testWidgets('Musaic starts with its own app title', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    tester.view.viewPadding = const FakeViewPadding(top: 62, bottom: 34);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewPadding);
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
    final popup = find.byKey(const ValueKey('album-cover-popup'));
    AlbumCanvas canvas() =>
        tester.widget<AlbumCanvas>(find.byType(AlbumCanvas));
    Future<void> dismissAlbum(Offset hiddenOffset) async {
      await tester.tapAt(const Offset(16, 20));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 459));
      expect(canvas().hiddenTileOffset, hiddenOffset);
      await tester.pump(const Duration(milliseconds: 2));
      expect(
        canvas().hiddenTileOffset,
        isNull,
        reason: 'Paint the source in the frame that ends the reverse animation',
      );
      expect(popup, findsNothing);
      await tester.pump(const Duration(milliseconds: 250));
    }

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
    const tapPoint = Offset(150, 250);
    final scenePoint = controller.toScene(tapPoint);
    final source = find.byKey(
      ValueKey(((scenePoint.dy / 100).floor(), (scenePoint.dx / 100).floor())),
    );
    final originalWidth = tester.getRect(source).width;
    final selectedPosition = controller.value.clone();
    await tester.tapAt(tapPoint);
    await tester.pump();
    expect(popup, findsNothing);
    await tester.pump(const Duration(milliseconds: 250));
    final lifted = find
        .descendant(
          of: find.byType(SelectedAlbum),
          matching: find.byType(GestureDetector),
        )
        .first;
    final liftedBounds = tester.getRect(lifted);
    expect(liftedBounds.width, closeTo(originalWidth * 1.16, 0.001));
    expect(popup, findsNothing);

    final sourceTile = tester.widget<Positioned>(source);
    final hiddenOffset = Offset(sourceTile.left!, sourceTile.top!);
    expect(canvas().hiddenTileOffset, isNull);
    await tester.tapAt(liftedBounds.topLeft + const Offset(12, 12));
    await tester.pump();
    expect(canvas().hiddenTileOffset, hiddenOffset);
    expect(
      (tester.getTopLeft(popup) - liftedBounds.topLeft).distance,
      lessThan(0.001),
    );
    await tester.pump(const Duration(milliseconds: 120));
    final flip = find.ancestor(of: popup, matching: find.byType(Transform));
    expect(
      tester.widget<Transform>(flip).transform.entry(2, 0),
      greaterThan(0.05),
    );
    final fades = find.ancestor(
      of: popup,
      matching: find.byType(FadeTransition),
    );
    expect(fades, findsNothing);
    await tester.pump(const Duration(milliseconds: 180));
    expect(
      tester.widget<Transform>(flip).transform.entry(2, 0),
      lessThan(-0.05),
    );
    await tester.pump(const Duration(milliseconds: 180));
    expect(tester.getSize(popup), const Size.square(352));
    expect(tester.getCenter(popup), const Offset(200, 400));
    expect(controller.value, selectedPosition);
    final popupPlay = find.descendant(
      of: popup,
      matching: find.byIcon(PhosphorIcons.playFill),
    );
    expect(tester.getSize(popupPlay).width, greaterThan(32));
    await tester.tap(popupPlay);
    await tester.pump();
    final popupPause = find.descendant(
      of: popup,
      matching: find.byIcon(PhosphorIcons.pauseFill),
    );
    await tester.tap(popupPause);
    await tester.pump();
    await dismissAlbum(hiddenOffset);
    expect(find.byType(SelectedAlbum), findsOneWidget);
    expect(canvas().hiddenTileOffset, isNull);
    await tester.tap(
      find.descendant(
        of: find.byType(SelectedAlbum),
        matching: find.byType(AlbumPlayButton),
      ),
    );
    await tester.pump();
    expect(find.byIcon(PhosphorIcons.pauseFill), findsOneWidget);
    expect(popup, findsNothing);
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
      expect(popup, findsNothing);
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
        matching: find.byType(AlbumPlayButton),
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
      final padding = PortraitTilt.viewportPadding(const Size(400, 800));
      final translation = controller.value.getTranslation();
      expect(
        covers
            .map((cell) => cell.left! * scale + translation.x)
            .reduce((a, b) => a < b ? a : b),
        lessThanOrEqualTo(-padding.dx),
      );
      expect(
        covers
            .map((cell) => (cell.left! + 100) * scale + translation.x)
            .reduce((a, b) => a > b ? a : b),
        greaterThanOrEqualTo(400 + padding.dx),
      );
      expect(
        covers
            .map((cell) => cell.top! * scale + translation.y)
            .reduce((a, b) => a < b ? a : b),
        lessThanOrEqualTo(-padding.dy),
      );
      expect(
        covers
            .map((cell) => (cell.top! + 100) * scale + translation.y)
            .reduce((a, b) => a > b ? a : b),
        greaterThanOrEqualTo(800 + padding.dy),
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
