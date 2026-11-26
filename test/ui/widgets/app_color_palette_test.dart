import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musaic/ui/widgets/app_color_palette.dart';

void main() {
  testWidgets('the raised swatch keeps its color until it nears the target', (
    tester,
  ) async {
    const swatches = [
      (
        value: 0,
        label: 'All colors',
        fill: BoxDecoration(
          gradient: SweepGradient(
            colors: [Colors.red, Colors.blue, Colors.red],
          ),
        ),
      ),
      (value: 1, label: 'Orange', fill: BoxDecoration(color: Colors.orange)),
    ];

    var selection = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: StatefulBuilder(
            builder: (context, setState) => AppColorPalette<int>(
              swatches: swatches,
              selection: selection,
              onSelected: (value) => setState(() => selection = value),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey(1)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final raised = find.byKey(const ValueKey('palette-raised-swatch'));
    List<Color> raisedColors() {
      final surface = tester.widget<DecoratedBox>(
        find.descendant(of: raised, matching: find.byType(DecoratedBox)),
      );
      return (surface.decoration as BoxDecoration).gradient!.colors;
    }

    const rainbow = [Colors.red, Colors.blue, Colors.red];
    expect(raisedColors(), rainbow);

    await tester.pump(const Duration(milliseconds: 70));
    final arriving = raisedColors();
    expect(arriving, isNot(rainbow));
    expect(arriving.map((color) => color.a), everyElement(1.0));
    await tester.pumpAndSettle();
    expect(raisedColors(), everyElement(Colors.orange));
  });
}
