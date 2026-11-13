import 'package:musaic/ui/bottom_sheet/constants.dart';
import 'package:musaic/ui/bottom_sheet/push_direction.dart';
import 'package:musaic/ui/bottom_sheet/sheet_pan.dart';
import 'package:musaic/ui/bottom_sheet/types.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const screenHeight = 800.0;
  const topInset = 50.0;
  final snapPoints = [
    BottomSheetDetent.percent('50%'),
    BottomSheetDetent.percent('90%'),
  ];

  group('resolveSheetPanEnd bottom', () {
    test('dismisses when dragged past threshold', () {
      final result = resolveSheetPanEnd(
        currentY: 400 + kDismissDragThreshold + 10,
        velocityY: 0,
        currentIndex: 0,
        effectiveSnapPoints: snapPoints,
        screenHeight: screenHeight,
        topInset: topInset,
        detents: kDetentFractions,
        dismissDragThreshold: kDismissDragThreshold,
        dismissVelocityThreshold: kDismissVelocityThreshold,
        detentVelocityThreshold: kDetentVelocityThreshold,
        enablePanDownToClose: true,
        pushDirection: PushDirectionJs.bottom,
      );
      expect(result.kind, SheetPanEndKind.dismiss);
    });

    test('dismisses on fast downward velocity', () {
      final result = resolveSheetPanEnd(
        currentY: 420,
        velocityY: kDismissVelocityThreshold + 1,
        currentIndex: 0,
        effectiveSnapPoints: snapPoints,
        screenHeight: screenHeight,
        topInset: topInset,
        detents: kDetentFractions,
        dismissDragThreshold: kDismissDragThreshold,
        dismissVelocityThreshold: kDismissVelocityThreshold,
        detentVelocityThreshold: kDetentVelocityThreshold,
        enablePanDownToClose: true,
        pushDirection: PushDirectionJs.bottom,
      );
      expect(result.kind, SheetPanEndKind.dismiss);
    });

    test('snaps to higher detent on upward velocity', () {
      final result = resolveSheetPanEnd(
        currentY: 400,
        velocityY: -(kDetentVelocityThreshold + 1),
        currentIndex: 0,
        effectiveSnapPoints: snapPoints,
        screenHeight: screenHeight,
        topInset: topInset,
        detents: kDetentFractions,
        dismissDragThreshold: kDismissDragThreshold,
        dismissVelocityThreshold: kDismissVelocityThreshold,
        detentVelocityThreshold: kDetentVelocityThreshold,
        enablePanDownToClose: true,
        pushDirection: PushDirectionJs.bottom,
      );
      expect(result.kind, SheetPanEndKind.snap);
      expect(result.targetIndex, 1);
    });

    test('collapses one stage before dismiss from higher detent', () {
      final result = resolveSheetPanEnd(
        currentY: 80,
        velocityY: kDismissVelocityThreshold + 1,
        currentIndex: 1,
        effectiveSnapPoints: snapPoints,
        screenHeight: screenHeight,
        topInset: topInset,
        detents: kDetentFractions,
        dismissDragThreshold: kDismissDragThreshold,
        dismissVelocityThreshold: kDismissVelocityThreshold,
        detentVelocityThreshold: kDetentVelocityThreshold,
        enablePanDownToClose: true,
        pushDirection: PushDirectionJs.bottom,
      );
      expect(result.kind, SheetPanEndKind.snap);
      expect(result.targetIndex, 0);
    });

    test('collapses on moderate downward velocity from higher detent', () {
      final result = resolveSheetPanEnd(
        currentY: 80,
        velocityY: kDetentVelocityThreshold + 1,
        currentIndex: 1,
        effectiveSnapPoints: snapPoints,
        screenHeight: screenHeight,
        topInset: topInset,
        detents: kDetentFractions,
        dismissDragThreshold: kDismissDragThreshold,
        dismissVelocityThreshold: kDismissVelocityThreshold,
        detentVelocityThreshold: kDetentVelocityThreshold,
        enablePanDownToClose: true,
        pushDirection: PushDirectionJs.bottom,
      );
      expect(result.kind, SheetPanEndKind.snap);
      expect(result.targetIndex, 0);
    });
  });
}
