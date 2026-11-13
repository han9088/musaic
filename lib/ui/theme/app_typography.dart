import 'package:material_ui/material_ui.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

abstract final class AppTypography {
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

  /// DIN-like display numerals with tabular figures.
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
