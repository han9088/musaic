import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musaic/pages/home/album_cover_flow.dart';
import 'package:musaic/pages/home/album_layout_transition.dart';
import 'package:musaic/pages/home/home_page.dart';
import 'package:musaic/services/mock_album_cache.dart';

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
        final next = flow.initialPosition.round() + 1;
        final title = flow.albums[next % flow.albums.length]['title'] as String;
        if (!reduced) {
          await tester.tap(find.byKey(ValueKey('cover-$next')));
          await tester.pumpAndSettle();
          expect(find.text(title), findsOneWidget);
        }
        tester.view.physicalSize = const Size(400, 800);
        await tester.pump();
        if (!reduced) await tester.pump(const Duration(milliseconds: 550));
        expect(find.byType(InteractiveViewer), findsOneWidget);
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
