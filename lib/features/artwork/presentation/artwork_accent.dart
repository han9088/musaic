import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

typedef ArtworkAccentBuilder = Widget Function(
  BuildContext context,
  Widget artwork,
  Color? accent,
);

/// Samples a small thumbnail from the same decoded image used by the cover.
class ArtworkAccent extends StatefulWidget {
  const ArtworkAccent({
    super.key,
    required this.sourceKey,
    required this.image,
    required this.size,
    required this.builder,
    required this.child,
  });

  final String? sourceKey;
  final ImageProvider<Object>? image;
  final Size? size;
  final ArtworkAccentBuilder builder;
  final Widget child;

  @override
  State<ArtworkAccent> createState() => _ArtworkAccentState();
}

class _ArtworkAccentState extends State<ArtworkAccent> {
  static const _cacheCapacity = 64;
  static final _sampleCache = <String, Future<Color?>>{};

  ImageStream? _stream;
  Future<Color?>? _sample;
  late final _listener = ImageStreamListener(
    _onImage,
    onError: (_, _) => _stopListening(),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_sample == null) _resolve();
  }

  @override
  void didUpdateWidget(ArtworkAccent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sourceKey != widget.sourceKey ||
        (_sample == null && oldWidget.image != widget.image)) {
      _resolve();
    }
  }

  void _resolve() {
    _stopListening();
    final key = widget.sourceKey;
    final provider = widget.image;
    _sample = key == null ? null : _sampleCache[key];
    if (_sample != null || provider == null || key == null) return;
    final stream = provider.resolve(
      createLocalImageConfiguration(context, size: widget.size),
    );
    _stream = stream;
    stream.addListener(_listener);
  }

  void _stopListening() {
    _stream?.removeListener(_listener);
    _stream = null;
  }

  void _onImage(ImageInfo info, bool synchronousCall) {
    _stopListening();
    final key = widget.sourceKey!;
    final existing = _sampleCache.remove(key);
    final sample =
        existing ?? readArtworkAccent(info.image).whenComplete(info.dispose);
    if (existing != null) info.dispose();
    _sampleCache[key] = sample;
    if (_sampleCache.length > _cacheCapacity) {
      _sampleCache.remove(_sampleCache.keys.first);
    }
    if (synchronousCall) {
      _sample = sample;
    } else {
      setState(() {
        _sample = sample;
      });
    }
  }

  @override
  void dispose() {
    _stopListening();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Color?>(
    future: _sample,
    builder: (context, snapshot) => widget.builder(
      context,
      widget.child,
      snapshot.connectionState == ConnectionState.done ? snapshot.data : null,
    ),
  );
}

Future<Color?> readArtworkAccent(ui.Image image) async {
  const side = 24;
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawImageRect(
    image,
    Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
    Rect.fromLTWH(0, 0, side.toDouble(), side.toDouble()),
    ui.Paint()..filterQuality = ui.FilterQuality.medium,
  );
  final picture = recorder.endRecording();
  ui.Image? thumbnail;
  try {
    thumbnail = await picture.toImage(side, side);
    final pixels = await thumbnail.toByteData(
      format: ui.ImageByteFormat.rawStraightRgba,
    );
    if (pixels == null) return null;

    // Group shades by hue so a large area with highlights and shadows still
    // counts as one prominent color.
    final hues = List.generate(12, (_) => _HueSample());
    for (var index = 0; index < pixels.lengthInBytes; index += 4) {
      if (pixels.getUint8(index + 3) < 224) continue;
      final color = Color.fromARGB(
        255,
        pixels.getUint8(index),
        pixels.getUint8(index + 1),
        pixels.getUint8(index + 2),
      );
      final hsl = HSLColor.fromColor(color);
      if (hsl.saturation < 0.18 ||
          hsl.lightness < 0.07 ||
          hsl.lightness > 0.93) {
        continue;
      }
      final bucket = (hsl.hue / 30).round() % hues.length;
      hues[bucket].add(color, 0.35 + hsl.saturation * 0.65);
    }
    final dominant = hues.reduce((a, b) => a.weight >= b.weight ? a : b);
    return dominant.weight == 0 ? const Color(0xffbfbfbf) : dominant.color;
  } catch (_) {
    return null;
  } finally {
    thumbnail?.dispose();
    picture.dispose();
  }
}

class _HueSample {
  double weight = 0;
  double _red = 0;
  double _green = 0;
  double _blue = 0;

  void add(Color color, double amount) {
    weight += amount;
    _red += color.r * amount;
    _green += color.g * amount;
    _blue += color.b * amount;
  }

  Color get color => Color.from(
    alpha: 1,
    red: _red / weight,
    green: _green / weight,
    blue: _blue / weight,
  );
}
