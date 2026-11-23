import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musaic/features/artwork/presentation/artwork_source_view.dart';
import 'package:musaic/features/coverflow/album_coverflow.dart';
import 'package:musaic/features/coverflow/coverflow_flip_card.dart';
import 'package:musaic/features/music/catalog/album_catalog_mapper.dart';
import 'package:musaic/features/music/catalog/album_track_list.dart';
import 'package:musaic/features/music/playback/album_play_button.dart';
import 'package:musaic/features/music/playback/album_playback.dart';
import 'package:musaic/l10n/generated/app_localizations.dart';
import 'package:musaic/services/music/music_models.dart';

void main() {
  testWidgets('portrait anchors the covers above the bottom edge', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetPadding);
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

    Rect coverRect() => tester.getRect(find.byKey(const ValueKey('cover-0')));

    double artworkBottomGap() {
      final cover = coverRect();
      return 800 - (cover.top + cover.width);
    }

    expect(artworkBottomGap(), closeTo(85, 0.01));
    tester.view.padding = const FakeViewPadding(bottom: 34);
    await tester.pump();
    expect(artworkBottomGap(), closeTo(85, 0.01));
    tester.view.padding = const FakeViewPadding(bottom: 92);
    await tester.pump();
    expect(artworkBottomGap(), closeTo(92, 0.01));

    tester.view.resetPadding();
    tester.view.physicalSize = const Size(800, 400);
    await tester.pump();
    final cover = coverRect();
    expect(cover.top + cover.width / 2, closeTo(400 * 0.52, 0.01));
  });

  testWidgets('a single track flips to its artwork and returns to its slot', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AlbumCoverFlow(
          albums: [
            {
              'asset': 'assets/albums/0.jpg',
              'artist': 'Artist',
              'title': 'First',
              'trackCount': 1,
            },
            {'asset': 'local:second', 'artist': 'Artist', 'title': 'Second'},
          ],
        ),
      ),
    );

    final flip = find.byKey(const ValueKey('cover-flow-flipping-card'));
    final face = find
        .descendant(of: flip, matching: find.byType(GestureDetector))
        .first;
    final artwork = find.descendant(
      of: flip,
      matching: find.byType(ArtworkSourceView),
    );
    final center = find.byKey(const ValueKey('cover-0'));
    final neighbor = find.byKey(const ValueKey('cover-1'));
    final restingRect = tester.getRect(face);
    final neighborRect = tester.getRect(neighbor);
    final touch = restingRect.topCenter + const Offset(0, 38);

    final drag = await tester.startGesture(touch);
    await drag.moveBy(const Offset(0, -24));
    await drag.moveBy(const Offset(0, -100));
    await tester.pump();
    expect(tester.getRect(face).top, lessThan(restingRect.top));
    Matrix4 flipTransform() => tester.widget<Transform>(flip).transform;
    expect(flipTransform().entry(3, 1), lessThan(0));
    expect(flipTransform().entry(3, 0), 0);

    await drag.moveBy(const Offset(0, -145));
    await tester.pump();
    expect(flipTransform().entry(3, 1), greaterThan(0));
    expect(flipTransform().entry(3, 0), 0);

    final card = tester.widget<CoverFlowFlipCard>(
      find.byType(CoverFlowFlipCard),
    );
    final travel = card.source.center.dy - card.destination.center.dy;
    await drag.moveBy(Offset(0, -travel * (0.85 - card.progress.value)));
    await tester.pump();
    expect(card.progress.value, closeTo(0.85, 0.001));
    expect(artwork, findsOneWidget);
    final finishingFace = tester.getRect(artwork);
    expect(finishingFace.height, closeTo(finishingFace.width, 0.01));

    await drag.up();
    await tester.pumpAndSettle();

    expect(find.byType(AlbumTrackList), findsNothing);
    final expanded = tester.getRect(artwork);
    expect(expanded.height, closeTo(expanded.width, 0.01));
    expect(expanded.width, greaterThan(restingRect.width * 2));
    expect(expanded.top + expanded.width, lessThan(restingRect.top));
    expect(center, findsOneWidget);
    expect(tester.getRect(neighbor), neighborRect);

    await tester.dragFrom(
      expanded.topCenter + const Offset(0, 80),
      const Offset(0, 200),
    );
    await tester.pumpAndSettle();
    expect(tester.getRect(face), restingRect);
    expect(tester.getRect(neighbor), neighborRect);

    await tester.dragFrom(touch, const Offset(0, -200));
    await tester.pumpAndSettle();
    tester.view.physicalSize = const Size(800, 400);
    await tester.pumpAndSettle();
    expect(flip, findsNothing);
    final landscapeRect = tester.getRect(center);
    await tester.dragFrom(
      landscapeRect.topCenter + const Offset(0, 38),
      const Offset(0, -160),
    );
    await tester.pumpAndSettle();
    expect(flip, findsNothing);
    expect(tester.getRect(center), landscapeRect);
  });

  testWidgets('the expanded back scrolls tracks and controls album playback', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = const Size(1200, 2400);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final messenger = tester.binding.defaultBinaryMessenger;
    const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
    final cache = Directory.systemTemp.createTempSync('musaic-flip-');
    messenger.setMockMethodCallHandler(pathChannel, (_) async => cache.path);
    addTearDown(() {
      messenger.setMockMethodCallHandler(pathChannel, null);
      cache.deleteSync(recursive: true);
    });
    const artworkChannel = MethodChannel('com.deskbtm.muasic.query');
    final bytes = (await tester.runAsync(
      () => rootBundle.load('assets/albums/0.jpg'),
    ))!.buffer.asUint8List();
    final artworkSizes = <int>[];
    messenger.setMockMethodCallHandler(artworkChannel, (call) async {
      expect(call.method, 'queryArtwork');
      artworkSizes.add(call.arguments['size'] as int);
      return bytes;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(artworkChannel, null));

    MusicReference reference(MusicKind kind, String id) => (
      provider: 'local',
      id: id,
      kind: kind,
      source: MusicSource.library,
      storefront: null,
    );
    final albums = mapProviderAlbums([
      (
        reference: reference(MusicKind.album, '9'),
        title: 'First',
        artist: 'Artist',
        artworkUrl: 'media-store:17',
        trackCount: 20,
        tracks: [
          for (var i = 1; i <= 20; i++)
            (
              reference: reference(MusicKind.song, '$i'),
              title: 'Track $i',
              artist: null,
              duration: null,
              artworkUrl: null,
              playable: true,
            ),
        ],
      ),
    ]);
    final playback = AlbumPlayback();
    addTearDown(playback.dispose);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AlbumCoverFlow(albums: albums, playback: playback),
      ),
    );
    await tester.pump();
    final cover = find.byType(CoverFlowFlipCard);
    final coverPlay = find.descendant(
      of: cover,
      matching: find.byType(AlbumPlayButton),
    );
    expect(coverPlay, findsOneWidget);
    expect(artworkSizes, isNotEmpty);
    expect(find.text('Track 1'), findsNothing);

    final touch = tester.widget<CoverFlowFlipCard>(cover).source.center;
    await tester.dragFrom(touch, const Offset(0, -200));
    await tester.pumpAndSettle();
    final back = find.byType(AlbumTrackList);
    final backPlay = find.descendant(
      of: back,
      matching: find.byType(AlbumPlayButton),
    );
    final artist = find.descendant(of: back, matching: find.text('Artist'));
    expect(artist, findsOne);
    expect(find.descendant(of: back, matching: find.text('01')), findsOne);
    expect(find.text('Track 1'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Track 2')).dy,
      greaterThan(tester.getTopLeft(find.text('Track 1')).dy),
    );
    expect(backPlay, findsOneWidget);
    expect(
      tester.getCenter(backPlay).dx,
      greaterThan(tester.getCenter(back).dx),
    );
    expect(backPlay.hitTestable(), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(backPlay.hitTestable(), findsNothing);
    await tester.tapAt(tester.getCenter(artist));
    await tester.pumpAndSettle();
    expect(backPlay.hitTestable(), findsOneWidget);
    expect(artworkSizes, everyElement(512));

    final scrollable = find.descendant(
      of: back,
      matching: find.byType(Scrollable),
    );
    final lastTrack = find.text('Track 20');
    await tester.scrollUntilVisible(lastTrack, 120, scrollable: scrollable);
    await tester.drag(scrollable, const Offset(0, -44));
    await tester.pumpAndSettle();
    expect(lastTrack.hitTestable(), findsOneWidget);
    await tester.tap(lastTrack);
    expect(playback.playing, isFalse);
    await tester.tap(backPlay);
    await tester.pump();
    expect(playback.isPlaying('media-store:17', 'First'), isTrue);
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(back, findsNothing);
    expect(coverPlay, findsOneWidget);
    await tester.tap(coverPlay);
    await tester.pump();
    expect(playback.playing, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  for (final direction in [-1.0, 1.0]) {
    for (final sample in [
      (20.0, 8, false),
      (20.0, 32, false),
      (5.0, 2, false),
    ]) {
      testWidgets('single short swipe never triggers tilt $direction $sample', (
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
        for (var i = 1; i <= 3; i++) {
          drag.onHorizontalDragUpdate!(
            DragUpdateDetails(
              delta: Offset(sample.$1 * direction, 0),
              primaryDelta: sample.$1 * direction,
              globalPosition: const Offset(400, 200),
              sourceTimeStamp: Duration(milliseconds: i * sample.$2),
            ),
          );
          await tester.pump(Duration(milliseconds: sample.$2));
        }
        for (var i = 0; i < 20; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        final tilt =
            tester
                .widget<Transform>(
                  find.byKey(const ValueKey('cover-flow-plane')),
                )
                .transform
                .entry(0, 2) *
            direction;
        expect(tilt, sample.$3 ? greaterThan(0.5) : closeTo(0, 0.000001));
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }

  testWidgets(
    'higher swipe frequency triggers tilt and keeps the existing coasting gain',
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
        expect(
          tilt.abs(),
          pause == 40 ? greaterThan(0.1) : closeTo(0, 0.000001),
        );
        final start = position;
        for (var i = 0; i < 60; i++) {
          await tester.pump(const Duration(milliseconds: 16));
          if (pause == 800) expect(tilt, closeTo(0, 0.000001));
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
            if (swipe < 2) expect(tilt(), closeTo(0, 0.000001));
          }
          drag.onHorizontalDragEnd!(
            DragEndDetails(
              velocity: Velocity(pixelsPerSecond: Offset(750 * direction, 0)),
              primaryVelocity: 750 * direction,
            ),
          );
          await tester.pump(const Duration(milliseconds: 16));
          if (swipe < 2) expect(tilt(), closeTo(0, 0.000001));
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
