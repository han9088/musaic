import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../canvas/album_grid_snapshot.dart';
import 'xerox_raster_request.dart';
import 'xerox_resolution.dart';

/// Builds a deduplicated, center-first list of raster jobs for one viewport.
class XeroxVisibleArtworkPlanner {
  const XeroxVisibleArtworkPlanner({this.maxProviderConcurrency = 4})
    : assert(maxProviderConcurrency > 0);

  final int maxProviderConcurrency;

  Future<List<XeroxRasterRequest>> build({
    required List<({int row, int column, Rect rect})> cells,
    required Size viewport,
    required double scale,
    required double devicePixelRatio,
    required String Function(int row, int column) assetAt,
    required Future<ImageProvider<Object>?> Function(String asset)
    resolveImageProvider,
    String? selectedAsset,
    double selectedScale = 1.16,
  }) async {
    if (cells.isEmpty && selectedAsset == null) return const [];

    final specs = <({String asset, double scale})>[];
    final seenSpecs = <({String asset, double scale})>{};

    void addSpec(String asset, double artworkScale) {
      final spec = (asset: asset, scale: artworkScale);
      if (seenSpecs.add(spec)) specs.add(spec);
    }

    final orderedCells = cells.toList()
      ..sort((a, b) {
        final aVisible = a.rect.overlaps(Offset.zero & viewport);
        final bVisible = b.rect.overlaps(Offset.zero & viewport);
        if (aVisible != bVisible) return aVisible ? -1 : 1;
        final aDistance =
            (a.rect.center - viewport.center(Offset.zero)).distanceSquared;
        final bDistance =
            (b.rect.center - viewport.center(Offset.zero)).distanceSquared;
        return aDistance.compareTo(bDistance);
      });

    // The selected tile is visually prominent; prepare it before the rest.
    if (selectedAsset != null) addSpec(selectedAsset, scale * selectedScale);
    for (final cell in orderedCells) {
      addSpec(assetAt(cell.row, cell.column), scale);
    }

    final resolved = List<XeroxRasterRequest?>.filled(specs.length, null);
    var cursor = 0;

    Future<void> resolveWorker() async {
      while (true) {
        final index = cursor++;
        if (index >= specs.length) return;
        final spec = specs[index];
        final provider = await resolveImageProvider(spec.asset);
        if (provider == null) continue;
        resolved[index] = XeroxRasterRequest(
          identity: spec.asset,
          image: provider,
          resolution: xeroxResolution(
            albumGridExtent * spec.scale * devicePixelRatio,
          ),
          fit: BoxFit.cover,
          devicePixelRatio: devicePixelRatio,
        );
      }
    }

    final workerCount = math.min(maxProviderConcurrency, specs.length);
    await Future.wait([
      for (var i = 0; i < workerCount; i++) resolveWorker(),
    ]);

    final requests = <XeroxRasterRequest>[];
    final seenKeys = <XeroxRasterKey>{};
    for (final request in resolved.whereType<XeroxRasterRequest>()) {
      if (seenKeys.add(request.key)) requests.add(request);
    }
    return requests;
  }
}
