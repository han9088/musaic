import 'detents.dart';
import 'push_direction.dart';
import 'types.dart';
import 'constants.dart';

enum SheetPanEndKind { dismiss, snap }

class SheetPanEndResult {
  const SheetPanEndResult({
    required this.kind,
    required this.targetIndex,
    required this.targetY,
  });

  final SheetPanEndKind kind;
  final int targetIndex;
  final double targetY;
}

/// Result of applying a drag update — mutates returned via [SheetDragUpdateResult].
class SheetDragUpdateResult {
  const SheetDragUpdateResult({
    required this.sheetTranslateY,
    required this.progress,
    this.pushProgressOpenY,
  });

  final double sheetTranslateY;
  final double progress;
  final double? pushProgressOpenY;
}

SheetDragUpdateResult applySheetDragUpdate({
  required double dragStartY,
  required double translationY,
  required int activeDetentIndex,
  required List<BottomSheetDetent> effectiveSnapPoints,
  required double screenHeight,
  required double topInset,
  required BottomSheetLayoutDetentsOptions detents,
  required bool isPushLayout,
  required int pushDirection,
}) {
  final nextY = dragStartY + translationY;
  late final double sheetTranslateY;

  if (pushDirection == PushDirectionJs.top) {
    final closedY = getPushClosedTopY(pushDirection, screenHeight, topInset);
    final maxY = getPushOpenTopY(pushDirection, screenHeight, topInset);
    sheetTranslateY = nextY.clamp(closedY, maxY);
  } else {
    final minY = getDetentTranslateY(
      BottomSheetDetent.full,
      screenHeight,
      topInset,
      detents,
    );
    sheetTranslateY = nextY < minY ? minY : nextY;
  }

  final openY = getPushDetentTopY(
    effectiveSnapPoints[activeDetentIndex],
    pushDirection,
    screenHeight,
    topInset,
    detents,
  );

  if (isPushLayout) {
    return SheetDragUpdateResult(
      sheetTranslateY: sheetTranslateY,
      progress: 0,
      pushProgressOpenY: openY,
    );
  }

  final closedY = getPushClosedTopY(pushDirection, screenHeight, topInset);
  final progress = interpolateClamped(sheetTranslateY, closedY, openY, 0, 1);
  return SheetDragUpdateResult(
    sheetTranslateY: sheetTranslateY,
    progress: progress,
  );
}

SheetPanEndResult resolveSheetPanEnd({
  required double currentY,
  required double velocityY,
  required int currentIndex,
  required List<BottomSheetDetent> effectiveSnapPoints,
  required double screenHeight,
  required double topInset,
  required BottomSheetLayoutDetentsOptions detents,
  required double dismissDragThreshold,
  required double dismissVelocityThreshold,
  required double detentVelocityThreshold,
  required bool enablePanDownToClose,
  required int pushDirection,
}) {
  final isTopPush = pushDirection == PushDirectionJs.top;
  final openY = getPushDetentTopY(
    effectiveSnapPoints[currentIndex],
    pushDirection,
    screenHeight,
    topInset,
    detents,
  );

  if (isTopPush) {
    final dismissY = openY - dismissDragThreshold;

    // Dragged past dismiss threshold → close (any stage).
    if (enablePanDownToClose && currentY < dismissY) {
      return SheetPanEndResult(
        kind: SheetPanEndKind.dismiss,
        targetIndex: currentIndex,
        targetY: currentY,
      );
    }

    // Expand toward fuller open.
    if (velocityY > detentVelocityThreshold &&
        currentIndex < effectiveSnapPoints.length - 1) {
      final nextIndex = currentIndex + 1;
      return SheetPanEndResult(
        kind: SheetPanEndKind.snap,
        targetIndex: nextIndex,
        targetY: getPushDetentTopY(
          effectiveSnapPoints[nextIndex],
          pushDirection,
          screenHeight,
          topInset,
          detents,
        ),
      );
    }

    // Multi-stage: collapse one stage before velocity-dismiss.
    if (velocityY < -detentVelocityThreshold && currentIndex > 0) {
      final prevIndex = currentIndex - 1;
      return SheetPanEndResult(
        kind: SheetPanEndKind.snap,
        targetIndex: prevIndex,
        targetY: getPushDetentTopY(
          effectiveSnapPoints[prevIndex],
          pushDirection,
          screenHeight,
          topInset,
          detents,
        ),
      );
    }

    if (enablePanDownToClose &&
        currentIndex == 0 &&
        velocityY < -dismissVelocityThreshold) {
      return SheetPanEndResult(
        kind: SheetPanEndKind.dismiss,
        targetIndex: currentIndex,
        targetY: currentY,
      );
    }

    return SheetPanEndResult(
      kind: SheetPanEndKind.snap,
      targetIndex: currentIndex,
      targetY: openY,
    );
  }

  final dismissY =
      getDetentTranslateY(
        effectiveSnapPoints[0],
        screenHeight,
        topInset,
        detents,
      ) +
      dismissDragThreshold;

  // Dragged past lowest detent + threshold → close (any stage).
  if (enablePanDownToClose && currentY > dismissY) {
    return SheetPanEndResult(
      kind: SheetPanEndKind.dismiss,
      targetIndex: currentIndex,
      targetY: currentY,
    );
  }

  // Expand to a higher detent.
  if (velocityY < -detentVelocityThreshold &&
      currentIndex < effectiveSnapPoints.length - 1) {
    final nextIndex = currentIndex + 1;
    return SheetPanEndResult(
      kind: SheetPanEndKind.snap,
      targetIndex: nextIndex,
      targetY: getDetentTranslateY(
        effectiveSnapPoints[nextIndex],
        screenHeight,
        topInset,
        detents,
      ),
    );
  }

  // Multi-stage: collapse one stage before velocity-dismiss.
  if (velocityY > detentVelocityThreshold && currentIndex > 0) {
    final prevIndex = currentIndex - 1;
    return SheetPanEndResult(
      kind: SheetPanEndKind.snap,
      targetIndex: prevIndex,
      targetY: getDetentTranslateY(
        effectiveSnapPoints[prevIndex],
        screenHeight,
        topInset,
        detents,
      ),
    );
  }

  // Stage 0 only: fast downward flick closes.
  if (enablePanDownToClose &&
      currentIndex == 0 &&
      velocityY > dismissVelocityThreshold) {
    return SheetPanEndResult(
      kind: SheetPanEndKind.dismiss,
      targetIndex: currentIndex,
      targetY: currentY,
    );
  }

  final nearestIndex = findNearestDetentIndex(
    currentY,
    effectiveSnapPoints,
    screenHeight,
    topInset,
    detents,
  );

  return SheetPanEndResult(
    kind: SheetPanEndKind.snap,
    targetIndex: nearestIndex,
    targetY: getDetentTranslateY(
      effectiveSnapPoints[nearestIndex],
      screenHeight,
      topInset,
      detents,
    ),
  );
}
