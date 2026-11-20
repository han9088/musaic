// 文件职责：根据视口中的封面请求生成 Xerox Raster 任务，并分配优先级。

import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../model/artwork_identity.dart';
import '../model/artwork_request.dart';
import '../model/artwork_resource.dart';
import '../pipeline/artwork_pipeline.dart';
import 'xerox_raster_request.dart';

/// 调用方提供可视 Tile、尺寸与封面映射；规划器不依赖页面或画布实现。
class XeroxVisibleArtworkPlanner {
  const XeroxVisibleArtworkPlanner({this.maxProviderConcurrency = 4})
    : assert(maxProviderConcurrency > 0);

  final int maxProviderConcurrency;

  Future<List<XeroxRasterRequest>> build({
    required List<({int row, int column, Rect rect})> cells,
    required Size viewport,
    required double scale,
    required double tileExtent,
    required double devicePixelRatio,
    required String Function(int row, int column) assetAt,
    required Future<ArtworkResource?> Function(ArtworkRequest request)
    resolveArtwork,
    ArtworkIdentity? Function(int row, int column)? identityAt,
    ArtworkVersion? Function(int row, int column)? versionAt,
    String? selectedAsset,
    ArtworkIdentity? selectedIdentity,
    ArtworkVersion? selectedVersion,
    double selectedScale = 1.16,
    bool Function()? isActive,
  }) async {
    if (cells.isEmpty && selectedAsset == null) return const [];

    final specs = <({
      String asset,
      double scale,
      ArtworkIdentity? identity,
      ArtworkVersion? version,
      XeroxRasterPriority priority,
    })>[];
    final specIndexes = <({
      String asset,
      double scale,
      ArtworkIdentity? identity,
      ArtworkVersion? version,
    }), int>{};

    void addSpec(
      String asset,
      double artworkScale,
      ArtworkIdentity? identity,
      ArtworkVersion? version,
      XeroxRasterPriority priority,
    ) {
      final key = (
        asset: asset,
        scale: artworkScale,
        identity: identity,
        version: version,
      );
      final existingIndex = specIndexes[key];
      if (existingIndex != null) {
        final existing = specs[existingIndex];
        if (priority.index > existing.priority.index) {
          specs[existingIndex] = (
            asset: existing.asset,
            scale: existing.scale,
            identity: existing.identity,
            version: existing.version,
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
        version: version,
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
        selectedVersion,
        XeroxRasterPriority.selected,
      );
    }

    for (final cell in orderedCells) {
      final visible = cell.rect.overlaps(viewportRect);
      addSpec(
        assetAt(cell.row, cell.column),
        scale,
        identityAt?.call(cell.row, cell.column),
        versionAt?.call(cell.row, cell.column),
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
          version: spec.version,
          targetSize: Size.square(tileExtent * spec.scale),
          devicePixelRatio: devicePixelRatio,
          fit: BoxFit.cover,
        );
        final resource = await resolveArtwork(request);
        if (resource == null) continue;

        final plan = ArtworkPipeline.instance.createDisplayPlan(
          resource: resource,
          targetSize: request.targetSize!,
          devicePixelRatio: request.devicePixelRatio,
          fit: request.fit,
          priority: spec.priority,
        );
        resolved[index] = plan.xeroxRequest;
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
