// 文件职责：底部弹层的状态、布局、手势与动画引擎。

import 'package:flutter/widgets.dart';

import '../controller/bottom_sheet_controller.dart';
import '../engine/bottom_sheet_engine.dart';
import '../types.dart';

/// 封装或定义底部弹层作用域相关类型与行为，负责底部弹层的状态、布局、手势与动画引擎。
class BottomSheetScope extends InheritedWidget {
  const BottomSheetScope({
    super.key,
    required this.engine,
    required super.child,
  });

  final BottomSheetEngine engine;

  /// 执行当前模块中的of操作，用于底部弹层的状态、布局、手势与动画引擎。
  static BottomSheetEngine of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<BottomSheetScope>();
    assert(scope != null, 'BottomSheetProvider not found in context');
    return scope!.engine;
  }

  /// 执行当前模块中的maybeof操作，用于底部弹层的状态、布局、手势与动画引擎。
  static BottomSheetEngine? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<BottomSheetScope>()
        ?.engine;
  }

  @override
  bool updateShouldNotify(BottomSheetScope oldWidget) =>
      engine != oldWidget.engine;
}

/// 封装或定义desk底部弹层相关类型与行为，负责底部弹层的状态、布局、手势与动画引擎。
class DeskBottomSheet {
  DeskBottomSheet._(this._engine);
  final BottomSheetEngine _engine;

  /// 执行当前模块中的of操作，用于底部弹层的状态、布局、手势与动画引擎。
  static DeskBottomSheet of(BuildContext context) =>
      DeskBottomSheet._(BottomSheetScope.of(context));

  /// 执行当前模块中的模式操作，用于底部弹层的状态、布局、手势与动画引擎。
  BottomSheetMode get mode => _engine.hostMode;

  /// 执行当前模块中的present操作，用于底部弹层的状态、布局、手势与动画引擎。
  String present(Widget content, [BottomSheetOptions? options]) =>
      _engine.present(content, options);

  /// 执行当前模块中的dismiss操作，用于底部弹层的状态、布局、手势与动画引擎。
  void dismiss([String? sheetId]) => _engine.dismiss(sheetId);

  /// 执行当前模块中的dismissall操作，用于底部弹层的状态、布局、手势与动画引擎。
  void dismissAll() => _engine.dismissAll();

  /// 判断当前状态是否满足指定条件，用于底部弹层的状态、布局、手势与动画引擎。
  bool get isPresented => _engine.sheetStore.snapshot.isPresented;

  /// 执行当前模块中的presented弹层count操作，用于底部弹层的状态、布局、手势与动画引擎。
  int get presentedSheetCount =>
      _engine.sheetStore.snapshot.presentedSheetCount;

  /// 执行当前模块中的top弹层标识操作，用于底部弹层的状态、布局、手势与动画引擎。
  String? get topSheetId => _engine.sheetStore.snapshot.topSheetId;

  /// 执行当前模块中的top弹层控制器操作，用于底部弹层的状态、布局、手势与动画引擎。
  BottomSheetControllerApi? get topSheetController =>
      _engine.sheetStore.snapshot.topSheetController;
}

/// 封装或定义底部弹层内容作用域相关类型与行为，负责底部弹层的状态、布局、手势与动画引擎。
class BottomSheetContentScope extends InheritedWidget {
  const BottomSheetContentScope({
    super.key,
    required this.controller,
    required this.bottomInset,
    required super.child,
  });

  final SheetController controller;
  final double bottomInset;

  /// 执行当前模块中的of操作，用于底部弹层的状态、布局、手势与动画引擎。
  static BottomSheetContentScope of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<BottomSheetContentScope>();
    assert(scope != null, 'Not inside a bottom sheet');
    return scope!;
  }

  /// 执行当前模块中的maybeof操作，用于底部弹层的状态、布局、手势与动画引擎。
  static BottomSheetContentScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<BottomSheetContentScope>();

  @override
  bool updateShouldNotify(BottomSheetContentScope oldWidget) =>
      controller != oldWidget.controller ||
      bottomInset != oldWidget.bottomInset;
}

/// 封装或定义底部弹层内容相关类型与行为，负责底部弹层的状态、布局、手势与动画引擎。
class BottomSheetContent {
  BottomSheetContent._(this._scope);
  final BottomSheetContentScope _scope;

  /// 执行当前模块中的of操作，用于底部弹层的状态、布局、手势与动画引擎。
  static BottomSheetContent of(BuildContext context) =>
      BottomSheetContent._(BottomSheetContentScope.of(context));

  /// 执行当前模块中的maybeof操作，用于底部弹层的状态、布局、手势与动画引擎。
  static BottomSheetContent? maybeOf(BuildContext context) {
    final scope = BottomSheetContentScope.maybeOf(context);
    if (scope == null) return null;
    return BottomSheetContent._(scope);
  }

  /// 协调动画进度与状态过渡，用于底部弹层的状态、布局、手势与动画引擎。
  ValueNotifier<double> get animatedIndex => _scope.controller.animatedIndex;

  /// 协调动画进度与状态过渡，用于底部弹层的状态、布局、手势与动画引擎。
  ValueNotifier<double> get animatedPosition =>
      _scope.controller.sheetTranslateY;
  VoidCallback slideOutForRoute(
    Animation<double> progress, {
    required double distance,
  }) => _scope.controller.slideOutForRoute(progress, distance: distance);

  /// 执行当前模块中的scrolloffset操作，用于底部弹层的状态、布局、手势与动画引擎。
  ValueNotifier<double> get scrollOffset => _scope.controller.scrollOffset;

  /// 执行当前模块中的snaptoindex操作，用于底部弹层的状态、布局、手势与动画引擎。
  void snapToIndex(int index) => _scope.controller.snapToIndex(index);

  /// 执行当前模块中的close操作，用于底部弹层的状态、布局、手势与动画引擎。
  void close() => _scope.controller.close();

  /// 执行当前模块中的expand操作，用于底部弹层的状态、布局、手势与动画引擎。
  void expand() => _scope.controller.expand();

  /// 执行当前模块中的collapse操作，用于底部弹层的状态、布局、手势与动画引擎。
  void collapse() => _scope.controller.collapse();

  /// 执行当前模块中的enable内容panninggesture操作，用于底部弹层的状态、布局、手势与动画引擎。
  bool get enableContentPanningGesture =>
      _scope.controller.options.enableContentPanningGesture;

  /// 执行当前模块中的enabledynamicsizing操作，用于底部弹层的状态、布局、手势与动画引擎。
  bool get enableDynamicSizing => _scope.controller.options.enableDynamicSizing;

  /// 处理对应事件并协调后续状态变化，用于底部弹层的状态、布局、手势与动画引擎。
  double get handleHeight => _scope.controller.handleHeight;

  /// 执行当前模块中的底部inset操作，用于底部弹层的状态、布局、手势与动画引擎。
  double get bottomInset => _scope.bottomInset;

  /// 处理对应事件并协调后续状态变化，用于底部弹层的状态、布局、手势与动画引擎。
  void onContentLayout(double height) =>
      _scope.controller.onContentLayout(height);
}
