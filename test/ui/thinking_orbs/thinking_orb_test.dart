import 'dart:ui' as ui;

import 'package:musaic/ui/thinking_orbs/thinking_orb.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('all nine states record non-empty 64 and 20 pixel frames', () {
    for (final state in ThinkingOrbState.values) {
      for (final size in ThinkingOrbSize.values) {
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(
          recorder,
          Rect.fromLTWH(0, 0, size.pixels, size.pixels),
        );
        debugPaintThinkingOrbFrame(canvas, state: state, size: size);
        final picture = recorder.endRecording();
        expect(
          picture.approximateBytesUsed,
          greaterThan(0),
          reason: '${state.name}/${size.name} should record draw commands',
        );
        picture.dispose();
      }
    }
  });

  testWidgets('uses state semantics and the exact tuned dimensions', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: ThinkingOrb(
            state: ThinkingOrbState.searching,
            size: ThinkingOrbSize.inline,
            paused: true,
          ),
        ),
      ),
    );

    expect(find.bySemanticsLabel('Searching…'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('thinking-orb-canvas'))),
      const Size.square(20),
    );
    semantics.dispose();
  });

  testWidgets('reduced motion paints a static representative frame', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Center(child: ThinkingOrb()),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.byType(ThinkingOrb), findsOneWidget);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });
}
