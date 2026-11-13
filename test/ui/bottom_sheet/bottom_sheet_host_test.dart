import 'package:musaic/ui/bottom_sheet/constants.dart';
import 'package:musaic/ui/bottom_sheet/host_layout_mode.dart';
import 'package:musaic/ui/bottom_sheet/merge_layout_options.dart';
import 'package:musaic/ui/bottom_sheet/widgets/bottom_sheet_host.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host({required int mode}) {
  return MaterialApp(
    home: BottomSheetHost(
      hostLayoutMode: ValueNotifier(mode),
      progress: ValueNotifier(1),
      sheetTopY: ValueNotifier(400),
      pushProgressOpenY: ValueNotifier(400),
      pushSheetHeight: ValueNotifier(400),
      topInset: 50,
      screenHeight: 800,
      screenWidth: 400,
      layout: kDefaultLayoutOptions,
      child: const ColoredBox(key: Key('host-content'), color: Colors.white),
    ),
  );
}

int _transformAncestorCount(WidgetTester tester, Finder finder) {
  var count = 0;
  tester.element(finder).visitAncestorElements((element) {
    if (element.widget is Transform) count++;
    return true;
  });
  return count;
}

void main() {
  testWidgets('presentation clips the transformed host edge', (tester) async {
    await tester.pumpWidget(_host(mode: HostLayoutMode.presentation));

    final clip = find.ancestor(
      of: find.byKey(const Key('host-content')),
      matching: find.byType(ClipRRect),
    );
    final widget = tester.widget<ClipRRect>(clip);

    expect(
      widget.borderRadius,
      BorderRadius.circular(kBottomSheetCornerRadius),
    );
    expect(_transformAncestorCount(tester, clip), greaterThanOrEqualTo(2));
  });

  testWidgets('push keeps its existing transform and corner structure', (
    tester,
  ) async {
    await tester.pumpWidget(_host(mode: HostLayoutMode.pushBottom));

    final clip = find.ancestor(
      of: find.byKey(const Key('host-content')),
      matching: find.byType(ClipRRect),
    );
    final widget = tester.widget<ClipRRect>(clip);
    final radius = widget.borderRadius as BorderRadius;

    expect(radius.topLeft, Radius.zero);
    expect(radius.topRight, Radius.zero);
    expect(radius.bottomLeft, const Radius.circular(kBottomSheetCornerRadius));
    expect(radius.bottomRight, const Radius.circular(kBottomSheetCornerRadius));
    expect(_transformAncestorCount(tester, clip), greaterThanOrEqualTo(2));
  });
}
