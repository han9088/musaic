// 文件职责：应用装配、全局依赖与页面宿主。

import 'dart:async';

import 'package:audius_sdk/audius_sdk.dart';
import 'package:flutter/foundation.dart';
// Talker still uses Flutter's legacy Material library.
// ignore: deprecated_member_use
import 'package:flutter/material.dart' as flutter_material;
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:musaic_query/musaic_query.dart';

import '../storage/music/audius_secure_session_store.dart';
import '../storage/music/music_index.dart';
import '../storage/music/custom_artwork_store.dart';
import '../storage/settings/app_language_preference.dart';
import '../services/music/directory_music_library.dart';
import '../services/music/audius_account.dart';
import '../services/music/music_source_controller.dart';
import '../features/artwork/presentation/directory_artwork.dart';
import '../features/artwork/presentation/custom_artwork_scope.dart';
import '../features/indiebase/indiebase_scope.dart';
import '../features/desktop_tray/desktop_tray_host.dart';
import '../features/settings/desktop_settings_window.dart';

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
  final _audiusAccount = _createAudiusAccount();
  late final _sources = MusicSourceController(
    systemLibraryEnabled: defaultTargetPlatform != TargetPlatform.windows,
    audiusAccount: _audiusAccount,
  );
  final _indiebase = IndiebaseRuntime.fromEnvironment();
  late final _language = AppLanguagePreference(widget.initialLanguage);
  final _settingsWindow = DesktopSettingsWindow.isEnabled
      ? DesktopSettingsWindow()
      : null;
  final _customArtwork =
      !kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS)
      ? CustomArtworkStore.instance
      : null;
  DirectoryMusicLibrary? _directories;
  late final AppLifecycleListener _lifecycle;

  static AudiusAccount? _createAudiusAccount() {
    const clientId = String.fromEnvironment('AUDIUS_API_KEY');
    if (clientId.isEmpty || kIsWeb) return null;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        break;
      default:
        return null;
    }
    final redirect = Uri.parse('com.deskbtm.musaic.audius://oauth/callback');
    return AudiusAccount(
      oauth: AudiusOAuth(clientId: clientId, redirectUri: redirect),
      store: const AudiusSecureSessionStore(),
      openBrowser: (url) async {
        try {
          final callback = await FlutterWebAuth2.authenticate(
            url: url.toString(),
            callbackUrlScheme: redirect.scheme,
          );
          return Uri.parse(callback);
        } on PlatformException catch (error) {
          if (error.code.toUpperCase() == 'CANCELED') return null;
          rethrow;
        }
      },
    );
  }

  /// 读取并恢复所需的数据或资源，用于应用装配、全局依赖与页面宿主。
  Future<void> _restoreMusic() async {
    if (kIsWeb) return;
    try {
      final directories = MusaicQuery().directories;
      if (!await directories.supported || !mounted) return;
      diagnosticLog.record(DiagnosticEvent.musicRestoreStarted);
      final index = await MusicIndex.open();
      if (!mounted) {
        await index.close();
        return;
      }
      final library = DirectoryMusicLibrary(
        index: index,
        directories: directories,
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
    _settingsWindow?.dispose();
    _language.dispose();
    _indiebase?.close();
    unawaited(_sources.dispose());
    _audiusAccount?.dispose();
    unawaited(_directories?.dispose());
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    unawaited(_audiusAccount?.restore());
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
    // Talker uses Flutter's ScaffoldMessenger across its routes.
    Widget content = flutter_material.ScaffoldMessenger(child: child!);
    if (_customArtwork case final store?) {
      content = CustomArtworkScope(store: store, child: content);
    }
    if (_indiebase case final runtime?) {
      content = IndiebaseScope(runtime: runtime, child: content);
    }
    return content;
  }

  Widget _buildApp({required Locale? locale, required Widget home}) =>
      MaterialApp(
        locale: locale,
        onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
        localizationsDelegates: const [
          ...AppLocalizations.localizationsDelegates,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        theme: buildAppTheme(),
        builder: _buildScopes,
        home: home,
      );

  @override
  Widget build(BuildContext context) => SignalBuilder(
    builder: (context) {
      final locale = _language.selected.value.locale;
      final settingsWindow = _settingsWindow;
      final home = DirectoryArtworkScope(
        library: _directories,
        child: AppBottomSheetHost(
          child: HomePage(
            albumCache: _albumCache,
            sources: _sources,
            language: _language,
            settingsWindow: settingsWindow,
          ),
        ),
      );
      final mainApp = _buildApp(
        locale: locale,
        home: DesktopSettingsWindow.isSupported
            ? DesktopTrayHost(settingsWindow: settingsWindow, child: home)
            : home,
      );
      return settingsWindow?.attach(
            child: mainApp,
            buildApp: (content) => _buildApp(
              locale: locale,
              home: Builder(builder: content),
            ),
          ) ??
          mainApp;
    },
  );
}
