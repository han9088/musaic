// 文件职责：专辑墙无限画布的布局、视口与交互状态。

import 'package:material_ui/material_ui.dart';

import 'canvas_drift.dart';

/// 封装或定义画布交互状态相关类型与行为，负责专辑墙无限画布的布局、视口与交互状态。
class CanvasInteractionState {
  CanvasInteractionState(this.drift);

  final CanvasDrift drift;
  bool touching = false;
  final pressedPointers = <int>{};
  bool selectionPaused = false;

  /// 执行当前模块中的pointerdown操作，用于专辑墙无限画布的布局、视口与交互状态。
  void pointerDown(int pointer) {
    pressedPointers.add(pointer);
  }

  /// 执行当前模块中的pointerup操作，用于专辑墙无限画布的布局、视口与交互状态。
  void pointerUp(int pointer) {
    pressedPointers.remove(pointer);
  }

  /// 执行当前模块中的交互start操作，用于专辑墙无限画布的布局、视口与交互状态。
  void interactionStart() {
    touching = true;
    drift.velocity = Offset.fromDirection(drift.velocity.direction, 12);
  }

  /// 执行当前模块中的交互update操作，用于专辑墙无限画布的布局、视口与交互状态。
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

  /// 执行当前模块中的交互end操作，用于专辑墙无限画布的布局、视口与交互状态。
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

  /// 移除、清理或重置相关状态与资源，用于专辑墙无限画布的布局、视口与交互状态。
  void resetForLayoutChange() {
    touching = false;
    pressedPointers.clear();
    selectionPaused = false;
  }
}
