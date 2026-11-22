// 文件职责：设置项展示与系统能力控制。

import 'package:material_ui/material_ui.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../services/app_icon_service.dart';
import '../../ui/theme/app_theme.dart';
import '../../ui/widgets/settings_section_heading.dart';

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsSectionHeading(l10n.appIcon),
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
                  Padding(
                    padding: settingsItemPadding,
                    child: Text(
                      l10n.appIconLoadFailed,
                      style: const TextStyle(color: Colors.white70),
                    ),
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
              return Padding(
                padding: settingsItemPadding,
                child: Text(
                  l10n.appIconUnsupported,
                  style: const TextStyle(color: Colors.white70),
                ),
              );
            }
            return Column(
              children: [
                Padding(
                  padding: settingsItemPadding.copyWith(top: 8),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      const spacing = 8.0;
                      const minTileWidth = 100.0;
                      const line = BorderSide(
                        color: Color(0x33FFFFFF),
                        width: 0.5,
                      );
                      final width = constraints.maxWidth;
                      final columns =
                          ((width + spacing) / (minTileWidth + spacing))
                              .floor()
                              .clamp(1, AppIconChoice.values.length);
                      final tileWidth =
                          (width - (columns - 1) * spacing) / columns;
                      final tiles = [
                        for (final choice in widget.icons.choices)
                          _AppIconTile(
                            key: ValueKey('app-icon-${choice.name}'),
                            choice: choice,
                            selected: choice == state.current,
                            onTap: _changing || choice == state.current
                                ? null
                                : () => _change(choice),
                          ),
                      ];
                      final edgeWidth = FixedColumnWidth(
                        tileWidth + spacing / 2,
                      );
                      return Table(
                        defaultVerticalAlignment:
                            TableCellVerticalAlignment.middle,
                        border: const TableBorder(
                          top: line,
                          right: line,
                          bottom: line,
                          left: line,
                          horizontalInside: line,
                          verticalInside: line,
                        ),
                        columnWidths: {
                          if (columns > 1) ...{
                            0: edgeWidth,
                            columns - 1: edgeWidth,
                          },
                        },
                        children: [
                          for (
                            var first = 0;
                            first < tiles.length;
                            first += columns
                          )
                            TableRow(
                              children: [
                                for (var column = 0; column < columns; column++)
                                  if (first + column < tiles.length)
                                    Padding(
                                      padding: EdgeInsets.only(
                                        left: column == 0 ? 0 : spacing / 2,
                                        right: column == columns - 1
                                            ? 0
                                            : spacing / 2,
                                      ),
                                      child: tiles[first + column],
                                    )
                                  else
                                    const SizedBox.shrink(),
                              ],
                            ),
                        ],
                      );
                    },
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
            child: Padding(
              padding: settingsItemPadding,
              child: Text(
                l10n.appIconChangeFailed,
                style: const TextStyle(color: Colors.redAccent),
              ),
            ),
          ),
      ],
    );
  }
}

class _AppIconTile extends StatelessWidget {
  const _AppIconTile({
    super.key,
    required this.choice,
    required this.selected,
    required this.onTap,
  });

  final AppIconChoice choice;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final title = switch (choice) {
      AppIconChoice.vinylPrimary => l10n.appIconDefault,
      AppIconChoice.text => l10n.appIconText,
      AppIconChoice.mosaic => l10n.appIconMosaic,
      AppIconChoice.vinyl => l10n.appIconVinyl,
      AppIconChoice.vinylWhite => l10n.appIconVinylWhite,
      AppIconChoice.mosaicXerox => l10n.appIconMosaicXerox,
    };
    final radius = BorderRadius.circular(12);
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: radius,
                    child: Image.asset(
                      choice.previewAsset,
                      width: 56,
                      height: 56,
                      cacheWidth: 168,
                      fit: BoxFit.cover,
                      excludeFromSemantics: true,
                    ),
                  ),
                  if (selected)
                    const Positioned(
                      right: 0,
                      bottom: 0,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black87,
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(
                            PhosphorIcons.checkBold,
                            size: 12,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
