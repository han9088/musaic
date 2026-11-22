// 文件职责：音乐源、媒体库、播放及切换流程。

import 'package:flutter/foundation.dart';

import '../../../services/music/directory_music_library.dart';

import 'package:material_ui/material_ui.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../services/music/music_source_controller.dart';
import '../../../ui/theme/app_theme.dart';
import '../../../ui/widgets/settings_section_heading.dart';

/// 封装或定义音乐来源选择器相关类型与行为，负责音乐源、媒体库、播放及切换流程。
class MusicSourcePicker extends StatelessWidget {
  const MusicSourcePicker({
    super.key,
    required this.sources,
    this.sourceSwitching,
    this.onSourceSelection,
    this.demoOnly = false,
  });
  final MusicSourceController sources;
  final ValueListenable<bool>? sourceSwitching;
  final Future<void> Function(Future<void> Function())? onSourceSelection;
  final bool demoOnly;

  Future<void> _select(Future<void> Function() selection) =>
      onSourceSelection?.call(selection) ?? selection();

  @override
  Widget build(BuildContext context) => SignalBuilder(
    builder: (context) {
      Widget buildPicker(bool switching) {
        final l10n = AppLocalizations.of(context);
        final albums = sources.catalog.value;
        final busy = sources.busy.value;
        final problem = sources.problem.value;
        final directorySelected = sources.directorySelected.value;
        final localSelected = albums != null && !directorySelected;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!demoOnly) SettingsSectionHeading(l10n.musicSourceDemoGroup),
            ListTile(
              key: const ValueKey('music-source-mock'),
              enabled: !busy && !switching,
              selected: albums == null && !sources.mock2Selected.value,
              leading: const Icon(
                PhosphorIcons.squaresFour,
                color: Colors.white70,
              ),
              title: Text(
                l10n.musicSourceMock,
                style: const TextStyle(color: Colors.white),
              ),
              trailing: albums == null && !sources.mock2Selected.value
                  ? const Icon(PhosphorIcons.check, color: Colors.white)
                  : null,
              onTap: () => _select(sources.selectMock),
            ),
            ListTile(
              key: const ValueKey('music-source-mock2'),
              enabled: !busy && !switching,
              selected: albums == null && sources.mock2Selected.value,
              leading: const Icon(
                PhosphorIcons.squaresFour,
                color: Colors.white70,
              ),
              title: Text(
                l10n.musicSourceMock2,
                style: const TextStyle(color: Colors.white),
              ),
              trailing: albums == null && sources.mock2Selected.value
                  ? const Icon(PhosphorIcons.check, color: Colors.white)
                  : null,
              onTap: () => _select(sources.selectMock2),
            ),
            if (!demoOnly && !kIsWeb) ...[
              SettingsSectionHeading(l10n.musicSourceDeviceGroup),
              ListTile(
                key: const ValueKey('music-source-local'),
                enabled: !busy && !switching,
                selected: localSelected,
                leading: const Icon(
                  PhosphorIcons.musicNotes,
                  color: Colors.white70,
                ),
                title: Text(
                  l10n.musicSourceLocal,
                  style: const TextStyle(color: Colors.white),
                ),
                subtitle: Text(
                  busy
                      ? l10n.musicSourceScanning
                      : albums == null || directorySelected
                      ? l10n.musicSourceLocalHint
                      : l10n.musicSourceAlbumCount(albums.length),
                  style: const TextStyle(color: Colors.white60),
                ),
                trailing: busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : localSelected
                    ? const Icon(PhosphorIcons.check, color: Colors.white)
                    : null,
                onTap: () => _select(sources.selectLocal),
              ),
              if (localSelected && !busy)
                TextButton(
                  onPressed: switching
                      ? null
                      : () => _select(sources.selectLocal),
                  child: Text(l10n.musicSourceRescan),
                ),
            ],
            if (sources.directories case final library? when !demoOnly) ...[
              ListTile(
                leading: const Icon(
                  PhosphorIcons.folder,
                  color: Colors.white70,
                ),
                title: Text(
                  l10n.musicDirectories,
                  style: const TextStyle(color: Colors.white),
                ),
                selected: directorySelected,
                trailing: directorySelected
                    ? const Icon(PhosphorIcons.check, color: Colors.white)
                    : null,
                onTap: busy || switching
                    ? null
                    : () => _select(sources.selectDirectories),
              ),
              TextButton(
                onPressed: busy || switching
                    ? null
                    : () => _select(() => sources.selectDirectories(add: true)),
                child: Text(l10n.musicAddDirectory),
              ),
              if (library.state.value == DirectoryScanState.scanning)
                TextButton(
                  onPressed: library.cancel,
                  child: Text(l10n.musicCancelScan),
                ),
              if (directorySelected) ...[
                Padding(
                  padding: settingsItemPadding,
                  child: Text(
                    l10n.musicScanCounts(
                      library.counts.value.added,
                      library.counts.value.updated,
                      library.counts.value.skipped,
                      library.counts.value.deleted,
                      library.counts.value.failed,
                    ),
                    style: const TextStyle(color: Colors.white60),
                  ),
                ),
                if (library.state.value != DirectoryScanState.scanning)
                  TextButton(
                    onPressed: switching
                        ? null
                        : () => _select(() => library.refresh(force: true)),
                    child: Text(l10n.musicForceRefresh),
                  ),
                for (final root in library.sources.value)
                  ListTile(
                    title: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          root.name,
                          style: const TextStyle(color: Colors.white),
                        ),
                        for (final folder in library.folders.value.where(
                          (f) => f.id == root.id,
                        ))
                          Text(
                            l10n.musicFolderSummary(
                              folder.count,
                              folder.bytes == null
                                  ? '—'
                                  : '${(folder.bytes! / (1024 * 1024)).toStringAsFixed(1)} MB',
                            ),
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 12,
                            ),
                          ),
                        if (library.folders.value.any(
                          (f) => f.id == root.id && !f.complete,
                        ))
                          Text(
                            l10n.musicFolderIncomplete,
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                    subtitle: TextButton(
                      onPressed: busy || switching
                          ? null
                          : () async {
                              try {
                                await library.reauthorize(root);
                              } catch (_) {
                                sources.problem.value =
                                    MusicSourceProblem.scanFailed;
                              }
                            },
                      child: Text(l10n.musicReauthorize),
                    ),
                    trailing: IconButton(
                      tooltip: l10n.musicRemoveDirectory,
                      icon: const Icon(PhosphorIcons.minusCircle),
                      onPressed: busy || switching
                          ? null
                          : () => library.remove(root),
                    ),
                  ),
                if (library.state.value == DirectoryScanState.failed)
                  Padding(
                    padding: settingsItemPadding,
                    child: Text(
                      l10n.musicSourceScanFailed,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
                if (library.state.value == DirectoryScanState.cancelled)
                  Padding(
                    padding: settingsItemPadding,
                    child: Text(
                      l10n.musicScanCancelled,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
              ],
            ],
            if (!demoOnly && problem != null)
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
              builder: (context, value, _) => buildPicker(value),
            );
    },
  );
}
