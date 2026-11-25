import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musaic/features/coverflow/album_coverflow.dart';
import 'package:musaic/services/album_haptics.dart';
import 'package:musaic/services/album_tick_sound.dart';
import 'package:musaic/ui/widgets/horizontal_selection_wheel.dart';

class SilentSound extends AlbumTickSound {
  final volumes = <double>[];
  bool prepared = false;
  @override
  Future<void> prepare() async {
    prepared = true;
  }

  @override
  Future<void> play(double volume) async {
    volumes.add(volume);
  }
}

class RecordingHaptics extends AlbumHaptics {
  RecordingHaptics() : super(sound: SilentSound());
  final directions = <bool>[];
  final strengths = <double>[];
  bool active = true;
  int disposals = 0;

  @override
  Future<void> tick({required bool movingLeft, double strength = 1}) async {
    if (active) {
      directions.add(movingLeft);
      strengths.add(strength);
    }
  }

  @override
  Future<void> setActive(bool active) async => this.active = active;

  @override
  Future<void> dispose() async => disposals++;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('macOS keeps sound without calling the mobile haptics plugin', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final calls = <MethodCall>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(const MethodChannel('pulsar'), (
      call,
    ) async {
      calls.add(call);
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(
        const MethodChannel('pulsar'),
        null,
      ),
    );
    final sound = SilentSound();
    final haptics = AlbumHaptics(sound: sound);
    await haptics.prepare();
    await haptics.tick(movingLeft: true);
    await haptics.dispose();
    expect(sound.prepared, isTrue);
    expect(sound.volumes, [1.0]);
    expect(calls, isEmpty);
  });

  test('iOS pairs Pulsar with system ticks without queuing feedback', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final calls = <MethodCall>[];
    final pending = Completer<void>();
    final hapticCalls = <MethodCall>[];
    var handle = 0;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(const MethodChannel('pulsar'), (
      call,
    ) async {
      hapticCalls.add(call);
      if (call.method == 'Pulsar_hapticSupport') return 3;
      if (call.method == 'PatternComposer_parsePattern') return ++handle;
      return null;
    });
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      calls.add(call);
      await pending.future;
      return null;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(const MethodChannel('pulsar'), null);
      debugDefaultTargetPlatformOverride = null;
      messenger.setMockMethodCallHandler(SystemChannels.platform, null);
    });
    final sound = SilentSound();
    final haptics = AlbumHaptics(sound: sound);
    await haptics.prepare();
    expect(sound.prepared, isFalse);
    final first = haptics.tick(movingLeft: true);
    await haptics.tick(movingLeft: false);
    expect(calls.single.method, 'SystemSound.play');
    expect(calls.single.arguments, 'SystemSoundType.tick');
    expect(
      hapticCalls.where((c) => c.method == 'PatternComposer_play'),
      hasLength(1),
    );
    pending.complete();
    await first;
    await haptics.setActive(false);
    await haptics.tick(movingLeft: true);
    expect(calls, hasLength(1));
    await haptics.setActive(true);
    await haptics.tick(movingLeft: false);
    expect(calls, hasLength(2));
    await haptics.dispose();
    await haptics.tick(movingLeft: true);
    expect(calls, hasLength(2));
    expect(sound.volumes, isEmpty);
    expect(
      hapticCalls.where((c) => c.method == 'PatternComposer_parsePattern'),
      hasLength(10),
    );
    expect(
      hapticCalls.where((c) => c.method == 'PatternComposer_play'),
      hasLength(2),
    );
    expect(
      hapticCalls.where((c) => c.method == 'PatternComposer_release'),
      hasLength(10),
    );
  });

  test('preloads directional ticks once and releases players', () async {
    const channel = MethodChannel('pulsar');
    final calls = <MethodCall>[];
    var handle = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (call.method == 'Pulsar_hapticSupport') return 3;
          if (call.method == 'PatternComposer_parsePattern') return ++handle;
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
    final sound = SilentSound();
    final haptics = AlbumHaptics(sound: sound);
    await haptics.prepare();
    await haptics.prepare();
    await haptics.tick(movingLeft: true);
    await haptics.tick(movingLeft: false, strength: 0.2);
    expect(sound.volumes, [1.0, 0.2]);
    await haptics.setActive(false);
    await haptics.tick(movingLeft: true);
    await haptics.dispose();
    await haptics.tick(movingLeft: true);
    expect(
      calls.where((c) => c.method == 'PatternComposer_parsePattern'),
      hasLength(10),
    );
    final plays = calls
        .where((c) => c.method == 'PatternComposer_play')
        .toList();
    expect(plays, hasLength(2));
    expect(plays[0].arguments, isNot(plays[1].arguments));
    expect(
      calls.where((c) => c.method == 'PatternComposer_release'),
      hasLength(10),
    );
  });

  testWidgets('wheel ticks once when a drag crosses one index', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final haptics = RecordingHaptics();
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 180,
            child: HorizontalSelectionWheel(
              labels: const ['10', '20', '30', '40', '60', '80', '90'],
              selectedIndex: 2,
              onSettled: (_) {},
              semanticLabel: 'Delay',
              semanticValue: (index) => '$index',
              textStyle: const TextStyle(fontSize: 18),
              haptics: haptics,
            ),
          ),
        ),
      ),
    );
    expect(haptics.directions, isEmpty);

    final wheel = find.byType(HorizontalSelectionWheel);
    final gesture = await tester.startGesture(tester.getCenter(wheel));
    await gesture.moveBy(const Offset(-20, 0));
      await gesture.moveBy(const Offset(-28, 0));
    expect(haptics.directions, [true]);
    expect(haptics.strengths.single, inInclusiveRange(0.15, 1.0));
    await gesture.moveBy(const Offset(-2, 0));
    expect(haptics.directions, [true]);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(haptics.directions, [true]);
    expect(haptics.disposals, 0);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(haptics.disposals, 0);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets(
    'ticks once per selected album without replaying skipped albums',
    (tester) async {
      final haptics = RecordingHaptics();
      await tester.pumpWidget(
        MaterialApp(
          home: AlbumCoverFlow(
            albums: const [
              {'asset': 'assets/albums/0.jpg', 'artist': 'A', 'title': 'B'},
              {'asset': 'assets/albums/0.jpg', 'artist': 'C', 'title': 'D'},
              {'asset': 'assets/albums/0.jpg', 'artist': 'E', 'title': 'F'},
            ],
            haptics: haptics,
          ),
        ),
      );
      final drag = tester
          .widgetList<GestureDetector>(find.byType(GestureDetector))
          .firstWhere((widget) => widget.onHorizontalDragUpdate != null);
      drag.onHorizontalDragStart!(DragStartDetails());
      void move(double dx) => drag.onHorizontalDragUpdate!(
        DragUpdateDetails(
          delta: Offset(dx, 0),
          primaryDelta: dx,
          globalPosition: Offset.zero,
        ),
      );
      await tester.pump(const Duration(milliseconds: 16));
      move(-40);
      await tester.pump(const Duration(milliseconds: 16));
      expect(haptics.directions, isEmpty);
      move(-30);
      await tester.pump(const Duration(milliseconds: 48));
      expect(haptics.directions, isEmpty);
      move(-40);
      await tester.pump(const Duration(milliseconds: 48));
      expect(haptics.directions, [true]);
      move(-5);
      await tester.pump(const Duration(milliseconds: 16));
      expect(haptics.directions, [true]);
      move(115);
      await tester.pump(const Duration(milliseconds: 48));
      expect(haptics.directions, [true, false]);
      await tester.pump(const Duration(milliseconds: 100));
      expect(haptics.directions, [true, false]);
      move(-1000);
      await tester.pump(const Duration(milliseconds: 48));
      expect(haptics.directions, [true, false, true]);
      await tester.pump(const Duration(milliseconds: 100));
      expect(haptics.directions, [true, false, true]);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
