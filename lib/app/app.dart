import 'package:material_ui/material_ui.dart';

import '../l10n/generated/app_localizations.dart';
import '../ui/theme/app_theme.dart';
import '../pages/home/home_page.dart';

class MusaicApp extends StatelessWidget {
  const MusaicApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: buildAppTheme(),
      home: const HomePage(),
    );
  }
}
