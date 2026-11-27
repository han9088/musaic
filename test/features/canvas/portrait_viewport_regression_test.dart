import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musaic/app/bottom_sheet_host.dart';
import 'package:musaic/features/artwork/presentation/artwork_source_view.dart';
import 'package:musaic/features/artwork/presentation/custom_artwork_scope.dart';
import 'package:musaic/features/canvas/album_canvas_viewport.dart';
import 'package:musaic/features/canvas/canvas_drift.dart';
import 'package:musaic/features/canvas/canvas_interaction_state.dart';
import 'package:musaic/features/canvas/home_album_layout_state.dart';
import 'package:musaic/features/canvas/portrait_tilt.dart';
import 'package:musaic/features/coverflow/album_coverflow.dart';
import 'package:musaic/features/music/catalog/album_track_list.dart';
import 'package:musaic/features/music/playback/album_play_button.dart';
import 'package:musaic/features/music/playback/album_playback.dart';
import 'package:musaic/features/music/playback/now_playing_capsule.dart';
import 'package:musaic/l10n/generated/app_localizations.dart';
import 'package:musaic/pages/home/home_page.dart';
import 'package:musaic/pages/home/home_sheet.dart';
import 'package:musaic/services/mock_album_cache.dart';
import 'package:musaic/services/music/music_source_controller.dart';
import 'package:musaic/storage/music/custom_artwork_store.dart';
import 'package:musaic/ui/bottom_sheet/bottom_sheet.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

class _FixedAlbumCache extends MockAlbumCache {
  _FixedAlbumCache({this.trackCount, this.asset = 'assets/albums/0.jpg'});

  final int? trackCount;
  final String asset;

  @override
  Future<List<Map<String, dynamic>>> load() async => [
    {
      'asset': asset,
      'title': 'Album',
      'artist': 'Artist',
      if (trackCount != null) 'trackCount': trackCount,
    },
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

class _CountingAlbumLayout extends HomeAlbumLayoutState {
  int lookups = 0;

  @override
  Map<String, dynamic> albumAt(
    int row,
    int column,
    List<Map<String, dynamic>> albums,
  ) {
    lookups++;
    return super.albumAt(row, column, albums);
  }
}

void main() {
  testWidgets('color organization keeps covers while no colors are indexed', (
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
        home: AppBottomSheetHost(
          child: HomePage(
            albumCache: _FixedAlbumCache(asset: 'local:placeholder'),
          ),
        ),
      ),
    );
    await tester.pump();
    final settings = tester.widget<HomeSheet>(find.byType(HomeSheet));
    expect(find.byType(AlbumCanvasViewport), findsOneWidget);
    expect(settings.colorIndex!.availableFamilies, isEmpty);

    settings.onColorOrganizeChanged!(true);
    await tester.pump(const Duration(milliseconds: 250));
    expect(tester.takeException(), isNull);
    final viewport = tester.widget<AlbumCanvasViewport>(
      find.byType(AlbumCanvasViewport),
    );
    expect(viewport.albums.single['title'], 'Album');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('color-organized canvas can switch to an empty local library', (
    tester,
  ) async {
    addTearDown(tester.pump);
    final preferences = SharedPreferencesAsyncPlatform.instance;
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    addTearDown(() => SharedPreferencesAsyncPlatform.instance = preferences);
    final sources = MusicSourceController();
    addTearDown(sources.dispose);
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AppBottomSheetHost(
          child: HomePage(albumCache: _FixedAlbumCache(), sources: sources),
        ),
      ),
    );
    await tester.pump();
    final viewport = find.byType(AlbumCanvasViewport);
    final sheet = tester.widget<HomeSheet>(find.byType(HomeSheet));
    final album = tester.widget<AlbumCanvasViewport>(viewport).albums.single;
    sheet.onColorOrganizeChanged!(true);
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.takeException(), isNull);
    expect(tester.widget<AlbumCanvasViewport>(viewport).albums, [album]);

    sheet.colorIndex!.register(album, Colors.red);
    await tester.pump();
    sheet.onColorFamilySelected!(sheet.colorIndex!.availableFamilies.single);
    await tester.pump(const Duration(milliseconds: 200));
    expect(
      tester.widget<AlbumCanvasViewport>(viewport).layout.colorOrganized,
      isTrue,
    );

    final selection = sheet.onSourceSelection!(() async {
      sources.catalog.value = const [];
    });
    await tester.pump();
    expect(tester.takeException(), isNull);
    final outgoing = tester.widget<AlbumCanvasViewport>(viewport);
    expect(outgoing.albums, [album]);
    expect(outgoing.layout.colorOrganized, isTrue);
    for (var frame = 0; frame < 150 && sheet.sourceSwitching!.value; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(sheet.sourceSwitching!.value, isFalse);
    await selection;
    final localizations = AppLocalizations.of(
      tester.element(find.byType(HomePage)),
    );
    expect(find.text(localizations.musicSourceEmpty), findsOneWidget);
    expect(viewport, findsNothing);
    expect(sheet.colorIndex!.availableFamilies, isEmpty);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    // Let artwork reads from the outgoing Android canvas reach their timeout.
    await tester.pump(const Duration(seconds: 4));
  });

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

  testWidgets('repeated covers keep one tappable semantic entry per album', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final transform = TransformationController(
      Matrix4.diagonal3Values(0.4, 0.4, 1)
        ..setEntry(0, 3, 13)
        ..setEntry(1, 3, 17),
    );
    final layout = _CountingAlbumLayout();
    final playback = AlbumPlayback();
    final selected = <String>[];
    const albums = [
      {'asset': 'local:one', 'title': 'First album'},
      {'asset': 'local:two', 'title': 'Second album'},
    ];
    addTearDown(transform.dispose);
    addTearDown(playback.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: AlbumCanvasViewport(
          albums: albums,
          layout: layout,
          transform: transform,
          interaction: CanvasInteractionState(CanvasDrift()),
          playback: playback,
          xerox: false,
          interactionBlocked: false,
          onViewportSizeChanged: (_) {},
          onTileSelected: (row, column) => selected.add(
            layout.albumAt(row, column, albums)['title'] as String,
          ),
          animateSourceTile: (_, _, child) => child,
        ),
      ),
    );

    final first = find.semantics.byLabel('First album');
    final second = find.semantics.byLabel('Second album');
    expect(first, findsOneWidget);
    expect(second, findsOneWidget);

    final initialNode = first.evaluate().single.id;
    layout.lookups = 0;
    transform.value = transform.value.clone()..setEntry(0, 3, 13.25);
    await tester.pump();
    expect(layout.lookups, isZero);
    expect(first.evaluate().single.id, initialNode);

    transform.value = transform.value.clone()..setEntry(0, 3, -850);
    await tester.pump();
    expect(first, findsOneWidget);
    expect(second, findsOneWidget);
    tester.semantics.tap(first);
    expect(selected, ['First album']);
    await tester.pumpWidget(const SizedBox.shrink());
    handle.dispose();
  });

  testWidgets('a vertical fling hands motion to canvas drift on release', (
    tester,
  ) async {
    final transform = TransformationController(
      Matrix4.diagonal3Values(0.4, 0.4, 1),
    );
    final drift = CanvasDrift();
    final playback = AlbumPlayback();
    addTearDown(transform.dispose);
    addTearDown(playback.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: AlbumCanvasViewport(
          albums: const [
            {'asset': 'local:placeholder', 'title': 'Album'},
          ],
          layout: HomeAlbumLayoutState(),
          transform: transform,
          interaction: CanvasInteractionState(drift),
          playback: playback,
          xerox: false,
          interactionBlocked: false,
          onViewportSizeChanged: (_) {},
          onTileSelected: (_, _) {},
          animateSourceTile: (_, _, child) => child,
        ),
      ),
    );

    final placeholders = tester.widgetList<RawImage>(find.byType(RawImage));
    expect(placeholders.length, greaterThan(1));
    expect(placeholders.map((tile) => tile.image).toSet(), hasLength(1));

    await tester.fling(
      find.byType(AlbumCanvasViewport),
      const Offset(0, -180),
      2400,
    );
    expect(drift.velocity.dy, lessThan(-2000));
    await tester.pump();
    drift.advance(Duration.zero, transform, enabled: true);
    const frame = Duration(milliseconds: 8);
    drift.advance(frame, transform, enabled: true);
    final driftPosition = transform.value.entry(1, 3);
    await tester.pump(frame);

    expect(transform.value.entry(1, 3), driftPosition);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('sensor shake does not reverse slow minimum-zoom drift', (
    tester,
  ) async {
    final events = StreamController<AccelerometerEvent>.broadcast();
    final originalSensors = SensorsPlatform.instance;
    SensorsPlatform.instance = _ControlledSensors(events.stream);
    final transform = TransformationController(
      Matrix4.diagonal3Values(0.4, 0.4, 1),
    );
    final drift = CanvasDrift()..velocity = const Offset(0, -12);
    final playback = AlbumPlayback();
    tester.view.physicalSize = const Size(1280, 2772);
    tester.view.devicePixelRatio = 3.25;
    addTearDown(() async {
      SensorsPlatform.instance = originalSensors;
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
          interaction: CanvasInteractionState(drift),
          playback: playback,
          xerox: false,
          interactionBlocked: false,
          onViewportSizeChanged: (_) {},
          onTileSelected: (_, _) {},
          animateSourceTile: (_, _, child) => child,
        ),
      ),
    );

    void sample(double z) =>
        events.add(AccelerometerEvent(0, 9.81, z, DateTime(2026)));
    sample(0);
    await tester.pump();

    // A cover near the screen edge is most sensitive to perspective changes.
    final tile = find.byKey(const ValueKey((20, 4)));
    var previousY = tester.getCenter(tile).dy;
    var largestReverse = 0.0;
    const frame = Duration(microseconds: 8333);
    drift.advance(Duration.zero, transform, enabled: true);
    for (var i = 1; i <= 120; i++) {
      if (i % 4 == 0) sample(1.2 * math.sin(i * math.pi / 16));
      drift.advance(frame * i, transform, enabled: true);
      await tester.pump(frame);
      final y = tester.getCenter(tile).dy;
      largestReverse = math.max(largestReverse, y - previousY);
      previousY = y;
    }
    expect(largestReverse, lessThan(1e-6));
    expect(transform.value.entry(1, 3), closeTo(-12, 0.001));
    await tester.pumpWidget(const SizedBox.shrink());
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

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

  testWidgets('the cover menu freezes canvas drift and tilt until it closes', (
    tester,
  ) async {
    final events = StreamController<AccelerometerEvent>.broadcast();
    final previousSensors = SensorsPlatform.instance;
    SensorsPlatform.instance = _ControlledSensors(events.stream);
    final store = CustomArtworkStore();
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() async {
      SensorsPlatform.instance = previousSensors;
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      await events.close();
      store.dispose();
    });
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: CustomArtworkScope(
          store: store,
          child: HomePage(albumCache: _FixedAlbumCache()),
        ),
      ),
    );
    await tester.pump();
    final transform = tester
        .widget<InteractiveViewer>(find.byType(InteractiveViewer))
        .transformationController!;
    Matrix4 tilt() => tester
        .widget<Transform>(find.byKey(const ValueKey('portrait-sensor-plane')))
        .transform;

    events.add(AccelerometerEvent(0, 0, 9.81, DateTime(2026)));
    await tester.pump();
    await tester.flingFrom(const Offset(200, 400), const Offset(0, -160), 2400);
    await tester.longPressAt(const Offset(200, 400));
    await tester.pump();
    expect(find.text('Add cover'), findsOneWidget);
    final frozenPosition = transform.value.clone();
    final frozenTilt = tilt().clone();
    for (var i = 0; i < 10; i++) {
      events.add(AccelerometerEvent(7, 0, 7, DateTime(2026)));
      await tester.pump(const Duration(milliseconds: 32));
      expect(transform.value, frozenPosition);
      expect(tilt(), frozenTilt);
    }

    await tester.tapAt(const Offset(24, 120));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(transform.value, frozenPosition);
    expect(tilt(), frozenTilt);

    await tester.pump(const Duration(milliseconds: 120));
    for (var i = 0; i < 8; i++) {
      events.add(AccelerometerEvent(7, 0, 7, DateTime(2026)));
      await tester.pump(const Duration(milliseconds: 32));
    }
    expect(find.text('Add cover'), findsNothing);
    expect(transform.value, isNot(frozenPosition));
    expect(tilt(), isNot(frozenTilt));
    await tester.pumpWidget(const SizedBox.shrink());
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('a single track keeps its artwork in the canvas preview', (
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
        home: HomePage(albumCache: _FixedAlbumCache(trackCount: 1)),
      ),
    );
    await tester.pump();
    const tap = Offset(150, 250);
    final scene = tester
        .widget<InteractiveViewer>(find.byType(InteractiveViewer))
        .transformationController!
        .toScene(tap);
    final cell = ((scene.dy / 100).floor(), (scene.dx / 100).floor());
    await tester.tapAt(tap);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    final cover = tester.getRect(
      find.byKey(ValueKey(('selected-cover', cell))),
    );
    await tester.tapAt(cover.topLeft + const Offset(12, 12));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final popup = find.byKey(const ValueKey('album-cover-popup'));
    Finder inPopup(Type type) =>
        find.descendant(of: popup, matching: find.byType(type));
    expect(inPopup(ArtworkSourceView), findsOneWidget);
    expect(inPopup(AlbumTrackList), findsNothing);
    expect(inPopup(AlbumPlayButton), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

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
