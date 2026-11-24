// 文件职责：应用装配、全局依赖与页面宿主。

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:musaic_query/musaic_query.dart';

import '../storage/music/music_index.dart';
import '../storage/music/custom_artwork_store.dart';
import '../storage/settings/app_language_preference.dart';
import '../services/music/directory_music_library.dart';
import '../services/music/music_source_controller.dart';
import '../features/artwork/presentation/directory_artwork.dart';
import '../features/artwork/presentation/custom_artwork_scope.dart';
import '../features/indiebase/indiebase_scope.dart';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../l10n/generated/app_localizations.dart';
import '../ui/theme/app_theme.dart';
import '../pages/home/home_page.dart';
import '../services/mock_album_cache.dart';
import '../services/diagnostics/diagnostic_log.dart';
import '../services/indiebase_runtime.dart';
import 'bottom_sheet_host.dart';

/// 封装musaic应用相关的类型与行为，负责应用装配、全局依赖与页面宿主。
class MusaicApp extends StatefulWidget {
  const MusaicApp({super.key, this.initialLanguage = AppLanguage.system});

  final AppLanguage initialLanguage;

  @override
  State<MusaicApp> createState() => _MusaicAppState();
}

/// 封装musaic应用状态相关的类型与行为，负责应用装配、全局依赖与页面宿主。
class _MusaicAppState extends State<MusaicApp> {
  final _albumCache = MockAlbumCache();
  final _sources = MusicSourceController();
  final _indiebase = IndiebaseRuntime.fromEnvironment();
  late final _language = AppLanguagePreference(widget.initialLanguage);
  final _customArtwork =
      !kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS)
      ? CustomArtworkStore.instance
      : null;
  DirectoryMusicLibrary? _directories;
  late final AppLifecycleListener _lifecycle;

  /// 读取并恢复所需的数据或资源，用于应用装配、全局依赖与页面宿主。
  Future<void> _restoreMusic() async {
    if (kIsWeb ||
        !{
          TargetPlatform.android,
          TargetPlatform.iOS,
        }.contains(defaultTargetPlatform)) {
      return;
    }
    diagnosticLog.record(DiagnosticEvent.musicRestoreStarted);
    try {
      final index = await MusicIndex.open();
      if (!mounted) {
        await index.close();
        return;
      }
      final library = DirectoryMusicLibrary(
        index: index,
        directories: MusaicQuery().directories,
      );
      _directories = library;
      await library.loadCached();
      if (!mounted) return;
      setState(() {});
      await _sources.attachDirectories(library);
      if (mounted) diagnosticLog.record(DiagnosticEvent.musicRestoreCompleted);
    } catch (error) {
      diagnosticLog.record(DiagnosticEvent.musicRestoreFailed, error: error);
      if (mounted) _sources.problem.value = MusicSourceProblem.scanFailed;
    }
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _language.dispose();
    _indiebase?.close();
    unawaited(_sources.dispose());
    unawaited(_directories?.dispose());
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onResume: () => diagnosticLog.record(DiagnosticEvent.appResumed),
      onHide: () {
        diagnosticLog.record(DiagnosticEvent.appHidden);
        unawaited(diagnosticLog.flush());
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_restoreMusic());
      unawaited(
        _customArtwork?.load().catchError((Object error) {
          debugPrint('Could not load custom cover index: ${error.runtimeType}');
        }),
      );
    });
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  Widget _buildScopes(BuildContext _, Widget? child) {
    Widget content = child!;
    if (_customArtwork case final store?) {
      content = CustomArtworkScope(store: store, child: content);
    }
    if (_indiebase case final runtime?) {
      content = IndiebaseScope(runtime: runtime, child: content);
    }
    return content;
  }

  @override
  Widget build(BuildContext context) => SignalBuilder(
    builder: (context) => MaterialApp(
      locale: _language.selected.value.locale,
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      theme: buildAppTheme(),
      builder: _customArtwork == null && _indiebase == null
          ? null
          : _buildScopes,
      home: DirectoryArtworkScope(
        library: _directories,
        child: AppBottomSheetHost(
          child: HomePage(
            albumCache: _albumCache,
            sources: _sources,
            language: _language,
          ),
        ),
      ),
    ),
  );
}
