// 文件职责：底部弹层的状态、布局、手势与动画引擎。

import 'package:flutter/painting.dart';

import 'types.dart';

const BottomSheetSpringOptions kSheetSpringConfig = BottomSheetSpringOptions(
  damping: 500,
  stiffness: 1000,
  mass: 3,
);

/// Responsive presentation motion. Kept separate so tuning the iOS-style
/// host treatment cannot change modal or push behavior.
const BottomSheetSpringOptions kPresentationSpringConfig =
    BottomSheetSpringOptions(damping: 32, stiffness: 320, mass: 0.85);

/// Softer spring for push layout — host + sheet driven by one sheetTranslateY.
const BottomSheetSpringOptions kPushLayoutSpringConfig =
    BottomSheetSpringOptions(damping: 32, stiffness: 320, mass: 0.85);

const double kPresentationHostScale = 0.92;
const double kBottomSheetCornerRadius = 24;
const double kPresentationHostTopInsetMin = 46;

/// 获取所需数据或资源，用于底部弹层的状态、布局、手势与动画引擎。
double getPresentationHostTopInset(
  double screenWidth, {
  double presentationHostScale = kPresentationHostScale,
  double presentationHostTopInsetMin = kPresentationHostTopInsetMin,
}) {
  final sideLetterbox = (screenWidth * (1 - presentationHostScale)) / 2;
  return sideLetterbox > presentationHostTopInsetMin
      ? sideLetterbox
      : presentationHostTopInsetMin;
}

const double kPushHostHorizontalInset = 16;

/// Vertical gap between pushed host and sheet. Defaults to matching
/// [kPushHostHorizontalInset] so side and middle spacing stay equal unless
/// overridden independently (e.g. side inset 0, middle gap kept).
const double kPushHostVerticalGap = kPushHostHorizontalInset;

/// 执行当前模块中的推动insettoscale操作，用于底部弹层的状态、布局、手势与动画引擎。
double pushInsetToScale(double screenWidth, double inset) {
  if (screenWidth <= 0) return 1;
  final scale = (screenWidth - inset * 2) / screenWidth;
  return scale < 0 ? 0 : scale;
}

const double kStackCardScalePerLevel = 0.96;
const double kStackHorizontalInsetPerLevel = 10;
const double kStackCardOffsetYPerLevel = -8;
const double kStackCardRadiusBonusPerLevel = 4;

const double kDismissDragThreshold = 120;
const double kDismissVelocityThreshold = 800;
const double kDetentVelocityThreshold = 500;

const double kHandleHeight = 25;
const double kHiddenHandleHeight = 20;

const double kSheetScrollEndExtra = 24;

/// 获取所需数据或资源，用于底部弹层的状态、布局、手势与动画引擎。
double getBottomSheetScrollBottomPadding(
  double bottomInset, {
  double endExtra = kSheetScrollEndExtra,
}) => bottomInset + endExtra;

const double kScrollOffsetEpsilon = 1;
const double kSheetActivationOffset = 8;

const BottomSheetLayoutDetentsOptions kDetentFractions =
    BottomSheetLayoutDetentsOptions(medium: 0.5, large: 0.9, full: 1);

const ResolvedBottomSheetTheme kDefaultTheme = ResolvedBottomSheetTheme(
  sheetBackgroundColor: Color(0xFFFFFFFF),
  letterboxColor: Color(0xFF000000),
  hostBackgroundColor: Color(0x00000000),
  letterboxOpacity: 1,
  handleColor: Color(0xFFD1D1D6),
  scrimColor: Color(0x00000000),
  modalBackdropColor: Color(0x73000000), // rgba(0,0,0,0.45)
);

const String kDefaultAccessibilityLabel = 'Bottom sheet';

/// 执行当前模块中的clamp01操作，用于底部弹层的状态、布局、手势与动画引擎。
double clamp01(double value) {
  if (value < 0) return 0;
  if (value > 1) return 1;
  return value;
}

/// 执行当前模块中的lerpdouble操作，用于底部弹层的状态、布局、手势与动画引擎。
double lerpDouble(double a, double b, double t) => a + (b - a) * t;

/// 协调动画进度与状态过渡，用于底部弹层的状态、布局、手势与动画引擎。
double interpolateClamped(
  double value,
  double inputMin,
  double inputMax,
  double outputMin,
  double outputMax,
) {
  if (inputMax == inputMin) return outputMin;
  final t = clamp01((value - inputMin) / (inputMax - inputMin));
  return lerpDouble(outputMin, outputMax, t);
}
