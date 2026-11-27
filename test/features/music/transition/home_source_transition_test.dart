import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musaic/features/music/transition/home_source_transition.dart';
import 'package:musaic/ui/transitions/source_tile_motion.dart';

void main() {
  testWidgets('source transition commits once between exit and enter', (
    tester,
  ) async {
    final phases = <SourceTransitionPhase?>[];
    var handoffs = 0;
    const viewport = Size(300, 600);
    const cells = [(row: 0, column: 0, rect: Rect.fromLTWH(0, 0, 100, 100))];
    final exit = SourceTileMotion.exit(cells, viewport);
    final enter = SourceTileMotion.enter(cells);
    late final HomeSourceTransition transition;
    transition = HomeSourceTransition(
      vsync: tester,
      isMounted: () => true,
      notifyChanged: () => phases.add(transition.phase),
      onMotionChanged: () {},
    );
    final completed = transition.start(
      targetAlbums: [
        {'asset': 'asset-a', 'title': 'Album A'},
      ],
      exit: exit,
      enter: enter,
      onHandoff: (albums) {
        expect(albums.single['asset'], 'asset-a');
        handoffs++;
      },
    );
    expect(transition.phase, SourceTransitionPhase.exit);
    await tester.pump();
    await tester.pump(Duration(milliseconds: exit.durationMs.ceil() + 1));
    expect(transition.phase, SourceTransitionPhase.handoff);
    expect(handoffs, 0);
    await tester.pump(Duration(milliseconds: sourceHandoffMs.ceil() + 1));
    expect(transition.phase, SourceTransitionPhase.enter);
    expect(handoffs, 1);
    await tester.pump(const Duration(seconds: 1));
    await completed;
    expect(transition.phase, isNull);
    expect(handoffs, 1);
    expect(
      phases,
      containsAllInOrder([
        SourceTransitionPhase.exit,
        SourceTransitionPhase.handoff,
        SourceTransitionPhase.enter,
        null,
      ]),
    );
    transition.dispose();
  });
}
