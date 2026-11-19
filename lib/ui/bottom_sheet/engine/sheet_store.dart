// 文件职责：底部弹层的状态、布局、手势与动画引擎。

import '../types.dart';

/// 封装或定义底部弹层存储snapshot相关类型与行为，负责底部弹层的状态、布局、手势与动画引擎。
class BottomSheetStoreSnapshot {
  const BottomSheetStoreSnapshot({
    required this.isPresented,
    required this.presentedSheetCount,
    required this.topSheetId,
    this.topSheetController,
  });

  final bool isPresented;
  final int presentedSheetCount;
  final String? topSheetId;
  final BottomSheetControllerApi? topSheetController;

  static const empty = BottomSheetStoreSnapshot(
    isPresented: false,
    presentedSheetCount: 0,
    topSheetId: null,
  );
}

/// 封装或定义底部弹层弹层存储相关类型与行为，负责底部弹层的状态、布局、手势与动画引擎。
class BottomSheetSheetStore {
  BottomSheetStoreSnapshot _snapshot = BottomSheetStoreSnapshot.empty;
  final List<void Function()> _listeners = [];

  /// 执行当前模块中的snapshot操作，用于底部弹层的状态、布局、手势与动画引擎。
  BottomSheetStoreSnapshot get snapshot => _snapshot;

  /// 应用选择并更新对应状态，用于底部弹层的状态、布局、手势与动画引擎。
  void setSnapshot(BottomSheetStoreSnapshot next) {
    _snapshot = next;
    for (final listener in List.of(_listeners)) {
      listener();
    }
  }

  /// 注册或添加相关数据与监听关系，用于底部弹层的状态、布局、手势与动画引擎。
  void addListener(void Function() listener) => _listeners.add(listener);

  /// 移除、清理或重置相关状态与资源，用于底部弹层的状态、布局、手势与动画引擎。
  void removeListener(void Function() listener) => _listeners.remove(listener);
}
