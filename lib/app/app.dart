import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../l10n/generated/app_localizations.dart';
import '../ui/theme/app_theme.dart';
import '../pages/home/home_page.dart';
import '../pages/home/home_sheet.dart';
import '../services/mock_album_cache.dart';
import 'bottom_sheet_host.dart';

class MusaicApp extends StatefulWidget {
  const MusaicApp({super.key});

  @override
  State<MusaicApp> createState() => _MusaicAppState();
}

class _MusaicAppState extends State<MusaicApp> {
  final _albumCache = MockAlbumCache();

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      theme: buildAppTheme(),
      home: AppBottomSheetHost(
        child: HomeSheet(child: HomePage(albumCache: _albumCache)),
      ),
    );
  }
}
