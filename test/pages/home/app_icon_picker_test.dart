import 'package:flutter/rendering.dart' show RenderTable;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musaic/l10n/generated/app_localizations.dart';
import 'package:musaic/features/settings/app_icon_picker.dart';
import 'package:musaic/services/app_icon_service.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

void main() {
  for (final choice in [AppIconChoice.mosaic, AppIconChoice.vinyl]) {
    for (final fails in [false, true]) {
      testWidgets(
        'icon selection follows system result ($choice, fails: $fails)',
        (tester) async {
          await tester.binding.setSurfaceSize(const Size(390, 600));
          addTearDown(() => tester.binding.setSurfaceSize(null));
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
          Finder tile(AppIconChoice icon) =>
              find.byKey(ValueKey('app-icon-${icon.name}'));
          final first = tester.getTopLeft(tile(AppIconChoice.vinylPrimary));
          final third = tester.getTopLeft(tile(AppIconChoice.mosaic));
          final nextRow = tester.getTopLeft(tile(AppIconChoice.vinyl));
          expect(third.dx, greaterThan(first.dx));
          expect(third.dy, first.dy);
          expect(nextRow.dx, first.dx);
          expect(nextRow.dy, greaterThan(first.dy));
          final table = find.byType(Table);
          final grid = tester.renderObject<RenderTable>(table);
          for (final (rowIndex, rowChoice) in [
            (0, AppIconChoice.vinylPrimary),
            (1, AppIconChoice.vinyl),
          ]) {
            final image = find.descendant(
              of: tile(rowChoice),
              matching: find.byType(Image),
            );
            final label = find.descendant(
              of: tile(rowChoice),
              matching: find.byType(Text),
            );
            final contentTop = tester.getTopLeft(image).dy;
            final contentBottom = tester.getBottomRight(label).dy;
            final rowCenterY = grid
                .localToGlobal(grid.getRowBox(rowIndex).center)
                .dy;
            expect((contentTop + contentBottom) / 2, closeTo(rowCenterY, 0.01));
          }
          final border = tester.widget<Table>(table).border!;
          expect(
            border.horizontalInside,
            const BorderSide(color: Color(0x33FFFFFF), width: 0.5),
          );
          expect(border.isUniform, isTrue);

          await tester.tap(tile(choice));
          await tester.pumpAndSettle();

          final selected = tile(fails ? AppIconChoice.text : choice);
          expect(
            find.descendant(
              of: selected,
              matching: find.byIcon(PhosphorIcons.checkBold),
            ),
            findsOneWidget,
          );
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
  AppIconChoice current = AppIconChoice.text;
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
