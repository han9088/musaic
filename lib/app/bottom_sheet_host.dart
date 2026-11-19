// 文件职责：应用装配、全局依赖与页面宿主。

import 'package:material_ui/material_ui.dart';

import '../ui/bottom_sheet/bottom_sheet.dart';
import '../ui/theme/app_colors.dart';

/// 封装应用底部弹层宿主相关的类型与行为，负责应用装配、全局依赖与页面宿主。
class AppBottomSheetHost extends StatelessWidget {
  const AppBottomSheetHost({
    super.key,
    required this.child,
    this.mode = BottomSheetMode.push,
    this.layout = const BottomSheetLayoutOptionsPartial(
      hostHorizontalInset: 0,
      hostVerticalGap: 16,
    ),
  });

  final Widget child;
  final BottomSheetMode mode;
  final BottomSheetLayoutOptionsPartial? layout;

  static const theme = BottomSheetTheme(
    sheetBackgroundColor: AppColors.sheetBackground,
    letterboxColor: AppColors.sheetHostBackground,
    hostBackgroundColor: AppColors.sheetHostBackground,
    handleColor: AppColors.secondary,
    modalBackdropColor: AppColors.sheetModalBackdrop,
  );

  @override
  Widget build(BuildContext context) {
    return BottomSheetProvider(
      mode: mode,
      layout: layout,
      theme: theme,
      child: child,
    );
  }
}
