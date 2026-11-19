// 文件职责：应用视觉令牌、主题配置与排版规范。

import 'package:material_ui/material_ui.dart';

/// 封装或定义应用色彩相关类型与行为，负责应用视觉令牌、主题配置与排版规范。
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
  static const sheetBackground = Color(0xFF000000);

  /// Slightly lighter black visible between the sheet and host.
  static const sheetHostBackground = Color(0xFF181818);

  /// Modal sheet scrim (~45% black).
  static const sheetModalBackdrop = Color(0x73000000);
}
