@TestOn('browser')
library;

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musaic/l10n/generated/app_localizations.dart';
import 'package:musaic/features/music/presentation/music_source_picker.dart';
import 'package:musaic/services/music/local_music_library.dart';
import 'package:musaic/services/music/music_models.dart';
import 'package:musaic/services/music/music_source_controller.dart';

void main() {
  testWidgets('Web keeps sample source and omits local sources', (
    tester,
  ) async {
    expect(kIsWeb, isTrue);
    final sources = MusicSourceController();
    addTearDown(sources.dispose);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: MusicSourcePicker(sources: sources)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('music-source-mock')), findsOneWidget);
    expect(find.byKey(const ValueKey('music-source-local')), findsNothing);
    expect(sources.directories, isNull);
    final library = LocalMusicLibrary();
    expect(await library.authorizationStatus(), MusicAccess.unavailable);
    expect(
      await library.authorizationStatus(request: true),
      MusicAccess.unavailable,
    );
    await sources.selectLocal();
    expect(sources.problem.value, MusicSourceProblem.unavailable);
    expect(sources.catalog.value, isNull);
  });
}
