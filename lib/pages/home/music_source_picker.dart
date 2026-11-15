import 'package:flutter/foundation.dart';

import '../../services/music/directory_music_library.dart';

import 'package:material_ui/material_ui.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../services/music/music_source_controller.dart';

class MusicSourcePicker extends StatelessWidget {
  const MusicSourcePicker({super.key, required this.sources});
  final MusicSourceController sources;

  @override
  Widget build(BuildContext context) => SignalBuilder(
    builder: (context) {
      final l10n = AppLocalizations.of(context);
      final albums = sources.catalog.value;
      final busy = sources.busy.value;
      final problem = sources.problem.value;
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.musicSource,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            ListTile(
              key: const ValueKey('music-source-mock'),
              enabled: !busy,
              selected: albums == null,
              leading: const Icon(
                PhosphorIcons.squaresFour,
                color: Colors.white70,
              ),
              title: Text(
                l10n.musicSourceMock,
                style: const TextStyle(color: Colors.white),
              ),
              trailing: albums == null
                  ? const Icon(PhosphorIcons.check, color: Colors.white)
                  : null,
              onTap: sources.selectMock,
            ),
            if (!kIsWeb)
              ListTile(
                key: const ValueKey('music-source-local'),
                enabled: !busy,
                selected: albums != null && !sources.directorySelected.value,
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
                      : albums == null
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
                    : albums != null
                    ? const Icon(PhosphorIcons.check, color: Colors.white)
                    : null,
                onTap: sources.selectLocal,
              ),
            if (sources.directories case final library?) ...[
              ListTile(
                leading: const Icon(
                  PhosphorIcons.folder,
                  color: Colors.white70,
                ),
                title: Text(
                  l10n.musicDirectories,
                  style: const TextStyle(color: Colors.white),
                ),
                selected: sources.directorySelected.value,
                onTap: busy ? null : () => sources.selectDirectories(),
              ),
              TextButton(
                onPressed: busy
                    ? null
                    : () => sources.selectDirectories(add: true),
                child: Text(l10n.musicAddDirectory),
              ),
              if (library.state.value == DirectoryScanState.scanning)
                TextButton(
                  onPressed: library.cancel,
                  child: Text(l10n.musicCancelScan),
                ),
              if (sources.directorySelected.value) ...[
                Text(
                  l10n.musicScanCounts(
                    library.counts.value.added,
                    library.counts.value.updated,
                    library.counts.value.skipped,
                    library.counts.value.deleted,
                    library.counts.value.failed,
                  ),
                  style: const TextStyle(color: Colors.white60),
                ),
                if (library.state.value != DirectoryScanState.scanning)
                  TextButton(
                    onPressed: () => library.refresh(force: true),
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
                      onPressed: busy
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
                      onPressed: busy ? null : () => library.remove(root),
                    ),
                  ),
                if (library.state.value == DirectoryScanState.failed)
                  Text(
                    l10n.musicSourceScanFailed,
                    style: const TextStyle(color: Colors.white70),
                  ),
                if (library.state.value == DirectoryScanState.cancelled)
                  Text(
                    l10n.musicScanCancelled,
                    style: const TextStyle(color: Colors.white70),
                  ),
              ],
            ],
            if (albums != null && !busy && !sources.directorySelected.value)
              TextButton(
                onPressed: sources.selectLocal,
                child: Text(l10n.musicSourceRescan),
              ),
            if (problem != null)
              Semantics(
                liveRegion: true,
                child: Text(switch (problem) {
                  MusicSourceProblem.denied => l10n.musicSourceDenied,
                  MusicSourceProblem.restricted => l10n.musicSourceRestricted,
                  MusicSourceProblem.unavailable => l10n.musicSourceUnavailable,
                  MusicSourceProblem.scanFailed => l10n.musicSourceScanFailed,
                }, style: const TextStyle(color: Colors.white70)),
              ),
          ],
        ),
      );
    },
  );
}
