// 文件职责：规划 Xerox 模式切换所需的可视封面，并为任务分配处理优先级。

import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../canvas/album_grid_snapshot.dart';
import '../model/artwork_identity.dart';
import '../model/artwork_request.dart';
import '../source/artwork_resolver.dart';
import 'xerox_raster_request.dart';
import 'xerox_resolution.dart';

/// 根据画布快照选择需要处理的图片，并限制并发解析 Provider 的数量。
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
    required Future<ResolvedArtwork?> Function(ArtworkRequest request)
    resolveArtwork,
    ArtworkIdentity? Function(int row, int column)? identityAt,
    String? selectedAsset,
    ArtworkIdentity? selectedIdentity,
    double selectedScale = 1.16,
    bool Function()? isActive,
  }) async {
    if (cells.isEmpty && selectedAsset == null) return const [];

    final specs = <({
      String asset,
      double scale,
      ArtworkIdentity? identity,
      XeroxRasterPriority priority,
    })>[];
    final specIndexes = <({
      String asset,
      double scale,
      ArtworkIdentity? identity,
    }), int>{};

    void addSpec(
      String asset,
      double artworkScale,
      ArtworkIdentity? identity,
      XeroxRasterPriority priority,
    ) {
      final key = (asset: asset, scale: artworkScale, identity: identity);
      final existingIndex = specIndexes[key];
      if (existingIndex != null) {
        final existing = specs[existingIndex];
        if (priority.index > existing.priority.index) {
          specs[existingIndex] = (
            asset: existing.asset,
            scale: existing.scale,
            identity: existing.identity,
            priority: priority,
          );
        }
        return;
      }
      specIndexes[key] = specs.length;
      specs.add((
        asset: asset,
        scale: artworkScale,
        identity: identity,
        priority: priority,
      ));
    }

    final viewportRect = Offset.zero & viewport;
    final orderedCells = cells.toList()
      ..sort((a, b) {
        final aVisible = a.rect.overlaps(viewportRect);
        final bVisible = b.rect.overlaps(viewportRect);
        if (aVisible != bVisible) return aVisible ? -1 : 1;
        final aDistance =
            (a.rect.center - viewport.center(Offset.zero)).distanceSquared;
        final bDistance =
            (b.rect.center - viewport.center(Offset.zero)).distanceSquared;
        return aDistance.compareTo(bDistance);
      });

    if (selectedAsset != null) {
      addSpec(
        selectedAsset,
        scale * selectedScale,
        selectedIdentity,
        XeroxRasterPriority.selected,
      );
    }

    for (final cell in orderedCells) {
      final visible = cell.rect.overlaps(viewportRect);
      addSpec(
        assetAt(cell.row, cell.column),
        scale,
        identityAt?.call(cell.row, cell.column),
        visible ? XeroxRasterPriority.visible : XeroxRasterPriority.overscan,
      );
    }

    final resolved = List<XeroxRasterRequest?>.filled(specs.length, null);
    var cursor = 0;

    Future<void> resolveWorker() async {
      while (true) {
        if (isActive != null && !isActive()) {
          throw StateError('Xerox artwork planning was cancelled.');
        }
        final index = cursor++;
        if (index >= specs.length) return;
        final spec = specs[index];
        final request = ArtworkRequest(
          source: spec.asset,
          identity: spec.identity,
          targetSize: Size.square(albumGridExtent * spec.scale),
          devicePixelRatio: devicePixelRatio,
          fit: BoxFit.cover,
        );
        final artwork = await resolveArtwork(request);
        if (artwork == null) continue;

        resolved[index] = XeroxRasterRequest(
          identity: artwork.identity,
          sourceKey: artwork.sourceKey,
          image: artwork.image,
          resolution: xeroxResolution(
            request.targetSize!.longestSide * request.devicePixelRatio,
          ),
          fit: request.fit,
          devicePixelRatio: request.devicePixelRatio,
          priority: spec.priority,
        );
      }
    }

    final workerCount = math.min(maxProviderConcurrency, specs.length);
    await Future.wait([
      for (var i = 0; i < workerCount; i++) resolveWorker(),
    ]);
    if (isActive != null && !isActive()) {
      throw StateError('Xerox artwork planning was cancelled.');
    }

    final requests = <XeroxRasterRequest>[];
    final seenKeys = <XeroxRasterKey>{};
    for (final request in resolved.whereType<XeroxRasterRequest>()) {
      if (seenKeys.add(request.key)) requests.add(request);
    }
    return requests;
  }
}
