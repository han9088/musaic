// 文件职责：专辑封面来源解析、图片解码、缓存及 Xerox 处理。

import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import 'xerox_raster_request.dart';
import 'xerox_shader_renderer.dart';

/// 封装或定义Xerox光栅化器相关类型与行为，负责专辑封面来源解析、图片解码、缓存及 Xerox 处理。
class XeroxRasterizer {
  static Future<ui.FragmentProgram>? _programFuture;

  /// 读取并恢复所需数据或资源，用于专辑封面来源解析、图片解码、缓存及 Xerox 处理。
  static Future<ui.FragmentProgram> _loadProgram() =>
      _programFuture ??= ui.FragmentProgram.fromAsset('shaders/xerox.frag');

  /// 执行当前模块中的rasterize操作，用于专辑封面来源解析、图片解码、缓存及 Xerox 处理。
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
      // 解码得到的源图片句柄与 ImageCache 持有的句柄相互独立。
      source.dispose();
    }
  }

  /// 解析输入并转换为内部数据，用于专辑封面来源解析、图片解码、缓存及 Xerox 处理。
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
        // ImageStream 监听器拥有回调收到的 ImageInfo；异步光栅化期间需要
        // 保留单独的图片句柄，避免 GPU 处理完成前源图片资源被释放。
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
