import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';

class SettingsSectionHeading extends StatelessWidget {
  const SettingsSectionHeading(
    this.title, {
    super.key,
    this.horizontalPadding = settingsContentInset,
  });

  final String title;
  final double horizontalPadding;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(horizontalPadding, 16, horizontalPadding, 8),
    child: Semantics(
      header: true,
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white60,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
    ),
  );
}
