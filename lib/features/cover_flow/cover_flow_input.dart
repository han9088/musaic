// 文件职责：Cover Flow 的几何计算、输入处理与动效。

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// 封装或定义封面流动输入相关类型与行为，负责Cover Flow 的几何计算、输入处理与动效。
class CoverFlowInput extends StatefulWidget {
  const CoverFlowInput({
    super.key,
    required this.canStartInput,
    required this.onScroll,
    required this.onScrollEnd,
    required this.onStep,
    required this.child,
  });

  final bool Function() canStartInput;
  final void Function(double delta, Duration time) onScroll;
  final VoidCallback onScrollEnd;
  final ValueChanged<int> onStep;
  final Widget child;

  @override
  State<CoverFlowInput> createState() => _CoverFlowInputState();
}

/// 封装或定义封面流动输入状态相关类型与行为，负责Cover Flow 的几何计算、输入处理与动效。
class _CoverFlowInputState extends State<CoverFlowInput> {
  FocusNode? _focus;
  Timer? _scrollEnd;
  bool _scrolling = false;

  /// 控制流程的开始、暂停、取消或结束，用于Cover Flow 的几何计算、输入处理与动效。
  void _finishScroll() {
    _scrollEnd?.cancel();
    if (!_scrolling) return;
    _scrolling = false;
    widget.onScrollEnd();
  }

  bool get _modified =>
      HardwareKeyboard.instance.isControlPressed ||
      HardwareKeyboard.instance.isMetaPressed ||
      HardwareKeyboard.instance.isAltPressed;

  void _signal(PointerSignalEvent event) {
    if ((!widget.canStartInput() && !_scrolling) ||
        _modified ||
        event is! PointerScrollEvent ||
        !event.scrollDelta.dx.isFinite ||
        event.scrollDelta.dx == 0 ||
        event.scrollDelta.dx.abs() < event.scrollDelta.dy.abs()) {
      return;
    }
    GestureBinding.instance.pointerSignalResolver.register(event, (_) {
      _scrolling = true;
      widget.onScroll(event.scrollDelta.dx, event.timeStamp);
      _scrollEnd?.cancel();
      _scrollEnd = Timer(const Duration(milliseconds: 120), _finishScroll);
    });
  }

  KeyEventResult _key(FocusNode node, KeyEvent event) {
    if ((!widget.canStartInput() && !_scrolling) ||
        _modified ||
        event is KeyUpEvent ||
        (event.logicalKey != LogicalKeyboardKey.arrowLeft &&
            event.logicalKey != LogicalKeyboardKey.arrowRight)) {
      return KeyEventResult.ignored;
    }
    _finishScroll();
    widget.onStep(event.logicalKey == LogicalKeyboardKey.arrowRight ? 1 : -1);
    return KeyEventResult.handled;
  }

  void _takeFocus() {
    _finishScroll();
    _focus?.requestFocus();
  }

  @override
  void dispose() {
    _scrollEnd?.cancel();
    _focus?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)) {
      return widget.child;
    }
    return Focus(
      focusNode: _focus ??= FocusNode(debugLabel: 'Cover Flow'),
      autofocus: true,
      onKeyEvent: _key,
      onFocusChange: (focused) {
        if (!focused) _finishScroll();
      },
      child: Listener(
        onPointerDown: (_) => _takeFocus(),
        onPointerPanZoomStart: (_) => _takeFocus(),
        onPointerSignal: _signal,
        child: widget.child,
      ),
    );
  }
}
