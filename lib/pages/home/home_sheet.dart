// 文件职责：页面状态组织与业务流程协调。

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import '../../features/music/playback/album_playback.dart';
import '../../features/music/playback/now_playing_capsule.dart';
import '../../features/music/presentation/music_source_picker.dart';
import '../../features/settings/appearance_settings.dart';
import '../../features/settings/settings_sheet.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../services/app_icon_service.dart';
import '../../services/music/music_source_controller.dart';
import '../../storage/settings/manual_rotation_preference.dart';
import '../../ui/bottom_sheet/bottom_sheet.dart';
import '../../ui/widgets/frosted_control_surface.dart';
import '../settings/settings_page.dart';

/// 封装或定义首页弹层相关类型与行为，负责页面状态组织与业务流程协调。
class HomeSheet extends StatefulWidget {
  const HomeSheet({
    super.key,
    required this.child,
    this.icons = const AppIconService(),
    this.enabled = true,
    this.sources,
    this.playback,
    this.layoutSwitch,
    this.sourceSwitching,
    this.onSourceSelection,
    this.manualRotation,
    this.xeroxEnabled = false,
    this.onXeroxChanged,
    this.xeroxPalettePicker,
  });

  final Widget child;
  final AppIconService icons;
  final bool enabled;
  final MusicSourceController? sources;
  final AlbumPlayback? playback;
  final ({Widget button, bool visible})? layoutSwitch;
  final ValueListenable<bool>? sourceSwitching;
  final Future<void> Function(Future<void> Function())? onSourceSelection;
  final ManualRotationPreference? manualRotation;
  final bool xeroxEnabled;
  final FutureOr<bool> Function(bool enabled)? onXeroxChanged;
  final Widget? xeroxPalettePicker;

  @override
  State<HomeSheet> createState() => _HomeSheetState();
}

/// 封装或定义首页弹层状态相关类型与行为，负责页面状态组织与业务流程协调。
class _HomeSheetState extends State<HomeSheet> {
  bool _open = false;
  bool _sourceSelectionPending = false;
  Completer<void>? _sourceSheetDismissed;
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
    DeskBottomSheet.of(context).present(
      SettingsSheet(
        sources: widget.sources,
        sourceSwitching: widget.sourceSwitching,
        onSourceSelection: _selectSource,
        onOpenSection: _openSettings,
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

  void _openSettings(BuildContext source, SettingsSection section) {
    if (!_open || _sourceSelectionPending) return;
    final navigator = Navigator.of(source, rootNavigator: true);
    final l10n = AppLocalizations.of(source);
    late final PageRoute<void> route;
    final (path, title, body) = switch (section) {
      SettingsSection.musicSource => (
        '/settings/music-source',
        l10n.musicSource,
        MusicSourcePicker(
          sources: widget.sources!,
          sourceSwitching: widget.sourceSwitching,
          onSourceSelection: (select) async {
            if (!route.isCurrent) return;
            navigator.pop();
            await route.completed;
            if (mounted) await _selectSource(select);
          },
        ),
      ),
      SettingsSection.appearance => (
        '/settings/appearance',
        l10n.settingsAppearance,
        AppearanceSettings(
          icons: widget.icons,
          manualRotation: widget.manualRotation,
          xeroxEnabled: widget.xeroxEnabled,
          onXeroxChanged: widget.onXeroxChanged,
          xeroxPalettePicker: widget.xeroxPalettePicker,
        ),
      ),
    };
    route = pushSettingsPage(
      source: source,
      navigator: navigator,
      path: path,
      title: title,
      body: body,
    );
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
    final layoutSwitch = _open ? null : widget.layoutSwitch;
    final capsuleVisible = !_open && _visible;
    return PopScope(
      canPop: !_open,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || !_open || _sourceSelectionPending) return;
        DeskBottomSheet.of(context).dismiss();
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
              if (widget.enabled)
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 45,
                  child: Center(
                    child: FrostedControlPair(
                      primaryVisible: capsuleVisible,
                      companion: layoutSwitch?.button,
                      companionVisible: layoutSwitch?.visible ?? false,
                      onPrimaryPullUp: _present,
                      primary: NowPlayingCapsule(
                        playback: widget.playback,
                        visible: capsuleVisible,
                        onOpenSheet: _present,
                      ),
                    ),
                  ),
                ),
              if (!widget.enabled && layoutSwitch != null)
                Positioned(
                  right: 20,
                  bottom: 20,
                  child: SafeArea(child: layoutSwitch.button),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
