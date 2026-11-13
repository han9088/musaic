import 'package:material_ui/material_ui.dart';

/// Musaic design system color tokens.
abstract final class AppColors {
  static const background = Color(0xFFFFFFFF);
  static const surface = Color(0xFFF7F8FA);
  static const border = Color(0xFFE2E4E8);
  static const primary = Color(0xFF18191C);
  static const secondary = Color(0xFF626873);
  static const danger = Color(0xFFB42318);
  static const warning = Color(0xFF946200);
  static const success = Color(0xFF237A3B);

  /// Bottom sheet panel fill.
  static const sheetBackground = background;

  /// Transparent host behind sheets (shows dashboard through).
  static const sheetHostBackground = Color(0x00000000);

  /// Modal sheet scrim (~45% black).
  static const sheetModalBackdrop = Color(0x73000000);
}
