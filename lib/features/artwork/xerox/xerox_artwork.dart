import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'xerox_config.dart';
import 'xerox_resolution.dart';
import 'xerox_seed.dart';

export 'xerox_config.dart';
export 'xerox_resolution.dart';
export 'xerox_seed.dart';

part 'xerox_painter.dart';

class XeroxArtwork extends StatefulWidget {
  const XeroxArtwork({
    super.key,
    required this.identity,
    required this.image,
    this.width,
    this.height,
    this.fit,
    this.filterQuality = FilterQuality.medium,
    this.semanticLabel,
    this.excludeFromSemantics = false,
    this.scale = 1,
    this.errorBuilder,
  });

  final String identity;
  final ImageProvider<Object> image;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final FilterQuality filterQuality;
  final String? semanticLabel;
  final bool excludeFromSemantics;
  final double scale;
  final ImageErrorWidgetBuilder? errorBuilder;

  @override
  State<XeroxArtwork> createState() => _XeroxArtworkState();
}

class _XeroxArtworkState extends State<XeroxArtwork> {
  static Future<ui.FragmentProgram?>? _programFuture;

  ui.FragmentProgram? _program;
  ui.FragmentShader? _shader;
  ui.Image? _image;
  ImageStream? _stream;
  ImageStreamListener? _listener;
  int _resolution = 0;
  int _generation = 0;
  bool _resolveScheduled = false;

  static Future<ui.FragmentProgram?> _loadProgram() =>
      _programFuture ??= ui.FragmentProgram.fromAsset('shaders/xerox.frag')
          .then(
            (program) => program,
            onError: (Object error, StackTrace stack) {
              debugPrint('Xerox shader unavailable: $error');
              return null;
            },
          );

  @override
  void initState() {
    super.initState();
    unawaited(
      _loadProgram().then((program) {
        if (mounted) setState(() => _program = program);
      }),
    );
  }

  @override
  void didUpdateWidget(XeroxArtwork oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.identity != widget.identity ||
        oldWidget.image != widget.image) {
      _unbindImage();
      _image = null;
      _scheduleResolve();
    }
  }

  void _unbindImage() {
    _generation++;
    final stream = _stream;
    final listener = _listener;
    if (stream != null && listener != null) stream.removeListener(listener);
    _stream = null;
    _listener = null;
  }

  void _scheduleResolve() {
    if (_resolveScheduled) return;
    _resolveScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _resolveScheduled = false;
      if (mounted) _resolveImage();
    });
  }

  void _resolveImage() {
    _unbindImage();
    final generation = _generation;
    final provider = ResizeImage(widget.image, width: _resolution);
    final stream = provider.resolve(
      createLocalImageConfiguration(
        context,
        size: Size(
          widget.width ?? _resolution.toDouble(),
          widget.height ?? _resolution.toDouble(),
        ),
      ),
    );
    final listener = ImageStreamListener(
      (frame, _) {
        if (!mounted || generation != _generation) return;
        setState(() => _image = frame.image);
      },
      onError: (error, stackTrace) {
        if (!mounted || generation != _generation) return;
        setState(() => _image = null);
      },
    );
    _stream = stream;
    _listener = listener;
    stream.addListener(listener);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scheduleResolve();
  }

  @override
  void dispose() {
    _unbindImage();
    _shader?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = widget.width ?? constraints.maxWidth;
      final height = widget.height ?? constraints.maxHeight;
      final extent = math.max(
        width.isFinite ? width : 0,
        height.isFinite ? height : 0,
      );
      final requestedResolution = xeroxResolution(
        extent * widget.scale * MediaQuery.devicePixelRatioOf(context),
        current: _resolution == 0 ? null : _resolution,
      );
      if (_resolution != requestedResolution) {
        _resolution = requestedResolution;
        _unbindImage();
        _image = null;
        _scheduleResolve();
      }
      final program = _program;
      if (program != null) _shader ??= program.fragmentShader();
      final provider = ResizeImage(widget.image, width: requestedResolution);
      final isXeroxReady = _image != null && _shader != null;
      return RepaintBoundary(
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            // Keep the original image laid out and subscribed, but avoid
            // drawing it underneath the fully opaque Xerox output.
            Opacity(
              opacity: isXeroxReady ? 0 : 1,
              alwaysIncludeSemantics: true,
              child: Image(
                image: provider,
                width: widget.width,
                height: widget.height,
                fit: widget.fit,
                filterQuality: widget.filterQuality,
                semanticLabel: widget.semanticLabel,
                excludeFromSemantics: widget.excludeFromSemantics,
                errorBuilder: widget.errorBuilder,
              ),
            ),
            if (isXeroxReady)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _XeroxPainter(
                      image: _image!,
                      shader: _shader!,
                      fit: widget.fit ?? BoxFit.scaleDown,
                      identity: widget.identity,
                      config: xeroxConfig,
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );
}

