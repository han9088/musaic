import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musaic/features/artwork/mode/artwork_mode_controller.dart';
import 'package:musaic/features/artwork/mode/artwork_mode_transition.dart';
import 'package:musaic/features/artwork/presentation/xerox_palette.dart';
import 'package:musaic/ui/transitions/source_tile_motion.dart';

void main() {
  testWidgets('Xerox mode flies originals out before processed covers enter', (
    tester,
  ) async {
    const viewport = Size(300, 600);
    const cells = [
      (row: 0, column: 0, rect: Rect.fromLTWH(0, 0, 100, 100)),
      (row: 1, column: 0, rect: Rect.fromLTWH(0, 100, 100, 100)),
    ];
    final exit = SourceTileMotion.exit(cells, viewport);
    final enter = SourceTileMotion.enter(cells);
    final phases = <ArtworkModeTransitionPhase?>[];
    var xeroxEnabled = false;
    var completed = false;
    late final ArtworkModeTransition transition;
    transition = ArtworkModeTransition(
      vsync: tester,
      isMounted: () => true,
      notifyChanged: () => phases.add(transition.phase),
      onMotionChanged: () {},
    );

    final done = transition.start(
      exit: exit,
      enter: enter,
      onHandoff: () => xeroxEnabled = true,
      onCompleted: () => completed = true,
    );
    expect(transition.phase, ArtworkModeTransitionPhase.exit);
    expect(xeroxEnabled, isFalse);

    await tester.pump();
    await tester.pump(Duration(milliseconds: exit.durationMs.ceil() + 1));
    expect(transition.phase, ArtworkModeTransitionPhase.handoff);
    expect(xeroxEnabled, isFalse);

    await tester.pump(Duration(milliseconds: sourceHandoffMs.ceil() + 1));
    expect(transition.phase, ArtworkModeTransitionPhase.enter);
    expect(xeroxEnabled, isTrue);

    await tester.pump(const Duration(seconds: 1));
    await done;
    expect(transition.phase, isNull);
    expect(completed, isTrue);
    expect(
      phases,
      containsAllInOrder([
        ArtworkModeTransitionPhase.exit,
        ArtworkModeTransitionPhase.handoff,
        ArtworkModeTransitionPhase.enter,
        null,
      ]),
    );
    transition.dispose();
  });

  testWidgets('paper color changes at the Xerox animation handoff', (
    tester,
  ) async {
    const viewport = Size(300, 600);
    const cells = [(row: 0, column: 0, rect: Rect.fromLTWH(0, 0, 100, 100))];
    final controller = ArtworkModeController(
      vsync: tester,
      isMounted: () => true,
      notifyChanged: () {},
      onMotionChanged: () {},
    )..enabled = true;
    addTearDown(controller.dispose);

    Future<void> pick(XeroxPalette palette, {bool reduceMotion = false}) =>
        controller.applyPalette(
          selection: palette,
          visibleCells: cells,
          viewport: viewport,
          reduceMotion: reduceMotion,
        );

    final done = pick(XeroxPalette.ochre);
    expect(controller.phase, ArtworkModeTransitionPhase.exit);
    expect(controller.palette.value, XeroxPalette.original);

    await pick(XeroxPalette.sage);
    await tester.pump();
    await tester.pump(
      Duration(
        milliseconds:
            SourceTileMotion.exit(cells, viewport).durationMs.ceil() + 1,
      ),
    );
    expect(controller.phase, ArtworkModeTransitionPhase.handoff);
    expect(controller.palette.value, XeroxPalette.original);

    await tester.pump(Duration(milliseconds: sourceHandoffMs.ceil() + 1));
    expect(controller.phase, ArtworkModeTransitionPhase.enter);
    expect(controller.palette.value, XeroxPalette.ochre);
    expect(controller.enabled, isTrue);

    await tester.pump(const Duration(seconds: 1));
    await done;
    expect(controller.phase, isNull);
    await pick(XeroxPalette.ochre);
    expect(controller.phase, isNull);

    await pick(XeroxPalette.indigo, reduceMotion: true);
    expect(controller.palette.value, XeroxPalette.indigo);
    expect(controller.phase, isNull);
  });
}
