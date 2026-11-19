import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import 'xerox_raster_request.dart';
import 'xerox_shader_renderer.dart';

/// Turns an artwork provider into a reusable, opaque Xerox bitmap.
class XeroxRasterizer {
  static Future<ui.FragmentProgram>? _programFuture;

  static Future<ui.FragmentProgram> _loadProgram() =>
      _programFuture ??= ui.FragmentProgram.fromAsset('shaders/xerox.frag');

  Future<ui.Image> rasterize(XeroxRasterRequest request) async {
    final source = await _resolveSource(request);
    final program = await _loadProgram();
    final shader = program.fragmentShader();
    final recorder = ui.PictureRecorder();
    final size = ui.Size.square(request.resolution.toDouble());

    try {
      XeroxShaderRenderer.paint(
        canvas: ui.Canvas(recorder),
        size: size,
        image: source,
        shader: shader,
        fit: request.fit,
        identity: request.identity,
        config: request.config,
      );
      final picture = recorder.endRecording();
      try {
        return await picture.toImage(request.resolution, request.resolution);
      } finally {
        picture.dispose();
      }
    } finally {
      shader.dispose();
    }
  }

  Future<ui.Image> _resolveSource(XeroxRasterRequest request) async {
    final completer = Completer<ui.Image>();
    final provider = ResizeImage(
      request.image,
      width: request.resolution,
    );
    final stream = provider.resolve(
      ImageConfiguration(
        devicePixelRatio: request.devicePixelRatio,
        size: ui.Size.square(request.resolution.toDouble()),
      ),
    );
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (frame, _) {
        if (!completer.isCompleted) completer.complete(frame.image);
      },
      onError: (error, stackTrace) {
        if (!completer.isCompleted) {
          completer.completeError(error, stackTrace ?? StackTrace.current);
        }
      },
    );
    stream.addListener(listener);
    try {
      return await completer.future;
    } finally {
      stream.removeListener(listener);
    }
  }
}
