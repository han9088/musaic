import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musaic/app/app.dart';
import 'package:musaic/pages/home/home_sheet.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('switches the grid from Mock to Mock 2', (tester) async {
    await tester.pumpWidget(const MusaicApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final homeSheet = find.byType(HomeSheet);
    final size = tester.getSize(homeSheet);
    await tester.tapAt(Offset(size.width / 2, size.height - 32));
    await tester.pump(const Duration(milliseconds: 450));
    await tester.tap(find.byKey(const ValueKey('music-source-mock')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.tap(find.byKey(const ValueKey('music-source-mock2')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    expect(
      tester
          .widget<ListTile>(find.byKey(const ValueKey('music-source-mock2')))
          .selected,
      isTrue,
    );
    expect(
      tester
          .widget<ListTile>(find.byKey(const ValueKey('music-source-mock')))
          .selected,
      isFalse,
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.semanticLabel?.startsWith('Mock 2 · ') == true,
      ),
      findsWidgets,
    );
    expect(tester.takeException(), isNull);
  });
}
