import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musaic/features/canvas/album_artwork_atlas.dart';
import 'package:musaic/features/canvas/album_canvas_viewport.dart';
import 'package:musaic/features/canvas/album_grid_snapshot.dart';
import 'package:musaic/features/canvas/album_sprite_canvas.dart';
import 'package:musaic/features/canvas/canvas_drift.dart';
import 'package:musaic/features/canvas/canvas_interaction_state.dart';
import 'package:musaic/features/canvas/home_album_layout_state.dart';
import 'package:musaic/features/canvas/portrait_tilt.dart';
import 'package:musaic/features/music/playback/album_playback.dart';

void main() {
  testWidgets('prepared assets switch the viewport to the batched renderer', (
    tester,
  ) async {
    const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
    final cache = Directory.systemTemp.createTempSync('musaic-sprite-test-');
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(pathChannel, (_) async => cache.path);
    addTearDown(() {
      messenger.setMockMethodCallHandler(pathChannel, null);
      cache.deleteSync(recursive: true);
    });
    final transform = TransformationController();
    final playback = AlbumPlayback();
    final layout = HomeAlbumLayoutState();
    final interaction = CanvasInteractionState(CanvasDrift());
    addTearDown(transform.dispose);
    addTearDown(playback.dispose);
    Widget app(String source) => MaterialApp(
      home: AlbumCanvasViewport(
        albums: [
          {'asset': source, 'title': 'Album'},
        ],
        layout: layout,
        transform: transform,
        interaction: interaction,
        playback: playback,
        xerox: false,
        interactionBlocked: false,
        onViewportSizeChanged: (_) {},
        onTileSelected: (_, _) {},
        animateSourceTile: (_, _, child) => child,
      ),
    );

    await tester.pumpWidget(app('assets/albums/0.jpg'));
    final batched = find.byType(AlbumSpriteCanvas);
    for (var i = 0; i < 25 && batched.evaluate().isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
      await tester.pump();
    }
    expect(batched, findsOneWidget);

    await tester.pumpWidget(app('local:missing'));
    expect(batched, findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets(
    'batched covers retain gestures, selected hit targets and semantics',
    (tester) async {
      tester.view.physicalSize = const Size(344, 704);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final semantics = tester.ensureSemantics();

      final atlas = (await tester.runAsync(() async {
        final images = <String, ui.Image>{};
        for (final (title, color) in [
          ('Red', Colors.red),
          ('Blue', Colors.blue),
        ]) {
          final recorder = ui.PictureRecorder();
          const extent = albumCanvasArtworkResolution;
          Canvas(recorder).drawRect(
            Rect.fromLTWH(0, 0, extent.toDouble(), extent.toDouble()),
            Paint()..color = color,
          );
          final picture = recorder.endRecording();
          images[title] = picture.toImageSync(extent, extent);
          picture.dispose();
        }
        try {
          return await CanvasArtworkAtlas.pack(images);
        } finally {
          for (final image in images.values) {
            image.dispose();
          }
        }
      }))!;
      addTearDown(atlas.dispose);
      final transform = TransformationController(
        Matrix4.diagonal3Values(.4, .4, .4)
          ..setEntry(0, 3, 13)
          ..setEntry(1, 3, 17),
      );
      addTearDown(transform.dispose);
      final taps = <(int, int)>[];
      final longPresses = <(int, int)>[];
      var opened = false;
      String album(int row, int column) =>
          gridAlbumIndex(row, column, 2) == 0 ? 'Red' : 'Blue';

      Widget app({(int, int)? selected, (int, int)? hidden}) => MaterialApp(
        home: PortraitTilt(
          child: InteractiveViewer(
            constrained: false,
            clipBehavior: Clip.none,
            transformationController: transform,
            boundaryMargin: const EdgeInsets.all(double.infinity),
            child: AlbumSpriteCanvas(
              viewport: const Size(344, 704),
              tiltPadding: PortraitTilt.viewportPadding(const Size(344, 704)),
              transform: transform,
              atlas: atlas,
              albumAt: album,
              titleAt: album,
              onTileSelected: (row, column) => taps.add((row, column)),
              longPressAt: (row, column) =>
                  (_) => longPresses.add((row, column)),
              selected: selected,
              hidden: hidden,
              child: selected == null
                  ? null
                  : GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => opened = true,
                      child: const SizedBox.expand(),
                    ),
            ),
          ),
        ),
      );

      await tester.pumpWidget(app());
      final red = find.semantics.byLabel('Red');
      final blue = find.semantics.byLabel('Blue');
      expect(red, findsOneWidget);
      expect(blue, findsOneWidget);
      final redNode = red.evaluate().single.id;

      await tester.tapAt(const Offset(2, 2));
      expect(taps.removeLast(), (-1, -1));
      await tester.longPressAt(const Offset(26, 41));
      expect(longPresses, [(0, 0)]);
      expect(taps, isEmpty);

      transform.value = transform.value.clone()..setEntry(0, 3, 13.25);
      await tester.pump();
      expect(red.evaluate().single.id, redNode);
      tester.semantics.tap(red);
      expect(taps, hasLength(1));

      await tester.pumpWidget(app(selected: (0, 0)));
      await tester.tapAt(const Offset(26, 41));
      expect(opened, isTrue);
      expect(taps, hasLength(1));

      opened = false;
      await tester.pumpWidget(app(selected: (0, 0), hidden: (0, 0)));
      await tester.tapAt(const Offset(26, 41));
      expect(opened, isFalse);
      expect(taps, hasLength(1));
      await tester.pumpWidget(const SizedBox.shrink());
      semantics.dispose();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
}
