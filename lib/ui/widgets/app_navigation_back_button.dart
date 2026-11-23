import 'package:material_ui/material_ui.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

class AppNavigationBackButton extends StatelessWidget {
  const AppNavigationBackButton({
    super.key,
    required this.icon,
    required this.onPressed,
  });

  final IconData icon;
  final VoidCallback onPressed;

  static const hitSize = 44.0;
  static const circleDiameter = 22.0;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: MaterialLocalizations.of(context).backButtonTooltip,
    padding: EdgeInsets.zero,
    style: const ButtonStyle(
      minimumSize: WidgetStatePropertyAll(Size.square(hitSize)),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    ),
    onPressed: onPressed,
    icon: SizedBox.square(
      dimension: circleDiameter,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: AppColors.settingsAccent,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Icon(
            icon,
            color: Colors.white,
            size: appNavigationBackIconSize,
          ),
        ),
      ),
    ),
  );
}
