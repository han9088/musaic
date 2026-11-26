// 文件职责：将托盘资源绑定到应用生命周期和本地化环境。

import 'package:flutter/widgets.dart';

import '../../l10n/generated/app_localizations.dart';
import 'desktop_tray_controller.dart';

class DesktopTrayHost extends StatefulWidget {
  const DesktopTrayHost({super.key, required this.child});

  final Widget child;

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
    (_controller ??= DesktopTrayController())
        .updateLocale(AppLocalizations.of(context));
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
