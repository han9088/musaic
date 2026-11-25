// 文件职责：底部弹层的状态、布局、手势与动画引擎。

import 'package:flutter/painting.dart';

import 'constants.dart';
import 'detents.dart';
import 'types.dart';

/// 合并多组配置并保留各自约束，用于底部弹层的状态、布局、手势与动画引擎。
ResolvedBottomSheetTheme mergeTheme({
  BottomSheetTheme? providerTheme,
  BottomSheetTheme? defaultsTheme,
  BottomSheetTheme? optionsTheme,
}) {
  /// 执行当前模块中的pickcolor操作，用于底部弹层的状态、布局、手势与动画引擎。
  Color pickColor(Color? a, Color? b, Color? c, Color fallback) =>
      a ?? b ?? c ?? fallback;

  /// 执行当前模块中的pickdouble操作，用于底部弹层的状态、布局、手势与动画引擎。
  double pickDouble(double? a, double? b, double? c, double fallback) =>
      a ?? b ?? c ?? fallback;

  return ResolvedBottomSheetTheme(
    sheetBackgroundColor: pickColor(
      optionsTheme?.sheetBackgroundColor,
      defaultsTheme?.sheetBackgroundColor,
      providerTheme?.sheetBackgroundColor,
      kDefaultTheme.sheetBackgroundColor,
    ),
    letterboxColor: pickColor(
      optionsTheme?.letterboxColor,
      defaultsTheme?.letterboxColor,
      providerTheme?.letterboxColor,
      kDefaultTheme.letterboxColor,
    ),
    hostBackgroundColor: pickColor(
      optionsTheme?.hostBackgroundColor,
      defaultsTheme?.hostBackgroundColor,
      providerTheme?.hostBackgroundColor,
      kDefaultTheme.hostBackgroundColor,
    ),
    letterboxOpacity: pickDouble(
      optionsTheme?.letterboxOpacity,
      defaultsTheme?.letterboxOpacity,
      providerTheme?.letterboxOpacity,
      kDefaultTheme.letterboxOpacity,
    ),
    handleColor: pickColor(
      optionsTheme?.handleColor,
      defaultsTheme?.handleColor,
      providerTheme?.handleColor,
      kDefaultTheme.handleColor,
    ),
    scrimColor: pickColor(
      optionsTheme?.scrimColor,
      defaultsTheme?.scrimColor,
      providerTheme?.scrimColor,
      kDefaultTheme.scrimColor,
    ),
    modalBackdropColor: pickColor(
      optionsTheme?.modalBackdropColor,
      defaultsTheme?.modalBackdropColor,
      providerTheme?.modalBackdropColor,
      kDefaultTheme.modalBackdropColor,
    ),
  );
}

/// 解析输入并转换为内部数据，用于底部弹层的状态、布局、手势与动画引擎。
ResolvedBottomSheetOptions resolveBottomSheetOptions({
  BottomSheetOptions? options,
  BottomSheetOptions? providerDefaults,
  BottomSheetTheme? providerTheme,
  BottomSheetMode hostMode = BottomSheetMode.presentation,
  PushDirection layoutPushDirection = PushDirection.bottom,
}) {
  final enableDynamicSizing =
      options?.enableDynamicSizing ??
      providerDefaults?.enableDynamicSizing ??
      false;

  final snapPoints = enableDynamicSizing
      ? (options?.snapPoints ?? providerDefaults?.snapPoints ?? const [])
      : (options?.snapPoints ??
            providerDefaults?.snapPoints ??
            const [BottomSheetDetent.medium, BottomSheetDetent.large]);

  final resolvedSnapPoints = snapPoints.isNotEmpty
      ? snapPoints
      : enableDynamicSizing
      ? const <BottomSheetDetent>[]
      : const [BottomSheetDetent.medium];

  final rawIndex =
      options?.index ??
      providerDefaults?.index ??
      (resolvedSnapPoints.isNotEmpty
          ? findDetentIndex(resolvedSnapPoints, resolvedSnapPoints.first)
          : 0);

  final pushDirection =
      options?.pushDirection ??
      providerDefaults?.pushDirection ??
      layoutPushDirection;

  final theme = mergeTheme(
    providerTheme: providerTheme,
    defaultsTheme: providerDefaults?.theme,
    optionsTheme: options?.theme,
  );

  final mode = options?.mode ?? providerDefaults?.mode ?? hostMode;

  return ResolvedBottomSheetOptions(
    mode: mode,
    pushDirection: pushDirection,
    snapPoints: resolvedSnapPoints,
    index: resolvedSnapPoints.isNotEmpty
        ? clampIndex(rawIndex, resolvedSnapPoints.length)
        : 0,
    enableDynamicSizing: enableDynamicSizing,
    enablePanDownToClose:
        options?.enablePanDownToClose ??
        providerDefaults?.enablePanDownToClose ??
        true,
    dismissOnScrimPress:
        options?.dismissOnScrimPress ??
        providerDefaults?.dismissOnScrimPress ??
        true,
    scrimColor:
        options?.scrimColor ?? providerDefaults?.scrimColor ?? theme.scrimColor,
    enableContentPanningGesture:
        options?.enableContentPanningGesture ??
        providerDefaults?.enableContentPanningGesture ??
        false,
    keyboardBehavior:
        options?.keyboardBehavior ??
        providerDefaults?.keyboardBehavior ??
        BottomSheetKeyboardBehavior.interactive,
    keyboardBlurBehavior:
        options?.keyboardBlurBehavior ??
        providerDefaults?.keyboardBlurBehavior ??
        BottomSheetKeyboardBlurBehavior.restore,
    showHandle: options?.showHandle ?? providerDefaults?.showHandle ?? true,
    onDismiss: options?.onDismiss ?? providerDefaults?.onDismiss,
    onChange: options?.onChange ?? providerDefaults?.onChange,
    onAnimate: options?.onAnimate ?? providerDefaults?.onAnimate,
    theme: theme,
    sheetStyle: options?.sheetStyle ?? providerDefaults?.sheetStyle,
    accessibilityLabel:
        options?.accessibilityLabel ??
        providerDefaults?.accessibilityLabel ??
        kDefaultAccessibilityLabel,
  );
}
