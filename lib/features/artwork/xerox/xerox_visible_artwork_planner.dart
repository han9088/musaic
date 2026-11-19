// 文件职责：专辑封面来源解析、图片解码、缓存及 Xerox 处理。

import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../canvas/album_grid_snapshot.dart';
import 'xerox_raster_request.dart';
import 'xerox_resolution.dart';

/// 封装或定义Xeroxvisible专辑封面规划器相关类型与行为，负责专辑封面来源解析、图片解码、缓存及 Xerox 处理。
class XeroxVisibleArtworkPlanner {
  const XeroxVisibleArtworkPlanner({this.maxProviderConcurrency = 4})
    : assert(maxProviderConcurrency > 0);

  final int maxProviderConcurrency;

  /// 构建并返回当前组件的界面，用于专辑封面来源解析、图片解码、缓存及 Xerox 处理。
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
    bool Function()? isActive,
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

    // 当前选中的专辑视觉权重更高，应优先于其他可视项准备。
    if (selectedAsset != null) addSpec(selectedAsset, scale * selectedScale);
    for (final cell in orderedCells) {
      addSpec(assetAt(cell.row, cell.column), scale);
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
