// 文件职责：底部弹层的状态、布局、手势与动画引擎。

var _sheetIdCounter = 0;

/// 创建并组装所需对象或界面结构，用于底部弹层的状态、布局、手势与动画引擎。
String createBottomSheetId() {
  _sheetIdCounter += 1;
  return 'sheet-$_sheetIdCounter-${DateTime.now().millisecondsSinceEpoch}';
}

/// 执行当前模块中的debugreset底部弹层标识counter操作，用于底部弹层的状态、布局、手势与动画引擎。
void debugResetBottomSheetIdCounter() {
  _sheetIdCounter = 0;
}
