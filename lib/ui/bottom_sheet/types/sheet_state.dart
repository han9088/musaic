// 文件职责：底部弹层的状态、布局、手势与动画引擎。

part of '../types.dart';

/// 封装或定义底部弹层状态相关类型与行为，负责底部弹层的状态、布局、手势与动画引擎。
class BottomSheetState {
  const BottomSheetState({
    required this.id,
    required this.content,
    required this.options,
  });

  final String id;
  final Widget content;
  final ResolvedBottomSheetOptions options;
}
