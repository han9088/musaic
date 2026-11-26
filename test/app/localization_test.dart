import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musaic/l10n/generated/app_localizations.dart';
import 'package:musaic/main.dart' as app;

void main() {
  testWidgets('Chinese locale loads app and framework localizations', (
    tester,
  ) async {
    // Drain font notifications queued while the test tree is torn down.
    addTearDown(tester.pump);
    tester.binding.platformDispatcher.localesTestValue = const [Locale('zh')];
    addTearDown(tester.binding.platformDispatcher.clearLocalesTestValue);

    app.main();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    final context = tester.element(find.byType(Scaffold));
    expect(Localizations.localeOf(context), const Locale('zh'));
    expect(AppLocalizations.of(context).localeName, 'zh');
    expect(MaterialLocalizations.of(context).cancelButtonLabel, '取消');
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
  });
}
