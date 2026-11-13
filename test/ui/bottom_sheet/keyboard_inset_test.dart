import 'package:musaic/ui/bottom_sheet/widgets/bottom_sheet_overlay.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ignores a keyboard owned by a dialog above the sheet', () {
    expect(resolveBottomSheetKeyboardInset(420, focusBelongsToSheet: false), 0);
  });

  test('keeps keyboard handling for an input inside the sheet', () {
    expect(
      resolveBottomSheetKeyboardInset(420, focusBelongsToSheet: true),
      420,
    );
  });
}
