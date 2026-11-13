import 'dart:typed_data';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musaic/ui/widgets/natural_rainbow.dart';

Future<void> _show(
  WidgetTester tester,
  NaturalRainbow rainbow, {
  bool reduceMotion = false,
}) async {
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
        data: MediaQueryData(disableAnimations: reduceMotion),
        child: Center(child: SizedBox(width: 400, height: 300, child: rainbow)),
      ),
    ),
  );
}

CustomPainter _painter(WidgetTester tester) =>
    tester.widget<CustomPaint>(find.byType(CustomPaint)).painter!;

Future<Uint8List> _render(WidgetTester tester, {Color? background}) async =>
    (await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      if (background != null) canvas.drawColor(background, BlendMode.src);
      _painter(tester).paint(canvas, const Size(400, 300));
      final picture = recorder.endRecording();
      final image = await picture.toImage(400, 300);
      final data = await image.toByteData(
        format: ui.ImageByteFormat.rawStraightRgba,
      );
      final bytes = Uint8List.fromList(data!.buffer.asUint8List());
      image.dispose();
      picture.dispose();
      return bytes;
    }))!;

List<int> _pixel(Uint8List bytes, int x, int y) =>
    bytes.sublist((y * 400 + x) * 4, (y * 400 + x) * 4 + 4);

int _light(Uint8List bytes) {
  var total = 0;
  for (var i = 3; i < bytes.length; i += 4) {
    total += bytes[i];
  }
  return total;
}

void main() {
  testWidgets(
    'spectrum is transparent, continuous, red outside and violet inside',
    (tester) async {
      await _show(tester, const NaturalRainbow(autoPlay: false));
      final transparent = await _render(tester);
      expect(_pixel(transparent, 0, 0)[3], 0);
      expect(_pixel(transparent, 200, 290)[3], 0);
      final alphas = [
        for (var y = 70; y < 195; y++) _pixel(transparent, 200, y)[3],
      ];
      final peak = alphas.reduce((a, b) => a > b ? a : b);
      expect(peak, inExclusiveRange(180, 235));
      expect(alphas.first, lessThan(peak ~/ 5));
      expect(alphas.last, lessThan(peak ~/ 5));
      final colors = {
        for (var y = 103; y < 160; y++)
          _pixel(transparent, 200, y).take(3).join(','),
      };
      expect(colors.length, greaterThan(35));
      final outer = _pixel(transparent, 200, 105);
      final inner = _pixel(transparent, 200, 160);
      expect(outer[0], greaterThan(outer[2]));
      expect(inner[2], greaterThan(inner[1]));
      // Equal radii at the apex and on the flank must retain equal light.
      expect(
        _pixel(transparent, 200, 130)[3],
        closeTo(_pixel(transparent, 302, 164)[3], 3),
      );
      expect(alphas.where((alpha) => alpha > 60).length, greaterThan(55));

      for (final background in [
        const Color(0xFFFFFFFF),
        const Color(0xFF17232E),
      ]) {
        final composite = await _render(tester, background: background);
        expect(
          _pixel(composite, 200, 130),
          isNot([
            background.r * 255,
            background.g * 255,
            background.b * 255,
            255,
          ]),
        );
        expect(_pixel(composite, 0, 0), [
          (background.r * 255).round(),
          (background.g * 255).round(),
          (background.b * 255).round(),
          255,
        ]);
      }
    },
  );

  testWidgets('outer rim fades smoothly to transparent', (tester) async {
    await _show(
      tester,
      const NaturalRainbow(
        autoPlay: false,
        glowIntensity: 0,
        radius: 170,
        thickness: 60,
      ),
    );
    final pixels = await _render(tester);
    final outerFade = [
      for (var y = 105; y >= 60; y--) _pixel(pixels, 200, y)[3],
    ];
    for (var i = 1; i < outerFade.length; i++) {
      expect(outerFade[i], lessThanOrEqualTo(outerFade[i - 1]));
      if (i >= outerFade.length - 10) {
        expect(outerFade[i - 1] - outerFade[i], lessThanOrEqualTo(2));
      }
    }
    expect(_pixel(pixels, 200, 75)[3], lessThan(8));
    expect(outerFade.last, 0);
  });

  testWidgets(
    'erasing clears the right side first and leaves the left intact',
    (tester) async {
      final erased = ValueNotifier(0.0);
      addTearDown(erased.dispose);
      await _show(tester, NaturalRainbow(autoPlay: false, eraseAngle: erased));
      final painter = _painter(tester);
      final full = await _render(tester);
      expect(_pixel(full, 368, 290)[3], greaterThan(0));
      expect(_pixel(full, 31, 290)[3], greaterThan(0));

      erased.value = math.pi / 2;
      await tester.pump();
      final half = await _render(tester);
      expect(_pixel(half, 368, 290)[3], 0);
      // Cached 8-bit vertex colors may round one channel differently from a shader.
      expect(
        _pixel(half, 31, 290),
        pairwiseCompare<int, int>(
          _pixel(full, 31, 290),
          (actual, expected) => (actual - expected).abs() <= 2,
          'same spectrum within 8-bit rounding',
        ),
      );
      expect(_light(half), inExclusiveRange(0, _light(full)));
      expect(identical(painter, _painter(tester)), isTrue);

      erased.value = math.pi;
      await tester.pump();
      expect(_light(await _render(tester)), 0);
      erased.value = 0;
      await tester.pump();
      expect(_light(await _render(tester)), _light(full));
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('visible sweep grows continuously into the complete spectrum', (
    tester,
  ) async {
    final sweep = ValueNotifier(0.0);
    addTearDown(sweep.dispose);
    await _show(tester, NaturalRainbow(autoPlay: false, sweepAngle: sweep));
    var previous = _light(await _render(tester));
    expect(previous, 0);
    for (final progress in [0.25, 0.5, 0.75, 0.999]) {
      sweep.value = math.pi * progress;
      await tester.pump();
      final light = _light(await _render(tester));
      expect(light, greaterThan(previous));
      previous = light;
    }
    sweep.value = math.pi;
    await tester.pump();
    final full = _light(await _render(tester));
    expect(previous / full, closeTo(1, 0.02));
  });

  testWidgets('inner hues lead both entry and disappearance', (tester) async {
    final sweep = ValueNotifier(math.pi / 2);
    final erased = ValueNotifier(0.0);
    addTearDown(sweep.dispose);
    addTearDown(erased.dispose);
    await _show(
      tester,
      NaturalRainbow(autoPlay: false, sweepAngle: sweep, eraseAngle: erased),
    );
    final painter = _painter(tester);
    final entering = await _render(tester);
    expect(_pixel(entering, 200, 155)[3], greaterThan(20));
    expect(_pixel(entering, 200, 105)[3], 0);

    sweep.value = math.pi;
    await tester.pump();
    final full = await _render(tester);
    expect(_pixel(full, 200, 105)[3], greaterThan(20));
    erased.value = math.pi / 2;
    await tester.pump();
    final exiting = await _render(tester);
    expect(_pixel(exiting, 200, 155)[3], 0);
    expect(_pixel(exiting, 200, 105), _pixel(full, 200, 105));
    expect(identical(painter, _painter(tester)), isTrue);

    erased.value = math.pi;
    await tester.pump();
    expect(_light(await _render(tester)), 0);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'manual progress forms and dissipates light; geometry and intensity are controllable',
    (tester) async {
      await _show(tester, const NaturalRainbow(autoPlay: false, progress: 0));
      expect(_light(await _render(tester)), 0);
      await _show(tester, const NaturalRainbow(autoPlay: false, progress: 0.5));
      final half = _light(await _render(tester));
      await _show(tester, const NaturalRainbow(autoPlay: false));
      final full = _light(await _render(tester));
      expect(half, inExclusiveRange(0, full));
      await _show(tester, const NaturalRainbow(autoPlay: false, progress: 0));
      expect(_light(await _render(tester)), 0);
      await _show(tester, const NaturalRainbow(autoPlay: false, intensity: 0));
      expect(_light(await _render(tester)), 0);
      await _show(
        tester,
        const NaturalRainbow(autoPlay: false, radius: 100, thickness: 12),
      );
      final smaller = await _render(tester);
      expect(_pixel(smaller, 200, 110)[3], 0);
      expect(_pixel(smaller, 200, 200)[3], greaterThan(0));
    },
  );

  testWidgets(
    'automatic cycle fades, rests and disappears without rebuilding; reduced motion stops it',
    (tester) async {
      const rainbow = NaturalRainbow(duration: Duration(seconds: 8));
      await _show(tester, rainbow);
      final originalPainter = _painter(tester);
      expect(_light(await _render(tester)), 0);
      await tester.pump(const Duration(seconds: 2));
      final formed = _light(await _render(tester));
      expect(formed, greaterThan(0));
      await tester.pump(const Duration(seconds: 2));
      final stable = _light(await _render(tester));
      expect(stable, closeTo(formed, formed * 0.05));
      expect(identical(originalPainter, _painter(tester)), isTrue);
      await tester.pump(const Duration(seconds: 3));
      expect(_light(await _render(tester)), lessThan(formed ~/ 2));
      await tester.pump(const Duration(seconds: 1));
      expect(_light(await _render(tester)), 0);
      await tester.pump(const Duration(seconds: 2));
      expect(_light(await _render(tester)), greaterThan(0));
      await _show(tester, rainbow, reduceMotion: true);
      final reduced = _light(await _render(tester));
      await tester.pump(const Duration(seconds: 3));
      expect(_light(await _render(tester)), reduced);
      expect(tester.binding.hasScheduledFrame, isFalse);
    },
  );
}
