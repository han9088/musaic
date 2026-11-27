import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musaic/app/app.dart';
import 'package:musaic/features/music/playback/now_playing_capsule.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('switches the grid from Mock to Mock 2', (tester) async {
    await tester.pumpWidget(const MusaicApp());

    final mock = find.byKey(const ValueKey('music-source-mock'));
    final mock2 = find.byKey(const ValueKey('music-source-mock2'));
    final capsule = find.byType(NowPlayingCapsule);
    Future<void> waitFor(Finder target) async {
      final elapsed = Stopwatch()..start();
      while (target.evaluate().isEmpty &&
          elapsed.elapsed < const Duration(seconds: 10)) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(target, findsWidgets);
    }

    Future<void> openMusicSources() async {
      await waitFor(capsule.hitTestable());
      await tester.drag(capsule, const Offset(0, -140));
      await waitFor(mock2.hitTestable());
    }

    await openMusicSources();
    expect(tester.widget<ListTile>(mock).selected, isTrue);
    await tester.tap(mock2);

    await waitFor(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.semanticLabel?.startsWith('Mock 2 · ') == true,
      ),
    );
    await openMusicSources();
    expect(tester.widget<ListTile>(mock2).selected, isTrue);
    expect(tester.widget<ListTile>(mock).selected, isFalse);
    expect(tester.takeException(), isNull);
  });
}
