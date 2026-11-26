// 文件职责：将托盘资源绑定到应用生命周期和本地化环境。

import 'dart:async';

import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../l10n/generated/app_localizations.dart';
import '../settings/desktop_settings_window.dart';
import 'desktop_tray_controller.dart';

class DesktopTrayHost extends StatefulWidget {
  const DesktopTrayHost({super.key, required this.child, this.settingsWindow});

  final Widget child;
  final DesktopSettingsWindow? settingsWindow;

  @override
  State<DesktopTrayHost> createState() => _DesktopTrayHostState();
}

class _DesktopTrayHostState extends State<DesktopTrayHost> {
  DesktopTrayController? _controller;
  Locale? _locale;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!DesktopTrayController.isAvailable) return;
    final locale = Localizations.localeOf(context);
    if (_locale == locale) return;
    _locale = locale;
    final l10n = AppLocalizations.of(context);
    widget.settingsWindow?.updateTitle(l10n.settings);
    (_controller ??= DesktopTrayController(
      onOpenSettings: widget.settingsWindow?.open,
    )).updateLocale(l10n);
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settingsWindow = widget.settingsWindow;
    if (settingsWindow == null ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      return widget.child;
    }
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(
          LogicalKeyboardKey.comma,
          control: true,
          includeRepeats: false,
        ): () => unawaited(settingsWindow.open()),
      },
      child: Focus(
        autofocus: true,
        skipTraversal: true,
        includeSemantics: false,
        child: widget.child,
      ),
    );
  }
}
