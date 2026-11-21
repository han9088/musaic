import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musaic/app/bottom_sheet_host.dart';
import 'package:musaic/features/canvas/album_canvas_viewport.dart';
import 'package:musaic/features/canvas/canvas_drift.dart';
import 'package:musaic/features/canvas/canvas_interaction_state.dart';
import 'package:musaic/features/canvas/home_album_layout_state.dart';
import 'package:musaic/features/canvas/portrait_tilt.dart';
import 'package:musaic/features/coverflow/album_coverflow.dart';
import 'package:musaic/features/music/playback/album_playback.dart';
import 'package:musaic/features/music/playback/now_playing_capsule.dart';
import 'package:musaic/l10n/generated/app_localizations.dart';
import 'package:musaic/pages/home/home_page.dart';
import 'package:musaic/pages/home/home_sheet.dart';
import 'package:musaic/services/mock_album_cache.dart';
import 'package:musaic/ui/bottom_sheet/bottom_sheet.dart';
import 'package:sensors_plus/sensors_plus.dart';

class _FixedAlbumCache extends MockAlbumCache {
  @override
  Future<List<Map<String, dynamic>>> load() async => [
    {'asset': 'assets/albums/0.jpg', 'title': 'Album', 'artist': 'Artist'},
  ];

  @override
  Future<void> warmImages(
    Future<void> Function(ImageProvider) precache,
  ) async {}
}

class _ControlledSensors extends SensorsPlatform {
  _ControlledSensors(this.events);

  final Stream<AccelerometerEvent> events;

  @override
  Stream<AccelerometerEvent> accelerometerEventStream({
    Duration samplingPeriod = SensorInterval.normalInterval,
  }) => events;
}

void main() {
  testWidgets('the entire visible tilted canvas accepts pans at minimum zoom', (
    tester,
  ) async {
    final events = StreamController<AccelerometerEvent>.broadcast();
    final oldSensors = SensorsPlatform.instance;
    SensorsPlatform.instance = _ControlledSensors(events.stream);
    final transform = TransformationController();
    final interaction = CanvasInteractionState(CanvasDrift());
    final playback = AlbumPlayback();
    final selected = <(int, int)>[];
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() async {
      SensorsPlatform.instance = oldSensors;
      await events.close();
      transform.dispose();
      playback.dispose();
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      MaterialApp(
        home: AlbumCanvasViewport(
          albums: const [
            {'asset': 'local:placeholder', 'title': 'Album'},
          ],
          layout: HomeAlbumLayoutState(),
          transform: transform,
          interaction: interaction,
          playback: playback,
          xerox: false,
          interactionBlocked: false,
          onViewportSizeChanged: (_) {},
          onTileSelected: (row, column) => selected.add((row, column)),
          animateSourceTile: (_, _, child) => child,
        ),
      ),
    );
    events.add(AccelerometerEvent(0, 0, 9.81, DateTime(2026)));
    await tester.pump();
    for (var i = 0; i < 20; i++) {
      events.add(AccelerometerEvent(6.4, 2.5, 7, DateTime(2026)));
      await tester.pump(const Duration(milliseconds: 32));
    }
    await tester.pump(const Duration(milliseconds: 180));

    final missed = <String>[];
    for (final x in [5.0, 18.0, 200.0, 382.0, 395.0]) {
      for (final y in [11.0, 400.0, 722.0]) {
        transform.value = Matrix4.diagonal3Values(0.4, 0.4, 0.4);
        await tester.pump(const Duration(milliseconds: 16));
        final touch = await tester.startGesture(Offset(x, y));
        final pointerArrived = interaction.pressedPointers.isNotEmpty;
        final inward = Offset(x > 200 ? -1 : 1, y > 400 ? -1 : 1);
        await touch.moveBy(inward * 24);
        await tester.pump(const Duration(milliseconds: 12));
        await touch.moveBy(inward * 44);
        await tester.pump(const Duration(milliseconds: 12));
        final shift = transform.value.getTranslation().length;
        if (shift < 4) missed.add('$x,$y pointer=$pointerArrived');
        await touch.up();
        await tester.pump();
      }
    }
    expect(missed, isEmpty);

    const edge = Offset(395, 722);
    final projection = tester
        .widget<Transform>(find.byKey(const ValueKey('portrait-sensor-plane')))
        .transform;
    final centered = Matrix4.translationValues(200, 400, 0)
      ..multiply(projection)
      ..translateByDouble(-200, -400, 0, 1);
    final local = MatrixUtils.transformPoint(
      Matrix4.inverted(PointerEvent.removePerspectiveTransform(centered)),
      edge,
    );
    expect(local.dx, greaterThan(400));
    // Put a cell boundary between the nominal viewport and the actual tap.
    final shift = ((local.dx + 400) / 2) % 40;
    transform.value = Matrix4.diagonal3Values(0.4, 0.4, 0.4)
      ..setEntry(0, 3, shift);
    await tester.pump();
    await tester.tapAt(edge);
    expect(selected, [
      ((local.dy / 40).floor(), ((local.dx - shift) / 40).floor()),
    ]);

    final inner = await tester.startGesture(const Offset(205, 722));
    final outer = await tester.startGesture(edge);
    expect(interaction.pressedPointers, hasLength(2));
    await inner.moveBy(const Offset(-35, 0));
    await inner.moveBy(const Offset(-40, 0));
    await tester.pump();
    expect(transform.value.getColumn(0).length, greaterThan(0.45));
    await outer.up();
    await inner.up();
    await tester.pumpWidget(const SizedBox.shrink());
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets(
    'the canvas retains overlapping covers while panning at minimum zoom',
    (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final transform = TransformationController();
      final playback = AlbumPlayback();
      addTearDown(transform.dispose);
      addTearDown(playback.dispose);
      var coverBuilds = 0;
      void moveTo(double zoom, double x) {
        transform.value = Matrix4.diagonal3Values(zoom, zoom, 1)
          ..setEntry(0, 3, x)
          ..setEntry(1, 3, 17);
      }

      moveTo(0.4, 13);
      await tester.pumpWidget(
        MaterialApp(
          home: AlbumCanvasViewport(
            albums: const [
              {'asset': 'local:placeholder', 'title': 'Album'},
            ],
            layout: HomeAlbumLayoutState(),
            transform: transform,
            interaction: CanvasInteractionState(CanvasDrift()),
            playback: playback,
            xerox: false,
            interactionBlocked: false,
            onViewportSizeChanged: (_) {},
            onTileSelected: (_, _) {},
            animateSourceTile: (_, _, child) {
              coverBuilds++;
              return child;
            },
          ),
        ),
      );
      final initialBuilds = coverBuilds;
      expect(initialBuilds, greaterThan(300));

      coverBuilds = 0;
      moveTo(0.4, 14);
      await tester.pump();
      moveTo(0.4001, 14);
      await tester.pump();
      expect(
        coverBuilds,
        0,
        reason: 'the tile window and decode tiers are stable',
      );

      moveTo(0.4001, -120);
      await tester.pump();
      expect(coverBuilds, inExclusiveRange(0, initialBuilds ~/ 4));
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final transition in ['BottomSheet', 'Cover Flow']) {
    testWidgets('tilt responds after returning from $transition', (
      tester,
    ) async {
      var listens = 0;
      final events = StreamController<AccelerometerEvent>.broadcast(
        onListen: () => listens++,
      );
      final originalSensors = SensorsPlatform.instance;
      SensorsPlatform.instance = _ControlledSensors(events.stream);
      addTearDown(() {
        SensorsPlatform.instance = originalSensors;
        unawaited(events.close());
      });
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: AppBottomSheetHost(
            child: HomePage(albumCache: _FixedAlbumCache()),
          ),
        ),
      );
      await tester.pump();

      Future<void> holdAt(double degrees) async {
        final radians = degrees * math.pi / 180;
        for (var i = 0; i < 24; i++) {
          events.add(
            AccelerometerEvent(
              0,
              9.81 * math.cos(radians),
              9.81 * math.sin(radians),
              DateTime(2026),
            ),
          );
          await tester.pump(const Duration(milliseconds: 32));
        }
        await tester.pump(const Duration(milliseconds: 160));
      }

      double pitch() => tester
          .widget<Transform>(
            find.byKey(const ValueKey('portrait-sensor-plane')),
          )
          .transform
          .entry(2, 1)
          .abs();

      if (transition == 'BottomSheet') {
        await holdAt(0);
        final sheet = DeskBottomSheet.of(tester.element(find.byType(HomePage)));
        final gesture = await tester.startGesture(
          tester.getCenter(find.byType(NowPlayingCapsule)),
        );
        await gesture.moveBy(const Offset(0, -25));
        await gesture.moveBy(const Offset(0, -125));
        await gesture.up();
        await tester.pump();
        expect(sheet.isPresented, isTrue);
        await holdAt(60);
        sheet.dismiss();
        await holdAt(60);
        await tester.pump(const Duration(milliseconds: 200));
        expect(sheet.isPresented, isFalse);
      } else {
        tester
            .widget<HomeSheet>(find.byType(HomeSheet))
            .manualRotation!
            .setEnabled(true);
        await tester.pump(const Duration(milliseconds: 200));
        final switchButton = find.byKey(const ValueKey('layout-switch'));
        await tester.tap(switchButton);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 550));
        expect(find.byType(AlbumCoverFlow), findsOneWidget);
        expect(events.hasListener, isFalse);
        await tester.tap(switchButton);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 550));
        await holdAt(0);
        await holdAt(60);
      }

      expect(events.hasListener, isTrue);
      final steep = pitch();
      expect(steep, greaterThan(0.1));
      await holdAt(45);
      expect(pitch(), lessThan(steep - 0.005), reason: '60° → 45°');
      await holdAt(0);
      expect(pitch(), lessThan(0.001));

      await holdAt(45);
      expect(pitch(), greaterThan(0.1));
      final listensBeforeStall = listens;
      if (transition == 'BottomSheet') {
        for (var i = 0; i < 40; i++) {
          events.add(AccelerometerEvent(0, 0, 0, DateTime(2026)));
          await tester.pump(const Duration(milliseconds: 32));
        }
      } else {
        await tester.pump(const Duration(seconds: 2));
      }
      await tester.pump(const Duration(milliseconds: 200));
      expect(pitch(), 0, reason: 'stale tilt must return to neutral');
      expect(listens - listensBeforeStall, transition == 'Cover Flow' ? 1 : 0);
      await holdAt(45);
      expect(pitch(), 0, reason: 'the first fresh pose becomes neutral');
      await holdAt(0);
      expect(pitch(), greaterThan(0.1));
      await tester.pumpWidget(const SizedBox.shrink());
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  }

  testWidgets('HomePage keeps the sensor plane inside the infinite viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: HomePage(albumCache: _FixedAlbumCache()),
      ),
    );
    await tester.pump();
    expect(find.byType(PortraitTilt), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AlbumCanvasViewport),
        matching: find.byType(PortraitTilt),
      ),
      findsOneWidget,
    );
    expect(find.byType(InteractiveViewer), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'the canvas preserves the portrait sensor plane across rebuilds',
    (tester) async {
      final events = StreamController<AccelerometerEvent>.broadcast();
      addTearDown(events.close);
      final originalSensors = SensorsPlatform.instance;
      final originalPlatformOverride = debugDefaultTargetPlatformOverride;
      SensorsPlatform.instance = _ControlledSensors(events.stream);
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() {
        SensorsPlatform.instance = originalSensors;
        debugDefaultTargetPlatformOverride = originalPlatformOverride;
      });
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final transform = TransformationController();
      final playback = AlbumPlayback();
      addTearDown(transform.dispose);
      addTearDown(playback.dispose);
      final layout = HomeAlbumLayoutState();
      final interaction = CanvasInteractionState(CanvasDrift());

      Widget canvas({bool xerox = false}) => MaterialApp(
        home: AlbumCanvasViewport(
          albums: const [
            {
              'asset': 'assets/albums/0.jpg',
              'title': 'Album',
              'artist': 'Artist',
            },
          ],
          layout: layout,
          transform: transform,
          interaction: interaction,
          playback: playback,
          xerox: xerox,
          interactionBlocked: false,
          onViewportSizeChanged: (_) {},
          onTileSelected: (_, _) {},
          animateSourceTile: (_, _, child) => child,
        ),
      );

      await tester.pumpWidget(canvas());
      expect(find.byType(PortraitTilt), findsOneWidget);
      expect(find.byType(InteractiveViewer), findsOneWidget);
      expect(events.hasListener, isTrue);

      void emit(double x, double y, double z) {
        events.add(AccelerometerEvent(x, y, z, DateTime(2026)));
      }

      emit(0, 9.81, 0);
      await tester.pump();
      for (var i = 0; i < 12; i++) {
        emit(4, 8, 4);
        await tester.pump(const Duration(milliseconds: 32));
      }
      await tester.pumpAndSettle();

      Matrix4 matrix() => tester
          .widget<Transform>(
            find.byKey(const ValueKey('portrait-sensor-plane')),
          )
          .transform;
      final tilted = matrix().entry(0, 2);
      expect(tilted.abs(), greaterThan(0.01));

      await tester.pumpWidget(canvas(xerox: true));
      await tester.pump();
      expect(events.hasListener, isTrue);
      expect(matrix().entry(0, 2), closeTo(tilted, 1e-6));
      expect(find.byType(PortraitTilt), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(events.hasListener, isFalse);
      SensorsPlatform.instance = originalSensors;
      debugDefaultTargetPlatformOverride = originalPlatformOverride;
    },
  );
}
