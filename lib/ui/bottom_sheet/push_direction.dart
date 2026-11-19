// 文件职责：底部弹层的状态、布局、手势与动画引擎。

import 'types.dart';

/// 封装或定义推动方向js相关类型与行为，负责底部弹层的状态、布局、手势与动画引擎。
abstract final class PushDirectionJs {
  static const int bottom = 0;
  static const int top = 1;
}

/// 执行当前模块中的推动方向tojs操作，用于底部弹层的状态、布局、手势与动画引擎。
int pushDirectionToJs(PushDirection direction) => direction == PushDirection.top
    ? PushDirectionJs.top
    : PushDirectionJs.bottom;

/// 判断当前状态是否满足指定条件，用于底部弹层的状态、布局、手势与动画引擎。
bool isTopPushDirection(PushDirection direction) =>
    direction == PushDirection.top;

/// 判断当前状态是否满足指定条件，用于底部弹层的状态、布局、手势与动画引擎。
bool isTopPushDirectionJs(int direction) => direction == PushDirectionJs.top;
