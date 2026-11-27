import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../ui/theme/app_theme.dart';
import '../../../ui/widgets/app_color_palette.dart';
import 'album_color_family.dart';

class AlbumColorOrganizationSettings extends StatelessWidget {
  const AlbumColorOrganizationSettings({
    super.key,
    required this.index,
    required this.enabled,
    required this.onChanged,
    this.selectedFamily,
    this.onFamilySelected,
  });

  final AlbumColorFamilyIndex index;
  final ValueListenable<bool> enabled;
  final ValueChanged<bool> onChanged;
  final ValueListenable<AlbumColorFamily?>? selectedFamily;
  final ValueChanged<AlbumColorFamily?>? onFamilySelected;

  @override
  Widget build(BuildContext context) {
    final selected = selectedFamily;
    final onSelect = onFamilySelected;
    return AnimatedBuilder(
      animation: index,
      builder: (context, _) {
        final families = index.availableFamilies;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ValueListenableBuilder<bool>(
              valueListenable: enabled,
              builder: (_, value, _) => SwitchListTile(
                key: const ValueKey('album-color-organize-toggle'),
                secondary: const Icon(
                  PhosphorIcons.palette,
                  color: Colors.white70,
                ),
                title: const Text('按色系整理画布'),
                subtitle: const Text(
                  '将主题色相近的专辑集中排列',
                  style: TextStyle(fontSize: 12, color: Colors.white60),
                ),
                value: value,
                onChanged: onChanged,
              ),
            ),
            if (selected != null && onSelect != null)
              ValueListenableBuilder<bool>(
                valueListenable: enabled,
                builder: (_, isEnabled, _) {
                  if (!isEnabled || families.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(
                      settingsContentInset,
                      0,
                      settingsContentInset,
                      12,
                    ),
                    child: ValueListenableBuilder<AlbumColorFamily?>(
                      valueListenable: selected,
                      builder: (_, current, _) =>
                          AppColorPalette<AlbumColorFamily?>(
                            selection: current,
                            onSelected: onSelect,
                            swatches: [
                              const (
                                value: null,
                                label: '显示全部色系',
                                fill: BoxDecoration(
                                  gradient: SweepGradient(
                                    colors: [
                                      Color(0xffe34b4b),
                                      Color(0xffe5a33b),
                                      Color(0xffe4d34a),
                                      Color(0xff59a96a),
                                      Color(0xff45aeb0),
                                      Color(0xff477bd0),
                                      Color(0xff9368c5),
                                      Color(0xffe34b4b),
                                    ],
                                  ),
                                ),
                              ),
                              for (final family in families)
                                (
                                  value: family,
                                  label: family.label,
                                  fill: BoxDecoration(
                                    color: family.isNeutral
                                        ? const Color(0xff888888)
                                        : HSLColor.fromAHSL(
                                            1,
                                            family.hue,
                                            0.62,
                                            0.52,
                                          ).toColor(),
                                  ),
                                ),
                            ],
                          ),
                    ),
                  );
                },
              ),
          ],
        );
      },
    );
  }
}
