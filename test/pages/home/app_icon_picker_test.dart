import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musaic/l10n/generated/app_localizations.dart';
import 'package:musaic/pages/home/app_icon_picker.dart';
import 'package:musaic/services/app_icon_service.dart';

void main() {
  for (final choice in [AppIconChoice.mosaic, AppIconChoice.vinyl]) {
    for (final fails in [false, true]) {
      testWidgets(
        'icon selection follows system result ($choice, fails: $fails)',
        (tester) async {
          final icons = _Icons(fails: fails);
          await tester.pumpWidget(
            MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              locale: const Locale('en'),
              home: Scaffold(body: AppIconPicker(icons: icons)),
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(ValueKey('app-icon-${choice.name}')));
          await tester.pumpAndSettle();

          final selected = tester.widget<ListTile>(
            find.byKey(
              ValueKey(fails ? 'app-icon-classic' : 'app-icon-${choice.name}'),
            ),
          );
          expect(selected.trailing, isNotNull);
          expect(icons.changes, 1);
          expect(tester.takeException(), isNull);
          expect(
            find.text('Could not change the app icon. Please try again.'),
            fails ? findsOneWidget : findsNothing,
          );
        },
      );
    }
  }
}

class _Icons extends AppIconService {
  _Icons({required this.fails});

  final bool fails;
  AppIconChoice current = AppIconChoice.classic;
  int changes = 0;

  @override
  Future<AppIconSnapshot> read() async => (supported: true, current: current);

  @override
  Future<void> change(AppIconChoice choice) async {
    changes++;
    if (fails) throw StateError('Icon update failed');
    current = choice;
  }
}
