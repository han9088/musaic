// 文件职责：底部弹层的状态、布局、手势与动画引擎。

import 'detents.dart';
import 'push_direction.dart';
import 'types.dart';
import 'constants.dart';

/// 封装或定义弹层拖拽endkind相关类型与行为，负责底部弹层的状态、布局、手势与动画引擎。
enum SheetPanEndKind { dismiss, snap }

/// 封装或定义弹层拖拽endresult相关类型与行为，负责底部弹层的状态、布局、手势与动画引擎。
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

/// 封装或定义弹层dragupdateresult相关类型与行为，负责底部弹层的状态、布局、手势与动画引擎。
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

/// 应用选择并更新对应状态，用于底部弹层的状态、布局、手势与动画引擎。
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

/// 解析输入并转换为内部数据，用于底部弹层的状态、布局、手势与动画引擎。
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

    // 拖动距离超过关闭阈值时，直接关闭弹层（适用于任意阶段）。
    if (enablePanDownToClose && currentY < dismissY) {
      return SheetPanEndResult(
        kind: SheetPanEndKind.dismiss,
        targetIndex: currentIndex,
        targetY: currentY,
      );
    }

    // 向更大的展开阶段移动。
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

    // 多阶段弹层先回退一个阶段，再根据速度判断是否关闭。
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

  // 拖动越过最低停靠点及关闭阈值时，直接关闭弹层（适用于任意阶段）。
  if (enablePanDownToClose && currentY > dismissY) {
    return SheetPanEndResult(
      kind: SheetPanEndKind.dismiss,
      targetIndex: currentIndex,
      targetY: currentY,
    );
  }

  // 展开到更高的停靠点。
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

  // 多阶段弹层先回退一个阶段，再根据速度判断是否关闭。
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

  // 仅在第 0 阶段，快速向下甩动才会触发关闭。
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
