import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musaic/features/canvas/album_canvas_viewport.dart';
import 'package:musaic/features/canvas/canvas_drift.dart';
import 'package:musaic/features/canvas/canvas_interaction_state.dart';
import 'package:musaic/features/canvas/home_album_layout_state.dart';
import 'package:musaic/features/canvas/portrait_tilt.dart';
import 'package:musaic/features/music/playback/album_playback.dart';
import 'package:sensors_plus/sensors_plus.dart';

void main() {
  testWidgets('the canvas preserves the portrait sensor plane across rebuilds', (
    tester,
  ) async {
    final events = StreamController<AccelerometerEvent>.broadcast();
    addTearDown(events.close);
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
      home: PortraitTilt(
        events: events.stream,
        child: AlbumCanvasViewport(
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

    Matrix4 matrix() => tester.widget<Transform>(
      find.byKey(const ValueKey('portrait-sensor-plane')),
    ).transform;
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
  });
}
