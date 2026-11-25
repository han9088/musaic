// 文件职责：底部弹层的状态、布局、手势与动画引擎。

part of '../types.dart';

/// 封装或定义底部弹层控制器api相关类型与行为，负责底部弹层的状态、布局、手势与动画引擎。
abstract class BottomSheetControllerApi {
  /// 执行当前模块中的close操作，用于底部弹层的状态、布局、手势与动画引擎。
  void close();

  /// 执行当前模块中的snaptoindex操作，用于底部弹层的状态、布局、手势与动画引擎。
  void snapToIndex(int index);

  /// 执行当前模块中的snapto位置操作，用于底部弹层的状态、布局、手势与动画引擎。
  void snapToPosition(double position);

  /// 执行当前模块中的expand操作，用于底部弹层的状态、布局、手势与动画引擎。
  void expand();

  /// 执行当前模块中的collapse操作，用于底部弹层的状态、布局、手势与动画引擎。
  void collapse();
}

/// 封装或定义底部弹层模态控制器相关类型与行为，负责底部弹层的状态、布局、手势与动画引擎。
abstract class BottomSheetModalController extends BottomSheetControllerApi {
  /// 执行当前模块中的present操作，用于底部弹层的状态、布局、手势与动画引擎。
  void present();

  /// 执行当前模块中的dismiss操作，用于底部弹层的状态、布局、手势与动画引擎。
  void dismiss();

  /// 执行当前模块中的forceclose操作，用于底部弹层的状态、布局、手势与动画引擎。
  void forceClose();

  /// 执行当前模块中的dismissall操作，用于底部弹层的状态、布局、手势与动画引擎。
  void dismissAll();
}
