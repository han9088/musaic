import 'dart:async';

// Talker still uses Flutter's legacy Material library.
// ignore: deprecated_member_use
import 'package:flutter/material.dart' as flutter_material;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musaic/app/app.dart';
import 'package:musaic/features/settings/developer_options_settings.dart';
import 'package:musaic/l10n/generated/app_localizations.dart';
import 'package:musaic/main.dart' as app;
import 'package:musaic/services/diagnostics/diagnostic_log.dart';
import 'package:musaic/storage/settings/app_language_preference.dart';

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

  for (final (language, cancelLabel) in [
    (AppLanguage.english, 'Cancel'),
    (AppLanguage.simplifiedChinese, '取消'),
  ]) {
    testWidgets('Talker works in ${language.name}', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.pump);
      await tester.pumpWidget(MusaicApp(initialLanguage: language));
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      unawaited(
        navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: DeveloperOptionsSettings()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      diagnosticLog.record(DiagnosticEvent.playbackStarted);
      await tester.tap(find.text('Talker DevTool'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final toolbar = tester.element(find.byType(flutter_material.AppBar));
      expect(
        flutter_material.MaterialLocalizations.of(toolbar).cancelButtonLabel,
        cancelLabel,
      );
      expect(find.text('playbackStarted'), findsWidgets);

      await tester.tap(find.byIcon(flutter_material.Icons.copy).first);
      await tester.pumpAndSettle();
      expect(find.text('Log item is copied in clipboard'), findsOneWidget);

      await tester.enterText(
        find.byType(flutter_material.TextField),
        'no matching log',
      );
      await tester.pumpAndSettle();
      expect(find.text('playbackStarted'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  }
}
