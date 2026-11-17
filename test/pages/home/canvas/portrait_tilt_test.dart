import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musaic/features/canvas/portrait_tilt.dart';
import 'package:sensors_plus/sensors_plus.dart';

void main() {
  test('overscanned album plane covers every screen corner at every tilt', () {
    for (final size in [
      const Size(390, 844),
      const Size(768, 1024),
      const Size(1024, 2200),
    ]) {
      final center = size.center(Offset.zero);
      final screen = Offset.zero & size;
      final painted = screen.inflate(PortraitTilt.overscan(size));
      for (var direction = 0; direction < 360; direction += 5) {
        final angle = Offset.fromDirection(
          direction * math.pi / 180,
          PortraitTiltMotion.maxAngle,
        );
        final projection = PortraitTilt.projection(angle, size);
        final polygon = Path()
          ..addPolygon([
            for (final corner in [
              painted.topLeft,
              painted.topRight,
              painted.bottomRight,
              painted.bottomLeft,
            ])
              MatrixUtils.transformPoint(projection, corner - center) + center,
          ], true);
        for (final corner in [
          screen.topLeft,
          screen.topRight,
          screen.bottomRight,
          screen.bottomLeft,
        ]) {
          expect(
            polygon.contains(corner),
            isTrue,
            reason: '$size at $direction degrees leaves $corner uncovered',
          );
        }
      }
    }
  });

  test('all tilt directions stay within ten degrees and return to neutral', () {
    for (final x in [-5.0, 0.0, 5.0]) {
      for (final z in [-5.0, 0.0, 5.0]) {
        final motion = PortraitTiltMotion();
        expect(motion.update(0, 9.81, 0), Offset.zero);
        final y = math.sqrt(9.81 * 9.81 - x * x - z * z);
        var angle = Offset.zero;
        for (var i = 0; i < 40; i++) {
          angle = motion.update(x, y, z);
          expect(
            angle.distance,
            lessThanOrEqualTo(PortraitTiltMotion.maxAngle + 1e-10),
          );
        }
        expect(angle.dx.sign, -z.sign);
        expect(angle.dy.sign, -x.sign);
        for (var i = 0; i < 60; i++) {
          angle = motion.update(0, 9.81, 0);
        }
        expect(angle.distance, lessThan(1e-6));
      }
    }
  });

  test('calibrates flat devices, rejects shakes and recalibrates', () {
    final motion = PortraitTiltMotion();
    expect(motion.update(0, 0, 9.81), Offset.zero);
    final angle = motion.update(0, 4, 8.96);
    expect(angle.dx, greaterThan(0));
    expect(motion.update(double.nan, 0, 0), angle);
    expect(motion.update(0, 0, 0), angle);
    expect(motion.update(30, 30, 30), angle);
    motion.reset();
    expect(motion.update(0, 4, 8.96), Offset.zero);
  });

  testWidgets(
    'sensor transform preserves child and suspends outside active portrait',
    (tester) async {
      final events = StreamController<AccelerometerEvent>.broadcast();
      addTearDown(events.close);
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var builds = 0;
      final child = Builder(
        builder: (_) {
          builds++;
          return const SizedBox.expand();
        },
      );
      Widget app({bool reduced = false}) => MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
          child: child!,
        ),
        home: PortraitTilt(events: events.stream, child: child),
      );
      await tester.pumpWidget(app());
      final before = builds;
      void sample(double x, double y, double z) =>
          events.add(AccelerometerEvent(x, y, z, DateTime.now()));
      Matrix4 matrix() => tester
          .widget<Transform>(
            find.byKey(const ValueKey('portrait-sensor-plane')),
          )
          .transform;
      sample(0, 9.81, 0);
      await tester.pump();
      for (var i = 0; i < 12; i++) {
        sample(4, 8, 4);
        await tester.pump(const Duration(milliseconds: 32));
      }
      await tester.pumpAndSettle();
      expect(matrix().entry(0, 2).abs(), greaterThan(0));
      expect(matrix().entry(2, 1).abs(), greaterThan(0));
      expect(builds, before);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(events.hasListener, isFalse);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(events.hasListener, isTrue);
      sample(4, 8, 4);
      await tester.pumpAndSettle();
      expect(matrix().entry(0, 2), 0);
      tester.view.physicalSize = const Size(800, 400);
      await tester.pump();
      expect(events.hasListener, isFalse);
      tester.view.physicalSize = const Size(400, 800);
      await tester.pumpWidget(app(reduced: true));
      expect(events.hasListener, isFalse);
      await tester.pumpWidget(const SizedBox());
      expect(events.hasListener, isFalse);
    },
  );
}
