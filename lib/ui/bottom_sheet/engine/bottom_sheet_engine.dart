import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../create_bottom_sheet_id.dart';
import '../host_layout_mode.dart';
import '../merge_layout_options.dart';
import '../resolve_options.dart';
import '../types.dart';
import 'sheet_store.dart';

typedef DismissHandler = void Function();

/// Global sheet engine — stack, shared animation values, present/dismiss.
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

  void updateTheme(BottomSheetTheme? theme) {
    mergedTheme = mergeTheme(providerTheme: theme);
    notifyListeners();
  }

  void updateLayout(BottomSheetLayoutOptionsPartial? layoutPartial) {
    mergedLayout = mergeLayoutOptionsPartial(layoutPartial);
    notifyListeners();
  }

  void updateScreenSize(double height, double width) {
    screenHeight = height;
    screenWidth = width;
    if (sheets.isEmpty) {
      hostSheetTopY.value = height;
      pushProgressOpenY.value = height;
    }
  }

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

  void commitSheets() {
    syncSheetStore();
    notifyListeners();
  }

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

  void dismiss([String? sheetId]) {
    if (sheets.isEmpty) return;
    final top = sheets.last;
    if (sheetId != null && sheetId != top.id) {
      // Can only dismiss top sheet (RN parity).
      return;
    }
    dismissHandlers[top.id]?.call();
  }

  void dismissTop() {
    if (sheets.isEmpty) return;
    dismissHandlers[sheets.last.id]?.call();
  }

  void dismissAll() {
    if (sheets.isEmpty) return;
    dismissingAll = true;
    dismissTop();
  }

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

  void handleDismissHandlerChange(String id, DismissHandler? handler) {
    if (handler == null) {
      dismissHandlers.remove(id);
    } else {
      dismissHandlers[id] = handler;
    }
  }

  void handleControllerReady(String id, BottomSheetControllerApi? api) {
    if (api == null) {
      controllers.remove(id);
    } else {
      controllers[id] = api;
    }
    syncSheetStore();
  }

  void register(RegisteredBottomSheetModal modal) {
    modals[modal.id] = modal;
  }

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
