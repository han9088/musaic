import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_radius.dart';
import 'app_typography.dart';

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
    // Flex themes may omit fontSize on some styles; TextTheme.apply asserts
    // when scaling a null fontSize — scale only styles that define one.
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

/// White surfaces for sheet tabs and root-navigator secondary pages.
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

/// Secondary pages share the sheet surface.
ThemeData buildSecondaryPageTheme(ThemeData base) => buildSheetTheme(base);

/// Uses a restrained InkWell overlay for settings controls.
ThemeData buildSettingsInteractionTheme(ThemeData base) {
  return base.copyWith(
    splashFactory: InkRipple.splashFactory,
    splashColor: base.colorScheme.onSurface.withValues(alpha: 0.10),
    highlightColor: base.colorScheme.onSurface.withValues(alpha: 0.10),
    hoverColor: base.colorScheme.onSurface.withValues(alpha: 0.06),
  );
}

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

/// Wraps a root-navigator page in the shared secondary-page theme.
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
