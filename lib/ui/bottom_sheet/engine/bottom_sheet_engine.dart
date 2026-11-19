// 文件职责：底部弹层的状态、布局、手势与动画引擎。

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../create_bottom_sheet_id.dart';
import '../host_layout_mode.dart';
import '../merge_layout_options.dart';
import '../resolve_options.dart';
import '../types.dart';
import 'sheet_store.dart';

/// 封装或定义dismisshandler相关类型与行为，负责底部弹层的状态、布局、手势与动画引擎。
typedef DismissHandler = void Function();

/// 封装或定义底部弹层引擎相关类型与行为，负责底部弹层的状态、布局、手势与动画引擎。
class BottomSheetEngine extends ChangeNotifier {
  BottomSheetEngine({
    this.hostMode = BottomSheetMode.presentation,
    this.sheetDefaults,
    BottomSheetLayoutOptionsPartial? layoutPartial,
    BottomSheetTheme? theme,
    required this.screenHeight,
    required this.screenWidth,
  }) : mergedLayout = mergeLayoutOptionsPartial(layoutPartial),
       mergedTheme = mergeTheme(providerTheme: theme) {
    hostSheetTopY.value = screenHeight;
    pushProgressOpenY.value = screenHeight;
  }

  BottomSheetMode hostMode;
  BottomSheetOptions? sheetDefaults;
  BottomSheetLayoutOptions mergedLayout;
  ResolvedBottomSheetTheme mergedTheme;
  double screenHeight;
  double screenWidth;

  final bottomProgress = ValueNotifier<double>(0);
  final hostSheetTopY = ValueNotifier<double>(0);
  final pushProgressOpenY = ValueNotifier<double>(0);
  final pushSheetHeight = ValueNotifier<double>(0);
  final activeHostMode = ValueNotifier<int>(HostLayoutMode.presentation);

  final sheetStore = BottomSheetSheetStore();
  final List<BottomSheetState> sheets = [];
  final Map<String, DismissHandler> dismissHandlers = {};
  final Map<String, BottomSheetControllerApi> controllers = {};
  final Map<String, RegisteredBottomSheetModal> modals = {};
  bool dismissingAll = false;

  /// 更新相关状态并同步依赖方，用于底部弹层的状态、布局、手势与动画引擎。
  void updateTheme(BottomSheetTheme? theme) {
    mergedTheme = mergeTheme(providerTheme: theme);
    notifyListeners();
  }

  /// 更新相关状态并同步依赖方，用于底部弹层的状态、布局、手势与动画引擎。
  void updateLayout(BottomSheetLayoutOptionsPartial? layoutPartial) {
    mergedLayout = mergeLayoutOptionsPartial(layoutPartial);
    notifyListeners();
  }

  /// 更新相关状态并同步依赖方，用于底部弹层的状态、布局、手势与动画引擎。
  void updateScreenSize(double height, double width) {
    screenHeight = height;
    screenWidth = width;
    if (sheets.isEmpty) {
      hostSheetTopY.value = height;
      pushProgressOpenY.value = height;
    }
  }

  /// 更新相关状态并同步依赖方，用于底部弹层的状态、布局、手势与动画引擎。
  void syncSheetStore() {
    final topSheet = sheets.isNotEmpty ? sheets.last : null;
    final drivingSheet = sheets.isNotEmpty ? sheets.first : null;
    final layoutMode = topSheet?.options.mode ?? hostMode;
    final pushDirection =
        drivingSheet?.options.pushDirection ??
        topSheet?.options.pushDirection ??
        mergedLayout.push.direction;
    activeHostMode.value = resolveHostLayoutMode(
      layoutMode,
      pushDirection: pushDirection,
    );
    sheetStore.setSnapshot(
      BottomSheetStoreSnapshot(
        isPresented: sheets.isNotEmpty,
        presentedSheetCount: sheets.length,
        topSheetId: topSheet?.id,
        topSheetController: topSheet != null ? controllers[topSheet.id] : null,
      ),
    );
  }

  /// 应用选择并更新对应状态，用于底部弹层的状态、布局、手势与动画引擎。
  void commitSheets() {
    syncSheetStore();
    notifyListeners();
  }

  /// 执行当前模块中的present操作，用于底部弹层的状态、布局、手势与动画引擎。
  String present(Widget content, [BottomSheetOptions? options]) {
    final resolved = resolveBottomSheetOptions(
      options: options,
      providerDefaults: sheetDefaults,
      providerTheme: BottomSheetTheme(
        sheetBackgroundColor: mergedTheme.sheetBackgroundColor,
        letterboxColor: mergedTheme.letterboxColor,
        hostBackgroundColor: mergedTheme.hostBackgroundColor,
        letterboxOpacity: mergedTheme.letterboxOpacity,
        handleColor: mergedTheme.handleColor,
        scrimColor: mergedTheme.scrimColor,
        modalBackdropColor: mergedTheme.modalBackdropColor,
      ),
      hostMode: hostMode,
      layoutPushDirection: mergedLayout.push.direction,
    );

    final id = options?.sheetId ?? createBottomSheetId();
    sheets.add(BottomSheetState(id: id, content: content, options: resolved));
    commitSheets();
    return id;
  }

  /// 执行当前模块中的dismiss操作，用于底部弹层的状态、布局、手势与动画引擎。
  void dismiss([String? sheetId]) {
    if (sheets.isEmpty) return;
    final top = sheets.last;
    if (sheetId != null && sheetId != top.id) {
      // 为与 React Native 版本保持一致，只允许关闭最顶层的弹层。
      return;
    }
    dismissHandlers[top.id]?.call();
  }

  /// 执行当前模块中的dismisstop操作，用于底部弹层的状态、布局、手势与动画引擎。
  void dismissTop() {
    if (sheets.isEmpty) return;
    dismissHandlers[sheets.last.id]?.call();
  }

  /// 执行当前模块中的dismissall操作，用于底部弹层的状态、布局、手势与动画引擎。
  void dismissAll() {
    if (sheets.isEmpty) return;
    dismissingAll = true;
    dismissTop();
  }

  /// 处理对应事件并协调后续状态变化，用于底部弹层的状态、布局、手势与动画引擎。
  void handleDismissComplete(String id) {
    final closing = sheets.cast<BottomSheetState?>().firstWhere(
      (s) => s?.id == id,
      orElse: () => null,
    );
    closing?.options.onDismiss?.call();

    dismissHandlers.remove(id);
    controllers.remove(id);
    sheets.removeWhere((s) => s.id == id);

    final shouldChain = dismissingAll && sheets.isNotEmpty;
    if (!shouldChain) {
      dismissingAll = false;
      if (sheets.isEmpty) {
        bottomProgress.value = 0;
        hostSheetTopY.value = screenHeight;
        pushProgressOpenY.value = screenHeight;
        pushSheetHeight.value = 0;
        activeHostMode.value = resolveHostLayoutMode(hostMode);
      }
    }

    commitSheets();

    if (shouldChain) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        dismissTop();
      });
    }
  }

  /// 处理对应事件并协调后续状态变化，用于底部弹层的状态、布局、手势与动画引擎。
  void handleDismissHandlerChange(String id, DismissHandler? handler) {
    if (handler == null) {
      dismissHandlers.remove(id);
    } else {
      dismissHandlers[id] = handler;
    }
  }

  /// 处理对应事件并协调后续状态变化，用于底部弹层的状态、布局、手势与动画引擎。
  void handleControllerReady(String id, BottomSheetControllerApi? api) {
    if (api == null) {
      controllers.remove(id);
    } else {
      controllers[id] = api;
    }
    syncSheetStore();
  }

  /// 注册或添加相关数据与监听关系，用于底部弹层的状态、布局、手势与动画引擎。
  void register(RegisteredBottomSheetModal modal) {
    modals[modal.id] = modal;
  }

  /// 移除、清理或重置相关状态与资源，用于底部弹层的状态、布局、手势与动画引擎。
  void unregister(String id) {
    modals.remove(id);
  }

  @override
  void dispose() {
    bottomProgress.dispose();
    hostSheetTopY.dispose();
    pushProgressOpenY.dispose();
    pushSheetHeight.dispose();
    activeHostMode.dispose();
    super.dispose();
  }
}

/// 封装或定义registered底部弹层模态相关类型与行为，负责底部弹层的状态、布局、手势与动画引擎。
class RegisteredBottomSheetModal {
  const RegisteredBottomSheetModal({
    required this.id,
    required this.renderContent,
    required this.options,
  });

  final String id;
  final Widget Function() renderContent;
  final ResolvedBottomSheetOptions options;
}
