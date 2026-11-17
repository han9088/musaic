import 'package:material_ui/material_ui.dart';

import 'canvas_drift.dart';

/// Owns gesture-derived canvas state; the page controls whether the ticker runs.
class CanvasInteractionState {
  CanvasInteractionState(this.drift);

  final CanvasDrift drift;
  bool touching = false;
  final pressedPointers = <int>{};
  bool selectionPaused = false;

  void pointerDown(int pointer) => pressedPointers.add(pointer);
  void pointerUp(int pointer) => pressedPointers.remove(pointer);

  void interactionStart() {
    touching = true;
    drift.velocity = Offset.fromDirection(drift.velocity.direction, 12);
  }

  void interactionUpdate(ScaleUpdateDetails details) {
    if (details.pointerCount == 1 &&
        details.focalPointDelta.distance > 0.1) {
      selectionPaused = false;
      drift.velocity = Offset.fromDirection(
        details.focalPointDelta.direction,
        12,
      );
    }
  }

  void interactionEnd(ScaleEndDetails details) {
    final velocity = details.velocity.pixelsPerSecond;
    if (velocity.distance > 12) {
      drift.velocity = Offset.fromDirection(
        velocity.direction,
        velocity.distance.clamp(12.0, 2400.0),
      );
    }
    touching = false;
  }

  void resetForLayoutChange() {
    touching = false;
    pressedPointers.clear();
    selectionPaused = false;
  }
}
