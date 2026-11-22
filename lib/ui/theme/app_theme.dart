// 文件职责：应用视觉令牌、主题配置与排版规范。

import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_radius.dart';
import 'app_typography.dart';

const appNavigationBackIconSize = 20.0;
const settingsContentInset = 28.0;
const settingsItemPadding = EdgeInsets.symmetric(
  horizontal: settingsContentInset,
);
const settingsItemArrowSize = 12.0;
const settingsItemTitleGap = 12.0;

/// 创建并组装所需对象或界面结构，用于应用视觉令牌、主题配置与排版规范。
ThemeData buildAppTheme({double fontScale = 1.0}) {
  final base = FlexThemeData.light(
    colors: const FlexSchemeColor(
      primary: AppColors.primary,
      primaryContainer: AppColors.surface,
      secondary: AppColors.secondary,
      secondaryContainer: AppColors.border,
      tertiary: AppColors.success,
      appBarColor: AppColors.surface,
      error: AppColors.danger,
    ),
    surfaceMode: FlexSurfaceMode.levelSurfacesLowScaffold,
    blendLevel: 0,
    subThemesData: const FlexSubThemesData(
      blendOnLevel: 0,
      cardRadius: AppRadius.medium,
      bottomSheetRadius: AppRadius.large,
      fabRadius: AppRadius.medium,
    ),
    useMaterial3: true,
  );

  return base.copyWith(
    scaffoldBackgroundColor: AppColors.background,
    canvasColor: AppColors.background,
    cardColor: AppColors.surface,
    dividerColor: AppColors.border,
    // Flex 主题中的部分文本样式可能没有设置 fontSize；此时调用 TextTheme.apply
    // 会因缩放 null 字体尺寸而触发断言，因此只缩放已定义 fontSize 的样式。
    textTheme: _scaleTextTheme(base.textTheme, fontScale).copyWith(
      bodyMedium: AppTypography.inter(fontSize: 14 * fontScale),
      bodyLarge: AppTypography.inter(fontSize: 16 * fontScale),
      titleMedium: AppTypography.inter(
        fontSize: 18 * fontScale,
        fontWeight: FontWeight.w600,
      ),
    ),
    colorScheme: base.colorScheme.copyWith(
      surface: AppColors.surface,
      onSurface: AppColors.primary,
      outline: AppColors.border,
    ),
    appBarTheme: AppBarThemeData(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.primary,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      systemOverlayStyle: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: AppColors.background,
        systemNavigationBarIconBrightness: Brightness.dark,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
      titleTextStyle: AppTypography.inter(
        fontSize: 18 * fontScale,
        fontWeight: FontWeight.w600,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.surface,
      indicatorColor: AppColors.border,
      labelTextStyle: WidgetStatePropertyAll(
        AppTypography.inter(
          fontSize: 12 * fontScale,
          color: AppColors.secondary,
        ),
      ),
    ),
  );
}

TextTheme _scaleTextTheme(TextTheme theme, double factor) {
  if (factor == 1.0) return theme;

  /// 执行当前模块中的比例操作，用于应用视觉令牌、主题配置与排版规范。
  TextStyle? scale(TextStyle? style) {
    if (style == null || style.fontSize == null) return style;
    return style.apply(fontSizeFactor: factor);
  }

  return TextTheme(
    displayLarge: scale(theme.displayLarge),
    displayMedium: scale(theme.displayMedium),
    displaySmall: scale(theme.displaySmall),
    headlineLarge: scale(theme.headlineLarge),
    headlineMedium: scale(theme.headlineMedium),
    headlineSmall: scale(theme.headlineSmall),
    titleLarge: scale(theme.titleLarge),
    titleMedium: scale(theme.titleMedium),
    titleSmall: scale(theme.titleSmall),
    bodyLarge: scale(theme.bodyLarge),
    bodyMedium: scale(theme.bodyMedium),
    bodySmall: scale(theme.bodySmall),
    labelLarge: scale(theme.labelLarge),
    labelMedium: scale(theme.labelMedium),
    labelSmall: scale(theme.labelSmall),
  );
}

/// 创建并组装所需对象或界面结构，用于应用视觉令牌、主题配置与排版规范。
ThemeData buildSheetTheme(ThemeData base) {
  const surface = AppColors.sheetBackground;
  return base.copyWith(
    scaffoldBackgroundColor: surface,
    canvasColor: surface,
    cardColor: surface,
    colorScheme: base.colorScheme.copyWith(
      surface: surface,
      surfaceContainerLowest: surface,
      surfaceContainerLow: surface,
      surfaceContainer: surface,
      surfaceContainerHigh: surface,
      surfaceContainerHighest: surface,
      primaryContainer: surface,
      secondaryContainer: AppColors.border,
    ),
    appBarTheme: base.appBarTheme.copyWith(
      backgroundColor: surface,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    dialogTheme: base.dialogTheme.copyWith(backgroundColor: surface),
    bottomSheetTheme: base.bottomSheetTheme.copyWith(
      backgroundColor: surface,
      modalBackgroundColor: surface,
    ),
    listTileTheme: const ListTileThemeData(tileColor: surface),
    dividerTheme: const DividerThemeData(color: AppColors.border),
    tabBarTheme: base.tabBarTheme.copyWith(dividerColor: AppColors.border),
  );
}

/// 创建并组装所需对象或界面结构，用于应用视觉令牌、主题配置与排版规范。
ThemeData buildSecondaryPageTheme(ThemeData base) => buildSheetTheme(base);

/// 创建并组装所需对象或界面结构，用于应用视觉令牌、主题配置与排版规范。
ThemeData buildSettingsInteractionTheme(ThemeData base) {
  return base.copyWith(
    splashFactory: InkRipple.splashFactory,
    splashColor: Colors.white.withValues(alpha: 0.10),
    highlightColor: Colors.white.withValues(alpha: 0.10),
    hoverColor: Colors.white.withValues(alpha: 0.06),
  );
}

/// 封装或定义settingsinteraction主题相关类型与行为，负责应用视觉令牌、主题配置与排版规范。
class SettingsInteractionTheme extends StatelessWidget {
  const SettingsInteractionTheme({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: buildSettingsInteractionTheme(Theme.of(context)),
      child: child,
    );
  }
}

/// 执行当前模块中的secondarypage主题操作，用于应用视觉令牌、主题配置与排版规范。
Widget secondaryPageTheme({required Widget child}) {
  return Builder(
    builder: (context) {
      return Theme(
        data: buildSecondaryPageTheme(Theme.of(context)),
        child: child,
      );
    },
  );
}
