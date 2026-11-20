// 文件职责：通过独立 FragmentShader 将指定原图 LOD 光栅化为 Xerox 输出位图。

import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import 'xerox_raster_request.dart';
import 'xerox_shader_renderer.dart';

class XeroxRasterizer {
  static Future<ui.FragmentProgram>? _programFuture;

  static Future<ui.FragmentProgram> _loadProgram() =>
      _programFuture ??= ui.FragmentProgram.fromAsset('shaders/xerox.frag');

  Future<ui.Image> rasterize(XeroxRasterRequest request) async {
    final source = await _resolveSource(request);
    try {
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
    } finally {
      source.dispose();
    }
  }

  /// 原图解码尺寸与 Xerox 输出尺寸独立控制。
  Future<ui.Image> _resolveSource(XeroxRasterRequest request) async {
    final decodeResolution = request.originalDecodeResolution;
    final completer = Completer<ui.Image>();
    final provider = ResizeImage(
      request.image,
      width: decodeResolution,
      height: decodeResolution,
      policy: ResizeImagePolicy.fit,
    );
    final stream = provider.resolve(
      ImageConfiguration(
        devicePixelRatio: request.devicePixelRatio,
        size: ui.Size.square(decodeResolution.toDouble()),
      ),
    );
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (frame, _) {
        ui.Image? retained;
        try {
          if (!completer.isCompleted) retained = frame.image.clone();
        } catch (error, stackTrace) {
          if (!completer.isCompleted) {
            completer.completeError(error, stackTrace);
          }
        } finally {
          frame.dispose();
        }
        if (retained != null) completer.complete(retained);
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
