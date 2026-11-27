// 文件职责：音乐源、媒体库、播放及切换流程。

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../services/music/directory_music_library.dart';
import '../../../services/music/music_models.dart';
import '../../../services/music/music_source_controller.dart';
import '../../../ui/theme/app_theme.dart';
import '../../../ui/theme/app_typography.dart';
import '../../../ui/widgets/app_selection_dot.dart';
import '../../../ui/widgets/settings_section_heading.dart';

/// 封装或定义音乐来源选择器相关类型与行为，负责音乐源、媒体库、播放及切换流程。
class MusicSourcePicker extends StatelessWidget {
  const MusicSourcePicker({
    super.key,
    required this.sources,
    this.sourceSwitching,
    this.onSourceSelection,
  });

  final MusicSourceController sources;
  final ValueListenable<bool>? sourceSwitching;
  final Future<void> Function(Future<void> Function())? onSourceSelection;

  Future<void> _select(Future<void> Function() selection) =>
      onSourceSelection?.call(selection) ?? selection();

  String _localMusicSummary(AppLocalizations l10n, List<ProviderAlbum> albums) {
    final singles = albums.where((album) => album.trackCount == 1).length;
    final albumCount = l10n.musicSourceAlbumCount(albums.length - singles);
    if (singles == 0) return albumCount;
    return '$albumCount · ${l10n.musicSourceSingleCount(singles)}';
  }

  @override
  Widget build(BuildContext context) => SignalBuilder(
    builder: (context) {
      Widget buildPicker(bool switching) {
        final l10n = AppLocalizations.of(context);
        final albums = sources.catalog.value;
        final busy = sources.busy.value;
        final audiusLoading = sources.audiusLoading.value;
        final selectionBlocked = busy || switching;
        final windows =
            !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;
        final showLocal =
            !kIsWeb &&
            (sources.directories != null ||
                (!windows && sources.systemLibraryEnabled));
        final audiusSelected = sources.audiusSelected;
        final localSelected = sources.localSelected.value;
        final localAlbums = localSelected ? albums : null;
        final localHint = sources.systemLibraryEnabled
            ? l10n.musicSourceLocalHint
            : l10n.musicSourceDirectoryHint;
        final library = showLocal && localSelected ? sources.directories : null;
        final folderState = library?.state.value;
        final scanningFolders = folderState == DirectoryScanState.scanning;
        final problem =
            sources.problem.value ??
            (folderState == DirectoryScanState.failed
                ? MusicSourceProblem.scanFailed
                : null);
        final mock2Selected = sources.mock2Selected.value;
        final firstDemoSelected = albums == null && !mock2Selected;
        final secondDemoSelected = albums == null && mock2Selected;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!windows)
              ListTile(
                key: const ValueKey('music-source-apple-music'),
                leading: const Icon(
                  PhosphorIcons.appleLogoFill,
                  color: Colors.white,
                ),
                title: Text(
                  'Apple Music',
                  style: AppTypography.inter(
                    fontSize:
                        Theme.of(context).textTheme.bodyLarge?.fontSize ?? 16,
                    color: const Color(0xFFFA2D55),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                onTap: () {},
              ),
            ListTile(
              key: const ValueKey('music-source-audius'),
              selected: audiusSelected,
              leading: Image.asset(
                'assets/branding/audius_glyph_color.png',
                width: 26,
                height: 26,
                excludeFromSemantics: true,
              ),
              title: AppSelectionTitle(
                selected: audiusSelected,
                child: Text(
                  'Audius',
                  style: AppTypography.inter(
                    fontSize:
                        Theme.of(context).textTheme.bodyLarge?.fontSize ?? 16,
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              trailing: audiusLoading
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : audiusSelected && sources.audiusAccount != null
                  ? ListenableBuilder(
                      listenable: sources.audiusAccount!,
                      builder: (context, _) {
                        final account = sources.audiusAccount!;
                        final user = account.user;
                        return user == null
                            ? TextButton(
                                onPressed: account.busy
                                    ? null
                                    : account.connect,
                                child: Text(l10n.audiusConnect),
                              )
                            : SizedBox(
                                width: 112,
                                child: Text(
                                  '@${user.handle ?? user.id}',
                                  textAlign: TextAlign.end,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                      },
                    )
                  : null,
              onTap: selectionBlocked || audiusSelected
                  ? null
                  : () => sources.selectAudius(transition: _select),
            ),
            SettingsSectionHeading(l10n.musicSourceDemoGroup),
            ListTile(
              key: const ValueKey('music-source-mock'),
              selected: firstDemoSelected,
              leading: const Icon(PhosphorIcons.squaresFour),
              title: AppSelectionTitle(
                selected: firstDemoSelected,
                child: Text(l10n.musicSourceMock),
              ),
              onTap: selectionBlocked
                  ? null
                  : () => _select(sources.selectMock),
            ),
            ListTile(
              key: const ValueKey('music-source-mock2'),
              selected: secondDemoSelected,
              leading: const Icon(
                PhosphorIcons.squaresFour,
                color: Colors.white70,
              ),
              title: AppSelectionTitle(
                selected: secondDemoSelected,
                child: Text(l10n.musicSourceMock2),
              ),
              onTap: selectionBlocked
                  ? null
                  : () => _select(sources.selectMock2),
            ),
            if (showLocal) ...[
              SettingsSectionHeading(l10n.musicSourceDeviceGroup),
              ListTile(
                key: const ValueKey('music-source-local'),
                selected: localSelected,
                leading: const Icon(PhosphorIcons.musicNotes),
                title: AppSelectionTitle(
                  selected: localSelected,
                  child: Text(l10n.musicSourceLocal),
                ),
                subtitle: Text(
                  busy && !audiusLoading
                      ? l10n.musicSourceScanning
                      : localAlbums == null
                      ? localHint
                      : _localMusicSummary(l10n, localAlbums),
                  style: const TextStyle(color: Colors.white60),
                ),
                trailing: busy && !audiusLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : null,
                onTap: selectionBlocked
                    ? null
                    : () => _select(sources.selectLocal),
              ),
              if (localSelected) ...[
                Padding(
                  padding: settingsItemPadding,
                  child: OutlinedButtonTheme(
                    data: OutlinedButtonThemeData(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        disabledForegroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white24),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                        minimumSize: const Size(0, 36),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                      ),
                    ),
                    child: Row(
                      spacing: 8,
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: Icon(
                              scanningFolders
                                  ? PhosphorIcons.x
                                  : PhosphorIcons.arrowsClockwise,
                              size: 18,
                            ),
                            label: Text(
                              scanningFolders
                                  ? l10n.musicCancelScan
                                  : l10n.musicSourceRescan,
                            ),
                            onPressed: scanningFolders
                                ? library?.cancel
                                : selectionBlocked
                                ? null
                                : sources.rescanLocal,
                          ),
                        ),
                        if (library != null)
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(
                                PhosphorIcons.folderSimplePlus,
                                size: 18,
                              ),
                              label: Text(l10n.musicAddDirectory),
                              onPressed: selectionBlocked
                                  ? null
                                  : () => sources.selectDirectories(add: true),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                if (library != null)
                  for (final folder in library.sources.value)
                    ListTile(
                      dense: true,
                      leading: const Icon(PhosphorIcons.folderSimple),
                      title: Text(
                        folder.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ),
              ],
            ],
            if (problem != null)
              Semantics(
                liveRegion: true,
                child: Padding(
                  padding: settingsItemPadding,
                  child: Text(switch (problem) {
                    MusicSourceProblem.denied => l10n.musicSourceDenied,
                    MusicSourceProblem.restricted => l10n.musicSourceRestricted,
                    MusicSourceProblem.unavailable =>
                      l10n.musicSourceUnavailable,
                    MusicSourceProblem.scanFailed => l10n.musicSourceScanFailed,
                    MusicSourceProblem.audiusUnavailable =>
                      l10n.audiusUnavailable,
                    MusicSourceProblem.audiusRateLimited =>
                      l10n.audiusRateLimited,
                    MusicSourceProblem.audiusEmpty => l10n.audiusEmpty,
                  }, style: const TextStyle(color: Colors.white70)),
                ),
              ),
          ],
        );
      }

      final switching = sourceSwitching;
      return switching == null
          ? buildPicker(false)
          : ValueListenableBuilder<bool>(
              valueListenable: switching,
              builder: (context, value, _) =>
                  SignalBuilder(builder: (_) => buildPicker(value)),
            );
    },
  );
}
