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

/// Top letterbox aligned with side inset from scale.
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

/// Maps horizontal inset to uniform scale so layout size stays unchanged.
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

double clamp01(double value) {
  if (value < 0) return 0;
  if (value > 1) return 1;
  return value;
}

double lerpDouble(double a, double b, double t) => a + (b - a) * t;

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
