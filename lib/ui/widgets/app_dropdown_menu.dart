import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../dialogs/app_alert_dialog.dart';
import '../dialogs/app_jelly_transition.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_theme.dart';
import 'app_selection_dot.dart';

const _itemHeight = 44.0;

class AppDropdownMenuEntry<T extends Object> {
  const AppDropdownMenuEntry(this.value, this.label, {this.keywords = ''});

  final T value;
  final String label;
  final String keywords;

  bool _matches(String query) =>
      label.toLowerCase().contains(query) ||
      keywords.toLowerCase().contains(query);
}

class AppDropdownMenu<T extends Object> extends StatefulWidget {
  const AppDropdownMenu({
    super.key,
    required this.title,
    required this.value,
    required this.entries,
    required this.onSelected,
    required this.searchLabel,
    required this.emptyLabel,
    this.leading,
  });

  final String title;
  final T value;
  final List<AppDropdownMenuEntry<T>> entries;
  final ValueChanged<T> onSelected;
  final String searchLabel;
  final String emptyLabel;
  final Widget? leading;

  @override
  State<AppDropdownMenu<T>> createState() => _AppDropdownMenuState<T>();
}

class _AppDropdownMenuState<T extends Object>
    extends State<AppDropdownMenu<T>> {
  bool _open = false;

  Future<void> _show() async {
    if (_open) return;
    final overlay = Navigator.of(context, rootNavigator: true).overlay!;
    final overlayBox = overlay.context.findRenderObject()! as RenderBox;
    final menu = widget;
    var anchor = Rect.zero;

    setState(() => _open = true);
    final T? selected;
    try {
      selected = await showAppDialog<T>(
        context: context,
        builder: (_) => _DropdownOptions(menu: menu),
        layoutBuilder: (context, animation, child) => LayoutBuilder(
          builder: (context, constraints) {
            final renderObject = mounted
                ? this.context.findRenderObject()
                : null;
            if (renderObject case final RenderBox box
                when box.attached && box.hasSize) {
              anchor = MatrixUtils.transformRect(
                box.getTransformTo(overlayBox),
                Offset.zero & box.size,
              );
            }
            return _layout(
              context,
              constraints,
              anchor,
              menu.entries.length,
              animation,
              child,
            );
          },
        ),
      );
    } finally {
      if (mounted) setState(() => _open = false);
    }
    if (mounted && selected != null) widget.onSelected(selected);
  }

  static Widget _layout(
    BuildContext context,
    BoxConstraints constraints,
    Rect anchor,
    int entryCount,
    Animation<double> animation,
    Widget child,
  ) {
    const margin = 12.0;
    const gap = 6.0;
    final padding = MediaQuery.paddingOf(context);
    final insets = MediaQuery.viewInsetsOf(context);
    final bounds = Rect.fromLTRB(
      padding.left + insets.left + margin,
      padding.top + insets.top + margin,
      constraints.maxWidth - padding.right - insets.right - margin,
      constraints.maxHeight - padding.bottom - insets.bottom - margin,
    );
    if (bounds.isEmpty) return const SizedBox.shrink();

    final width = math.min(208.0, bounds.width);
    final idealLeft = Directionality.of(context) == TextDirection.ltr
        ? anchor.right - settingsContentInset - width
        : anchor.left + settingsContentInset;
    final left = idealLeft.clamp(bounds.left, bounds.right - width);

    final below = (anchor.bottom + gap).clamp(bounds.top, bounds.bottom);
    final above = (anchor.top - gap).clamp(bounds.top, bounds.bottom);
    final roomBelow = bounds.bottom - below;
    final roomAbove = above - bounds.top;
    final maxHeight = math.min(288.0, bounds.height);
    final preferredHeight = math.min(
      maxHeight,
      64.0 + _itemHeight * entryCount,
    );
    final opensBelow = roomBelow >= preferredHeight || roomBelow >= roomAbove;
    final room = opensBelow ? roomBelow : roomAbove;
    final fits = room >= math.min(144.0, preferredHeight);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: left,
          width: width,
          top: opensBelow ? (fits ? below : bounds.top) : null,
          bottom: opensBelow
              ? null
              : constraints.maxHeight - (fits ? above : bounds.bottom),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: fits ? math.min(maxHeight, room) : maxHeight,
            ),
            child: AppJellyTransition(
              animation: animation,
              alignment: opensBelow
                  ? AlignmentDirectional.topEnd
                  : AlignmentDirectional.bottomEnd,
              openingOffset: Offset(0, opensBelow ? -20 : 20),
              child: child,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.entries
        .where((entry) => entry.value == widget.value)
        .firstOrNull;
    return Semantics(
      expanded: _open,
      child: ListTile(
        leading: widget.leading,
        title: Text(widget.title),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 8,
          children: [
            if (selected != null)
              Text(
                selected.label,
                style: const TextStyle(color: Colors.white60),
              ),
            Icon(
              _open ? PhosphorIcons.caretUp : PhosphorIcons.caretDown,
              size: settingsItemArrowSize,
            ),
          ],
        ),
        onTap: widget.entries.isEmpty ? null : _show,
      ),
    );
  }
}

class _DropdownOptions<T extends Object> extends StatefulWidget {
  const _DropdownOptions({required this.menu});

  final AppDropdownMenu<T> menu;

  @override
  State<_DropdownOptions<T>> createState() => _DropdownOptionsState<T>();
}

class _DropdownOptionsState<T extends Object>
    extends State<_DropdownOptions<T>> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final menu = widget.menu;
    final entries = menu.entries
        .where((entry) => entry._matches(_query))
        .toList();
    const foreground = AppColors.dialogForeground;
    const textSize = 14.0;
    const secondaryText = TextStyle(fontSize: textSize, color: Colors.white70);
    const controlRadius = BorderRadius.all(Radius.circular(AppRadius.small));
    return AppDialogSurface(
      borderRadius: const BorderRadius.all(Radius.circular(AppRadius.medium)),
      child: Material(
        type: MaterialType.transparency,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 4, 6),
                child: TextField(
                  onChanged: (value) =>
                      setState(() => _query = value.trim().toLowerCase()),
                  textInputAction: TextInputAction.search,
                  style: const TextStyle(fontSize: textSize, color: foreground),
                  cursorColor: foreground,
                  decoration: InputDecoration(
                    hintText: menu.searchLabel,
                    hintStyle: secondaryText,
                    isDense: true,
                    filled: true,
                    fillColor: Colors.white10,
                    prefixIcon: const Icon(
                      PhosphorIcons.magnifyingGlass,
                      color: Colors.white70,
                      size: 18,
                    ),
                    border: const OutlineInputBorder(
                      borderRadius: controlRadius,
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              if (entries.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    menu.emptyLabel,
                    textAlign: TextAlign.center,
                    style: secondaryText,
                  ),
                ),
              for (final entry in entries)
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  minTileHeight: _itemHeight,
                  tileColor: Colors.transparent,
                  selectedTileColor: Colors.white10,
                  shape: const RoundedRectangleBorder(
                    borderRadius: controlRadius,
                  ),
                  textColor: foreground,
                  selectedColor: foreground,
                  title: AppSelectionTitle(
                    selected: entry.value == menu.value,
                    child: Text(
                      entry.label,
                      style: const TextStyle(fontSize: textSize),
                    ),
                  ),
                  selected: entry.value == menu.value,
                  onTap: () => Navigator.of(context).pop(entry.value),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
