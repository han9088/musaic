import 'constants.dart';
import 'types.dart';

const BottomSheetLayoutOptions kDefaultLayoutOptions = BottomSheetLayoutOptions(
  motion: BottomSheetLayoutMotionOptions(
    sheetSpring: kSheetSpringConfig,
    presentationSpring: kPresentationSpringConfig,
    pushLayoutSpring: kPushLayoutSpringConfig,
  ),
  presentation: BottomSheetLayoutPresentationOptions(
    hostScale: kPresentationHostScale,
    cornerRadius: kBottomSheetCornerRadius,
    hostTopInsetMin: kPresentationHostTopInsetMin,
  ),
  push: BottomSheetLayoutPushOptions(
    hostHorizontalInset: kPushHostHorizontalInset,
    hostVerticalGap: kPushHostVerticalGap,
    direction: PushDirection.bottom,
  ),
  stack: BottomSheetLayoutStackOptions(
    scalePerLevel: kStackCardScalePerLevel,
    horizontalInsetPerLevel: kStackHorizontalInsetPerLevel,
    offsetYPerLevel: kStackCardOffsetYPerLevel,
    radiusBonusPerLevel: kStackCardRadiusBonusPerLevel,
  ),
  gestures: BottomSheetLayoutGesturesOptions(
    dismissDragThreshold: kDismissDragThreshold,
    dismissVelocityThreshold: kDismissVelocityThreshold,
    detentVelocityThreshold: kDetentVelocityThreshold,
    activationOffset: kSheetActivationOffset,
  ),
  handle: BottomSheetLayoutHandleOptions(
    height: kHandleHeight,
    hiddenHeight: kHiddenHandleHeight,
  ),
  scroll: BottomSheetLayoutScrollOptions(
    endExtra: kSheetScrollEndExtra,
    offsetEpsilon: kScrollOffsetEpsilon,
  ),
  detents: kDetentFractions,
);

BottomSheetSpringOptions _mergeSpring(
  BottomSheetSpringOptions base,
  BottomSheetSpringOptions? override,
) {
  if (override == null) return base;
  return BottomSheetSpringOptions(
    damping: override.damping,
    stiffness: override.stiffness,
    mass: override.mass,
  );
}

/// Deep-merges partial layout options with [kDefaultLayoutOptions].
BottomSheetLayoutOptions mergeLayoutOptions([
  BottomSheetLayoutOptions? partial,
]) {
  if (partial == null) return kDefaultLayoutOptions;

  return BottomSheetLayoutOptions(
    motion: BottomSheetLayoutMotionOptions(
      sheetSpring: _mergeSpring(
        kDefaultLayoutOptions.motion.sheetSpring,
        partial.motion.sheetSpring,
      ),
      presentationSpring: _mergeSpring(
        kDefaultLayoutOptions.motion.presentationSpring,
        partial.motion.presentationSpring,
      ),
      pushLayoutSpring: _mergeSpring(
        kDefaultLayoutOptions.motion.pushLayoutSpring,
        partial.motion.pushLayoutSpring,
      ),
    ),
    presentation: BottomSheetLayoutPresentationOptions(
      hostScale: partial.presentation.hostScale,
      cornerRadius: partial.presentation.cornerRadius,
      hostTopInsetMin: partial.presentation.hostTopInsetMin,
    ),
    push: BottomSheetLayoutPushOptions(
      hostHorizontalInset: partial.push.hostHorizontalInset,
      hostVerticalGap: partial.push.hostVerticalGap,
      direction: partial.push.direction,
    ),
    stack: BottomSheetLayoutStackOptions(
      scalePerLevel: partial.stack.scalePerLevel,
      horizontalInsetPerLevel: partial.stack.horizontalInsetPerLevel,
      offsetYPerLevel: partial.stack.offsetYPerLevel,
      radiusBonusPerLevel: partial.stack.radiusBonusPerLevel,
    ),
    gestures: BottomSheetLayoutGesturesOptions(
      dismissDragThreshold: partial.gestures.dismissDragThreshold,
      dismissVelocityThreshold: partial.gestures.dismissVelocityThreshold,
      detentVelocityThreshold: partial.gestures.detentVelocityThreshold,
      activationOffset: partial.gestures.activationOffset,
    ),
    handle: BottomSheetLayoutHandleOptions(
      height: partial.handle.height,
      hiddenHeight: partial.handle.hiddenHeight,
    ),
    scroll: BottomSheetLayoutScrollOptions(
      endExtra: partial.scroll.endExtra,
      offsetEpsilon: partial.scroll.offsetEpsilon,
    ),
    detents: BottomSheetLayoutDetentsOptions(
      medium: partial.detents.medium,
      large: partial.detents.large,
      full: partial.detents.full,
    ),
  );
}

/// Merges a partial override onto defaults (RN-style Partial deep merge).
BottomSheetLayoutOptions mergeLayoutOptionsPartial(
  BottomSheetLayoutOptionsPartial? partial,
) {
  if (partial == null) return kDefaultLayoutOptions;

  final base = kDefaultLayoutOptions;
  return BottomSheetLayoutOptions(
    motion: BottomSheetLayoutMotionOptions(
      sheetSpring: _mergeSpring(base.motion.sheetSpring, partial.sheetSpring),
      presentationSpring: _mergeSpring(
        base.motion.presentationSpring,
        partial.presentationSpring,
      ),
      pushLayoutSpring: _mergeSpring(
        base.motion.pushLayoutSpring,
        partial.pushLayoutSpring,
      ),
    ),
    presentation: BottomSheetLayoutPresentationOptions(
      hostScale: partial.hostScale ?? base.presentation.hostScale,
      cornerRadius: partial.cornerRadius ?? base.presentation.cornerRadius,
      hostTopInsetMin:
          partial.hostTopInsetMin ?? base.presentation.hostTopInsetMin,
    ),
    push: BottomSheetLayoutPushOptions(
      hostHorizontalInset:
          partial.hostHorizontalInset ?? base.push.hostHorizontalInset,
      hostVerticalGap: partial.hostVerticalGap ?? base.push.hostVerticalGap,
      direction: partial.pushDirection ?? base.push.direction,
    ),
    stack: BottomSheetLayoutStackOptions(
      scalePerLevel: partial.scalePerLevel ?? base.stack.scalePerLevel,
      horizontalInsetPerLevel:
          partial.horizontalInsetPerLevel ?? base.stack.horizontalInsetPerLevel,
      offsetYPerLevel: partial.offsetYPerLevel ?? base.stack.offsetYPerLevel,
      radiusBonusPerLevel:
          partial.radiusBonusPerLevel ?? base.stack.radiusBonusPerLevel,
    ),
    gestures: BottomSheetLayoutGesturesOptions(
      dismissDragThreshold:
          partial.dismissDragThreshold ?? base.gestures.dismissDragThreshold,
      dismissVelocityThreshold:
          partial.dismissVelocityThreshold ??
          base.gestures.dismissVelocityThreshold,
      detentVelocityThreshold:
          partial.detentVelocityThreshold ??
          base.gestures.detentVelocityThreshold,
      activationOffset:
          partial.activationOffset ?? base.gestures.activationOffset,
    ),
    handle: BottomSheetLayoutHandleOptions(
      height: partial.handleHeight ?? base.handle.height,
      hiddenHeight: partial.hiddenHandleHeight ?? base.handle.hiddenHeight,
    ),
    scroll: BottomSheetLayoutScrollOptions(
      endExtra: partial.scrollEndExtra ?? base.scroll.endExtra,
      offsetEpsilon: partial.scrollOffsetEpsilon ?? base.scroll.offsetEpsilon,
    ),
    detents: BottomSheetLayoutDetentsOptions(
      medium: partial.detentMedium ?? base.detents.medium,
      large: partial.detentLarge ?? base.detents.large,
      full: partial.detentFull ?? base.detents.full,
    ),
  );
}

/// Flat partial overrides for provider `layout` prop (Dart-friendly).
class BottomSheetLayoutOptionsPartial {
  const BottomSheetLayoutOptionsPartial({
    this.sheetSpring,
    this.presentationSpring,
    this.pushLayoutSpring,
    this.hostScale,
    this.cornerRadius,
    this.hostTopInsetMin,
    this.hostHorizontalInset,
    this.hostVerticalGap,
    this.pushDirection,
    this.scalePerLevel,
    this.horizontalInsetPerLevel,
    this.offsetYPerLevel,
    this.radiusBonusPerLevel,
    this.dismissDragThreshold,
    this.dismissVelocityThreshold,
    this.detentVelocityThreshold,
    this.activationOffset,
    this.handleHeight,
    this.hiddenHandleHeight,
    this.scrollEndExtra,
    this.scrollOffsetEpsilon,
    this.detentMedium,
    this.detentLarge,
    this.detentFull,
  });

  final BottomSheetSpringOptions? sheetSpring;
  final BottomSheetSpringOptions? presentationSpring;
  final BottomSheetSpringOptions? pushLayoutSpring;
  final double? hostScale;
  final double? cornerRadius;
  final double? hostTopInsetMin;
  final double? hostHorizontalInset;
  final double? hostVerticalGap;
  final PushDirection? pushDirection;
  final double? scalePerLevel;
  final double? horizontalInsetPerLevel;
  final double? offsetYPerLevel;
  final double? radiusBonusPerLevel;
  final double? dismissDragThreshold;
  final double? dismissVelocityThreshold;
  final double? detentVelocityThreshold;
  final double? activationOffset;
  final double? handleHeight;
  final double? hiddenHandleHeight;
  final double? scrollEndExtra;
  final double? scrollOffsetEpsilon;
  final double? detentMedium;
  final double? detentLarge;
  final double? detentFull;
}
