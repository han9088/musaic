import 'package:material_ui/material_ui.dart';

import '../ui/bottom_sheet/bottom_sheet.dart';
import '../ui/theme/app_colors.dart';

/// App-wide bottom-sheet host chrome (theme + default mode/layout).
///
/// - **Home**: wrap the shell once (the routed content).
/// - **Secondary pages**: wrap that page (or a subtree) when it needs sheets.
///
/// Each host owns an independent sheet stack — nested hosts do not share
/// sheets with the shell.
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
