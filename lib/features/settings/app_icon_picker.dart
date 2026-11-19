// 文件职责：设置项展示与系统能力控制。

import 'package:material_ui/material_ui.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../services/app_icon_service.dart';

/// 封装或定义应用图标选择器相关类型与行为，负责设置项展示与系统能力控制。
class AppIconPicker extends StatefulWidget {
  const AppIconPicker({super.key, required this.icons});

  final AppIconService icons;

  @override
  State<AppIconPicker> createState() => _AppIconPickerState();
}

/// 封装或定义应用图标选择器状态相关类型与行为，负责设置项展示与系统能力控制。
class _AppIconPickerState extends State<AppIconPicker> {
  late Future<AppIconSnapshot> _loading = widget.icons.read();
  bool _changing = false;
  bool _changeFailed = false;

  Future<void> _change(AppIconChoice choice) async {
    if (_changing) return;
    setState(() {
      _changing = true;
      _changeFailed = false;
    });
    try {
      await widget.icons.change(choice);
      final current = await widget.icons.read();
      if (mounted) {
        setState(() {
          _loading = Future.value(current);
        });
      }
    } catch (error, stack) {
      debugPrint('App icon change failed: $error\n$stack');
      if (mounted) setState(() => _changeFailed = true);
    } finally {
      if (mounted) setState(() => _changing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              l10n.appIcon,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          FutureBuilder<AppIconSnapshot>(
            future: _loading,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                );
              }
              if (snapshot.hasError) {
                return Column(
                  children: [
                    Text(
                      l10n.appIconLoadFailed,
                      style: const TextStyle(color: Colors.white70),
                    ),
                    TextButton(
                      onPressed: () {
                        final loading = widget.icons.read();
                        setState(() {
                          _loading = loading;
                        });
                      },
                      child: Text(
                        l10n.retry,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                );
              }
              final state = snapshot.requireData;
              if (!state.supported) {
                return Text(
                  l10n.appIconUnsupported,
                  style: const TextStyle(color: Colors.white70),
                );
              }
              return Column(
                children: [
                  for (final choice in widget.icons.choices)
                    Semantics(
                      selected: choice == state.current,
                      child: ListTile(
                        key: ValueKey('app-icon-${choice.name}'),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 6,
                          horizontal: 8,
                        ),
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.asset(
                            choice.previewAsset,
                            width: 52,
                            height: 52,
                            cacheWidth: 156,
                            fit: BoxFit.cover,
                            excludeFromSemantics: true,
                          ),
                        ),
                        title: Text(switch (choice) {
                          AppIconChoice.vinylPrimary => l10n.appIconDefault,
                          AppIconChoice.text => l10n.appIconText,
                          AppIconChoice.mosaic => l10n.appIconMosaic,
                          AppIconChoice.vinyl => l10n.appIconVinyl,
                          AppIconChoice.vinylWhite => l10n.appIconVinylWhite,
                          AppIconChoice.mosaicXerox => l10n.appIconMosaicXerox,
                        }, style: const TextStyle(color: Colors.white)),
                        trailing: choice == state.current
                            ? const Icon(
                                PhosphorIcons.checkBold,
                                color: Colors.white,
                              )
                            : null,
                        enabled: !_changing,
                        onTap: choice == state.current
                            ? null
                            : () => _change(choice),
                      ),
                    ),
                  if (_changing)
                    const LinearProgressIndicator(color: Colors.white),
                ],
              );
            },
          ),
          if (_changeFailed)
            Semantics(
              liveRegion: true,
              child: Text(
                l10n.appIconChangeFailed,
                style: const TextStyle(color: Colors.redAccent),
              ),
            ),
        ],
      ),
    );
  }
}
