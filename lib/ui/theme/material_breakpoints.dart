import 'package:flutter/widgets.dart';

/// Material 3 window size classes (logical px / dp).
///
/// See: https://m3.material.io/foundations/layout/applying-layout/window-size-classes
enum MaterialWindowSizeClass {
  /// Width &lt; 600 — typically phones.
  compact,

  /// 600 ≤ width &lt; 840 — typically tablets (portrait) / large foldables.
  medium,

  /// 840 ≤ width &lt; 1200 — tablets (landscape) / small desktops.
  expanded,

  /// 1200 ≤ width &lt; 1600.
  large,

  /// Width ≥ 1600.
  extraLarge,
}

/// Material 3 breakpoint edges (minimum width for each class above compact).
abstract final class MaterialBreakpoints {
  static const double medium = 600;
  static const double expanded = 840;
  static const double large = 1200;
  static const double extraLarge = 1600;
}

MaterialWindowSizeClass materialWindowSizeClassForWidth(double width) {
  if (width < MaterialBreakpoints.medium) {
    return MaterialWindowSizeClass.compact;
  }
  if (width < MaterialBreakpoints.expanded) {
    return MaterialWindowSizeClass.medium;
  }
  if (width < MaterialBreakpoints.large) {
    return MaterialWindowSizeClass.expanded;
  }
  if (width < MaterialBreakpoints.extraLarge) {
    return MaterialWindowSizeClass.large;
  }
  return MaterialWindowSizeClass.extraLarge;
}

MaterialWindowSizeClass materialWindowSizeClassOf(BuildContext context) {
  return materialWindowSizeClassForWidth(MediaQuery.sizeOf(context).width);
}

/// Compact = phone-sized window; medium and up ≈ tablet / larger.
bool isMaterialCompactWindow(BuildContext context) {
  return materialWindowSizeClassOf(context) == MaterialWindowSizeClass.compact;
}

/// Uses the engine view size so cold-start / resumed Android frames do not
/// briefly reuse a stale [MediaQuery] orientation.
bool isLandscapeLayout(BuildContext context) {
  return isLandscapeLayoutForSizes(
    viewPhysicalSize: View.of(context).physicalSize,
    mediaQuerySize: MediaQuery.sizeOf(context),
  );
}

@visibleForTesting
bool isLandscapeLayoutForSizes({
  required Size viewPhysicalSize,
  required Size mediaQuerySize,
}) {
  final size = viewPhysicalSize.isEmpty ? mediaQuerySize : viewPhysicalSize;
  return size.width > size.height;
}
