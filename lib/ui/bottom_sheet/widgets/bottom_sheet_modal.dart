import 'package:material_ui/material_ui.dart';

import '../scope/bottom_sheet_scope.dart';
import '../types.dart';

/// Declarative bottom sheet — mount once, open via [controller].
class BottomSheetModal extends StatefulWidget {
  const BottomSheetModal({
    super.key,
    required this.controller,
    required this.child,
    this.sheetId,
    this.mode,
    this.pushDirection,
    this.snapPoints,
    this.index,
    this.enableDynamicSizing,
    this.enablePanDownToClose,
    this.dismissOnScrimPress,
    this.scrimColor,
    this.enableContentPanningGesture,
    this.keyboardBehavior,
    this.showHandle,
    this.onDismiss,
    this.onChange,
    this.onAnimate,
    this.theme,
    this.accessibilityLabel,
  });

  final BottomSheetModalControllerImpl controller;
  final Widget child;
  final String? sheetId;
  final BottomSheetMode? mode;
  final PushDirection? pushDirection;
  final List<BottomSheetDetent>? snapPoints;
  final int? index;
  final bool? enableDynamicSizing;
  final bool? enablePanDownToClose;
  final bool? dismissOnScrimPress;
  final Color? scrimColor;
  final bool? enableContentPanningGesture;
  final BottomSheetKeyboardBehavior? keyboardBehavior;
  final bool? showHandle;
  final VoidCallback? onDismiss;
  final ValueChanged<int>? onChange;
  final void Function(int fromIndex, int toIndex)? onAnimate;
  final BottomSheetTheme? theme;
  final String? accessibilityLabel;

  @override
  State<BottomSheetModal> createState() => _BottomSheetModalState();
}

class _BottomSheetModalState extends State<BottomSheetModal> {
  late final String _id;
  String? _presentedId;

  @override
  void initState() {
    super.initState();
    _id = widget.sheetId ?? 'modal-${identityHashCode(this)}';
    widget.controller._attach(this);
  }

  @override
  void dispose() {
    widget.controller._detach(this);
    super.dispose();
  }

  BottomSheetOptions get _options => BottomSheetOptions(
    mode: widget.mode,
    pushDirection: widget.pushDirection,
    snapPoints: widget.snapPoints,
    index: widget.index,
    enableDynamicSizing: widget.enableDynamicSizing,
    enablePanDownToClose: widget.enablePanDownToClose,
    dismissOnScrimPress: widget.dismissOnScrimPress,
    scrimColor: widget.scrimColor,
    enableContentPanningGesture: widget.enableContentPanningGesture,
    keyboardBehavior: widget.keyboardBehavior,
    showHandle: widget.showHandle,
    onDismiss: () {
      _presentedId = null;
      widget.onDismiss?.call();
    },
    onChange: widget.onChange,
    onAnimate: widget.onAnimate,
    theme: widget.theme,
    accessibilityLabel: widget.accessibilityLabel,
    sheetId: _id,
  );

  void present() {
    final engine = BottomSheetScope.of(context);
    if (_presentedId != null) return;
    _presentedId = engine.present(widget.child, _options);
  }

  void dismiss() {
    if (_presentedId == null) return;
    BottomSheetScope.of(context).dismiss(_presentedId);
  }

  void forceClose() {
    if (_presentedId == null) return;
    final engine = BottomSheetScope.of(context);
    engine.handleDismissComplete(_presentedId!);
    _presentedId = null;
  }

  void dismissAll() => BottomSheetScope.of(context).dismissAll();

  BottomSheetControllerApi? get _topController {
    final snap = BottomSheetScope.of(context).sheetStore.snapshot;
    if (snap.topSheetId == _presentedId) return snap.topSheetController;
    return null;
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class BottomSheetModalControllerImpl extends BottomSheetModalController {
  _BottomSheetModalState? _state;

  void _attach(_BottomSheetModalState state) => _state = state;
  void _detach(_BottomSheetModalState state) {
    if (_state == state) _state = null;
  }

  @override
  void present() => _state?.present();

  @override
  void dismiss() => _state?.dismiss();

  @override
  void forceClose() => _state?.forceClose();

  @override
  void dismissAll() => _state?.dismissAll();

  @override
  void close() {
    final api = _state?._topController;
    if (api != null) {
      api.close();
    } else {
      dismiss();
    }
  }

  @override
  void snapToIndex(int index) => _state?._topController?.snapToIndex(index);

  @override
  void snapToPosition(double position) =>
      _state?._topController?.snapToPosition(position);

  @override
  void expand() => _state?._topController?.expand();

  @override
  void collapse() => _state?._topController?.collapse();
}
