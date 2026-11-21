import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musaic/features/music/playback/now_playing_title.dart';

void main() {
  testWidgets('only an overflowing title scrolls and respects reduce motion', (
    tester,
  ) async {
    const shortTitle = 'Song';
    const longTitle = 'A song with a very long title';

    Widget app(String title, {bool reduceMotion = false}) => MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
        child: child!,
      ),
      home: Center(
        child: SizedBox(
          width: 90,
          child: NowPlayingTitle(
            title: title,
            style: const TextStyle(fontSize: 12),
            animate: true,
          ),
        ),
      ),
    );

    await tester.pumpWidget(app(shortTitle));
    final shortLabel = find.text(shortTitle);
    final shortStart = tester.getTopLeft(shortLabel);
    await tester.pump(const Duration(seconds: 2));
    expect(tester.getTopLeft(shortLabel), shortStart);

    await tester.pumpWidget(app(longTitle));
    final longLabel = find.text(longTitle).first;
    final longStart = tester.getTopLeft(longLabel);
    await tester.pump(const Duration(milliseconds: 800));
    expect(tester.getTopLeft(longLabel), longStart);
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.getTopLeft(longLabel).dx, lessThan(longStart.dx));

    await tester.pumpWidget(app(longTitle, reduceMotion: true));
    expect(find.text(longTitle), findsOneWidget);
    final reducedStart = tester.getTopLeft(longLabel);
    await tester.pump(const Duration(seconds: 2));
    expect(tester.getTopLeft(longLabel), reducedStart);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
