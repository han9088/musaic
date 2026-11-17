part of '../types.dart';

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

