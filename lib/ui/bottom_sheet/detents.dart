// 文件职责：底部弹层的状态、布局、手势与动画引擎。

import 'constants.dart';
import 'push_direction.dart';
import 'types.dart';

/// 解析输入并转换为内部数据，用于底部弹层的状态、布局、手势与动画引擎。
double resolveDetentFraction(
  BottomSheetDetent detent, [
  BottomSheetLayoutDetentsOptions fractions = kDetentFractions,
]) {
  return switch (detent) {
    BottomSheetDetentFraction(:final fraction) => clamp01(fraction),
    BottomSheetDetentPercent(:final percent) => clamp01(
      double.parse(percent.replaceAll('%', '')) / 100,
    ),
    BottomSheetDetentPresetValue(:final preset) => fractions[preset],
  };
}

/// 获取所需数据或资源，用于底部弹层的状态、布局、手势与动画引擎。
double getDetentHeight(
  BottomSheetDetent detent,
  double screenHeight,
  double topInset, [
  BottomSheetLayoutDetentsOptions fractions = kDetentFractions,
]) {
  if (detent is BottomSheetDetentPresetValue &&
      detent.preset == BottomSheetDetentPreset.full) {
    return screenHeight - topInset;
  }
  return screenHeight * resolveDetentFraction(detent, fractions);
}

/// 获取所需数据或资源，用于底部弹层的状态、布局、手势与动画引擎。
double getDetentTranslateY(
  BottomSheetDetent detent,
  double screenHeight,
  double topInset, [
  BottomSheetLayoutDetentsOptions fractions = kDetentFractions,
]) => screenHeight - getDetentHeight(detent, screenHeight, topInset, fractions);

/// 获取所需数据或资源，用于底部弹层的状态、布局、手势与动画引擎。
double getPushClosedTopY(
  int pushDirection,
  double screenHeight,
  double topInset,
) {
  if (pushDirection == PushDirectionJs.top) return -screenHeight;
  return screenHeight;
}

/// 获取所需数据或资源，用于底部弹层的状态、布局、手势与动画引擎。
double getPushDetentTopY(
  BottomSheetDetent detent,
  int pushDirection,
  double screenHeight,
  double topInset, [
  BottomSheetLayoutDetentsOptions fractions = kDetentFractions,
]) {
  if (pushDirection == PushDirectionJs.top) return 0;
  return getDetentTranslateY(detent, screenHeight, topInset, fractions);
}

/// 获取所需数据或资源，用于底部弹层的状态、布局、手势与动画引擎。
double getPushOpenTopY(
  int pushDirection,
  double screenHeight,
  double topInset,
) {
  if (pushDirection == PushDirectionJs.top) return 0;
  return screenHeight;
}

/// 获取所需数据或资源，用于底部弹层的状态、布局、手势与动画引擎。
int findNearestDetentIndex(
  double translateY,
  List<BottomSheetDetent> detents,
  double screenHeight,
  double topInset, [
  BottomSheetLayoutDetentsOptions fractions = kDetentFractions,
]) {
  var nearestIndex = 0;
  var minDistance = double.maxFinite;

  for (var index = 0; index < detents.length; index++) {
    final targetY = getDetentTranslateY(
      detents[index],
      screenHeight,
      topInset,
      fractions,
    );
    final distance = (translateY - targetY).abs();
    if (distance < minDistance) {
      minDistance = distance;
      nearestIndex = index;
    }
  }

  return nearestIndex;
}

/// 获取所需数据或资源，用于底部弹层的状态、布局、手势与动画引擎。
int findDetentIndex(List<BottomSheetDetent> detents, BottomSheetDetent detent) {
  final index = detents.indexOf(detent);
  return index >= 0 ? index : 0;
}

/// 执行当前模块中的clampindex操作，用于底部弹层的状态、布局、手势与动画引擎。
int clampIndex(int index, int detentCount) {
  if (detentCount <= 0) return 0;
  if (index < 0) return 0;
  if (index > detentCount - 1) return detentCount - 1;
  return index;
}

/// 创建并组装所需对象或界面结构，用于底部弹层的状态、布局、手势与动画引擎。
double buildDynamicSheetHeight(
  double contentHeight,
  double screenHeight,
  double topInset,
  double bottomInset,
  double handleHeight,
) {
  final totalHeight = contentHeight + handleHeight + bottomInset;
  final maxHeight = screenHeight - topInset;
  return totalHeight < maxHeight ? totalHeight : maxHeight;
}

/// 获取所需数据或资源，用于底部弹层的状态、布局、手势与动画引擎。
double getTranslateYFromSheetHeight(double sheetHeight, double screenHeight) =>
    screenHeight - sheetHeight;

/// 创建并组装所需对象或界面结构，用于底部弹层的状态、布局、手势与动画引擎。
BottomSheetDetent buildDynamicSnapPoint(
  double contentHeight,
  double screenHeight,
  double topInset,
  double bottomInset,
  double handleHeight,
) {
  final clampedHeight = buildDynamicSheetHeight(
    contentHeight,
    screenHeight,
    topInset,
    bottomInset,
    handleHeight,
  );
  return BottomSheetDetent.fraction(clampedHeight / screenHeight);
}

/// 合并多组配置并保留各自约束，用于底部弹层的状态、布局、手势与动画引擎。
List<BottomSheetDetent> mergeSnapPoints(
  List<BottomSheetDetent> snapPoints,
  BottomSheetDetent? dynamicSnapPoint,
  bool enableDynamicSizing,
) {
  if (!enableDynamicSizing) {
    return snapPoints.isNotEmpty
        ? snapPoints
        : const [BottomSheetDetent.medium];
  }

  if (dynamicSnapPoint == null) return snapPoints;

  if (snapPoints.isEmpty) return [dynamicSnapPoint];

  return [...snapPoints, dynamicSnapPoint];
}
