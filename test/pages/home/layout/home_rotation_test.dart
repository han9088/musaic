import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musaic/features/coverflow/album_coverflow.dart';
import 'package:musaic/pages/home/home_page.dart';
import 'package:musaic/features/layout/album_layout_transition.dart';
import 'package:musaic/features/music/playback/album_play_button.dart';
import 'package:musaic/services/mock_album_cache.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

class RotationAlbumCache extends MockAlbumCache {
  @override
  Future<List<Map<String, dynamic>>> load() async => List.generate(
    17,
    (i) => {
      'asset': 'assets/albums/0.jpg',
      'artist': 'Artist $i',
      'title': 'Album $i',
    },
  );
  @override
  Future<void> warmImages(
    Future<void> Function(ImageProvider) precache,
  ) async {}
}

void main() {
  testWidgets('warmed covers remain visible during rotation and handoff', (
    tester,
  ) async {
    final messenger = tester.binding.defaultBinaryMessenger;
    for (final name in [
      'dev.fluttercommunity.plus/sensors/method',
      'dev.fluttercommunity.plus/sensors/accelerometer',
      'pulsar',
    ]) {
      final channel = MethodChannel(name);
      messenger.setMockMethodCallHandler(channel, (_) async => 0);
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    }
    const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
    final cache = Directory.systemTemp.createTempSync('musaic-rotation-');
    messenger.setMockMethodCallHandler(pathChannel, (_) async => cache.path);
    addTearDown(() {
      messenger.setMockMethodCallHandler(pathChannel, null);
      cache.deleteSync(recursive: true);
    });
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 800);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(home: HomePage(albumCache: RotationAlbumCache())),
    );
    await tester.pump();
    final context = tester.element(find.byType(HomePage));
    await tester.runAsync(
      () => precacheImage(
        const ResizeImage(
          AssetImage('assets/albums/0.jpg'),
          width: 128,
          height: 128,
          policy: ResizeImagePolicy.fit,
        ),
        context,
      ),
    );
    final covers = find.byWidgetPredicate(
      (widget) => widget is RawImage && widget.image != null,
    );
    await tester.pump();
    expect(covers, findsWidgets);

    final blankFrames = <String>[];
    for (final size in [const Size(800, 400), const Size(400, 800)]) {
      tester.view.physicalSize = size;
      for (var frame = 0; frame < 35; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        if (covers.evaluate().isEmpty) {
          blankFrames.add('${size.width}×${size.height}, frame $frame');
        }
      }
    }
    expect(blankFrames, isEmpty);
    await tester.pumpWidget(const SizedBox());
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('macOS opens the canvas even in a wide window', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1000, 700);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(home: HomePage(albumCache: RotationAlbumCache())),
    );
    await tester.pump();
    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(find.byType(AlbumCoverFlow), findsNothing);
    tester.view.physicalSize = const Size(1400, 800);
    await tester.pump();
    expect(find.byType(InteractiveViewer), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('layout-switch-wake')));
    await tester.pump();
    expect(find.byType(InteractiveViewer), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('layout-switch')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 550));
    expect(find.byType(AlbumCoverFlow), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('layout-switch')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 550));
    expect(find.byType(InteractiveViewer), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  for (final reduced in [false, true]) {
    testWidgets(
      'transition stays separate from original CoverFlow (reduced=$reduced)',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(400, 800);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        const channel = MethodChannel('pulsar');
        final calls = <String>[];
        var handle = 0;
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          (call) async {
            calls.add(call.method);
            if (call.method == 'Pulsar_hapticSupport') return 3;
            if (call.method == 'PatternComposer_parsePattern') return ++handle;
            return null;
          },
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            channel,
            null,
          ),
        );
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
              child: child!,
            ),
            home: HomePage(albumCache: RotationAlbumCache()),
          ),
        );
        await tester.pump();
        expect(handle, 10);
        await tester.tapAt(const Offset(150, 250));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));
        await tester.tap(find.byType(AlbumPlayButton).hitTestable());
        await tester.pump();
        expect(
          find.byIcon(PhosphorIcons.pauseFill).hitTestable(),
          findsOneWidget,
        );
        tester.view.physicalSize = const Size(800, 400);
        await tester.pump();
        if (!reduced) {
          expect(find.byType(AlbumCoverFlow), findsNothing);
          final transition = tester.widget<AlbumLayoutTransition>(
            find.byType(AlbumLayoutTransition),
          );
          await tester.pump(const Duration(milliseconds: 180));
          final before = transition.progress.value;
          expect(before, inExclusiveRange(0.0, 1.0));
          tester.view.physicalSize = const Size(400, 800);
          await tester.pump();
          expect(transition.progress.value, before);
          await tester.pump(const Duration(milliseconds: 550));
          expect(find.byType(InteractiveViewer), findsOneWidget);
          tester.view.physicalSize = const Size(800, 400);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 550));
        }
        expect(find.byType(AlbumLayoutTransition), findsNothing);
        expect(find.byType(AlbumCoverFlow), findsOneWidget);
        expect(calls.where((c) => c == 'PatternComposer_play'), isEmpty);
        final flow = tester.widget<AlbumCoverFlow>(find.byType(AlbumCoverFlow));
        expect(flow.playback!.playing, isTrue);
        final button = tester.widget<AlbumPlayButton>(
          find.byType(AlbumPlayButton).hitTestable(),
        );
        if (flow.playback!.isPlaying(button.asset, button.title)) {
          await tester.tap(find.byType(AlbumPlayButton).hitTestable());
          await tester.pump();
        }
        expect(
          find.byIcon(PhosphorIcons.playFill).hitTestable(),
          findsOneWidget,
        );
        final next = flow.initialPosition.round() + 1;
        final title = flow.albums[next % flow.albums.length]['title'] as String;
        if (!reduced) {
          await tester.tap(find.byKey(ValueKey('cover-$next')));
          await tester.pumpAndSettle();
          expect(find.text(title), findsOneWidget);
        }
        await tester.tap(find.byType(AlbumPlayButton).hitTestable());
        await tester.pump();
        expect(
          find.byIcon(PhosphorIcons.pauseFill).hitTestable(),
          findsOneWidget,
        );
        tester.view.physicalSize = const Size(400, 800);
        await tester.pump();
        if (!reduced) await tester.pump(const Duration(milliseconds: 550));
        expect(find.byType(InteractiveViewer), findsOneWidget);
        expect(
          find.byIcon(PhosphorIcons.pauseFill).hitTestable(),
          findsOneWidget,
        );
        expect(handle, 10);
        expect(calls.where((c) => c == 'PatternComposer_release'), isEmpty);
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        expect(
          calls.where((c) => c == 'PatternComposer_release'),
          hasLength(10),
        );
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );
  }
}
