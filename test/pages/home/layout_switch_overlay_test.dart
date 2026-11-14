import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musaic/pages/home/layout_switch_overlay.dart';

void main() {
  testWidgets('Mac hover reveals and holds the switch without clicking', (
    tester,
  ) async {
    var switches = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: LayoutSwitchOverlay(
          coverFlow: false,
          onSwitch: () => switches++,
          child: const SizedBox.expand(),
        ),
      ),
    );
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(10, 10));
    await tester.pump();
    expect(find.byKey(const ValueKey('layout-switch')), findsOneWidget);
    expect(switches, 0);
    await mouse.moveTo(
      tester.getCenter(find.byKey(const ValueKey('layout-switch'))),
    );
    await tester.pump(const Duration(seconds: 5));
    expect(find.byKey(const ValueKey('layout-switch')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('layout-switch')));
    await tester.pump();
    expect(switches, 1);
    await mouse.moveTo(const Offset(10, 10));
    await tester.pump();
    await tester.pump(const Duration(seconds: 4));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.byKey(const ValueKey('layout-switch')), findsNothing);
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
            child: const ColoredBox(color: Colors.black),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('layout-switch-wake')));
      await tester.pump();
      expect(switches, 0);
      expect(find.byKey(const ValueKey('layout-switch')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('layout-switch')));
      await tester.pump();
      expect(switches, 1);
      await tester.pump(const Duration(seconds: 4));
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.byKey(const ValueKey('layout-switch')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('layout-switch-wake')));
      await tester.pump();
      expect(switches, 1);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
