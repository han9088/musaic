import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musaic/main.dart' as app;

void main() {
  testWidgets('Musaic starts with its own app title', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    app.main();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    final context = tester.element(find.byType(Scaffold));
    expect(materialApp.onGenerateTitle!(context), 'Musaic');
    expect(find.byType(Image), findsWidgets);
    final controller = tester
        .widget<InteractiveViewer>(find.byType(InteractiveViewer))
        .transformationController!;
    final initial = controller.value.clone();
    await tester.pump(const Duration(milliseconds: 100));
    expect(controller.value, isNot(initial));
    await tester.drag(find.byType(InteractiveViewer), const Offset(1500, 900));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(Image), findsWidgets);
    final position = controller.value.entry(0, 3);
    await tester.pump(const Duration(milliseconds: 50));
    expect(controller.value.entry(0, 3), greaterThan(position));
    expect(tester.takeException(), isNull);
    final viewer = find.byType(InteractiveViewer);
    for (final scale in [0.4, 1.0, 2.5]) {
      controller.value = Matrix4.diagonal3Values(scale, scale, 1);
      await tester.pump();
      await tester.fling(viewer, const Offset(30, 0), 1800);
      final start = controller.value.entry(0, 3);
      for (var frame = 0; frame < 60; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      final travel = controller.value.entry(0, 3) - start;
      expect(travel, greaterThanOrEqualTo(0));
      expect(travel, lessThan(65));
      expect(tester.takeException(), isNull);
    }
    tester.view.physicalSize = const Size(850, 400);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump();
    expect(find.byType(InteractiveViewer), findsNothing);
    await tester.pump();
    final active = tester.getRect(find.byKey(const ValueKey('cover-0')));
    final next = tester.getRect(find.byKey(const ValueKey('cover-1')));
    final further = tester.getRect(find.byKey(const ValueKey('cover-2')));
    expect(active.width, greaterThan(next.width));
    expect(next.width, closeTo(further.width, 0.01));
    expect(active.right, lessThan(next.left));
    expect(next.right, lessThan(further.left));
    expect(find.byType(Image), findsWidgets);
    await tester.fling(find.byType(Scaffold), const Offset(-500, 0), 1600);
    await tester.pump(const Duration(milliseconds: 80));
    final plane = find.byKey(const ValueKey('cover-flow-plane'));
    expect(
      tester.widget<Transform>(plane).transform.entry(2, 0),
      greaterThan(0),
    );
    await tester.fling(find.byType(Scaffold), const Offset(500, 0), 1600);
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(tester.widget<Transform>(plane).transform.entry(2, 0), lessThan(0));
    for (var i = 0; i < 300; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(
      tester.widget<Transform>(plane).transform.entry(2, 0),
      closeTo(0, 0.001),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
    expect(tester.binding.hasScheduledFrame, isFalse);
    tester.view.physicalSize = const Size(400, 800);
    await tester.pump();
    expect(find.byType(InteractiveViewer), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
