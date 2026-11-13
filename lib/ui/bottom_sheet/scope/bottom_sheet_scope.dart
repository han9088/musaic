import 'package:flutter/widgets.dart';

import '../controller/bottom_sheet_controller.dart';
import '../engine/bottom_sheet_engine.dart';
import '../types.dart';

class BottomSheetScope extends InheritedWidget {
  const BottomSheetScope({
    super.key,
    required this.engine,
    required super.child,
  });

  final BottomSheetEngine engine;

  static BottomSheetEngine of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<BottomSheetScope>();
    assert(scope != null, 'BottomSheetProvider not found in context');
    return scope!.engine;
  }

  static BottomSheetEngine? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<BottomSheetScope>()
        ?.engine;
  }

  @override
  bool updateShouldNotify(BottomSheetScope oldWidget) =>
      engine != oldWidget.engine;
}

/// Public API mirroring RN `useBottomSheet()`.
class DeskBottomSheet {
  DeskBottomSheet._(this._engine);
  final BottomSheetEngine _engine;

  static DeskBottomSheet of(BuildContext context) =>
      DeskBottomSheet._(BottomSheetScope.of(context));

  BottomSheetMode get mode => _engine.hostMode;

  String present(Widget content, [BottomSheetOptions? options]) =>
      _engine.present(content, options);

  void dismiss([String? sheetId]) => _engine.dismiss(sheetId);

  void dismissAll() => _engine.dismissAll();

  bool get isPresented => _engine.sheetStore.snapshot.isPresented;

  int get presentedSheetCount =>
      _engine.sheetStore.snapshot.presentedSheetCount;

  String? get topSheetId => _engine.sheetStore.snapshot.topSheetId;

  BottomSheetControllerApi? get topSheetController =>
      _engine.sheetStore.snapshot.topSheetController;
}

class BottomSheetContentScope extends InheritedWidget {
  const BottomSheetContentScope({
    super.key,
    required this.controller,
    required this.bottomInset,
    required super.child,
  });

  final SheetController controller;
  final double bottomInset;

  static BottomSheetContentScope of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<BottomSheetContentScope>();
    assert(scope != null, 'Not inside a bottom sheet');
    return scope!;
  }

  static BottomSheetContentScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<BottomSheetContentScope>();

  @override
  bool updateShouldNotify(BottomSheetContentScope oldWidget) =>
      controller != oldWidget.controller ||
      bottomInset != oldWidget.bottomInset;
}

/// Public API mirroring RN `useBottomSheetContent()`.
class BottomSheetContent {
  BottomSheetContent._(this._scope);
  final BottomSheetContentScope _scope;

  static BottomSheetContent of(BuildContext context) =>
      BottomSheetContent._(BottomSheetContentScope.of(context));

  static BottomSheetContent? maybeOf(BuildContext context) {
    final scope = BottomSheetContentScope.maybeOf(context);
    if (scope == null) return null;
    return BottomSheetContent._(scope);
  }

  ValueNotifier<double> get animatedIndex => _scope.controller.animatedIndex;
  ValueNotifier<double> get animatedPosition =>
      _scope.controller.sheetTranslateY;
  ValueNotifier<double> get scrollOffset => _scope.controller.scrollOffset;

  void snapToIndex(int index) => _scope.controller.snapToIndex(index);
  void close() => _scope.controller.close();
  void expand() => _scope.controller.expand();
  void collapse() => _scope.controller.collapse();

  bool get enableContentPanningGesture =>
      _scope.controller.options.enableContentPanningGesture;
  bool get enableDynamicSizing => _scope.controller.options.enableDynamicSizing;
  double get handleHeight => _scope.controller.handleHeight;
  double get bottomInset => _scope.bottomInset;

  void onContentLayout(double height) =>
      _scope.controller.onContentLayout(height);
}
