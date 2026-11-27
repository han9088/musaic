import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musaic/app/app.dart';
import 'package:musaic/features/music/playback/now_playing_capsule.dart';
import 'package:musaic/l10n/generated/app_localizations.dart';
import 'package:musaic/pages/home/home_sheet.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('switches the grid back to the demo source', (tester) async {
    await tester.pumpWidget(const MusaicApp());

    final mock = find.byKey(const ValueKey('music-source-mock'));
    final mock2 = find.byKey(const ValueKey('music-source-mock2'));
    final capsule = find.byType(NowPlayingCapsule);
    final settledSource = find.byWidgetPredicate(
      (widget) =>
          widget is HomeSheet && widget.sourceSwitching?.value == false,
      description: 'settled music source',
    );
    final secondDemoArtwork = find.byWidgetPredicate(
      (widget) =>
          widget is Image &&
          widget.semanticLabel?.startsWith('Mock 2 · ') == true,
    );
    Future<void> waitFor(Finder target) async {
      final elapsed = Stopwatch()..start();
      while (target.evaluate().isEmpty &&
          elapsed.elapsed < const Duration(seconds: 10)) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(target, findsWidgets);
    }

    Future<void> openMusicSources() async {
      await waitFor(settledSource);
      await waitFor(capsule.hitTestable());
      final l10n = AppLocalizations.of(tester.element(capsule));
      final source = find.widgetWithText(ListTile, l10n.musicSource);
      await tester.drag(capsule, const Offset(0, -140));
      await waitFor(source.hitTestable());
      expect(mock, findsNothing);
      expect(mock2, findsNothing);
      await tester.tap(source);
      await waitFor(mock.hitTestable());
      expect(mock2, findsNothing);
    }

    await waitFor(settledSource);
    final home = tester.widget<HomeSheet>(find.byType(HomeSheet));
    final sources = home.sources!;
    // 第二套演示仅作为内部转场夹具，用户界面不再提供入口。
    final prepareSecondDemo = home.onSourceSelection!(sources.selectMock2);
    await waitFor(secondDemoArtwork);
    await waitFor(settledSource);
    await prepareSecondDemo;

    await openMusicSources();
    expect(tester.widget<ListTile>(mock).selected, isFalse);
    await tester.tap(mock);

    await waitFor(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.semanticLabel?.startsWith('Mock 2 · ') == false,
      ),
    );
    await waitFor(settledSource);
    expect(secondDemoArtwork, findsNothing);
    expect(sources.mock2Selected.value, isFalse);
    await openMusicSources();
    expect(tester.widget<ListTile>(mock).selected, isTrue);
    expect(mock2, findsNothing);
    expect(tester.takeException(), isNull);
  });
}
