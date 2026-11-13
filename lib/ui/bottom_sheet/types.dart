import 'package:flutter/widgets.dart';

/// Host presentation style for bottom sheets.
///
/// - [presentation] — iOS-style: scales the app behind the sheet, letterbox,
///   stacked card peek.
/// - [modal] — standard overlay: app stays full size, dimmed scrim.
/// - [push] — pushes the host away from the sheet.
enum BottomSheetMode { presentation, modal, push }

/// Which screen edge the sheet pushes from in [BottomSheetMode.push].
enum PushDirection { bottom, top }

/// Built-in snap heights: 50%, 90%, and full screen.
enum BottomSheetDetentPreset { medium, large, full }

/// Preset, screen-height fraction (0–1), or percentage string such as `50%`.
sealed class BottomSheetDetent {
  const BottomSheetDetent();

  const factory BottomSheetDetent.preset(BottomSheetDetentPreset preset) =
      BottomSheetDetentPresetValue;
  const factory BottomSheetDetent.fraction(double fraction) =
      BottomSheetDetentFraction;
  const factory BottomSheetDetent.percent(String percent) =
      BottomSheetDetentPercent;

  /// Parses a snap point: preset name, `0–1` fraction, or `"50%"` string.
  static BottomSheetDetent parse(Object value) {
    if (value is BottomSheetDetent) return value;
    if (value is BottomSheetDetentPreset) {
      return BottomSheetDetent.preset(value);
    }
    if (value is num) {
      return BottomSheetDetent.fraction(value.toDouble());
    }
    if (value is String) {
      switch (value) {
        case 'medium':
          return const BottomSheetDetent.preset(BottomSheetDetentPreset.medium);
        case 'large':
          return const BottomSheetDetent.preset(BottomSheetDetentPreset.large);
        case 'full':
          return const BottomSheetDetent.preset(BottomSheetDetentPreset.full);
        default:
          return BottomSheetDetent.percent(value);
      }
    }
    throw ArgumentError.value(value, 'value', 'Unsupported detent');
  }

  static const medium = BottomSheetDetent.preset(
    BottomSheetDetentPreset.medium,
  );
  static const large = BottomSheetDetent.preset(BottomSheetDetentPreset.large);
  static const full = BottomSheetDetent.preset(BottomSheetDetentPreset.full);
}

final class BottomSheetDetentPresetValue extends BottomSheetDetent {
  const BottomSheetDetentPresetValue(this.preset);
  final BottomSheetDetentPreset preset;

  @override
  bool operator ==(Object other) =>
      other is BottomSheetDetentPresetValue && other.preset == preset;

  @override
  int get hashCode => preset.hashCode;

  @override
  String toString() => 'BottomSheetDetent.preset($preset)';
}

final class BottomSheetDetentFraction extends BottomSheetDetent {
  const BottomSheetDetentFraction(this.fraction);
  final double fraction;

  @override
  bool operator ==(Object other) =>
      other is BottomSheetDetentFraction && other.fraction == fraction;

  @override
  int get hashCode => fraction.hashCode;

  @override
  String toString() => 'BottomSheetDetent.fraction($fraction)';
}

final class BottomSheetDetentPercent extends BottomSheetDetent {
  const BottomSheetDetentPercent(this.percent);
  final String percent;

  @override
  bool operator ==(Object other) =>
      other is BottomSheetDetentPercent && other.percent == percent;

  @override
  int get hashCode => percent.hashCode;

  @override
  String toString() => 'BottomSheetDetent.percent($percent)';
}

typedef SnapPoint = BottomSheetDetent;

enum BottomSheetKeyboardBehavior { interactive, fillParent, extend }

enum BottomSheetKeyboardBlurBehavior { none, restore }

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

abstract class BottomSheetControllerApi {
  void close();
  void snapToIndex(int index);
  void snapToPosition(double position);
  void expand();
  void collapse();
}

abstract class BottomSheetModalController extends BottomSheetControllerApi {
  void present();
  void dismiss();
  void forceClose();
  void dismissAll();
}

class BottomSheetSpringOptions {
  const BottomSheetSpringOptions({
    required this.damping,
    required this.stiffness,
    required this.mass,
  });

  final double damping;
  final double stiffness;
  final double mass;

  BottomSheetSpringOptions merge(BottomSheetSpringOptions? other) {
    if (other == null) return this;
    return BottomSheetSpringOptions(
      damping: other.damping,
      stiffness: other.stiffness,
      mass: other.mass,
    );
  }

  SpringDescription toSpringDescription() =>
      SpringDescription(mass: mass, stiffness: stiffness, damping: damping);
}

class BottomSheetLayoutMotionOptions {
  const BottomSheetLayoutMotionOptions({
    required this.sheetSpring,
    required this.presentationSpring,
    required this.pushLayoutSpring,
  });

  final BottomSheetSpringOptions sheetSpring;
  final BottomSheetSpringOptions presentationSpring;
  final BottomSheetSpringOptions pushLayoutSpring;
}

class BottomSheetLayoutPresentationOptions {
  const BottomSheetLayoutPresentationOptions({
    required this.hostScale,
    required this.cornerRadius,
    required this.hostTopInsetMin,
  });

  final double hostScale;
  final double cornerRadius;
  final double hostTopInsetMin;
}

class BottomSheetLayoutPushOptions {
  const BottomSheetLayoutPushOptions({
    required this.hostHorizontalInset,
    required this.hostVerticalGap,
    required this.direction,
  });

  final double hostHorizontalInset;

  /// Gap between host and sheet along the push axis.
  final double hostVerticalGap;
  final PushDirection direction;
}

class BottomSheetLayoutStackOptions {
  const BottomSheetLayoutStackOptions({
    required this.scalePerLevel,
    required this.horizontalInsetPerLevel,
    required this.offsetYPerLevel,
    required this.radiusBonusPerLevel,
  });

  final double scalePerLevel;
  final double horizontalInsetPerLevel;
  final double offsetYPerLevel;
  final double radiusBonusPerLevel;
}

class BottomSheetLayoutGesturesOptions {
  const BottomSheetLayoutGesturesOptions({
    required this.dismissDragThreshold,
    required this.dismissVelocityThreshold,
    required this.detentVelocityThreshold,
    required this.activationOffset,
  });

  final double dismissDragThreshold;
  final double dismissVelocityThreshold;
  final double detentVelocityThreshold;
  final double activationOffset;
}

class BottomSheetLayoutHandleOptions {
  const BottomSheetLayoutHandleOptions({
    required this.height,
    required this.hiddenHeight,
  });

  final double height;
  final double hiddenHeight;
}

class BottomSheetLayoutScrollOptions {
  const BottomSheetLayoutScrollOptions({
    required this.endExtra,
    required this.offsetEpsilon,
  });

  final double endExtra;
  final double offsetEpsilon;
}

class BottomSheetLayoutDetentsOptions {
  const BottomSheetLayoutDetentsOptions({
    required this.medium,
    required this.large,
    required this.full,
  });

  final double medium;
  final double large;
  final double full;

  double operator [](BottomSheetDetentPreset preset) {
    switch (preset) {
      case BottomSheetDetentPreset.medium:
        return medium;
      case BottomSheetDetentPreset.large:
        return large;
      case BottomSheetDetentPreset.full:
        return full;
    }
  }
}

class BottomSheetLayoutOptions {
  const BottomSheetLayoutOptions({
    required this.motion,
    required this.presentation,
    required this.push,
    required this.stack,
    required this.gestures,
    required this.handle,
    required this.scroll,
    required this.detents,
  });

  final BottomSheetLayoutMotionOptions motion;
  final BottomSheetLayoutPresentationOptions presentation;
  final BottomSheetLayoutPushOptions push;
  final BottomSheetLayoutStackOptions stack;
  final BottomSheetLayoutGesturesOptions gestures;
  final BottomSheetLayoutHandleOptions handle;
  final BottomSheetLayoutScrollOptions scroll;
  final BottomSheetLayoutDetentsOptions detents;
}

class BottomSheetState {
  const BottomSheetState({
    required this.id,
    required this.content,
    required this.options,
  });

  final String id;
  final Widget content;
  final ResolvedBottomSheetOptions options;
}
