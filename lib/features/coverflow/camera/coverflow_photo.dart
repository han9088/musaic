import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

/// Match the preview's center crop, then paint the screen's transparent overlay.
/// The caller owns the returned image.
Future<ui.Image> composeCoverFlowPhoto({
  required Uint8List cameraBytes,
  required ui.Size previewSize,
  required ui.Image overlay,
}) async {
  final codec = await ui.instantiateImageCodec(cameraBytes);
  ui.Image? camera;
  ui.Picture? picture;
  try {
    camera = (await codec.getNextFrame()).image;
    final cameraSize = ui.Size(
      camera.width.toDouble(),
      camera.height.toDouble(),
    );
    final outputSize = ui.Size(
      overlay.width.toDouble(),
      overlay.height.toDouble(),
    );
    final previewCrop = Alignment.center.inscribe(
      applyBoxFit(BoxFit.cover, cameraSize, previewSize).source,
      ui.Offset.zero & cameraSize,
    );
    final screenCrop = Alignment.center.inscribe(
      applyBoxFit(BoxFit.cover, previewCrop.size, outputSize).source,
      previewCrop,
    );
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder)
      ..drawImageRect(
        camera,
        screenCrop,
        ui.Offset.zero & outputSize,
        ui.Paint()..filterQuality = ui.FilterQuality.medium,
      )
      ..drawImage(overlay, ui.Offset.zero, ui.Paint());
    picture = recorder.endRecording();
    return await picture.toImage(overlay.width, overlay.height);
  } finally {
    picture?.dispose();
    camera?.dispose();
    codec.dispose();
  }
}
