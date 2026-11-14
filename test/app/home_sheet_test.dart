import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musaic/app/bottom_sheet_host.dart';
import 'package:musaic/pages/home/home_sheet.dart';
import 'package:musaic/ui/bottom_sheet/bottom_sheet.dart';

void main() {
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets('bottom handle opens once and dismisses on $platform', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = platform;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      await tester.pumpWidget(
        const MaterialApp(
          home: AppBottomSheetHost(
            child: HomeSheet(child: SizedBox.expand()),
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
    });
  }
}
