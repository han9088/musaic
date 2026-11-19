// 文件职责：应用视觉令牌、主题配置与排版规范。

import 'package:flutter/widgets.dart';

/// 封装或定义Materialwindow尺寸class相关类型与行为，负责应用视觉令牌、主题配置与排版规范。
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

/// 封装或定义Material断点相关类型与行为，负责应用视觉令牌、主题配置与排版规范。
abstract final class MaterialBreakpoints {
  static const double medium = 600;
  static const double expanded = 840;
  static const double large = 1200;
  static const double extraLarge = 1600;
}

/// 执行当前模块中的Materialwindow尺寸classforwidth操作，用于应用视觉令牌、主题配置与排版规范。
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

/// 执行当前模块中的Materialwindow尺寸classof操作，用于应用视觉令牌、主题配置与排版规范。
MaterialWindowSizeClass materialWindowSizeClassOf(BuildContext context) {
  return materialWindowSizeClassForWidth(MediaQuery.sizeOf(context).width);
}

/// 判断当前状态是否满足指定条件，用于应用视觉令牌、主题配置与排版规范。
bool isMaterialCompactWindow(BuildContext context) {
  return materialWindowSizeClassOf(context) == MaterialWindowSizeClass.compact;
}

/// 判断当前状态是否满足指定条件，用于应用视觉令牌、主题配置与排版规范。
bool isLandscapeLayout(BuildContext context) {
  return isLandscapeLayoutForSizes(
    viewPhysicalSize: View.of(context).physicalSize,
    mediaQuerySize: MediaQuery.sizeOf(context),
  );
}

@visibleForTesting
/// 判断当前状态是否满足指定条件，用于应用视觉令牌、主题配置与排版规范。
bool isLandscapeLayoutForSizes({
  required Size viewPhysicalSize,
  required Size mediaQuerySize,
}) {
  final size = viewPhysicalSize.isEmpty ? mediaQuerySize : viewPhysicalSize;
  return size.width > size.height;
}
