import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:musaic/pages/home/xerox_artwork.dart';

ui.Image _solidImage(int width, int height, ui.Color color) {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawColor(color, ui.BlendMode.src);
  return recorder.endRecording().toImageSync(width, height);
}

ui.Image _splitImage(int width, int height, int rightValue) {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawColor(const ui.Color(0xff808080), ui.BlendMode.src);
  canvas.drawRect(
    ui.Rect.fromLTWH(width / 2, 0, width / 2, height.toDouble()),
    ui.Paint()
      ..color = ui.Color.fromARGB(255, rightValue, rightValue, rightValue),
  );
  return recorder.endRecording().toImageSync(width, height);
}

Future<Uint8List> _render(
  ui.FragmentProgram program,
  ui.Image source, {
  required String identity,
  required double grain,
  double? contrast,
  int? outputWidth,
  int? outputHeight,
}) async {
  final width = outputWidth ?? source.width;
  final height = outputHeight ?? source.height;
  final shader = program.fragmentShader()
    ..setFloat(0, source.width.toDouble())
    ..setFloat(1, source.height.toDouble())
    ..setFloat(2, 0)
    ..setFloat(3, 0)
    ..setFloat(4, source.width.toDouble())
    ..setFloat(5, source.height.toDouble())
    ..setFloat(6, 0)
    ..setFloat(7, 0)
    ..setFloat(8, width.toDouble())
    ..setFloat(9, height.toDouble())
    ..setFloat(10, xeroxSeed(identity).toDouble())
    ..setFloat(11, xeroxConfig.edge)
    ..setFloat(12, contrast ?? xeroxConfig.contrast)
    ..setFloat(13, grain)
    ..setFloat(14, xeroxConfig.invert ? 1 : 0)
    ..setImageSampler(0, source, filterQuality: ui.FilterQuality.medium);
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(
    ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    ui.Paint()..shader = shader,
  );
  final output = recorder.endRecording().toImageSync(width, height);
  final bytes = (await output.toByteData(
    format: ui.ImageByteFormat.rawStraightRgba,
  ))!.buffer.asUint8List();
  output.dispose();
  shader.dispose();
  return bytes;
}

void main() {
  test('Xerox LOD uses stable buckets with hysteresis and identity seeds', () {
    expect(xeroxConfig.edge, 0.9);
    expect(xeroxConfig.contrast, 32);
    expect(xeroxConfig.smooth, 0);
    expect(xeroxConfig.grain, 0.5);
    expect(xeroxConfig.invert, isFalse);
    expect(xeroxResolution(100), 128);
    expect(xeroxResolution(90, current: 64), 128);
    expect(xeroxResolution(90, current: 128), 128);
    expect(xeroxResolution(80, current: 128), 64);
    expect(xeroxSeed('album-cover'), xeroxSeed('album-cover'));
    expect(xeroxSeed('album-cover'), isNot(xeroxSeed('other-cover')));
  });

  testWidgets('shader thresholds, composites alpha, and applies stable grain', (
    tester,
  ) async {
    const width = 32;
    const height = 32;
    final rendered = await tester.runAsync(() async {
      final program = await ui.FragmentProgram.fromAsset('shaders/xerox.frag');
      final samples = <String, ({ui.Color color, int binary})>{
        'white': (color: const ui.Color(0xffffffff), binary: 255),
        'black': (color: const ui.Color(0xff000000), binary: 0),
        'gray': (color: const ui.Color(0xffd9d9d9), binary: 255),
        'transparent': (color: const ui.Color(0x00000000), binary: 255),
        'half-transparent black': (
          color: const ui.Color(0x80000000),
          binary: 255,
        ),
      };
      final outputs = <String, ({Uint8List binary, Uint8List noisy})>{};
      Uint8List? repeatedWhite;
      for (final entry in samples.entries) {
        final source = _solidImage(width, height, entry.value.color);
        final binary = await _render(
          program,
          source,
          identity: 'test-cover',
          grain: 0,
        );
        final noisy = await _render(
          program,
          source,
          identity: 'test-cover',
          grain: xeroxConfig.grain,
        );
        if (entry.key == 'white') {
          repeatedWhite = await _render(
            program,
            source,
            identity: 'test-cover',
            grain: xeroxConfig.grain,
          );
        }
        source.dispose();
        outputs[entry.key] = (binary: binary, noisy: noisy);
      }
      final smallTileSource = _solidImage(
        width * 2,
        height * 2,
        const ui.Color(0xffffffff),
      );
      final smallTile = await _render(
        program,
        smallTileSource,
        identity: 'small-tile',
        grain: xeroxConfig.grain,
        outputWidth: 16,
        outputHeight: 16,
      );
      smallTileSource.dispose();
      final belowThresholdImage = _splitImage(width, height, 172);
      final belowThresholdEdge = await _render(
        program,
        belowThresholdImage,
        identity: 'edge-below-threshold',
        grain: 0,
      );
      belowThresholdImage.dispose();
      final aboveThresholdImage = _splitImage(width, height, 173);
      final aboveThresholdEdge = await _render(
        program,
        aboveThresholdImage,
        identity: 'edge-above-threshold',
        grain: 0,
      );
      aboveThresholdImage.dispose();
      final translucentRed = _solidImage(
        width,
        height,
        const ui.Color(0x80ff0000),
      );
      final redAtContrast150 = await _render(
        program,
        translucentRed,
        identity: 'translucent-red',
        grain: 0,
        contrast: 150,
      );
      final redAtContrast190 = await _render(
        program,
        translucentRed,
        identity: 'translucent-red',
        grain: 0,
        contrast: 190,
      );
      translucentRed.dispose();
      return (
        outputs,
        repeatedWhite!,
        smallTile,
        belowThresholdEdge,
        aboveThresholdEdge,
        redAtContrast150,
        redAtContrast190,
      );
    });
    final (
      outputs,
      repeatedWhite,
      smallTile,
      belowThresholdEdge,
      aboveThresholdEdge,
      redAtContrast150,
      redAtContrast190,
    ) = rendered!;
    expect(outputs['white']!.noisy, repeatedWhite);

    int pixel(Uint8List image, int x, int y) => image[(y * width + x) * 4];
    for (final entry in outputs.entries) {
      final expectedBinary = entry.key == 'black' ? 0 : 255;
      final noisyValues = <int>{};
      for (var offset = 0; offset < entry.value.binary.length; offset += 4) {
        final binary = entry.value.binary[offset];
        final noisy = entry.value.noisy[offset];
        expect(binary, expectedBinary, reason: '${entry.key} threshold');
        expect(entry.value.binary[offset + 1], binary);
        expect(entry.value.binary[offset + 2], binary);
        expect(entry.value.binary[offset + 3], 255);
        expect(entry.value.noisy[offset + 1], noisy);
        expect(entry.value.noisy[offset + 2], noisy);
        expect(entry.value.noisy[offset + 3], 255);
        if (entry.key == 'black') {
          expect(noisy, inInclusiveRange(0, 38));
        } else {
          expect(noisy, inInclusiveRange(218, 255));
        }
        noisyValues.add(noisy);
      }
      expect(
        noisyValues.length,
        greaterThan(25),
        reason: '${entry.key} grain: $noisyValues',
      );
    }
    final smallTileValues = <int>{};
    for (var offset = 0; offset < smallTile.length; offset += 4) {
      final value = smallTile[offset];
      expect(value, inInclusiveRange(218, 255));
      expect(smallTile[offset + 1], value);
      expect(smallTile[offset + 2], value);
      expect(smallTile[offset + 3], 255);
      smallTileValues.add(value);
    }
    expect(smallTileValues.length, greaterThan(25));
    expect(pixel(belowThresholdEdge, 15, 16), 255);
    expect(pixel(aboveThresholdEdge, 15, 16), 0);
    expect(pixel(aboveThresholdEdge, 16, 16), 0);
    expect(pixel(aboveThresholdEdge, 0, 16), 255);
    expect(pixel(aboveThresholdEdge, width - 1, 16), 255);
    expect(pixel(redAtContrast150, 16, 16), 255);
    expect(pixel(redAtContrast190, 16, 16), 0);
  });
}
