// 文件职责：底部弹层的状态、布局、手势与动画引擎。

import 'push_direction.dart';
import 'types.dart';

/// 封装或定义宿主布局模式相关类型与行为，负责底部弹层的状态、布局、手势与动画引擎。
abstract final class HostLayoutMode {
  static const int modal = 0;
  static const int presentation = 1;
  static const int pushBottom = 2;
  static const int pushTop = 3;
}

/// 解析输入并转换为内部数据，用于底部弹层的状态、布局、手势与动画引擎。
int resolveHostLayoutMode(
  BottomSheetMode mode, {
  PushDirection pushDirection = PushDirection.bottom,
}) {
  if (mode == BottomSheetMode.push) {
    return pushDirection == PushDirection.top
        ? HostLayoutMode.pushTop
        : HostLayoutMode.pushBottom;
  }
  switch (mode) {
    case BottomSheetMode.modal:
      return HostLayoutMode.modal;
    case BottomSheetMode.presentation:
      return HostLayoutMode.presentation;
    case BottomSheetMode.push:
      return HostLayoutMode.pushBottom;
  }
}

/// 执行当前模块中的推动方向jsto宿主布局模式操作，用于底部弹层的状态、布局、手势与动画引擎。
int pushDirectionJsToHostLayoutMode(int direction) =>
    direction == PushDirectionJs.top
    ? HostLayoutMode.pushTop
    : HostLayoutMode.pushBottom;
