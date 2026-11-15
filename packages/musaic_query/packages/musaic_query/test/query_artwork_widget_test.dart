import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musaic_query/musaic_query.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('rebuilds reuse artwork; changing the request reloads it',
      (tester) async {
    var calls = 0;
    const channel = MethodChannel('com.deskbtm.muasic.query');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls++;
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    Widget artwork(int id, {int size = 200}) => MaterialApp(
            home: QueryArtworkWidget(
          id: id,
          type: ArtworkType.AUDIO,
          size: size,
        ));
    await tester.pumpWidget(artwork(1));
    await tester.pumpAndSettle();
    expect(calls, 1);
    await tester.pumpWidget(artwork(1));
    await tester.pumpAndSettle();
    expect(calls, 1);
    await tester.pumpWidget(artwork(2));
    await tester.pumpAndSettle();
    expect(calls, 2);
    await tester.pumpWidget(artwork(2, size: 300));
    await tester.pumpAndSettle();
    expect(calls, 3);
  });

  for (final keep in [false, true]) {
    testWidgets(
        'pending artwork keeps previous image only when requested: $keep',
        (tester) async {
      final png = await tester.runAsync(() async {
        final recorder = ui.PictureRecorder();
        ui.Canvas(recorder).drawColor(const Color(0xffff0000), BlendMode.src);
        final picture = recorder.endRecording();
        final image = await picture.toImage(1, 1);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        picture.dispose();
        return bytes!.buffer.asUint8List();
      });
      final pending = Completer<Uint8List?>();
      const channel = MethodChannel('com.deskbtm.muasic.query');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel,
          (call) async => call.arguments['id'] == 1 ? png : pending.future);
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      Widget artwork(int id) => MaterialApp(
          home: QueryArtworkWidget(
              id: id, type: ArtworkType.AUDIO, keepOldArtwork: keep));
      await tester.pumpWidget(artwork(1));
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsOneWidget);
      await tester.pumpWidget(artwork(2));
      await tester.pump();
      expect(find.byType(Image), keep ? findsOneWidget : findsNothing);
      pending.complete(null);
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsNothing);
    });
  }
  test('rejects filter enum mismatches before reaching native code', () async {
    await expectLater(
        MusaicQuery().queryWithFilters('artist', WithFiltersType.ARTISTS,
            args: AudiosArgs.ARTIST),
        throwsArgumentError);
  });
  test('rejects invalid artwork requests before calling native code', () async {
    await expectLater(MusaicQuery().queryArtwork(1, ArtworkType.AUDIO, size: 0),
        throwsRangeError);
    await expectLater(
        MusaicQuery().queryArtwork(1, ArtworkType.AUDIO, quality: -1),
        throwsRangeError);
  });
}
