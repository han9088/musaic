// 文件职责：把 ArtworkRequest 转换为 Pipeline 资源，再交给纯渲染组件。

import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../../../services/music/directory_music_library.dart';
import '../model/artwork_request.dart';
import '../model/artwork_resource.dart';
import '../pipeline/artwork_pipeline.dart';
import '../pipeline/xerox_raster_resource.dart';
import '../xerox/xerox_raster_request.dart';
import 'artwork_renderer.dart';
import 'directory_artwork.dart';

/// 负责资源请求与展示之间的生命周期，不直接接触下载器或缓存实现。
class ArtworkSourceView extends StatefulWidget {
  const ArtworkSourceView({
    super.key,
    required this.request,
    required this.placeholder,
    this.width,
    this.height,
    this.fit,
    this.filterQuality = FilterQuality.medium,
    this.semanticLabel,
    this.excludeFromSemantics = false,
    this.xerox = false,
    this.scale = 1,
    this.pipeline,
  });

  final ArtworkRequest request;
  final Widget placeholder;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final FilterQuality filterQuality;
  final String? semanticLabel;
  final bool excludeFromSemantics;
  final bool xerox;
  final double scale;
  final ArtworkPipeline? pipeline;

  @override
  State<ArtworkSourceView> createState() => _ArtworkSourceViewState();
}

class _ArtworkSourceViewState extends State<ArtworkSourceView> {
  ArtworkPipeline get _pipeline => widget.pipeline ?? ArtworkPipeline.instance;

  DirectoryMusicLibrary? _directories;
  int _directoryRevision = -1;
  int _resourceRevision = 0;
  Future<ArtworkResource?>? _resourceFuture;
  int? _originalDecodeResolution;
  int? _xeroxResolution;
  XeroxRasterKey? _lastBackgroundKey;

  void _resolve() {
    _resourceRevision++;
    _originalDecodeResolution = null;
    _xeroxResolution = null;
    _lastBackgroundKey = null;
    _resourceFuture = _pipeline.resolve(
      widget.request,
      directories: _directories,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = DirectoryArtworkScope.watch(context);
    final directoryChanged = scope.library != _directories ||
        scope.revision != _directoryRevision;
    final usesDirectorySource = widget.request.source.startsWith('directory:');

    _directories = scope.library;
    _directoryRevision = scope.revision;
    if (_resourceFuture == null ||
        (usesDirectorySource && directoryChanged)) {
      _resolve();
    }
  }

  @override
  void didUpdateWidget(ArtworkSourceView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.request != widget.request ||
        oldWidget.pipeline != widget.pipeline) {
      _resolve();
    } else if (oldWidget.xerox != widget.xerox) {
      _lastBackgroundKey = null;
    }
  }

  void _scheduleBackgroundXerox(ArtworkDisplayPlan plan) {
    if (widget.xerox || _lastBackgroundKey == plan.xeroxRequest.key) return;

    final key = plan.xeroxRequest.key;
    _lastBackgroundKey = key;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.xerox || _lastBackgroundKey != key) return;
      _pipeline.prepareXerox(plan);
    });
  }

  Widget _render(
    ArtworkResource resource,
    ArtworkDisplayPlan plan, {
    ui.Image? processedImage,
  }) => ArtworkRenderer(
    resource: resource,
    plan: plan,
    width: widget.width,
    height: widget.height,
    fit: widget.fit,
    filterQuality: widget.filterQuality,
    semanticLabel: widget.semanticLabel,
    excludeFromSemantics: widget.excludeFromSemantics,
    xerox: widget.xerox,
    placeholder: widget.placeholder,
    processedImage: processedImage,
  );

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = widget.width ?? constraints.maxWidth;
      final height = widget.height ?? constraints.maxHeight;
      final extent = width.isFinite && height.isFinite
          ? (width > height ? width : height)
          : width.isFinite
          ? width
          : height.isFinite
          ? height
          : 100.0;
      final targetSize = Size.square(extent > 0 ? extent : 100);
      final dpr = MediaQuery.devicePixelRatioOf(context);

      return FutureBuilder<ArtworkResource?>(
        key: ValueKey(_resourceRevision),
        future: _resourceFuture,
        builder: (context, snapshot) {
          final resource = snapshot.data;
          if (resource == null) return widget.placeholder;

          final plan = _pipeline.createDisplayPlan(
            resource: resource,
            targetSize: targetSize,
            devicePixelRatio: dpr,
            scale: widget.scale,
            fit: widget.fit ?? BoxFit.scaleDown,
            currentOriginalDecodeResolution: _originalDecodeResolution,
            currentXeroxResolution: _xeroxResolution,
            priority: widget.xerox
                ? XeroxRasterPriority.visible
                : XeroxRasterPriority.background,
          );
          _originalDecodeResolution = plan.originalDecodeResolution;
          _xeroxResolution = plan.xeroxRequest.resolution;
          _scheduleBackgroundXerox(plan);

          if (!widget.xerox) return _render(resource, plan);

          return XeroxRasterResource(
            request: plan.xeroxRequest,
            pipeline: _pipeline,
            builder: (image, _) => _render(
              resource,
              plan,
              processedImage: image,
            ),
          );
        },
      );
    },
  );
}
