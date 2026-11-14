import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musaic/pages/home/album_cover_flow.dart';

void main() {
  testWidgets(
    'higher swipe frequency increases coasting distance without short-swipe tilt',
    (tester) async {
      Future<double> coast(int pause) async {
        var position = 0.0;
        var tilt = 0.0;
        await tester.pumpWidget(
          MaterialApp(
            home: AlbumCoverFlow(
              key: ValueKey(pause),
              albums: const [
                {
                  'asset': 'assets/albums/0.jpg',
                  'artist': 'Artist',
                  'title': 'Album',
                },
              ],
              onMotionChanged: (p, t) {
                position = p;
                tilt = t;
              },
            ),
          ),
        );
        final drag = tester
            .widgetList<GestureDetector>(find.byType(GestureDetector))
            .firstWhere((w) => w.onHorizontalDragUpdate != null);
        var time = Duration.zero;
        for (var swipe = 0; swipe < 3; swipe++) {
          drag.onHorizontalDragStart!(DragStartDetails(sourceTimeStamp: time));
          for (var frame = 0; frame < 8; frame++) {
            time += const Duration(milliseconds: 16);
            drag.onHorizontalDragUpdate!(
              DragUpdateDetails(
                delta: const Offset(-12, 0),
                primaryDelta: -12,
                globalPosition: const Offset(400, 200),
                sourceTimeStamp: time,
              ),
            );
            await tester.pump(const Duration(milliseconds: 16));
          }
          drag.onHorizontalDragEnd!(
            DragEndDetails(
              velocity: const Velocity(pixelsPerSecond: Offset(-750, 0)),
              primaryVelocity: -750,
            ),
          );
          if (swipe < 2) {
            time += Duration(milliseconds: pause);
            await tester.pump(Duration(milliseconds: pause));
          }
        }
        final start = position;
        for (var i = 0; i < 60; i++) {
          await tester.pump(const Duration(milliseconds: 16));
          expect(tilt, closeTo(0, 0.000001));
        }
        return position - start;
      }

      final slow = await coast(800);
      final fast = await coast(40);
      expect(fast, greaterThan(slow * 1.1));
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('gentle dragging and settling keep the plane level', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AlbumCoverFlow(
          albums: [
            {
              'asset': 'assets/albums/0.jpg',
              'artist': 'Artist',
              'title': 'Album',
            },
          ],
        ),
      ),
    );
    final drag = tester
        .widgetList<GestureDetector>(find.byType(GestureDetector))
        .firstWhere((widget) => widget.onHorizontalDragUpdate != null);
    void expectLevel() {
      final plane = tester.widget<Transform>(
        find.byKey(const ValueKey('cover-flow-plane')),
      );
      final perspective =
          0.88 /
          tester.getSize(find.byKey(const ValueKey('cover-flow-plane'))).width;
      expect(
        plane.transform.entry(3, 2),
        closeTo(perspective * plane.transform.entry(2, 2), 1e-9),
      );
      expect(
        plane.transform.entry(3, 0),
        closeTo(perspective * plane.transform.entry(2, 0), 1e-9),
      );
      expect(plane.transform.entry(0, 2), closeTo(0, 0.000001));
    }

    drag.onHorizontalDragStart!(
      DragStartDetails(sourceTimeStamp: Duration.zero),
    );
    for (var i = 1; i <= 20; i++) {
      drag.onHorizontalDragUpdate!(
        DragUpdateDetails(
          delta: const Offset(1, 0),
          primaryDelta: 1,
          globalPosition: Offset(400 + i.toDouble(), 200),
          sourceTimeStamp: Duration(milliseconds: i * 16),
        ),
      );
      await tester.pump(const Duration(milliseconds: 16));
      expectLevel();
    }
    drag.onHorizontalDragEnd!(DragEndDetails(primaryVelocity: 0));
    for (var i = 0; i < 120; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      expectLevel();
    }
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  for (final direction in [-1.0, 1.0]) {
    testWidgets(
      'short then long swipe restores full tilt from residual angle $direction',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: AlbumCoverFlow(
              initialTilt: 0.02 * direction,
              albums: const [
                {
                  'asset': 'assets/albums/0.jpg',
                  'artist': 'Artist',
                  'title': 'Album',
                },
              ],
            ),
          ),
        );
        final drag = tester
            .widgetList<GestureDetector>(find.byType(GestureDetector))
            .firstWhere((widget) => widget.onHorizontalDragUpdate != null);
        var time = Duration.zero;
        for (final steps in [4, 50]) {
          drag.onHorizontalDragStart!(DragStartDetails(sourceTimeStamp: time));
          for (var i = 0; i < steps; i++) {
            time += const Duration(milliseconds: 16);
            drag.onHorizontalDragUpdate!(
              DragUpdateDetails(
                delta: Offset(12 * direction, 0),
                primaryDelta: 12 * direction,
                globalPosition: const Offset(400, 200),
                sourceTimeStamp: time,
              ),
            );
            await tester.pump(const Duration(milliseconds: 16));
          }
          if (steps == 50) {
            final plane = tester.widget<Transform>(
              find.byKey(const ValueKey('cover-flow-plane')),
            );
            expect(plane.transform.entry(0, 2) * direction, greaterThan(0.54));
          }
          drag.onHorizontalDragEnd!(DragEndDetails(primaryVelocity: 0));
          await tester.pump(const Duration(milliseconds: 16));
        }
        await tester.pumpWidget(const SizedBox());
      },
    );

    testWidgets('one slow long swipe tilts the plane $direction', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AlbumCoverFlow(
            albums: [
              {
                'asset': 'assets/albums/0.jpg',
                'artist': 'Artist',
                'title': 'Album',
              },
            ],
          ),
        ),
      );
      final drag = tester
          .widgetList<GestureDetector>(find.byType(GestureDetector))
          .firstWhere((widget) => widget.onHorizontalDragUpdate != null);
      drag.onHorizontalDragStart!(
        DragStartDetails(sourceTimeStamp: Duration.zero),
      );
      for (var i = 1; i <= 240; i++) {
        drag.onHorizontalDragUpdate!(
          DragUpdateDetails(
            delta: Offset(2 * direction, 0),
            primaryDelta: 2 * direction,
            globalPosition: Offset(400 + i * 2 * direction, 200),
            sourceTimeStamp: Duration(milliseconds: i * 16),
          ),
        );
        await tester.pump(const Duration(milliseconds: 16));
      }
      final plane = tester.widget<Transform>(
        find.byKey(const ValueKey('cover-flow-plane')),
      );
      final perspective =
          0.88 /
          tester.getSize(find.byKey(const ValueKey('cover-flow-plane'))).width;
      expect(
        plane.transform.entry(3, 2),
        closeTo(perspective * plane.transform.entry(2, 2), 1e-9),
      );
      expect(
        plane.transform.entry(3, 0),
        closeTo(perspective * plane.transform.entry(2, 0), 1e-9),
      );
      expect(plane.transform.entry(0, 2) * direction, greaterThan(0.2));
      drag.onHorizontalDragEnd!(
        DragEndDetails(
          velocity: Velocity(pixelsPerSecond: Offset(125 * direction, 0)),
          primaryVelocity: 125 * direction,
        ),
      );
      await tester.pump(const Duration(milliseconds: 16));
      final released = tester.widget<Transform>(
        find.byKey(const ValueKey('cover-flow-plane')),
      );
      expect(released.transform.entry(0, 2) * direction, greaterThan(0.2));
      for (var i = 0; i < 15; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      final coasting = tester.widget<Transform>(
        find.byKey(const ValueKey('cover-flow-plane')),
      );
      expect(
        coasting.transform.entry(0, 2),
        closeTo(released.transform.entry(0, 2), 0.0001),
      );
      await tester.pumpAndSettle();
      final settled = tester.widget<Transform>(
        find.byKey(const ValueKey('cover-flow-plane')),
      );
      expect(settled.transform.entry(0, 2), closeTo(0, 0.000001));
    });

    testWidgets(
      'consecutive swipes preserve tilt and allow reversal $direction',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: AlbumCoverFlow(
              albums: [
                {
                  'asset': 'assets/albums/0.jpg',
                  'artist': 'Artist',
                  'title': 'Album',
                },
              ],
            ),
          ),
        );
        final drag = tester
            .widgetList<GestureDetector>(find.byType(GestureDetector))
            .firstWhere((widget) => widget.onHorizontalDragUpdate != null);
        var time = Duration.zero;
        double tilt() => tester
            .widget<Transform>(find.byKey(const ValueKey('cover-flow-plane')))
            .transform
            .entry(0, 2);
        Future<void> move(double dx) async {
          time += const Duration(milliseconds: 16);
          drag.onHorizontalDragUpdate!(
            DragUpdateDetails(
              delta: Offset(dx, 0),
              primaryDelta: dx,
              globalPosition: const Offset(400, 200),
              sourceTimeStamp: time,
            ),
          );
          await tester.pump(const Duration(milliseconds: 16));
        }

        for (var swipe = 0; swipe < 5; swipe++) {
          drag.onHorizontalDragStart!(DragStartDetails(sourceTimeStamp: time));
          for (var i = 0; i < 8; i++) {
            await move(12 * direction);
            expect(tilt(), closeTo(0, 0.000001));
          }
          drag.onHorizontalDragEnd!(
            DragEndDetails(
              velocity: Velocity(pixelsPerSecond: Offset(750 * direction, 0)),
              primaryVelocity: 750 * direction,
            ),
          );
          await tester.pump(const Duration(milliseconds: 16));
          expect(tilt(), closeTo(0, 0.000001));
        }

        for (var swipe = 0; swipe < 3; swipe++) {
          final previousTilt = tilt() * direction;
          drag.onHorizontalDragStart!(DragStartDetails(sourceTimeStamp: time));
          await tester.pump(const Duration(milliseconds: 16));
          expect(
            tilt() * direction,
            greaterThanOrEqualTo(previousTilt - 0.000001),
          );
          for (var i = 0; i < 50; i++) {
            await move(12 * direction);
            if (i < 16) {
              expect(
                tilt() * direction,
                greaterThanOrEqualTo(previousTilt - 0.000001),
              );
            }
            expect(
              tilt() * direction,
              greaterThanOrEqualTo(previousTilt - 0.000001),
            );
          }
          expect(tilt() * direction, greaterThan(0.54));
          drag.onHorizontalDragEnd!(
            DragEndDetails(
              velocity: Velocity(pixelsPerSecond: Offset(750 * direction, 0)),
              primaryVelocity: 750 * direction,
            ),
          );
          for (var i = 0; i < 6; i++) {
            time += const Duration(milliseconds: 16);
            await tester.pump(const Duration(milliseconds: 16));
          }
        }
        final beforeShortSwipe = tilt();
        drag.onHorizontalDragStart!(DragStartDetails(sourceTimeStamp: time));
        for (var i = 0; i < 4; i++) {
          await move(12 * direction);
        }
        drag.onHorizontalDragEnd!(
          DragEndDetails(
            velocity: Velocity(pixelsPerSecond: Offset(750 * direction, 0)),
            primaryVelocity: 750 * direction,
          ),
        );
        await tester.pump(const Duration(milliseconds: 16));
        expect(tilt(), closeTo(beforeShortSwipe, 0.000001));
        drag.onHorizontalDragStart!(DragStartDetails(sourceTimeStamp: time));
        for (var i = 0; i < 8; i++) {
          await move(-6 * direction);
        }
        expect(tilt() * direction, lessThan(-0.1));
        // Reverse again without lifting; neither short movement reaches 200 px.
        for (var i = 0; i < 8; i++) {
          await move(6 * direction);
        }
        expect(tilt() * direction, greaterThan(0.1));
        drag.onHorizontalDragEnd!(DragEndDetails(primaryVelocity: 0));
        await tester.pumpAndSettle();
        expect(tilt(), closeTo(0, 0.000001));
      },
    );

    testWidgets('one swipe coasts without heavy braking $direction', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AlbumCoverFlow(
            albums: [
              {
                'asset': 'assets/albums/0.jpg',
                'artist': 'Artist',
                'title': 'Album',
              },
            ],
          ),
        ),
      );
      final drag = tester
          .widgetList<GestureDetector>(find.byType(GestureDetector))
          .firstWhere((widget) => widget.onHorizontalDragUpdate != null);
      double coverLeft() => tester
          .widget<Positioned>(find.byKey(const ValueKey('cover-0')))
          .left!;
      drag.onHorizontalDragStart!(
        DragStartDetails(sourceTimeStamp: Duration.zero),
      );
      for (var i = 1; i <= 10; i++) {
        drag.onHorizontalDragUpdate!(
          DragUpdateDetails(
            delta: Offset(18 * direction, 0),
            primaryDelta: 18 * direction,
            globalPosition: Offset(400 + i * 18 * direction, 200),
            sourceTimeStamp: Duration(milliseconds: i * 16),
          ),
        );
        await tester.pump(const Duration(milliseconds: 16));
      }
      final before = coverLeft();
      drag.onHorizontalDragEnd!(
        DragEndDetails(
          velocity: Velocity(pixelsPerSecond: Offset(1125 * direction, 0)),
          primaryVelocity: 1125 * direction,
        ),
      );
      for (var i = 0; i < 60; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect((coverLeft() - before) * direction, greaterThan(400));
      await tester.pumpAndSettle();
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('release estimate cannot reverse drag $direction', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AlbumCoverFlow(
            albums: [
              {
                'asset': 'assets/albums/0.jpg',
                'artist': 'Artist',
                'title': 'Album',
              },
            ],
          ),
        ),
      );
      final drag = tester
          .widgetList<GestureDetector>(find.byType(GestureDetector))
          .firstWhere((widget) => widget.onHorizontalDragUpdate != null);
      drag.onHorizontalDragStart!(
        DragStartDetails(sourceTimeStamp: Duration.zero),
      );
      for (var i = 1; i <= 5; i++) {
        drag.onHorizontalDragUpdate!(
          DragUpdateDetails(
            delta: Offset(15 * direction, 0),
            primaryDelta: 15 * direction,
            globalPosition: Offset(400 + i * 15 * direction, 200),
            sourceTimeStamp: Duration(milliseconds: i * 16),
          ),
        );
        await tester.pump(const Duration(milliseconds: 16));
      }
      final before = tester
          .getTopLeft(find.byKey(const ValueKey('cover-0')))
          .dx;
      drag.onHorizontalDragEnd!(
        DragEndDetails(
          velocity: Velocity(pixelsPerSecond: Offset(-1800 * direction, 0)),
          primaryVelocity: -1800 * direction,
        ),
      );
      await tester.pump(const Duration(milliseconds: 16));
      final after = tester.getTopLeft(find.byKey(const ValueKey('cover-0'))).dx;
      expect((after - before) * direction, greaterThan(0));
      await tester.pumpWidget(const SizedBox());
    });
  }
}
