// 文件职责：应用通用界面组件及其视觉绘制实现。

import 'package:material_ui/material_ui.dart';

import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';

/// 封装或定义应用表面相关类型与行为，负责应用通用界面组件及其视觉绘制实现。
class AppSurface extends StatelessWidget {
  const AppSurface({
    super.key,
    required this.child,
    this.padding,
    this.radius = AppRadius.medium,
    this.border = true,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double radius;
  final bool border;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
        side: border
            ? BorderSide(color: Theme.of(context).colorScheme.outline)
            : BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: padding ?? const EdgeInsets.all(AppSpacing.sm),
        child: child,
      ),
    );
  }
}
