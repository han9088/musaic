// 文件职责：应用通用界面组件及其视觉绘制实现。

import 'package:material_ui/material_ui.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// 封装或定义应用文本variant相关类型与行为，负责应用通用界面组件及其视觉绘制实现。
enum AppTextVariant { body, caption, title, display }

/// 封装或定义应用文本相关类型与行为，负责应用通用界面组件及其视觉绘制实现。
class AppText extends StatelessWidget {
  const AppText(
    this.text, {
    super.key,
    this.variant = AppTextVariant.body,
    this.color,
    this.numeric = false,
    this.fontSize,
    this.fontWeight,
    this.textAlign,
  });

  final String text;
  final AppTextVariant variant;
  final Color? color;
  final bool numeric;
  final double? fontSize;
  final FontWeight? fontWeight;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final resolvedColor = color ?? _defaultColor();
    final style = numeric
        ? AppTypography.displayNumeric(
            fontSize: fontSize ?? _defaultSize(),
            fontWeight: fontWeight ?? _defaultWeight(),
            color: resolvedColor,
          )
        : AppTypography.inter(
            fontSize: fontSize ?? _defaultSize(),
            fontWeight: fontWeight ?? _defaultWeight(),
            color: resolvedColor,
          );

    return Text(text, style: style, textAlign: textAlign);
  }

  Color _defaultColor() {
    return switch (variant) {
      AppTextVariant.caption => AppColors.secondary,
      _ => AppColors.primary,
    };
  }

  double _defaultSize() {
    return switch (variant) {
      AppTextVariant.display => 48,
      AppTextVariant.title => 18,
      AppTextVariant.caption => 12,
      AppTextVariant.body => 14,
    };
  }

  FontWeight _defaultWeight() {
    return switch (variant) {
      AppTextVariant.display => FontWeight.w600,
      AppTextVariant.title => FontWeight.w600,
      _ => FontWeight.w400,
    };
  }
}
