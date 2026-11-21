import 'dart:async';

import 'package:flutter/rendering.dart' show OverflowBoxFit;
import 'package:material_ui/material_ui.dart';

class NowPlayingTitle extends StatelessWidget {
  const NowPlayingTitle({
    super.key,
    required this.title,
    required this.style,
    required this.animate,
  });

  final String title;
  final TextStyle style;
  final bool animate;

  static final _lineBreaks = RegExp(r'[\r\n]+');

  @override
  Widget build(BuildContext context) {
    final line = title.replaceAll(_lineBreaks, ' ');
    final label = Text(
      line,
      style: style,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
    if (!animate ||
        MediaQuery.disableAnimationsOf(context) ||
        !TickerMode.valuesOf(context).enabled) {
      return label;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final direction = Directionality.of(context);
        var effectiveStyle = DefaultTextStyle.of(context).style.merge(style);
        if (MediaQuery.boldTextOf(context)) {
          effectiveStyle = effectiveStyle.copyWith(fontWeight: FontWeight.bold);
        }
        final painter = TextPainter(
          text: TextSpan(text: line, style: effectiveStyle),
          textDirection: direction,
          textScaler: MediaQuery.textScalerOf(context),
          locale: Localizations.maybeLocaleOf(context),
          maxLines: 1,
        )..layout();
        final width = painter.width;
        painter.dispose();
        if (constraints.maxWidth <= 0 || width <= constraints.maxWidth) {
          return label;
        }

        return Semantics(
          label: line,
          excludeSemantics: true,
          child: _ScrollingTitle(
            key: ValueKey((line, width, constraints.maxWidth, direction)),
            width: constraints.maxWidth,
            distance: width + _ScrollingTitle.gap,
            label: Text(line, style: style, softWrap: false, maxLines: 1),
          ),
        );
      },
    );
  }
}

class _ScrollingTitle extends StatefulWidget {
  const _ScrollingTitle({
    super.key,
    required this.width,
    required this.distance,
    required this.label,
  });

  static const gap = 24.0;
  final double width;
  final double distance;
  final Widget label;

  @override
  State<_ScrollingTitle> createState() => _ScrollingTitleState();
}

class _ScrollingTitleState extends State<_ScrollingTitle>
    with SingleTickerProviderStateMixin {
  late final _scroll = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: (widget.distance * 1000 / 28).round()),
  )..addStatusListener(_onScrollStatus);
  late Timer _pause;

  @override
  void initState() {
    super.initState();
    _waitBeforeScrolling();
  }

  void _waitBeforeScrolling() {
    _pause = Timer(const Duration(seconds: 1), _scroll.forward);
  }

  void _onScrollStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    _scroll.reset();
    _waitBeforeScrolling();
  }

  @override
  void dispose() {
    _pause.cancel();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final direction = Directionality.of(context) == TextDirection.rtl ? 1 : -1;
    return SizedBox(
      width: widget.width,
      child: ClipRect(
        child: OverflowBox(
          fit: OverflowBoxFit.deferToChild,
          alignment: AlignmentDirectional.centerStart,
          maxWidth: double.infinity,
          child: AnimatedBuilder(
            animation: _scroll,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                widget.label,
                const SizedBox(width: _ScrollingTitle.gap),
                widget.label,
              ],
            ),
            builder: (context, child) => Transform.translate(
              offset: Offset(_scroll.value * widget.distance * direction, 0),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
