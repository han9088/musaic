import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musaic/features/layout/layout_switch_overlay.dart';

void main() {
  final switchButton = find
      .byKey(const ValueKey('layout-switch'))
      .hitTestable();
  testWidgets('Mac hover reveals and holds the switch without clicking', (
    tester,
  ) async {
    var switches = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: LayoutSwitchOverlay(
          coverFlow: false,
          onSwitch: () => switches++,
          builder: (button, _) => Align(
            alignment: Alignment.bottomRight,
            child: SizedBox.square(dimension: 38, child: button),
          ),
        ),
      ),
    );
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(10, 10));
    await tester.pump();
    expect(switchButton, findsOneWidget);
    expect(switches, 0);
    await mouse.moveTo(tester.getCenter(switchButton));
    await tester.pump(const Duration(seconds: 5));
    expect(switchButton, findsOneWidget);
    await tester.tap(switchButton);
    await tester.pump();
    expect(switches, 1);
    await mouse.moveTo(const Offset(10, 10));
    await tester.pump();
    await tester.pump(const Duration(seconds: 4));
    await tester.pump(const Duration(milliseconds: 250));
    expect(switchButton, findsNothing);
    await mouse.removePointer();
    await tester.pumpWidget(const SizedBox());
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets(
    'hidden switch wakes without toggling and hides after inactivity',
    (tester) async {
      var switches = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: LayoutSwitchOverlay(
            coverFlow: false,
            onSwitch: () => switches++,
            builder: (button, _) => Align(
              alignment: Alignment.bottomRight,
              child: SizedBox.square(dimension: 38, child: button),
            ),
          ),
        ),
      );
      expect(switchButton, findsOneWidget);
      await tester.pump(const Duration(milliseconds: 2499));
      expect(switchButton, findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 250));
      expect(switchButton, findsNothing);
      await tester.tap(find.byKey(const ValueKey('layout-switch-wake')));
      await tester.pump();
      expect(switches, 0);
      expect(switchButton, findsOneWidget);
      final press = await tester.startGesture(tester.getCenter(switchButton));
      await tester.pump(const Duration(seconds: 4));
      expect(switchButton, findsOneWidget);
      await press.cancel();
      await tester.tap(switchButton);
      await tester.pump();
      expect(switches, 1);
      await tester.pump(const Duration(milliseconds: 2500));
      await tester.pump(const Duration(milliseconds: 250));
      expect(switchButton, findsNothing);
      await tester.tap(find.byKey(const ValueKey('layout-switch-wake')));
      await tester.pump();
      expect(switches, 1);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
