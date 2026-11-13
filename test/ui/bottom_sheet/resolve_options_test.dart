import 'package:musaic/ui/bottom_sheet/constants.dart';
import 'package:musaic/ui/bottom_sheet/merge_layout_options.dart';
import 'package:musaic/ui/bottom_sheet/resolve_options.dart';
import 'package:musaic/ui/bottom_sheet/types.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('mergeLayoutOptionsPartial', () {
    test('returns defaults when partial is null', () {
      final layout = mergeLayoutOptionsPartial(null);
      expect(layout.presentation.hostScale, kPresentationHostScale);
      expect(layout.gestures.dismissDragThreshold, kDismissDragThreshold);
    });

    test('overrides corner radius', () {
      final layout = mergeLayoutOptionsPartial(
        const BottomSheetLayoutOptionsPartial(cornerRadius: 32),
      );
      expect(layout.presentation.cornerRadius, 32);
      expect(layout.presentation.hostScale, kPresentationHostScale);
    });
  });

  group('resolveBottomSheetOptions', () {
    test('defaults snap points to medium and large', () {
      final resolved = resolveBottomSheetOptions();
      expect(resolved.snapPoints, [
        BottomSheetDetent.medium,
        BottomSheetDetent.large,
      ]);
      expect(resolved.enablePanDownToClose, isTrue);
      expect(resolved.mode, BottomSheetMode.presentation);
    });

    test('per-sheet mode overrides provider', () {
      final resolved = resolveBottomSheetOptions(
        options: const BottomSheetOptions(mode: BottomSheetMode.modal),
        hostMode: BottomSheetMode.presentation,
      );
      expect(resolved.mode, BottomSheetMode.modal);
    });
  });
}
