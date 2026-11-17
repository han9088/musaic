import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../ui/widgets/glass_icon_button.dart';

class LayoutSwitchOverlay extends StatefulWidget {
  const LayoutSwitchOverlay({
    super.key,
    required this.child,
    required this.coverFlow,
    required this.onSwitch,
  });
  final Widget child;
  final bool coverFlow;
  final VoidCallback onSwitch;
  @override
  State<LayoutSwitchOverlay> createState() => _LayoutSwitchOverlayState();
}

class _LayoutSwitchOverlayState extends State<LayoutSwitchOverlay> {
  Timer? _hideTimer;
  bool _visible = false;
  bool _wakeOnly = false;
  bool _buttonHovered = false;
  bool get _isMac => defaultTargetPlatform == TargetPlatform.macOS;

  void _reveal() {
    if (!_visible) setState(() => _visible = true);
    _hideTimer?.cancel();
    if (!_buttonHovered && !MediaQuery.accessibleNavigationOf(context)) {
      _hideTimer = Timer(const Duration(seconds: 4), () {
        if (mounted) setState(() => _visible = false);
      });
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: _isMac ? (_) => _reveal() : null,
    onHover: _isMac ? (_) => _reveal() : null,
    child: Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) {
        _wakeOnly = !_visible;
        _reveal();
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          widget.child,
          Positioned(
            right: 20,
            bottom: 20,
            child: SafeArea(
              child: MouseRegion(
                onEnter: _isMac
                    ? (_) {
                        _buttonHovered = true;
                        _reveal();
                      }
                    : null,
                onExit: _isMac
                    ? (_) {
                        _buttonHovered = false;
                        _reveal();
                      }
                    : null,
                child: AnimatedSwitcher(
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 200),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  child: _visible
                      ? GlassIconButton(
                          key: const ValueKey('layout-switch'),
                          diameter: 36,
                          iconSize: 14,
                          label: widget.coverFlow ? '切换到画布' : '切换到 CoverFlow',
                          icon: widget.coverFlow
                              ? PhosphorIcons.squaresFour
                              : PhosphorIcons.cards,
                          onPressed: () {
                            if (!_wakeOnly) widget.onSwitch();
                            _reveal();
                          },
                        )
                      : GestureDetector(
                          key: const ValueKey('layout-switch-wake'),
                          behavior: HitTestBehavior.opaque,
                          onTap: _reveal,
                          child: const SizedBox(width: 44, height: 44),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
