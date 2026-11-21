// 文件职责：专辑墙布局切换及过渡效果。

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../ui/widgets/frosted_control_surface.dart';
import '../../ui/widgets/glass_icon_button.dart';

/// 封装或定义布局switch覆层相关类型与行为，负责专辑墙布局切换及过渡效果。
class LayoutSwitchOverlay extends StatefulWidget {
  const LayoutSwitchOverlay({
    super.key,
    required this.builder,
    required this.coverFlow,
    required this.onSwitch,
    this.screenLandscape = false,
    this.enabled = true,
  });
  final Widget Function(Widget? switchButton, bool visible) builder;
  final bool coverFlow;
  final VoidCallback onSwitch;
  final bool screenLandscape;
  final bool enabled;
  @override
  State<LayoutSwitchOverlay> createState() => _LayoutSwitchOverlayState();
}

/// 封装或定义布局switch覆层状态相关类型与行为，负责专辑墙布局切换及过渡效果。
class _LayoutSwitchOverlayState extends State<LayoutSwitchOverlay> {
  Timer? _hideTimer;
  late bool _visible = widget.enabled;
  bool _wakeOnly = false;
  bool _buttonHovered = false;
  Orientation? _lockedOrientation;
  bool get _showButton =>
      widget.enabled &&
      (!widget.screenLandscape || _lockedOrientation == Orientation.landscape);
  bool get _canRotate =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);
  bool get _hoverEnabled => switch (defaultTargetPlatform) {
    TargetPlatform.macOS ||
    TargetPlatform.windows ||
    TargetPlatform.linux => true,
    _ => false,
  };

  void _reveal() {
    if (!_showButton) return;
    if (!_visible) setState(() => _visible = true);
    _scheduleHide();
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    if (_showButton &&
        !_buttonHovered &&
        !MediaQuery.accessibleNavigationOf(context)) {
      _hideTimer = Timer(Duration(seconds: widget.coverFlow ? 4 : 3), () {
        if (mounted) setState(() => _visible = false);
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_visible) _scheduleHide();
  }

  @override
  void didUpdateWidget(LayoutSwitchOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled != widget.enabled) {
      _hideTimer?.cancel();
      if (!widget.enabled) _unlockOrientation();
      _buttonHovered = false;
      _wakeOnly = false;
      _visible = widget.enabled;
      if (_visible) _scheduleHide();
      return;
    }
    if (oldWidget.coverFlow == widget.coverFlow) return;
    _buttonHovered = false;
    if (_visible) _reveal();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _unlockOrientation();
    super.dispose();
  }

  void _switchLayout() {
    if (!_wakeOnly && _showButton && !widget.screenLandscape) widget.onSwitch();
    _reveal();
  }

  void _rotateScreen() {
    if (!_showButton || _wakeOnly) return;
    final landscape = MediaQuery.orientationOf(context) == Orientation.portrait;
    _lockedOrientation = landscape
        ? Orientation.landscape
        : Orientation.portrait;
    unawaited(
      SystemChrome.setPreferredOrientations(
        landscape
            ? const [
                DeviceOrientation.landscapeLeft,
                DeviceOrientation.landscapeRight,
              ]
            : const [DeviceOrientation.portraitUp],
      ),
    );
  }

  void _unlockOrientation() {
    if (_lockedOrientation == null) return;
    _lockedOrientation = null;
    unawaited(SystemChrome.setPreferredOrientations(const []));
  }

  Widget _wakeButton(Widget child) => GestureDetector(
    key: const ValueKey('layout-switch-wake'),
    behavior: HitTestBehavior.opaque,
    onTap: _reveal,
    child: child,
  );

  Widget _buildSwitch(BuildContext context) {
    const buttonKey = ValueKey('layout-switch');
    const iconSize = 18.0;
    final onLongPress = _canRotate ? _rotateScreen : null;
    if (widget.coverFlow) {
      return AnimatedSwitcher(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 200),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        child: _visible
            ? GlassIconButton(
                key: buttonKey,
                diameter: 36,
                iconSize: iconSize,
                label: widget.screenLandscape ? '长按旋转回竖屏' : '切换到画布',
                icon: widget.screenLandscape
                    ? PhosphorIcons.deviceRotate
                    : PhosphorIcons.gridNine,
                onPressed: _switchLayout,
                onLongPress: onLongPress,
              )
            : _wakeButton(const SizedBox.square(dimension: 44)),
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        IgnorePointer(
          ignoring: !_visible,
          child: FrostedControlSurface(
            key: buttonKey,
            visible: _visible,
            child: Material(
              type: MaterialType.transparency,
              child: IconButton(
                tooltip: '切换到 CoverFlow',
                iconSize: iconSize,
                color: Colors.white,
                padding: EdgeInsets.zero,
                icon: const Icon(PhosphorIcons.cards),
                onPressed: _switchLayout,
                onLongPress: onLongPress,
              ),
            ),
          ),
        ),
        if (!_visible) _wakeButton(const SizedBox.expand()),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: _showButton && _hoverEnabled ? (_) => _reveal() : null,
    onHover: _showButton && _hoverEnabled ? (_) => _reveal() : null,
    child: Listener(
      behavior: _showButton
          ? HitTestBehavior.translucent
          : HitTestBehavior.deferToChild,
      onPointerDown: _showButton
          ? (_) {
              _wakeOnly = !_visible;
              _reveal();
              if (!widget.coverFlow) _hideTimer?.cancel();
            }
          : null,
      onPointerUp: _showButton && !widget.coverFlow ? (_) => _reveal() : null,
      onPointerCancel: _showButton && !widget.coverFlow
          ? (_) => _reveal()
          : null,
      child: widget.builder(
        _showButton
            ? MouseRegion(
                onEnter: _hoverEnabled
                    ? (_) {
                        _buttonHovered = true;
                        _reveal();
                      }
                    : null,
                onExit: _hoverEnabled
                    ? (_) {
                        _buttonHovered = false;
                        _reveal();
                      }
                    : null,
                child: _buildSwitch(context),
              )
            : null,
        _showButton && _visible,
      ),
    ),
  );
}
