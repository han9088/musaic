import 'dart:io';

import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musaic/app/bottom_sheet_host.dart';
import 'package:musaic/features/canvas/album_grid_snapshot.dart';
import 'package:musaic/features/coverflow/album_coverflow.dart';
import 'package:musaic/pages/home/home_page.dart';
import 'package:musaic/features/layout/album_layout_transition.dart';
import 'package:musaic/features/music/playback/album_play_button.dart';
import 'package:musaic/features/music/playback/now_playing_capsule.dart';
import 'package:musaic/l10n/generated/app_localizations.dart';
import 'package:musaic/services/mock_album_cache.dart';
import 'package:musaic/services/music/music_models.dart';
import 'package:musaic/services/music/music_source_controller.dart';
import 'package:musaic/ui/bottom_sheet/bottom_sheet.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

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

void _mockRotationPlugins(WidgetTester tester) {
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
}

void main() {
  testWidgets('warmed covers remain visible during rotation and handoff', (
    tester,
  ) async {
    _mockRotationPlugins(tester);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 800);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: HomePage(albumCache: RotationAlbumCache()),
      ),
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

  testWidgets(
    'return to canvas fits the landscape strip to the portrait viewport',
    (tester) async {
      _mockRotationPlugins(tester);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(800, 400);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: HomePage(albumCache: RotationAlbumCache()),
        ),
      );
      await tester.pump();
      expect(find.byType(AlbumCoverFlow), findsOneWidget);
      final capsule = find.byType(NowPlayingCapsule);
      final opacity = find.descendant(
        of: capsule,
        matching: find.byType(Opacity),
      );
      expect(capsule, findsNothing);

      tester.view.physicalSize = const Size(400, 800);
      await tester.pump();
      expect(find.byType(AlbumCoverFlow), findsNothing);
      final transition = find.byType(AlbumLayoutTransition);
      expect(transition, findsOneWidget);
      expect(tester.widget<Opacity>(opacity).opacity, 0);
      final transforms = tester.widgetList<Transform>(
        find.descendant(of: transition, matching: find.byType(Transform)),
      );
      final plane = transforms.singleWhere(
        (widget) => widget.transform.entry(3, 2) > 0,
      );
      expect(plane.alignment, const Alignment(0, 0.04));
      expect(plane.transform.entry(3, 2), closeTo(0.88 / 400, 0.000001));
      final coverWidths = transforms
          .where((widget) => widget.alignment == Alignment.topLeft)
          .map((widget) => widget.transform.entry(0, 0) * 142);
      expect(coverWidths, contains(closeTo(124, 0.01)));
      expect(coverWidths, everyElement(lessThanOrEqualTo(124.01)));

      await tester.pump(const Duration(milliseconds: 250));
      expect(transition, findsOneWidget);
      expect(tester.widget<Opacity>(opacity).opacity, 0);
      await tester.pump(const Duration(milliseconds: 300));
      expect(transition, findsNothing);
      expect(find.byType(InteractiveViewer), findsOneWidget);
      expect(tester.widget<Opacity>(opacity).opacity, 0);
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.widget<Opacity>(opacity).opacity, closeTo(0.5, 0.01));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.widget<Opacity>(opacity).opacity, 1);
      await tester.pumpWidget(const SizedBox());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets('local covers stay visible when Cover Flow returns to canvas', (
    tester,
  ) async {
    _mockRotationPlugins(tester);
    final bytes = (await tester.runAsync(
      () => rootBundle.load('assets/albums/0.jpg'),
    ))!.buffer.asUint8List();
    final messenger = tester.binding.defaultBinaryMessenger;
    var artworkReads = 0;
    const artwork = MethodChannel('com.deskbtm.muasic.query');
    messenger.setMockMethodCallHandler(artwork, (call) async {
      expect(call.method, 'queryArtwork');
      artworkReads++;
      await Future<void>.delayed(const Duration(milliseconds: 48));
      return bytes;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(artwork, null));
    final sources = MusicSourceController();
    addTearDown(sources.dispose);
    sources.catalog.value = const [
      (
        reference: (
          provider: 'local',
          id: '1',
          kind: MusicKind.album,
          source: MusicSource.library,
          storefront: null,
        ),
        title: 'Local album',
        artist: null,
        artworkUrl: 'media-store:1?modified=1',
        trackCount: 1,
        tracks: null,
      ),
    ];
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 400);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: HomePage(albumCache: RotationAlbumCache(), sources: sources),
      ),
    );
    await tester.pump(const Duration(milliseconds: 48));
    await tester.pump();
    final image = tester.widget<Image>(find.byType(Image).first);
    await tester.runAsync(
      () => precacheImage(image.image, tester.element(find.byType(HomePage))),
    );
    await tester.pump();
    final covers = find.byWidgetPredicate(
      (widget) => widget is RawImage && widget.image != null,
    );
    expect(covers, findsWidgets);
    expect(artworkReads, 1);

    tester.view.physicalSize = const Size(400, 800);
    final blankFrames = <int>[];
    for (var frame = 0; frame < 35; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
      if (covers.evaluate().isEmpty) blankFrames.add(frame);
    }
    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(blankFrames, isEmpty, reason: '$artworkReads local artwork reads');
    expect(artworkReads, 1);
    await tester.pumpWidget(const SizedBox());
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets(
    'layout buttons switch manually and phone rotation resets the layout',
    (tester) async {
      final preferences = SharedPreferencesAsyncPlatform.instance;
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      addTearDown(() => SharedPreferencesAsyncPlatform.instance = preferences);
      final mobile =
          defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS;
      final orientationRequests = <List<String>>[];
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'SystemChrome.setPreferredOrientations') {
          orientationRequests.add((call.arguments as List).cast<String>());
        }
        return null;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
      );
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = mobile
          ? const Size(400, 800)
          : const Size(1000, 700);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: AppBottomSheetHost(
            child: HomePage(albumCache: RotationAlbumCache()),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(InteractiveViewer), findsOneWidget);
      expect(find.byType(AlbumCoverFlow), findsNothing);
      if (!mobile) tester.view.physicalSize = const Size(1400, 800);
      await tester.pump();
      expect(find.byType(InteractiveViewer), findsOneWidget);
      final wakeButton = find.byKey(const ValueKey('layout-switch-wake'));
      final button = find.byKey(const ValueKey('layout-switch'));
      expect(wakeButton, findsNothing);
      expect(button.hitTestable(), findsOneWidget);

      Future<void> changeSetting(bool enabled) async {
        final sheet = DeskBottomSheet.of(tester.element(find.byType(HomePage)));
        await tester.drag(
          find.byType(NowPlayingCapsule),
          const Offset(0, -150),
        );
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        final settings = find.widgetWithIcon(Tab, PhosphorIcons.gearBold);
        await tester.tap(settings);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));
        final system = find.widgetWithText(ListTile, 'System');
        await tester.ensureVisible(system);
        await tester.tap(system);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 450));
        final tile = find.widgetWithText(
          SwitchListTile,
          'Show layout switcher',
        );
        expect(
          find.text('Switch to Cover Flow in portrait mode.'),
          findsOneWidget,
        );
        expect(tester.widget<SwitchListTile>(tile).value, !enabled);
        await tester.tap(tile);
        await tester.pump();
        expect(tester.widget<SwitchListTile>(tile).value, enabled);
        await tester.tap(find.byIcon(PhosphorIcons.caretDownBold));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 450));
        sheet.dismiss();
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
      }

      final capsule = tester.getRect(find.byType(NowPlayingCapsule));
      final switchButton = tester.getRect(button);
      expect(capsule.center.dx, tester.view.physicalSize.width / 2);
      expect(switchButton.center.dy, capsule.center.dy);
      expect(switchButton.height, capsule.height);
      expect(switchButton.left, greaterThan(capsule.right));
      if (mobile) {
        await tester.longPress(button);
        expect(orientationRequests, [
          [
            'DeviceOrientation.landscapeLeft',
            'DeviceOrientation.landscapeRight',
          ],
        ]);
        tester.view.physicalSize = const Size(800, 400);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 550));
        expect(find.byType(AlbumCoverFlow), findsOneWidget);
        expect(find.byType(InteractiveViewer), findsNothing);
        expect(
          find.descendant(
            of: button,
            matching: find.byIcon(PhosphorIcons.deviceRotate),
          ),
          findsOneWidget,
        );
        await tester.tap(button);
        expect(orientationRequests, hasLength(2));
        expect(orientationRequests.last, ['DeviceOrientation.portraitUp']);
        tester.view.physicalSize = const Size(400, 800);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 550));
        expect(find.byType(InteractiveViewer), findsOneWidget);
      }
      await tester.tap(button);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 550));
      expect(find.byType(AlbumCoverFlow), findsOneWidget);
      expect(find.byType(NowPlayingCapsule), findsNothing);
      expect(orientationRequests, hasLength(mobile ? 2 : 0));
      await tester.tap(button);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 550));
      expect(find.byType(InteractiveViewer), findsOneWidget);
      if (mobile) {
        tester.view.physicalSize = const Size(800, 400);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 550));
        expect(find.byType(AlbumCoverFlow), findsOneWidget);
        expect(button, findsNothing);
        expect(wakeButton, findsNothing);

        tester.view.physicalSize = const Size(400, 800);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 550));
        expect(find.byType(InteractiveViewer), findsOneWidget);
      }
      await changeSetting(false);
      expect(wakeButton, findsNothing);
      expect(button, findsNothing);
      if (mobile) {
        expect(orientationRequests, hasLength(3));
        expect(orientationRequests.last, isEmpty);
        tester.view.physicalSize = const Size(800, 400);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 550));
        expect(find.byType(AlbumCoverFlow), findsOneWidget);
        expect(button, findsNothing);
      }
      await tester.pumpWidget(const SizedBox());
    },
    variant: const TargetPlatformVariant({
      TargetPlatform.macOS,
      TargetPlatform.linux,
      TargetPlatform.windows,
      TargetPlatform.android,
      TargetPlatform.iOS,
    }),
  );

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
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
              child: child!,
            ),
            home: HomePage(albumCache: RotationAlbumCache()),
          ),
        );
        await tester.pump();
        expect(handle, 10);
        Finder pauseIcon(Finder button) => find
            .descendant(
              of: button,
              matching: find.byIcon(PhosphorIcons.pauseFill),
            )
            .hitTestable();
        const tap = Offset(150, 250);
        final scene = tester
            .widget<InteractiveViewer>(find.byType(InteractiveViewer))
            .transformationController!
            .toScene(tap);
        final cell = (
          (scene.dy / albumGridExtent).floor(),
          (scene.dx / albumGridExtent).floor(),
        );
        await tester.tapAt(tap);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));
        final selectedButton = find.descendant(
          of: find.byKey(ValueKey(('selected-cover', cell))),
          matching: find.byType(AlbumPlayButton),
        );
        await tester.tap(selectedButton);
        await tester.pump();
        expect(pauseIcon(selectedButton), findsOneWidget);
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
        final flowFinder = find.byType(AlbumCoverFlow);
        final flow = tester.widget<AlbumCoverFlow>(flowFinder);
        final flowButton = find
            .descendant(of: flowFinder, matching: find.byType(AlbumPlayButton))
            .hitTestable();
        expect(flow.playback!.playing, isTrue);
        final button = tester.widget<AlbumPlayButton>(flowButton);
        if (flow.playback!.isPlaying(button.asset, button.title)) {
          await tester.tap(flowButton);
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
        final nextButton = tester.widget<AlbumPlayButton>(flowButton);
        await tester.tap(flowButton);
        await tester.pump();
        expect(pauseIcon(flowButton), findsOneWidget);
        tester.view.physicalSize = const Size(400, 800);
        await tester.pump();
        if (!reduced) await tester.pump(const Duration(milliseconds: 550));
        expect(find.byType(InteractiveViewer), findsOneWidget);
        expect(
          flow.playback!.isPlaying(nextButton.asset, nextButton.title),
          isTrue,
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
