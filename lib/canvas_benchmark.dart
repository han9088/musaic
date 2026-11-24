// Android benchmark entry point for comparing renderers on the same runtime.
import 'dart:async';
import 'dart:convert';
import 'dart:developer' show Timeline;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show debugPrintSynchronously;
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';

import 'app/app.dart';
import 'features/artwork/presentation/custom_artwork_menu.dart';
import 'features/canvas/album_canvas_viewport.dart';
import 'features/canvas/album_sprite_canvas.dart';
import 'storage/settings/app_language_preference.dart';

final root = GlobalKey();
final captureKey = GlobalKey();

Future<void> wait(int milliseconds) =>
    Future<void>.delayed(Duration(milliseconds: milliseconds));

void main() {
  final previousHandler = FlutterError.onError;
  FlutterError.onError = (details) {
    if (const bool.fromEnvironment('CANVAS_DIAGNOSTICS')) {
      debugPrintSynchronously('CANVAS_FRAME_ERROR ${details.exception}');
    }
    previousHandler?.call(details);
  };
  GoogleFonts.config.allowRuntimeFetching = false;
  runApp(
    RepaintBoundary(
      key: captureKey,
      child: MusaicApp(
        key: root,
        initialLanguage: AppLanguage.simplifiedChinese,
      ),
    ),
  );
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(
      benchmark().catchError((Object error, StackTrace stack) {
        debugPrintSynchronously('CANVAS_ERROR $error');
        debugPrintSynchronously('$stack');
      }),
    );
  });
}

Element findCanvas() {
  Element? result;
  void visit(Element element) {
    if (result != null) return;
    if (element.widget is AlbumCanvasViewport) {
      result = element;
    } else {
      element.visitChildElements(visit);
    }
  }

  root.currentContext!.visitChildElements(visit);
  return result ?? (throw StateError('Canvas not mounted'));
}

bool hasSprites(Element element) {
  var found = false;
  void visit(Element child) {
    if (found) return;
    if (child.widget is AlbumSpriteCanvas) {
      found = true;
    } else {
      child.visitChildElements(visit);
    }
  }

  element.visitChildElements(visit);
  return found;
}

Future<List<int>> capture() async {
  final boundary =
      captureKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: 1);
  try {
    final data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  } finally {
    image.dispose();
  }
}

Future<void> benchmark() async {
  await wait(2500);
  var element = findCanvas();
  var canvas = element.widget as AlbumCanvasViewport;
  if (canvas.xerox) throw StateError('Expected original artwork benchmark');
  const scale = .4;
  void cameraAtStart() {
    canvas.interaction.selectionPaused = true;
    canvas.transform.value = Matrix4.diagonal3Values(scale, scale, scale)
      ..setEntry(0, 3, -23.75)
      ..setEntry(1, 3, -91.125);
  }

  cameraAtStart();
  for (var retries = 0; retries < 40 && !hasSprites(element); retries++) {
    await wait(250);
    element = findCanvas();
    canvas = element.widget as AlbumCanvasViewport;
  }
  if (!hasSprites(element)) throw StateError('Batched renderer is unavailable');
  debugPrintSynchronously('CANVAS_ATLAS covers=${canvas.albums.length}');
  AlbumCanvasViewport.useWidgetGridForBenchmark = true;
  element.markNeedsBuild();
  await wait(350);
  final before = await capture();
  AlbumCanvasViewport.useWidgetGridForBenchmark = false;
  element.markNeedsBuild();
  await wait(350);
  final after = await capture();
  var error = 0;
  for (var i = 0; i < before.length; i += 4) {
    error +=
        (before[i] - after[i]).abs() +
        (before[i + 1] - after[i + 1]).abs() +
        (before[i + 2] - after[i + 2]).abs();
  }
  debugPrintSynchronously(
    'CANVAS_PIXELS meanChannelError=${error / (before.length * .75)}',
  );

  final view = View.of(element);
  final box = element.findRenderObject()! as RenderBox;
  final tap = box.localToGlobal(
    Offset(box.size.width * .48, box.size.height * .32),
  );
  final press = box.localToGlobal(
    Offset(box.size.width * .70, box.size.height * .48),
  );
  final dpr = view.devicePixelRatio;
  debugPrintSynchronously(
    'CANVAS_TAP ${(tap.dx * dpr).round()} ${(tap.dy * dpr).round()}',
  );
  for (
    var attempt = 0;
    attempt < 30 && canvas.layout.selectedAlbum == null;
    attempt++
  ) {
    await wait(100);
  }
  debugPrintSynchronously('CANVAS_TAP_RESULT ${canvas.layout.selectedAlbum}');
  debugPrintSynchronously(
    'CANVAS_LONG_PRESS ${(press.dx * dpr).round()} ${(press.dy * dpr).round()}',
  );
  for (
    var attempt = 0;
    attempt < 28 && !customArtworkMenuVisible.value;
    attempt++
  ) {
    await wait(100);
  }
  debugPrintSynchronously(
    'CANVAS_LONG_PRESS_RESULT ${customArtworkMenuVisible.value}',
  );
  if (customArtworkMenuVisible.value) {
    debugPrintSynchronously('CANVAS_CLOSE_MENU');
    for (
      var attempt = 0;
      attempt < 30 && customArtworkMenuVisible.value;
      attempt++
    ) {
      await wait(100);
    }
  }
  canvas.layout.selectedAlbum = null;
  findCanvas().markNeedsBuild();

  final frames = <ui.FrameTiming>[];
  void timings(List<ui.FrameTiming> batch) => frames.addAll(batch);
  SchedulerBinding.instance.addTimingsCallback(timings);
  const sequence = [
    'widgets',
    'sprites',
    'sprites',
    'widgets',
    'sprites',
    'widgets',
    'widgets',
    'sprites',
  ];
  for (final (run, mode) in sequence.indexed) {
    AlbumCanvasViewport.useWidgetGridForBenchmark = mode == 'widgets';
    element = findCanvas();
    canvas = element.widget as AlbumCanvasViewport;
    cameraAtStart();
    element.markNeedsBuild();
    await wait(850);
    frames.clear();

    final goingUp = run ~/ 2 % 2 == 0;
    final view = View.of(element);
    final box = element.findRenderObject()! as RenderBox;
    final start = box.localToGlobal(
      Offset(box.size.width * .56, box.size.height * (goingUp ? .72 : .29)),
    );
    final x = (start.dx * view.devicePixelRatio).round();
    final y = (start.dy * view.devicePixelRatio).round();
    final endY =
        y +
        (goingUp ? -1 : 1) *
            (box.size.height * view.devicePixelRatio * .36).round();

    const count = 8;
    final began = Completer<int>();
    final released = Completer<int>();
    var received = 0;
    void track(PointerEvent event) {
      if (event is PointerDownEvent && !began.isCompleted) {
        began.complete(Timeline.now);
      }
      if (event is PointerUpEvent && ++received == count) {
        released.complete(Timeline.now);
      }
    }

    GestureBinding.instance.pointerRouter.addGlobalRoute(track);
    debugPrintSynchronously('CANVAS_STROKES $x $y $endY $count');
    try {
      await released.future.timeout(const Duration(seconds: 14));
    } finally {
      GestureBinding.instance.pointerRouter.removeGlobalRoute(track);
    }
    final lastFingerUp = await released.future;
    final firstFingerDown = await began.future;
    await wait(2280);
    canvas.interaction.selectionPaused = true;
    await wait(1050);
    frames.sort((a, b) => a.frameNumber.compareTo(b.frameNumber));
    double budget = 1000000 / view.display.refreshRate;
    for (final (phase, start, end) in [
      ('continuous', firstFingerDown, lastFingerUp),
      ('inertia', lastFingerUp, lastFingerUp + 830000),
      ('drift', lastFingerUp + 1030000, lastFingerUp + 2230000),
    ]) {
      final sample = frames.where((f) {
        final t = f.timestampInMicroseconds(ui.FramePhase.vsyncStart);
        return t >= start && t <= end;
      }).toList();
      if (sample.length < 2) continue;
      final uiTimes = sample.map((f) => f.buildDuration.inMicroseconds).toList()
        ..sort();
      final gpuTimes =
          sample.map((f) => f.rasterDuration.inMicroseconds).toList()..sort();
      final gaps = [
        for (var i = 1; i < sample.length; i++)
          sample[i].timestampInMicroseconds(ui.FramePhase.vsyncStart) -
              sample[i - 1].timestampInMicroseconds(ui.FramePhase.vsyncStart),
      ]..sort();
      debugPrintSynchronously(
        'CANVAS_RESULT ${jsonEncode({'run': run, 'mode': mode, 'phase': phase, 'hz': view.display.refreshRate, 'frames': sample.length, 'duration': end - start, 'uiP50': uiTimes[uiTimes.length ~/ 2], 'uiP95': uiTimes[(uiTimes.length * .95).floor()], 'gpuP50': gpuTimes[gpuTimes.length ~/ 2], 'gpuP95': gpuTimes[(gpuTimes.length * .95).floor()], 'gaps': gaps.where((t) => t > budget * 1.5).length, 'gapP95': gaps[(gaps.length * .95).floor()], 'gapMax': gaps.last})}',
      );
    }
  }
  SchedulerBinding.instance.removeTimingsCallback(timings);
  debugPrintSynchronously('CANVAS_DONE');
}
