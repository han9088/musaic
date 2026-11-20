// 文件职责：应用装配、全局依赖与页面宿主。

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:musaic_query/musaic_query.dart';

import '../storage/music/music_index.dart';
import '../services/music/directory_music_library.dart';
import '../services/music/music_source_controller.dart';
import '../features/artwork/presentation/directory_artwork.dart';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../l10n/generated/app_localizations.dart';
import '../ui/theme/app_theme.dart';
import '../pages/home/home_page.dart';
import '../services/mock_album_cache.dart';
import 'bottom_sheet_host.dart';

/// 封装musaic应用相关的类型与行为，负责应用装配、全局依赖与页面宿主。
class MusaicApp extends StatefulWidget {
  const MusaicApp({super.key});

  @override
  State<MusaicApp> createState() => _MusaicAppState();
}

/// 封装musaic应用状态相关的类型与行为，负责应用装配、全局依赖与页面宿主。
class _MusaicAppState extends State<MusaicApp> {
  final _albumCache = MockAlbumCache();
  final _sources = MusicSourceController();
  DirectoryMusicLibrary? _directories;

  /// 读取并恢复所需的数据或资源，用于应用装配、全局依赖与页面宿主。
  Future<void> _restoreMusic() async {
    if (kIsWeb ||
        !{
          TargetPlatform.android,
          TargetPlatform.iOS,
        }.contains(defaultTargetPlatform)) {
      return;
    }
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
    } catch (_) {
      if (mounted) _sources.problem.value = MusicSourceProblem.scanFailed;
    }
  }

  @override
  void dispose() {
    unawaited(_sources.dispose());
    unawaited(_directories?.dispose());
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_restoreMusic());
    });
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
      home: DirectoryArtworkScope(
        library: _directories,
        child: AppBottomSheetHost(
          child: HomePage(albumCache: _albumCache, sources: _sources),
        ),
      ),
    );
  }
}
