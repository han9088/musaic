import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/semantics.dart' show OrdinalSortKey;
import 'package:material_ui/material_ui.dart';

typedef AppColorSwatch<T> = ({T value, String label, BoxDecoration fill});

class AppColorPalette<T> extends StatelessWidget {
  const AppColorPalette({
    super.key,
    required this.swatches,
    required this.selection,
    required this.onSelected,
  });

  final List<AppColorSwatch<T>> swatches;
  final T selection;
  final ValueChanged<T> onSelected;

  static const _preferredEdge = 26.0;
  static const _minEdgeBeforeWrapping = 22.0;

  @override
  Widget build(BuildContext context) {
    if (swatches.isEmpty) return const SizedBox.shrink();
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 200);

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.hasBoundedWidth
              ? constraints.maxWidth
              : swatches.length * _preferredEdge;
          final columns = (width / _minEdgeBeforeWrapping)
              .floor()
              .clamp(1, swatches.length)
              .toInt();
          final edge = (width / columns).clamp(0.0, _preferredEdge).toDouble();
          final rows = (swatches.length + columns - 1) ~/ columns;
          final selected = swatches.indexWhere(
            (swatch) => swatch.value == selection,
          );

          Offset offsetFor(int index) =>
              Offset(edge * (index % columns), edge * (index ~/ columns));

          final fills = [for (final swatch in swatches) swatch.fill];
          final textDirection = Directionality.of(context);
          Widget strip(int covered) => CustomPaint(
            painter: _PaletteStripPainter(
              fills: fills,
              selected: covered,
              columns: columns,
              edge: edge,
              textDirection: textDirection,
            ),
          );

          final destination = selected < 0 ? null : offsetFor(selected);
          return SizedBox(
            width: edge * columns,
            height: edge * rows,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: IgnorePointer(
                    child: destination == null
                        ? strip(-1)
                        : TweenAnimationBuilder<Offset>(
                            duration: duration,
                            curve: Curves.easeOutCubic,
                            tween: Tween(begin: destination, end: destination),
                            child: Transform.scale(
                              key: const ValueKey('palette-raised-swatch'),
                              scale: 1.16,
                              child: AnimatedContainer(
                                duration: duration,
                                curve: Curves.easeOutCubic,
                                decoration: _raisedFill(fills, selected)
                                    .copyWith(
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Color(0x70000000),
                                          offset: Offset(0, 3),
                                          blurRadius: 6,
                                        ),
                                      ],
                                    ),
                              ),
                            ),
                            builder: (context, offset, swatch) => Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Positioned.fill(
                                  child: strip(
                                    offset == destination ? selected : -1,
                                  ),
                                ),
                                PositionedDirectional(
                                  start: offset.dx,
                                  top: offset.dy,
                                  width: edge,
                                  height: edge,
                                  child: swatch!,
                                ),
                              ],
                            ),
                          ),
                  ),
                ),
                for (final (index, swatch) in swatches.indexed)
                  PositionedDirectional(
                    key: ValueKey((swatch.value, 'position')),
                    start: offsetFor(index).dx,
                    top: offsetFor(index).dy,
                    width: edge,
                    height: edge,
                    child: _swatch(swatch, index),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  BoxDecoration _raisedFill(List<BoxDecoration> fills, int selected) {
    final fill = fills[selected];
    final color = fill.color;
    if (color == null ||
        fill.gradient != null ||
        !fills.any((fill) => fill.gradient is SweepGradient)) {
      return fill;
    }

    // Interpolate between opaque shaders so the fill is visible mid-slide.
    return BoxDecoration(gradient: SweepGradient(colors: [color, color]));
  }

  Widget _swatch(AppColorSwatch<T> swatch, int index) {
    final selected = swatch.value == selection;
    return Semantics(
      key: ValueKey<T>(swatch.value),
      label: swatch.label,
      button: true,
      selected: selected,
      sortKey: OrdinalSortKey(index.toDouble()),
      child: Tooltip(
        message: swatch.label,
        excludeFromSemantics: true,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(onTap: () => onSelected(swatch.value)),
        ),
      ),
    );
  }
}

class _PaletteStripPainter extends CustomPainter {
  const _PaletteStripPainter({
    required this.fills,
    required this.selected,
    required this.columns,
    required this.edge,
    required this.textDirection,
  });

  final List<BoxDecoration> fills;
  final int selected;
  final int columns;
  final double edge;
  final TextDirection textDirection;

  @override
  void paint(Canvas canvas, Size size) {
    final rtl = textDirection == TextDirection.rtl;
    final paint = Paint()..isAntiAlias = false;
    for (var index = 0; index < fills.length; index++) {
      if (index == selected) continue;
      final column = index % columns;
      final row = index ~/ columns;
      final start = edge * column;
      final end = edge * (column + 1);
      final bounds = Rect.fromLTRB(
        rtl ? size.width - end : start,
        edge * row,
        rtl ? size.width - start : end,
        edge * (row + 1),
      );
      final fill = fills[index];
      paint
        ..color = fill.color ?? Colors.white
        ..shader = fill.gradient?.createShader(
          bounds,
          textDirection: textDirection,
        );
      canvas.drawRect(bounds, paint);
    }
  }

  @override
  bool shouldRepaint(_PaletteStripPainter oldDelegate) =>
      !listEquals(fills, oldDelegate.fills) ||
      selected != oldDelegate.selected ||
      columns != oldDelegate.columns ||
      edge != oldDelegate.edge ||
      textDirection != oldDelegate.textDirection;
}
