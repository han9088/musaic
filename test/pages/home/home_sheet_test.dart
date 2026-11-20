import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musaic/app/bottom_sheet_host.dart';
import 'package:musaic/features/artwork/presentation/xerox_palette.dart';
import 'package:musaic/features/artwork/presentation/xerox_palette_picker.dart';
import 'package:musaic/pages/home/home_sheet.dart';
import 'package:musaic/l10n/generated/app_localizations.dart';
import 'package:musaic/services/app_icon_service.dart';
import 'package:musaic/ui/bottom_sheet/bottom_sheet.dart';

void main() {
  testWidgets(
    'handle fades after idle, wakes on touch, stays hidden in CoverFlow',
    (tester) async {
      Widget app(bool enabled) => MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AppBottomSheetHost(
          child: HomeSheet(
            enabled: enabled,
            icons: const _Icons(),
            child: const ColoredBox(color: Colors.black),
          ),
        ),
      );
      final opacity = find.descendant(
        of: find.byType(HomeSheet),
        matching: find.byType(AnimatedOpacity),
      );
      await tester.pumpWidget(app(true));
      expect(tester.widget<AnimatedOpacity>(opacity).opacity, 1);
      await tester.pump(const Duration(seconds: 4));
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.widget<AnimatedOpacity>(opacity).opacity, 0);
      await tester.tapAt(const Offset(100, 100));
      await tester.pump();
      expect(tester.widget<AnimatedOpacity>(opacity).opacity, 1);
      await tester.pumpWidget(app(false));
      await tester.tapAt(const Offset(100, 100));
      await tester.pump();
      expect(tester.widget<AnimatedOpacity>(opacity).opacity, 0);
      await tester.pumpWidget(app(true));
      expect(tester.widget<AnimatedOpacity>(opacity).opacity, 1);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('Xerox mode toggles from the existing bottom sheet', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var xeroxEnabled = false;
    var allowModeChange = true;
    final palette = ValueNotifier(XeroxPalette.original);
    addTearDown(palette.dispose);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: StatefulBuilder(
          builder: (context, setState) => AppBottomSheetHost(
            child: HomeSheet(
              icons: const _Icons(),
              xeroxEnabled: xeroxEnabled,
              xeroxPalettePicker: XeroxPalettePicker(
                selection: palette,
                onChanged: (value) => palette.value = value,
              ),
              onXeroxChanged: (enabled) {
                if (allowModeChange) setState(() => xeroxEnabled = enabled);
                return xeroxEnabled;
              },
              child: const ColoredBox(color: Colors.black),
            ),
          ),
        ),
      ),
    );

    final sheet = DeskBottomSheet.of(tester.element(find.byType(HomeSheet)));
    final size = tester.getSize(find.byType(HomeSheet));
    final gesture = await tester.startGesture(
      Offset(size.width / 2, size.height - 32),
    );
    await gesture.moveBy(const Offset(0, -25));
    await gesture.moveBy(const Offset(0, -50));
    await gesture.moveBy(const Offset(0, -50));
    await gesture.up();
    await tester.pumpAndSettle();

    final toggle = find.byKey(const ValueKey('xerox-toggle'));
    expect(toggle, findsOneWidget);
    expect(tester.widget<ListTile>(toggle).selected, isFalse);
    final picker = find.byType(XeroxPalettePicker);
    expect(picker, findsNothing);
    await tester.tap(toggle);
    await tester.pump();
    expect(xeroxEnabled, isTrue);
    expect(tester.widget<ListTile>(toggle).selected, isTrue);
    for (final preset in XeroxPalette.values) {
      final swatch = find.byKey(ValueKey(preset));
      await tester.ensureVisible(swatch);
      await tester.tap(swatch);
      await tester.pump();
      expect(palette.value, preset);
    }
    await tester.ensureVisible(toggle);
    allowModeChange = false;
    await tester.tap(toggle);
    await tester.pump();
    expect(tester.widget<ListTile>(toggle).selected, isTrue);
    expect(picker, findsOneWidget);

    allowModeChange = true;
    await tester.tap(toggle);
    await tester.pump();
    expect(xeroxEnabled, isFalse);
    expect(tester.widget<ListTile>(toggle).selected, isFalse);
    expect(picker, findsNothing);

    sheet.dismiss();
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets('bottom handle opens once and dismisses on $platform', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: AppBottomSheetHost(
            child: HomeSheet(icons: _Icons(), child: SizedBox.expand()),
          ),
        ),
      );
      final context = tester.element(find.byType(HomeSheet));
      final sheet = DeskBottomSheet.of(context);
      final size = tester.getSize(find.byType(HomeSheet));
      final gesture = await tester.startGesture(
        Offset(size.width / 2, size.height - 32),
      );
      await gesture.moveBy(const Offset(0, -25));
      await gesture.moveBy(const Offset(0, -50));
      await gesture.moveBy(const Offset(0, -50));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(sheet.presentedSheetCount, 1);
      sheet.dismiss();
      await tester.pumpAndSettle();
      expect(sheet.isPresented, isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
    }, variant: TargetPlatformVariant.only(platform));
  }
}

class _Icons extends AppIconService {
  const _Icons();

  @override
  Future<AppIconSnapshot> read() async =>
      (supported: true, current: AppIconChoice.text);
}
