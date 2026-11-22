import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';

class SettingsSectionHeading extends StatelessWidget {
  const SettingsSectionHeading(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      settingsContentInset,
      16,
      settingsContentInset,
      8,
    ),
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
