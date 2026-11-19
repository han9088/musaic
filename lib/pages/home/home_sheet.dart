// 文件职责：页面状态组织与业务流程协调。

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../ui/bottom_sheet/bottom_sheet.dart';
import '../../services/app_icon_service.dart';
import '../../features/settings/app_icon_picker.dart';
import '../../features/settings/fullscreen_control.dart';
import '../../features/music/presentation/music_source_picker.dart';
import '../../services/music/music_source_controller.dart';

/// 封装或定义首页弹层相关类型与行为，负责页面状态组织与业务流程协调。
class HomeSheet extends StatefulWidget {
  const HomeSheet({
    super.key,
    required this.child,
    this.icons = const AppIconService(),
    this.enabled = true,
    this.sources,
    this.sourceSwitching,
    this.onSourceSelection,
    this.xeroxEnabled = false,
    this.onXeroxChanged,
  });

  final Widget child;
  final AppIconService icons;
  final bool enabled;
  final MusicSourceController? sources;
  final ValueListenable<bool>? sourceSwitching;
  final Future<void> Function(Future<void> Function())? onSourceSelection;
  final bool xeroxEnabled;
  final FutureOr<void> Function(bool enabled)? onXeroxChanged;

  @override
  State<HomeSheet> createState() => _HomeSheetState();
}

/// 封装或定义首页弹层状态相关类型与行为，负责页面状态组织与业务流程协调。
class _HomeSheetState extends State<HomeSheet> {
  bool _open = false;
  bool _sourceSelectionPending = false;
  Completer<void>? _sourceSheetDismissed;
  double _dragUp = 0;
  Timer? _hideTimer;
  bool _visible = true;

  void _reveal() {
    if (!widget.enabled || _open) return;
    if (!_visible) setState(() => _visible = true);
    _scheduleHide();
  }

  /// 准备并调度后续任务，用于页面状态组织与业务流程协调。
  void _scheduleHide() {
    _hideTimer?.cancel();
    if (!widget.enabled ||
        _open ||
        MediaQuery.accessibleNavigationOf(context)) {
      return;
    }
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _visible = false);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.accessibleNavigationOf(context)) _visible = true;
    _scheduleHide();
  }

  @override
  void didUpdateWidget(HomeSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled == widget.enabled) return;
    _visible = widget.enabled;
    _dragUp = 0;
    _scheduleHide();
    if (!widget.enabled && _open) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !widget.enabled && _open) {
          DeskBottomSheet.of(context).dismiss();
        }
      });
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    final dismissed = _sourceSheetDismissed;
    if (dismissed != null && !dismissed.isCompleted) dismissed.complete();
    super.dispose();
  }

  void _present() {
    if (_open || !widget.enabled) return;
    _hideTimer?.cancel();
    final landscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    var xeroxEnabled = widget.xeroxEnabled;
    var xeroxPending = false;
    final onXeroxChanged = widget.onXeroxChanged;
    DeskBottomSheet.of(context).present(
      BottomSheetScrollView(
        child: Column(
          children: [
            if (widget.sources case final sources?)
              MusicSourcePicker(
                sources: sources,
                sourceSwitching: widget.sourceSwitching,
                onSourceSelection: _selectSource,
              ),
            if (kIsWeb) const FullscreenControl(),
            if (onXeroxChanged != null)
              StatefulBuilder(
                builder: (context, setSheetState) => ListTile(
                  key: const ValueKey('xerox-toggle'),
                  selected: xeroxEnabled,
                  leading: const Icon(
                    PhosphorIcons.printer,
                    color: Colors.white70,
                  ),
                  title: Text(
                    AppLocalizations.of(context).xeroxMode,
                    style: const TextStyle(color: Colors.white),
                  ),
                  trailing: xeroxPending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : xeroxEnabled
                      ? const Icon(PhosphorIcons.check, color: Colors.white)
                      : null,
                  onTap: xeroxPending
                      ? null
                      : () async {
                          final enabled = !xeroxEnabled;
                          setSheetState(() => xeroxPending = true);
                          try {
                            await onXeroxChanged(enabled);
                            if (context.mounted) {
                              setSheetState(() => xeroxEnabled = enabled);
                            }
                          } finally {
                            if (context.mounted) {
                              setSheetState(() => xeroxPending = false);
                            }
                          }
                        },
                ),
              ),
            AppIconPicker(icons: widget.icons),
          ],
        ),
      ),
      BottomSheetOptions(
        mode: BottomSheetMode.push,
        pushDirection: PushDirection.bottom,
        snapPoints: [
          const BottomSheetDetent.fraction(0.38),
          BottomSheetDetent.fraction(landscape ? 0.76 : 0.78),
        ],
        index: 0,
        enableDynamicSizing: false,
        enablePanDownToClose: true,
        dismissOnScrimPress: true,
        enableContentPanningGesture: true,
        showHandle: true,
        onDismiss: () {
          final dismissed = _sourceSheetDismissed;
          if (dismissed != null && !dismissed.isCompleted) {
            dismissed.complete();
          }
          if (mounted) {
            setState(() => _open = false);
            _reveal();
          }
        },
      ),
    );
    setState(() => _open = true);
  }

  Future<void> _selectSource(Future<void> Function() select) async {
    if (_sourceSelectionPending) return;
    _sourceSelectionPending = true;
    try {
      if (_open) {
        final dismissed = Completer<void>();
        _sourceSheetDismissed = dismissed;
        DeskBottomSheet.of(context).dismiss();
        await dismissed.future;
        _sourceSheetDismissed = null;
      }
      if (!mounted) return;
      final onSourceSelection = widget.onSourceSelection;
      if (onSourceSelection == null) {
        await select();
      } else {
        await onSourceSelection(select);
      }
    } finally {
      _sourceSheetDismissed = null;
      _sourceSelectionPending = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_open,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _open) DeskBottomSheet.of(context).dismiss();
      },
      child: MouseRegion(
        onHover: (_) => _reveal(),
        child: Listener(
          onPointerDown: (_) {
            _reveal();
            _hideTimer?.cancel();
          },
          onPointerUp: (_) => _scheduleHide(),
          onPointerCancel: (_) => _scheduleHide(),
          child: Stack(
            fit: StackFit.expand,
            children: [
              widget.child,
              Positioned(
                left: 0,
                right: 0,
                bottom: 23,
                child: Center(
                  child: IgnorePointer(
                    ignoring: _open || !widget.enabled || !_visible,
                    child: AnimatedOpacity(
                      opacity: _open || !widget.enabled || !_visible ? 0 : 1,
                      duration: MediaQuery.disableAnimationsOf(context)
                          ? Duration.zero
                          : const Duration(milliseconds: 200),
                      child: Semantics(
                        button: true,
                        label: MaterialLocalizations.of(context)
                            .showMenuTooltip,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: _present,
                          onVerticalDragStart: (_) => _dragUp = 0,
                          onVerticalDragUpdate: (details) {
                            final dy = details.primaryDelta ?? 0;
                            _dragUp = dy < 0 ? _dragUp - dy : 0;
                            if (_dragUp >= 36) _present();
                          },
                          onVerticalDragEnd: (details) {
                            if ((details.primaryVelocity ?? 0) <= -200) {
                              _present();
                            }
                            _dragUp = 0;
                          },
                          onVerticalDragCancel: () => _dragUp = 0,
                          child: Container(
                            width: 60,
                            height: 39,
                            foregroundDecoration: kDebugMode
                                ? BoxDecoration(
                                    color: const Color(0x3300E5FF),
                                    border: Border.all(
                                      color: const Color(0xFF00E5FF),
                                    ),
                                  )
                                : null,
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 3),
                                child: Container(
                                  width: 44,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: const Color(0xB3FFFFFF),
                                    borderRadius: BorderRadius.circular(3),
                                    boxShadow: const [
                                      BoxShadow(
                                        blurRadius: 4,
                                        color: Color(0x66000000),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
