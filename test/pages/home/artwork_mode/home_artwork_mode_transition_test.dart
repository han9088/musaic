import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musaic/pages/home/artwork_mode/home_artwork_mode_transition.dart';
import 'package:musaic/features/transitions/source_tile_motion.dart';

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
    late final HomeArtworkModeTransition transition;
    transition = HomeArtworkModeTransition(
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
    await tester.pump(
      Duration(milliseconds: exit.durationMs.ceil() + 1),
    );
    expect(transition.phase, ArtworkModeTransitionPhase.handoff);
    expect(xeroxEnabled, isFalse);

    await tester.pump(
      Duration(milliseconds: sourceHandoffMs.ceil() + 1),
    );
    expect(transition.phase, ArtworkModeTransitionPhase.enter);
    expect(xeroxEnabled, isTrue);

    await tester.pump(const Duration(seconds: 1));
    await done;
    expect(transition.phase, isNull);
    expect(completed, isTrue);
    expect(phases, containsAllInOrder([
      ArtworkModeTransitionPhase.exit,
      ArtworkModeTransitionPhase.handoff,
      ArtworkModeTransitionPhase.enter,
      null,
    ]));
    transition.dispose();
  });
}
