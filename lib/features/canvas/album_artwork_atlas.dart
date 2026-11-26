// Packs a small catalog into a single texture for the album canvas.
import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter/widgets.dart' show Matrix4;

import '../../services/music/directory_music_library.dart';
import '../artwork/presentation/artwork_accent.dart';
import '../artwork/model/artwork_request.dart';
import '../artwork/pipeline/artwork_pipeline.dart';
import 'album_grid_snapshot.dart';

class CanvasArtworkAtlas {
  CanvasArtworkAtlas._(this.image, this.sources);

  final ui.Image image;
  final Map<Object, Rect> sources;
  static const maxCovers = 32;

  final _paint = Paint()..filterQuality = FilterQuality.medium;
  var _transforms = Float32List(2048);
  var _rects = Float32List(2048);
  var _length = 0;

  static Future<CanvasArtworkAtlas?> load({
    required List<({Object album, ArtworkRequest request})> covers,
    required DirectoryMusicLibrary? directories,
    required ImageConfiguration configuration,
    required bool Function() isCurrent,
    void Function(Object album, Color accent)? onAccent,
  }) async {
    final images = <Object, ui.Image>{};
    final pipeline = ArtworkPipeline.instance;
    try {
      for (final (:album, :request) in covers) {
        if (!isCurrent()) return null;
        final resource = await pipeline.resolve(
          request,
          directories: directories,
        );
        if (resource == null || !isCurrent()) {
          return null;
        }
        const extent = albumCanvasArtworkResolution;
        final provider = ResizeImage(
          resource.image,
          width: extent,
          height: extent,
          policy: ResizeImagePolicy.fit,
        );
        final image = await _readImage(provider, configuration);
        images[album] = image;
        if (onAccent != null) {
          final accent = await readArtworkAccent(image);
          if (accent != null && isCurrent()) onAccent(album, accent);
        }
        if (image.width != albumCanvasArtworkResolution ||
            image.height != albumCanvasArtworkResolution) {
          return null;
        }
      }
      if (!isCurrent()) return null;
      return await pack(images);
    } finally {
      for (final image in images.values) {
        image.dispose();
      }
    }
  }

  static Future<ui.Image> _readImage(
    ImageProvider<Object> provider,
    ImageConfiguration configuration,
  ) async {
    final stream = provider.resolve(configuration);
    final resolved = Completer<ui.Image>();
    final listener = ImageStreamListener(
      (info, _) {
        if (!resolved.isCompleted) resolved.complete(info.image.clone());
        info.dispose();
      },
      onError: (error, stack) {
        if (!resolved.isCompleted) resolved.completeError(error, stack);
      },
    );
    stream.addListener(listener);
    try {
      return await resolved.future.timeout(const Duration(seconds: 4));
    } finally {
      stream.removeListener(listener);
    }
  }

  static Future<CanvasArtworkAtlas> pack(Map<Object, ui.Image> images) async {
    const extent = albumCanvasArtworkResolution;
    const padding = 4;
    const stride = extent + padding * 2;
    final columns = images.length.clamp(1, 8);
    final rows = (images.length + columns - 1) ~/ columns;
    final size = Size(
      (columns * stride).toDouble(),
      (rows * stride).toDouble(),
    );
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Offset.zero & size);
    final sources = <Object, Rect>{};
    final matrix = Matrix4.identity().storage;
    var index = 0;
    for (final item in images.entries) {
      final image = item.value;
      if (image.width != extent || image.height != extent) continue;
      final x = (index % columns) * stride + padding;
      final y = (index ~/ columns) * stride + padding;
      final origin = Offset(x.toDouble(), y.toDouble());
      final rect = origin & Size.square(extent.toDouble());
      sources[item.key] = rect;
      canvas.save();
      canvas.translate(origin.dx, origin.dy);
      final shader = ui.ImageShader(
        image,
        TileMode.clamp,
        TileMode.clamp,
        matrix,
      );
      canvas.drawRect(
        Rect.fromLTWH(
          -padding.toDouble(),
          -padding.toDouble(),
          stride.toDouble(),
          stride.toDouble(),
        ),
        Paint()..shader = shader,
      );
      canvas.restore();
      shader.dispose();
      index++;
    }
    final picture = recorder.endRecording();
    try {
      return CanvasArtworkAtlas._(
        await picture.toImage(size.width.toInt(), size.height.toInt()),
        sources,
      );
    } finally {
      picture.dispose();
    }
  }

  bool contains(Object album) => sources.containsKey(album);

  void begin() => _length = 0;

  bool add(Object album, Offset offset) {
    final rect = sources[album];
    if (rect == null) return false;
    if (_length == _transforms.length) {
      _transforms = Float32List(_length * 2)..setAll(0, _transforms);
      _rects = Float32List(_length * 2)..setAll(0, _rects);
    }
    const scale = albumGridExtent / albumCanvasArtworkResolution;
    _transforms[_length] = scale;
    _transforms[_length + 1] = 0;
    _transforms[_length + 2] = offset.dx;
    _transforms[_length + 3] = offset.dy;
    _rects[_length] = rect.left;
    _rects[_length + 1] = rect.top;
    _rects[_length + 2] = rect.right;
    _rects[_length + 3] = rect.bottom;
    _length += 4;
    return true;
  }

  void draw(Canvas canvas) {
    if (_length == 0) return;
    canvas.drawRawAtlas(
      image,
      Float32List.sublistView(_transforms, 0, _length),
      Float32List.sublistView(_rects, 0, _length),
      null,
      null,
      null,
      _paint,
    );
  }

  void dispose() => image.dispose();
}
