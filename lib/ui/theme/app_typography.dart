// 文件职责：应用视觉令牌、主题配置与排版规范。

import 'package:material_ui/material_ui.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// 封装或定义应用字体排版相关类型与行为，负责应用视觉令牌、主题配置与排版规范。
abstract final class AppTypography {
  /// 执行当前模块中的inter操作，用于应用视觉令牌、主题配置与排版规范。
  static TextStyle inter({
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.w400,
    Color color = AppColors.primary,
  }) {
    return GoogleFonts.inter(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: 1.3,
    );
  }

  /// 执行当前模块中的displaynumeric操作，用于应用视觉令牌、主题配置与排版规范。
  static TextStyle displayNumeric({
    required double fontSize,
    FontWeight fontWeight = FontWeight.w600,
    Color color = AppColors.primary,
  }) {
    return GoogleFonts.barlowCondensed(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      fontFeatures: const [FontFeature.tabularFigures()],
      height: 1.0,
    );
  }
}
