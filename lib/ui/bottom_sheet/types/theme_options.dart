// 文件职责：底部弹层的状态、布局、手势与动画引擎。

part of '../types.dart';

/// 封装或定义底部弹层主题相关类型与行为，负责底部弹层的状态、布局、手势与动画引擎。
class BottomSheetTheme {
  const BottomSheetTheme({
    this.sheetBackgroundColor,
    this.letterboxColor,
    this.hostBackgroundColor,
    this.letterboxOpacity,
    this.handleColor,
    this.scrimColor,
    this.modalBackdropColor,
  });

  final Color? sheetBackgroundColor;
  final Color? letterboxColor;
  final Color? hostBackgroundColor;
  final double? letterboxOpacity;
  final Color? handleColor;
  final Color? scrimColor;
  final Color? modalBackdropColor;

  /// 执行当前模块中的合并操作，用于底部弹层的状态、布局、手势与动画引擎。
  BottomSheetTheme merge(BottomSheetTheme? other) {
    if (other == null) return this;
    return BottomSheetTheme(
      sheetBackgroundColor: other.sheetBackgroundColor ?? sheetBackgroundColor,
      letterboxColor: other.letterboxColor ?? letterboxColor,
      hostBackgroundColor: other.hostBackgroundColor ?? hostBackgroundColor,
      letterboxOpacity: other.letterboxOpacity ?? letterboxOpacity,
      handleColor: other.handleColor ?? handleColor,
      scrimColor: other.scrimColor ?? scrimColor,
      modalBackdropColor: other.modalBackdropColor ?? modalBackdropColor,
    );
  }
}

/// 封装或定义resolved底部弹层主题相关类型与行为，负责底部弹层的状态、布局、手势与动画引擎。
class ResolvedBottomSheetTheme {
  const ResolvedBottomSheetTheme({
    required this.sheetBackgroundColor,
    required this.letterboxColor,
    required this.hostBackgroundColor,
    required this.letterboxOpacity,
    required this.handleColor,
    required this.scrimColor,
    required this.modalBackdropColor,
  });

  final Color sheetBackgroundColor;
  final Color letterboxColor;
  final Color hostBackgroundColor;
  final double letterboxOpacity;
  final Color handleColor;
  final Color scrimColor;
  final Color modalBackdropColor;
}

/// 封装或定义底部弹层选项相关类型与行为，负责底部弹层的状态、布局、手势与动画引擎。
class BottomSheetOptions {
  const BottomSheetOptions({
    this.mode,
    this.pushDirection,
    this.snapPoints,
    this.index,
    this.enableDynamicSizing,
    this.enablePanDownToClose,
    this.dismissOnScrimPress,
    this.scrimColor,
    this.enableContentPanningGesture,
    this.keyboardBehavior,
    this.keyboardBlurBehavior,
    this.showHandle,
    this.onDismiss,
    this.onChange,
    this.onAnimate,
    this.theme,
    this.sheetStyle,
    this.accessibilityLabel,
    this.sheetId,
  });

  final BottomSheetMode? mode;
  final PushDirection? pushDirection;
  final List<BottomSheetDetent>? snapPoints;
  final int? index;
  final bool? enableDynamicSizing;
  final bool? enablePanDownToClose;
  final bool? dismissOnScrimPress;
  final Color? scrimColor;
  final bool? enableContentPanningGesture;
  final BottomSheetKeyboardBehavior? keyboardBehavior;
  final BottomSheetKeyboardBlurBehavior? keyboardBlurBehavior;
  final bool? showHandle;
  final VoidCallback? onDismiss;
  final ValueChanged<int>? onChange;
  final void Function(int fromIndex, int toIndex)? onAnimate;
  final BottomSheetTheme? theme;
  final BoxDecoration? sheetStyle;
  final String? accessibilityLabel;
  final String? sheetId;

  /// 基于当前对象创建副本，仅替换指定字段，用于底部弹层的状态、布局、手势与动画引擎。
  BottomSheetOptions copyWith({
    BottomSheetMode? mode,
    PushDirection? pushDirection,
    List<BottomSheetDetent>? snapPoints,
    int? index,
    bool? enableDynamicSizing,
    bool? enablePanDownToClose,
    bool? dismissOnScrimPress,
    Color? scrimColor,
    bool? enableContentPanningGesture,
    BottomSheetKeyboardBehavior? keyboardBehavior,
    BottomSheetKeyboardBlurBehavior? keyboardBlurBehavior,
    bool? showHandle,
    VoidCallback? onDismiss,
    ValueChanged<int>? onChange,
    void Function(int fromIndex, int toIndex)? onAnimate,
    BottomSheetTheme? theme,
    BoxDecoration? sheetStyle,
    String? accessibilityLabel,
    String? sheetId,
  }) {
    return BottomSheetOptions(
      mode: mode ?? this.mode,
      pushDirection: pushDirection ?? this.pushDirection,
      snapPoints: snapPoints ?? this.snapPoints,
      index: index ?? this.index,
      enableDynamicSizing: enableDynamicSizing ?? this.enableDynamicSizing,
      enablePanDownToClose: enablePanDownToClose ?? this.enablePanDownToClose,
      dismissOnScrimPress: dismissOnScrimPress ?? this.dismissOnScrimPress,
      scrimColor: scrimColor ?? this.scrimColor,
      enableContentPanningGesture:
          enableContentPanningGesture ?? this.enableContentPanningGesture,
      keyboardBehavior: keyboardBehavior ?? this.keyboardBehavior,
      keyboardBlurBehavior: keyboardBlurBehavior ?? this.keyboardBlurBehavior,
      showHandle: showHandle ?? this.showHandle,
      onDismiss: onDismiss ?? this.onDismiss,
      onChange: onChange ?? this.onChange,
      onAnimate: onAnimate ?? this.onAnimate,
      theme: theme ?? this.theme,
      sheetStyle: sheetStyle ?? this.sheetStyle,
      accessibilityLabel: accessibilityLabel ?? this.accessibilityLabel,
      sheetId: sheetId ?? this.sheetId,
    );
  }
}

/// 封装或定义resolved底部弹层选项相关类型与行为，负责底部弹层的状态、布局、手势与动画引擎。
class ResolvedBottomSheetOptions {
  const ResolvedBottomSheetOptions({
    required this.mode,
    required this.pushDirection,
    required this.snapPoints,
    required this.index,
    required this.enableDynamicSizing,
    required this.enablePanDownToClose,
    required this.dismissOnScrimPress,
    required this.scrimColor,
    required this.enableContentPanningGesture,
    required this.keyboardBehavior,
    required this.keyboardBlurBehavior,
    required this.showHandle,
    required this.theme,
    required this.accessibilityLabel,
    this.onDismiss,
    this.onChange,
    this.onAnimate,
    this.sheetStyle,
  });

  final BottomSheetMode mode;
  final PushDirection pushDirection;
  final List<BottomSheetDetent> snapPoints;
  final int index;
  final bool enableDynamicSizing;
  final bool enablePanDownToClose;
  final bool dismissOnScrimPress;
  final Color scrimColor;
  final bool enableContentPanningGesture;
  final BottomSheetKeyboardBehavior keyboardBehavior;
  final BottomSheetKeyboardBlurBehavior keyboardBlurBehavior;
  final bool showHandle;
  final VoidCallback? onDismiss;
  final ValueChanged<int>? onChange;
  final void Function(int fromIndex, int toIndex)? onAnimate;
  final ResolvedBottomSheetTheme theme;
  final BoxDecoration? sheetStyle;
  final String accessibilityLabel;
}

