import 'constants.dart';
import 'detents.dart';
import 'push_direction.dart';
import 'types.dart';

/// Sheet top Y at fully open for the current detent — drives push progress.
double getPushLayoutProgress(
  double sheetTopY,
  double openY,
  double screenHeight,
  int pushDirection,
  double topInset,
) {
  if (pushDirection == PushDirectionJs.top) {
    final closed = -screenHeight;
    if (openY <= 0.5) {
      return interpolateClamped(sheetTopY, closed, openY, 0, 1);
    }
    return 0;
  }

  if (openY >= screenHeight - 0.5) return 0;
  return interpolateClamped(sheetTopY, screenHeight, openY, 0, 1);
}

double getPushHorizontalInset(
  double progress, {
  double targetInset = kPushHostHorizontalInset,
}) => interpolateClamped(progress, 0, 1, 0, targetInset);

double getPushScale(
  double screenWidth,
  double progress, {
  double targetInset = kPushHostHorizontalInset,
}) => pushInsetToScale(
  screenWidth,
  getPushHorizontalInset(progress, targetInset: targetInset),
);

double getPushVisualInset(
  double screenWidth,
  double progress, {
  double targetInset = kPushHostHorizontalInset,
}) {
  final scale = getPushScale(screenWidth, progress, targetInset: targetInset);
  return (screenWidth * (1 - scale)) / 2;
}

double getPushVisibleSheetHeight(
  double sheetTopY,
  double screenHeight,
  double topInset,
  int pushDirection,
  double sheetHeight,
) {
  if (pushDirection == PushDirectionJs.top) {
    final visible = sheetTopY + sheetHeight;
    if (visible < 0) return 0;
    if (visible > sheetHeight) return sheetHeight;
    return visible;
  }
  final h = screenHeight - sheetTopY;
  return h < 0 ? 0 : h;
}

/// Signed host translate offset for push mode.
double getPushHostOffset(
  double screenWidth,
  double screenHeight,
  double sheetTopY,
  double progress,
  int pushDirection,
  double topInset,
  double sheetHeight, {
  double targetInset = kPushHostHorizontalInset,
  double? verticalGap,
}) {
  // Vertical gap is independent of side inset so full-bleed sides can still
  // keep a host↔sheet seam (defaults to the horizontal inset for RN parity).
  final gap = interpolateClamped(progress, 0, 1, 0, verticalGap ?? targetInset);
  final visibleHeight = getPushVisibleSheetHeight(
    sheetTopY,
    screenHeight,
    topInset,
    pushDirection,
    sheetHeight,
  );
  final magnitude = visibleHeight + gap;
  return pushDirection == PushDirectionJs.top ? magnitude : -magnitude;
}

double getPushHostOffsetFromSheetTopY(
  double screenWidth,
  double screenHeight,
  double sheetTopY,
  double openY,
  int pushDirection,
  double topInset,
  double sheetHeight, {
  double targetInset = kPushHostHorizontalInset,
  double? verticalGap,
}) {
  final progress = getPushLayoutProgress(
    sheetTopY,
    openY,
    screenHeight,
    pushDirection,
    topInset,
  );
  return getPushHostOffset(
    screenWidth,
    screenHeight,
    sheetTopY,
    progress,
    pushDirection,
    topInset,
    sheetHeight,
    targetInset: targetInset,
    verticalGap: verticalGap,
  );
}

double getBottomSheetCornerRadius(
  double progress, {
  double maxRadius = kBottomSheetCornerRadius,
}) => interpolateClamped(progress, 0, 1, 0, maxRadius);

({double? topLeft, double? topRight, double? bottomLeft, double? bottomRight})
getPushHostCornerRadiusStyle(
  double progress,
  int pushDirection, {
  double maxRadius = kBottomSheetCornerRadius,
}) {
  final radius = getBottomSheetCornerRadius(progress, maxRadius: maxRadius);
  if (pushDirection == PushDirectionJs.top) {
    return (
      topLeft: radius,
      topRight: radius,
      bottomLeft: null,
      bottomRight: null,
    );
  }
  return (
    topLeft: null,
    topRight: null,
    bottomLeft: radius,
    bottomRight: radius,
  );
}

({double? topLeft, double? topRight, double? bottomLeft, double? bottomRight})
getPushSheetCornerRadiusStyle(
  double progress,
  int pushDirection, {
  double maxRadius = kBottomSheetCornerRadius,
}) {
  final radius = getBottomSheetCornerRadius(progress, maxRadius: maxRadius);
  if (pushDirection == PushDirectionJs.top) {
    return (
      topLeft: null,
      topRight: null,
      bottomLeft: radius,
      bottomRight: radius,
    );
  }
  return (
    topLeft: radius,
    topRight: radius,
    bottomLeft: null,
    bottomRight: null,
  );
}

String getPushTransformOrigin(int pushDirection) =>
    pushDirection == PushDirectionJs.top ? 'top' : 'bottom';

double getPushSheetHeightForDetent(
  BottomSheetDetent detent,
  double screenHeight,
  double topInset, [
  BottomSheetLayoutDetentsOptions fractions = kDetentFractions,
]) => getDetentHeight(detent, screenHeight, topInset, fractions);
