import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musaic/pages/home/fullscreen_control.dart';

void main() {
  testWidgets('native platforms do not display browser fullscreen controls', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: FullscreenControl()));
    expect(find.byType(TextButton), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });
}
