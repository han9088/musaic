// 文件职责：统一协调 Artwork 资源解析、LOD 规划、缓存请求与 Xerox 后台预处理。

import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../../../services/music/directory_music_library.dart';
import '../../../storage/music/custom_artwork_store.dart';
import '../model/artwork_identity.dart';
import '../model/artwork_request.dart';
import '../model/artwork_resource.dart';
import '../source/artwork_resolver.dart';
import '../xerox/xerox_raster_cache.dart';
import '../xerox/xerox_raster_request.dart';
import 'artwork_lod_manager.dart';
import 'xerox_background_processor.dart';

/// Pipeline 为渲染层提供的显示计划。
///
/// 资源解析和处理请求在进入渲染层之前已经完成；Renderer 不需要知道来源类型或缓存实现。
class ArtworkDisplayPlan {
  const ArtworkDisplayPlan({
    required this.originalDecodeResolution,
    required this.xeroxRequest,
  });

  final int originalDecodeResolution;
  final XeroxRasterRequest xeroxRequest;
}

class ArtworkResourceLease {
  ArtworkResourceLease._(this.future, {this._release, this.isMissing = false});

  final Future<ArtworkResource?> future;

  /// A previous display request confirmed there is no artwork for this source.
  final bool isMissing;
  VoidCallback? _release;

  void release() {
    _release?.call();
    _release = null;
  }
}

class _DisplayedArtwork {
  _DisplayedArtwork(Future<ArtworkResource?> resolution) {
    pending = resolution.then(
      (value) {
        completed = true;
        return resource = value;
      },
      onError: (Object error, StackTrace stack) {
        completed = true;
        failed = true;
        Error.throwWithStackTrace(error, stack);
      },
    );
  }

  late final Future<ArtworkResource?> pending;
  ArtworkResource? resource;
  bool completed = false;
  bool failed = false;
  int references = 0;
}

typedef _DisplayKey = (
  String,
  ArtworkIdentity?,
  ArtworkVersion?,
  DirectoryMusicLibrary?,
  int,
  int?,
  int?,
);

/// Artwork 的唯一资源协调入口。
///
/// Source Resolver 负责得到原图资源；LOD Manager 负责选档；缓存请求和后台处理
/// 由 Pipeline 统一转发。具体缓存实现仍由各自模块负责。
class ArtworkPipeline {
  ArtworkPipeline({
    this._resolver = const ArtworkResolver(),
    this._lodManager = ArtworkLodManager.instance,
    this._customArtwork,
    XeroxRasterCache? rasterCache,
    XeroxBackgroundProcessor? backgroundProcessor,
  }) : _rasterCache = rasterCache ?? XeroxRasterCache.instance,
       _backgroundProcessor = _createBackgroundProcessor(
         rasterCache,
         backgroundProcessor,
       );

  static final instance = ArtworkPipeline(
    customArtwork: CustomArtworkStore.instance,
  );

  final ArtworkResolver _resolver;
  final CustomArtworkStore? _customArtwork;
  int? customArtworkRevision(ArtworkRequest request) =>
      _customArtwork?.revisionOf(request.customArtworkKey);

  final ArtworkLodManager _lodManager;
  final XeroxRasterCache _rasterCache;
  final XeroxBackgroundProcessor _backgroundProcessor;
  final Map<String, Future<ArtworkResource?>> _resolving = {};
  final _displayed = <_DisplayKey, _DisplayedArtwork>{};

  _DisplayKey _displayKey(
    ArtworkRequest request,
    DirectoryMusicLibrary? directories,
    int directoryRevision,
  ) => (
    request.source,
    request.identity,
    request.version,
    directories,
    directoryRevision,
    request.sourceResolution,
    customArtworkRevision(request),
  );

  /// Borrows an already resolved display resource without requesting artwork.
  ({ArtworkResource resource, VoidCallback release})? tryBorrowDisplayed(
    ArtworkRequest request, {
    required DirectoryMusicLibrary? directories,
    required int directoryRevision,
  }) {
    final key = _displayKey(request, directories, directoryRevision);
    final entry = _displayed[key];
    final resource = entry?.resource;
    if (entry == null || resource == null) return null;
    return (resource: resource, release: _retainDisplayed(key, entry));
  }

  VoidCallback _retainDisplayed(_DisplayKey key, _DisplayedArtwork entry) {
    entry.references++;
    return () {
      if (--entry.references == 0 && identical(_displayed[key], entry)) {
        _displayed.remove(key);
      }
    };
  }

  /// Share the resolved source across layouts with different decode sizes.
  ArtworkResourceLease acquireForDisplay(
    ArtworkRequest request, {
    required DirectoryMusicLibrary? directories,
    required int directoryRevision,
  }) {
    final key = _displayKey(request, directories, directoryRevision);
    // Repeated canvas tiles share a confirmed absence until the last tile leaves.
    final reuseMissing = request.source.startsWith('media-store:');
    var entry = _displayed[key];
    if (entry == null ||
        entry.failed ||
        (entry.completed && entry.resource == null && !reuseMissing)) {
      entry = _DisplayedArtwork(resolve(request, directories: directories));
      if (entry.completed && entry.resource == null && !reuseMissing) {
        return ArtworkResourceLease._(entry.pending);
      }
      _displayed[key] = entry;
    }
    final displayed = entry;
    return ArtworkResourceLease._(
      !displayed.completed ||
              displayed.failed ||
              displayed.pending is SynchronousFuture<ArtworkResource?>
          ? displayed.pending
          : SynchronousFuture(displayed.resource),
      release: _retainDisplayed(key, displayed),
      isMissing:
          reuseMissing &&
          displayed.completed &&
          !displayed.failed &&
          displayed.resource == null,
    );
  }

  static XeroxBackgroundProcessor _createBackgroundProcessor(
    XeroxRasterCache? cache,
    XeroxBackgroundProcessor? processor,
  ) {
    if (processor != null) return processor;
    if (cache == null) return XeroxBackgroundProcessor.instance;
    return XeroxBackgroundProcessor(cache: cache);
  }

  /// 合并同一来源的并发解析请求，避免网格、预加载和模式切换重复查找同一文件。
  Future<ArtworkResource?> resolve(
    ArtworkRequest request, {
    required DirectoryMusicLibrary? directories,
  }) {
    final customRevision = customArtworkRevision(request);
    final key = jsonEncode([
      request.source,
      request.identity?.value,
      request.version?.value,
      identityHashCode(directories),
      request.sourceResolution,
      customRevision,
    ]);
    final existing = _resolving[key];
    if (existing != null) return existing;

    final resolution = customRevision == null
        ? _resolver.resolveRequest(request, directories: directories)
        : _resolveCustomArtwork(request, customRevision, directories);
    // Assets can paint on the first frame when their decoded image is cached.
    if (resolution is SynchronousFuture<ArtworkResource?>) return resolution;

    late final Future<ArtworkResource?> pending;
    pending = resolution.whenComplete(() {
      if (identical(_resolving[key], pending)) _resolving.remove(key);
    });
    _resolving[key] = pending;
    return pending;
  }

  Future<ArtworkResource?> _resolveCustomArtwork(
    ArtworkRequest request,
    int revision,
    DirectoryMusicLibrary? directories,
  ) async {
    final key = request.customArtworkKey;
    final bytes = await _customArtwork!.read(key, revision);
    if (bytes == null) {
      return _resolver.resolveRequest(request, directories: directories);
    }
    return ArtworkResource(
      identity: key,
      sourceKey: jsonEncode(['custom', key, revision]),
      image: MemoryImage(bytes),
    );
  }

  /// 根据目标物理尺寸生成原图解码和 Xerox 输出请求。
  ///
  /// LOD 仅决定资源规格；缓存是否命中、是否需要重新处理由对应缓存负责。
  ArtworkDisplayPlan createDisplayPlan({
    required ArtworkResource resource,
    required Size targetSize,
    required double devicePixelRatio,
    double scale = 1,
    BoxFit fit = BoxFit.cover,
    int? currentOriginalDecodeResolution,
    int? currentXeroxResolution,
    int? fixedResolution,
    XeroxRasterPriority priority = XeroxRasterPriority.background,
  }) {
    final extent = math.max(targetSize.width, targetSize.height).toDouble();
    final physicalExtent = extent * scale * devicePixelRatio;
    final lod = fixedResolution == null
        ? _lodManager.select(
            physicalExtent,
            currentOriginalDecodeResolution: currentOriginalDecodeResolution,
            currentXeroxResolution: currentXeroxResolution,
          )
        : ArtworkLodSelection(
            originalDecodeResolution: fixedResolution,
            xeroxResolution: fixedResolution,
          );
    return ArtworkDisplayPlan(
      originalDecodeResolution: lod.originalDecodeResolution,
      xeroxRequest: XeroxRasterRequest(
        identity: resource.identity,
        sourceKey: resource.sourceKey,
        image: resource.image,
        originalDecodeResolution: lod.originalDecodeResolution,
        resolution: lod.xeroxResolution,
        fit: fit,
        devicePixelRatio: devicePixelRatio,
        priority: priority,
      ),
    );
  }

  /// 显示时可借用同一封面的其他解码档位，直到目标位图准备好。
  XeroxRasterLease? tryAcquireXerox(XeroxRasterRequest request) => _rasterCache
      .tryAcquireBest(request, allowDifferentDecodeResolution: true);

  /// 请求 Xerox 结果。exactOnly 用于已有同封面低分辨率 Lease 时继续生成目标档位。
  XeroxRasterTask requestXerox(
    XeroxRasterRequest request, {
    bool exactOnly = false,
  }) => exactOnly
      ? _rasterCache.request(request)
      : _rasterCache.requestBest(request);

  /// 普通模式显示原图时，可在后台提前生成 Xerox 结果。
  void prepareXerox(ArtworkDisplayPlan plan) {
    _backgroundProcessor.enqueue(plan.xeroxRequest);
  }
}
