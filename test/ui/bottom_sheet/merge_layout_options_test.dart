import 'package:musaic/ui/bottom_sheet/constants.dart';
import 'package:musaic/ui/bottom_sheet/merge_layout_options.dart';
import 'package:musaic/ui/bottom_sheet/types.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('mergeLayoutOptionsPartial', () {
    test('keeps gesture defaults when only presentation overridden', () {
      final layout = mergeLayoutOptionsPartial(
        const BottomSheetLayoutOptionsPartial(hostScale: 0.9, cornerRadius: 32),
      );
      expect(layout.presentation.hostScale, 0.9);
      expect(layout.presentation.cornerRadius, 32);
      expect(layout.gestures.dismissDragThreshold, kDismissDragThreshold);
      expect(layout.motion.sheetSpring.mass, kSheetSpringConfig.mass);
    });

    test('presentation motion override cannot change push motion', () {
      const presentation = BottomSheetSpringOptions(
        damping: 28,
        stiffness: 360,
        mass: 0.8,
      );
      final layout = mergeLayoutOptionsPartial(
        const BottomSheetLayoutOptionsPartial(presentationSpring: presentation),
      );

      expect(layout.motion.presentationSpring.damping, presentation.damping);
      expect(
        layout.motion.pushLayoutSpring.damping,
        kPushLayoutSpringConfig.damping,
      );
      expect(
        layout.motion.pushLayoutSpring.stiffness,
        kPushLayoutSpringConfig.stiffness,
      );
      expect(layout.motion.pushLayoutSpring.mass, kPushLayoutSpringConfig.mass);
    });
  });
}
