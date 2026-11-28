import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musaic/features/canvas/album_cover_popup.dart';

void main() {
  testWidgets('the track list scrolls before the enlarged album flips', (
    tester,
  ) async {
    const viewport = Size(400, 800);
    tester.view.physicalSize = viewport;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const front = ValueKey('front');
    const header = ValueKey('header');
    const tracks = ValueKey('tracks');
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Builder(
              builder: (context) => TextButton(
                onPressed: () => showAlbumCoverPopup(
                  source: context,
                  artwork: const SizedBox.expand(key: front),
                  onReturned: () {},
                  trackList: ColoredBox(
                    color: Colors.black,
                    child: Column(
                      children: [
                        const SizedBox(key: header, height: 72),
                        Expanded(
                          child: ListView.builder(
                            key: tracks,
                            controller: scroll,
                            itemExtent: 48,
                            itemCount: 30,
                            itemBuilder: (_, index) => Text('Track $index'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                child: const Text('Open album'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open album'));
    await tester.pumpAndSettle();
    final trackList = find.byKey(tracks);

    await tester.drag(trackList, const Offset(0, -230));
    await tester.pumpAndSettle();
    final scrolled = scroll.offset;
    expect(scrolled, greaterThan(0));
    await tester.drag(trackList, const Offset(0, 100));
    await tester.pumpAndSettle();
    expect(scroll.offset, lessThan(scrolled));
    expect(find.byKey(front), findsNothing);
    final trackOffset = scroll.offset;
    await tester.drag(trackList, const Offset(0, 300));
    await tester.pumpAndSettle();
    expect(scroll.offset, 0);
    expect(trackList, findsOneWidget);
    scroll.jumpTo(trackOffset);
    await tester.pumpAndSettle();

    final popup = find.byKey(const ValueKey('album-cover-popup'));
    Matrix4 transform() => tester
        .widget<Transform>(
          find.descendant(of: popup, matching: find.byType(Transform)).first,
        )
        .transform;
    double rotation() => transform().entry(2, 1);
    void expectCoverInsideViewport() {
      final card = tester.getRect(popup);
      final painted = MatrixUtils.transformRect(
        transform(),
        card.shift(-card.center),
      ).shift(card.center);
      expect(painted.left, greaterThanOrEqualTo(0));
      expect(painted.right, lessThanOrEqualTo(viewport.width));
      expect(painted.top, greaterThanOrEqualTo(0));
      expect(painted.bottom, lessThanOrEqualTo(viewport.height));
    }

    await tester.flingFrom(
      tester.getCenter(find.byKey(header)),
      const Offset(0, 55),
      580,
    );
    await tester.pump();
    final released = rotation();
    // A downward swipe brings the top edge toward the viewer.
    expect(released, greaterThan(0.1));
    expectCoverInsideViewport();
    await tester.pump(const Duration(milliseconds: 70));
    expect(rotation(), isNot(closeTo(released, 0.01)));
    expect(trackList, findsOneWidget);
    expectCoverInsideViewport();
    await tester.pumpAndSettle();
    expect(rotation(), 0);
    expect(find.byKey(front), findsOneWidget);
    expect(trackList, findsNothing);

    await tester.dragFrom(
      tester.getCenter(find.byKey(front)),
      const Offset(0, 52),
    );
    await tester.pump();
    final lightDragAngle = rotation();
    await tester.pump(const Duration(milliseconds: 80));
    expect(rotation(), greaterThan(lightDragAngle));
    expect(find.byKey(front), findsOneWidget);
    await tester.pumpAndSettle();
    expect(trackList, findsOneWidget);
    expect(scroll.offset, trackOffset);

    Future<int> countFlips(Offset origin, double travel) async {
      var frontVisible = find.byKey(front).evaluate().isNotEmpty;
      var flips = 0;
      await tester.flingFrom(origin, Offset(0, travel), 1800);
      await tester.pump();
      for (var frame = 0; frame < 60; frame++) {
        expectCoverInsideViewport();
        final nextFrontVisible = find.byKey(front).evaluate().isNotEmpty;
        if (nextFrontVisible != frontVisible) flips++;
        frontVisible = nextFrontVisible;
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(rotation(), 0);
      return flips;
    }

    expect(await countFlips(tester.getCenter(find.byKey(header)), 55), 1);
    expect(find.byKey(front), findsOneWidget);
    final frontToBack = await countFlips(
      tester.getCenter(find.byKey(front)),
      190,
    );
    expect(frontToBack, greaterThan(1));
    expect(frontToBack.isOdd, isTrue);
    expect(trackList, findsOneWidget);
    expect(scroll.offset, trackOffset);

    final backToFront = await countFlips(
      tester.getCenter(find.byKey(header)),
      190,
    );
    expect(backToFront, greaterThan(1));
    expect(backToFront.isOdd, isTrue);
    expect(find.byKey(front), findsOneWidget);

    await tester.dragFrom(
      tester.getCenter(find.byKey(front)),
      const Offset(0, 25),
    );
    await tester.pumpAndSettle();
    expect(trackList, findsOneWidget);

    await tester.dragFrom(
      tester.getCenter(find.byKey(header)),
      const Offset(0, 52),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 320));
    expect(find.byKey(front), findsOneWidget);
    expect(rotation(), isNot(0));
    await tester.dragFrom(
      tester.getCenter(find.byKey(front)),
      const Offset(0, 25),
    );
    await tester.pumpAndSettle();
    expect(trackList, findsOneWidget);

    Future<List<bool>> closeAndReadFaces() async {
      final faces = [find.byKey(front).evaluate().isNotEmpty];
      var previousScale = 1.0;
      await tester.tapAt(const Offset(10, 10));
      await tester.pump();
      for (var frame = 0; frame < 14; frame++) {
        await tester.pump(const Duration(milliseconds: 32));
        if (faces.first) {
          final box = tester.renderObject<RenderBox>(popup);
          final bounds = MatrixUtils.transformRect(
            box.getTransformTo(null),
            Offset.zero & box.size,
          );
          expect(bounds.top, greaterThanOrEqualTo(0));
          expect(
            bounds.bottom,
            lessThanOrEqualTo(tester.view.physicalSize.height),
          );
          final transform = tester.widget<Transform>(
            find.ancestor(of: popup, matching: find.byType(Transform)),
          );
          final scale = transform.transform.entry(1, 1);
          expect(scale, lessThan(previousScale));
          previousScale = scale;
        }
        final frontVisible = find.byKey(front).evaluate().isNotEmpty;
        if (frontVisible != faces.last) faces.add(frontVisible);
      }
      await tester.pumpAndSettle();
      expect(popup, findsNothing);
      return faces;
    }

    expect(await closeAndReadFaces(), [false, true]);
    tester.view.physicalSize = const Size(800, 400);
    await tester.pump();
    await tester.tap(find.text('Open album'));
    await tester.pumpAndSettle();
    await tester.dragFrom(
      tester.getCenter(find.byKey(header)),
      const Offset(0, 52),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(front), findsOneWidget);
    expect(await closeAndReadFaces(), [true, false, true]);
  });
}
