// 文件职责：专辑墙布局切换及过渡效果。

import 'dart:async';

import 'package:flutter/foundation.dart';
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
    this.enabled = true,
  });
  final Widget Function(Widget? switchButton, bool visible) builder;
  final bool coverFlow;
  final VoidCallback onSwitch;
  final bool enabled;
  @override
  State<LayoutSwitchOverlay> createState() => _LayoutSwitchOverlayState();
}

/// 封装或定义布局switch覆层状态相关类型与行为，负责专辑墙布局切换及过渡效果。
class _LayoutSwitchOverlayState extends State<LayoutSwitchOverlay> {
  Timer? _hideTimer;
  bool _visible = false;
  bool _wakeOnly = false;
  bool _buttonHovered = false;
  bool get _hoverEnabled => switch (defaultTargetPlatform) {
    TargetPlatform.macOS ||
    TargetPlatform.windows ||
    TargetPlatform.linux => true,
    _ => false,
  };

  void _reveal() {
    if (!widget.enabled) return;
    if (!_visible) setState(() => _visible = true);
    _hideTimer?.cancel();
    if (!_buttonHovered && !MediaQuery.accessibleNavigationOf(context)) {
      _hideTimer = Timer(Duration(seconds: widget.coverFlow ? 4 : 3), () {
        if (mounted) setState(() => _visible = false);
      });
    }
  }

  @override
  void didUpdateWidget(LayoutSwitchOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled != widget.enabled) {
      _hideTimer?.cancel();
      _buttonHovered = false;
      _wakeOnly = false;
      _visible = widget.enabled;
      return;
    }
    if (oldWidget.coverFlow == widget.coverFlow) return;
    _buttonHovered = false;
    if (_visible) _reveal();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  void _switchLayout() {
    if (widget.enabled && !_wakeOnly) widget.onSwitch();
    _reveal();
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
                label: '切换到画布',
                icon: PhosphorIcons.gridNine,
                onPressed: _switchLayout,
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
    onEnter: widget.enabled && _hoverEnabled ? (_) => _reveal() : null,
    onHover: widget.enabled && _hoverEnabled ? (_) => _reveal() : null,
    child: Listener(
      behavior: widget.enabled
          ? HitTestBehavior.translucent
          : HitTestBehavior.deferToChild,
      onPointerDown: widget.enabled
          ? (_) {
              _wakeOnly = !_visible;
              _reveal();
              if (!widget.coverFlow) _hideTimer?.cancel();
            }
          : null,
      onPointerUp: widget.enabled && !widget.coverFlow
          ? (_) => _reveal()
          : null,
      onPointerCancel: widget.enabled && !widget.coverFlow
          ? (_) => _reveal()
          : null,
      child: widget.builder(
        widget.enabled
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
        widget.enabled && _visible,
      ),
    ),
  );
}
