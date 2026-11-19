import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musaic/app/bottom_sheet_host.dart';
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
    var xeroxEnabled = false;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AppBottomSheetHost(
          child: HomeSheet(
            icons: const _Icons(),
            xeroxEnabled: xeroxEnabled,
            onXeroxChanged: (enabled) => xeroxEnabled = enabled,
            child: const ColoredBox(color: Colors.black),
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
    await tester.tap(toggle);
    await tester.pump();
    expect(xeroxEnabled, isTrue);
    expect(tester.widget<ListTile>(toggle).selected, isTrue);
    await tester.tap(toggle);
    await tester.pump();
    expect(xeroxEnabled, isFalse);
    expect(tester.widget<ListTile>(toggle).selected, isFalse);

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
