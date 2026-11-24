import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../artwork/artwork_renderer.dart';

const _bandAngle = -0.18;

enum _BandItem { cover, time }

typedef _HorizontalSpan = ({double left, double right});
typedef _TitleGlyph = ({int start, int end, double left, double right});

class ScreensaverView extends StatefulWidget {
  const ScreensaverView({
    super.key,
    required this.title,
    required this.artwork,
    required this.readPosition,
  });

  final String title;
  final String artwork;
  final Duration? Function() readPosition;

  @override
  State<ScreensaverView> createState() => _ScreensaverViewState();
}

class _ScreensaverViewState extends State<ScreensaverView>
    with SingleTickerProviderStateMixin {
  static const _solidTitleColor = Color(0xFF979797);
  static const _grayscale = ColorFilter.matrix([
    0.2126,
    0.7152,
    0.0722,
    0,
    0,
    0.2126,
    0.7152,
    0.0722,
    0,
    0,
    0.2126,
    0.7152,
    0.0722,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
  ]);

  final _motion = ValueNotifier(0.0);
  final _fill = TextPainter(maxLines: 1);
  final _solid = TextPainter(maxLines: 1);
  final _outline = TextPainter(maxLines: 1);
  final _randomSeed = math.Random().nextInt(1 << 30);
  final _fragments = <(TextPainter, int, int), TextPainter>{};
  List<_TitleGlyph> _glyphs = const [];
  late final ui.Image _titleDotTile;
  late final ui.ImageShader _titleDots;
  ({String title, double fontSize, TextDirection direction, Locale? locale})?
  _typography;
  late final Ticker _ticker = createTicker((elapsed) {
    _motion.value = elapsed.inMicroseconds / Duration.microsecondsPerSecond;
  });
  late int? _playbackSeconds = widget.readPosition()?.inSeconds;
  late final Timer _positionTimer;

  @override
  void initState() {
    super.initState();
    _titleDotTile = _makeTitleDotTile();
    _titleDots = ui.ImageShader(
      _titleDotTile,
      ui.TileMode.repeated,
      ui.TileMode.repeated,
      Matrix4.diagonal3Values(0.25, 0.25, 1).storage,
      filterQuality: FilterQuality.low,
    );
    _positionTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final seconds = widget.readPosition()?.inSeconds;
      if (seconds != _playbackSeconds)
        setState(() => _playbackSeconds = seconds);
    });
  }

  @override
  void didUpdateWidget(ScreensaverView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _playbackSeconds = widget.readPosition()?.inSeconds;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _ticker.stop();
      _motion.value = 0;
    } else if (!_ticker.isActive) {
      _ticker.start();
    }
  }

  @override
  void dispose() {
    _positionTimer.cancel();
    _ticker.dispose();
    _motion.dispose();
    _clearFragments();
    _fill.dispose();
    _solid.dispose();
    _outline.dispose();
    _titleDots.dispose();
    _titleDotTile.dispose();
    super.dispose();
  }

  ui.Image _makeTitleDotTile() {
    final recorder = ui.PictureRecorder();
    Canvas(recorder)
      ..drawRect(
        const Rect.fromLTWH(0, 0, 16, 16),
        Paint()..color = _solidTitleColor,
      )
      ..drawCircle(
        const Offset(8, 8),
        3.4,
        Paint()..color = const Color(0x44000000),
      );
    final picture = recorder.endRecording();
    final tile = picture.toImageSync(16, 16);
    picture.dispose();
    return tile;
  }

  TextStyle _bandTextStyle(double fontSize) => TextStyle(
    inherit: false,
    fontFamily: 'Inter',
    fontWeight: FontWeight.w800,
    fontSize: fontSize,
    letterSpacing: -fontSize * 0.055,
    height: 1,
  );

  void _layoutTitles(BuildContext context, double fontSize) {
    final typography = (
      title: widget.title,
      fontSize: fontSize,
      direction: Directionality.of(context),
      locale: Localizations.maybeLocaleOf(context),
    );
    if (_typography == typography) return;
    _typography = typography;
    _clearFragments();

    final title = widget.title
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .toUpperCase();
    final style = _bandTextStyle(fontSize);
    _fill
      ..textDirection = typography.direction
      ..locale = typography.locale
      ..text = TextSpan(
        text: title,
        style: style.copyWith(foreground: Paint()..shader = _titleDots),
      )
      ..layout();
    _solid
      ..textDirection = typography.direction
      ..locale = typography.locale
      ..text = TextSpan(
        text: title,
        style: style.copyWith(color: _solidTitleColor),
      )
      ..layout();
    _outline
      ..textDirection = typography.direction
      ..locale = typography.locale
      ..text = TextSpan(
        text: title,
        style: style.copyWith(
          foreground: Paint()
            ..color = const Color(0xFF575757)
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(1, fontSize * 0.008),
        ),
      )
      ..layout();
    _glyphs = _measureGlyphs(title);
  }

  List<_TitleGlyph> _measureGlyphs(String title) {
    final glyphs = <_TitleGlyph>[];
    var start = 0;
    for (final character in title.characters) {
      final end = start + character.length;
      final boxes = _fill.getBoxesForSelection(
        TextSelection(baseOffset: start, extentOffset: end),
      );
      if (boxes.isNotEmpty) {
        glyphs.add((
          start: start,
          end: end,
          left: boxes.map((box) => box.left).reduce(math.min),
          right: boxes.map((box) => box.right).reduce(math.max),
        ));
      }
      start = end;
    }
    return glyphs;
  }

  void _clearFragments() {
    for (final fragment in _fragments.values) {
      fragment.dispose();
    }
    _fragments.clear();
  }

  TextPainter _titleFragment(TextPainter title, int start, int end) {
    final key = (title, start, end);
    if (_fragments[key] case final fragment?) return fragment;
    if (_fragments.length >= 48) {
      _fragments.remove(_fragments.keys.first)!.dispose();
    }
    final span = title.text! as TextSpan;
    return _fragments[key] = TextPainter(
      text: TextSpan(text: span.text!.substring(start, end), style: span.style),
      textDirection: title.textDirection,
      locale: title.locale,
      maxLines: 1,
    )..layout();
  }

  String _formatTime(int elapsed) {
    final seconds = math.max(0, elapsed);
    final minutes = seconds ~/ 60;
    final remainder = (seconds % 60).toString().padLeft(2, '0');
    if (minutes < 60) return '$minutes:$remainder';
    return '${minutes ~/ 60}:${(minutes % 60).toString().padLeft(2, '0')}:$remainder';
  }

  Widget _placeOnBand(_BandLayout bands, _BandItem item, Widget child) =>
      Center(
        child: AnimatedBuilder(
          animation: _motion,
          builder: (_, child) => Transform.rotate(
            angle: _bandAngle,
            child: Transform.translate(
              offset: bands.positionOf(item, _motion.value).offset,
              child: child,
            ),
          ),
          child: child,
        ),
      );

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.black,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        if (size.isEmpty) return const SizedBox.shrink();
        final shortSide = size.shortestSide;
        final fontSize = math.min(shortSide * 0.40, 250.0);
        _layoutTitles(context, fontSize);
        final position = _playbackSeconds;
        final bands = _BandLayout(
          size,
          fontSize,
          _fill.height,
          showTime: position != null,
          randomSeed: _randomSeed,
        );

        return Stack(
          fit: StackFit.expand,
          children: [
            RepaintBoundary(
              child: CustomPaint(
                painter: _TitleBands(
                  motion: _motion,
                  titleStyles: [_fill, _solid, _outline],
                  glyphs: _glyphs,
                  titleFragment: _titleFragment,
                  layout: bands,
                ),
              ),
            ),
            _placeOnBand(
              bands,
              _BandItem.cover,
              RepaintBoundary(
                child: ColorFiltered(
                  colorFilter: _grayscale,
                  child: albumArtwork(
                    widget.artwork,
                    width: bands.coverSide,
                    height: bands.coverSide,
                    fit: BoxFit.cover,
                    excludeFromSemantics: true,
                    prepareXerox: false,
                  ),
                ),
              ),
            ),
            if (position != null)
              _placeOnBand(
                bands,
                _BandItem.time,
                SizedBox(
                  width: bands.timeWidth,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      _formatTime(position),
                      textDirection: TextDirection.ltr,
                      textScaler: TextScaler.noScaling,
                      style: _bandTextStyle(fontSize * 0.34).copyWith(
                        color: const Color(0xFFACACAC),
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    ),
  );
}

class _BandLayout {
  const _BandLayout(
    this.size,
    this.fontSize,
    this.lineHeight, {
    required this.showTime,
    required this.randomSeed,
  });

  static const _scrollSpeed = 29.0;

  final Size size;
  final double fontSize;
  final double lineHeight;
  final bool showTime;
  final int randomSeed;

  double get halfWidth => size.width / 2 + size.height * 0.11;
  double get rowHeight => lineHeight * 0.87;
  double get coverSide => lineHeight * 0.75;
  double get itemSpacing => fontSize * 0.045;
  double get timeWidth => fontSize * 0.95;
  double get coverSlotWidth => coverSide + itemSpacing * 2;
  double get timeSlotWidth => timeWidth + itemSpacing * 2;
  double get cycleWidth =>
      halfWidth * 2 + math.max(coverSlotWidth, timeSlotWidth);

  int _rowDirection(int row) => row.isEven ? -1 : 1;

  double rowSpeed(int row) => _scrollSpeed * _rowDirection(row);

  double rowTop(int row, double elapsed) =>
      row * rowHeight +
      math.sin(elapsed * 0.16) * rowHeight * 0.22 +
      math.sin(elapsed * 0.19 + row * 0.73) * rowHeight * 0.07;

  ({int row, Offset offset}) positionOf(_BandItem item, double elapsed) {
    final halfCycle = cycleWidth / 2;
    final spacing = (coverSlotWidth + timeSlotWidth) / 2 + itemSpacing;
    // Keep the slots apart even when they choose the same row.
    final stagger = (item == _BandItem.cover ? -spacing : spacing) / 2;
    final travel = halfCycle + stagger + elapsed * _scrollSpeed;
    final pass = (travel / cycleWidth).floor();
    final rowPairs = math.max(
      1,
      (size.height / (2 * math.max(1.0, rowHeight)) - 0.35).floor(),
    );
    final itemSeed = Object.hash(randomSeed, item);
    // Alternate between the two row sets so the next pass always changes rows.
    final row =
        -rowPairs +
        (Object.hash(itemSeed, pass) % rowPairs) * 2 +
        (pass + itemSeed) % 2;
    return (
      row: row,
      offset: Offset(
        (travel % cycleWidth - halfCycle) * _rowDirection(row),
        rowTop(row, elapsed) + lineHeight / 2,
      ),
    );
  }
}

class _TitleBands extends CustomPainter {
  _TitleBands({
    required this.motion,
    required this.titleStyles,
    required this.glyphs,
    required this.titleFragment,
    required this.layout,
  }) : super(repaint: motion);

  final ValueListenable<double> motion;
  final List<TextPainter> titleStyles;
  final List<_TitleGlyph> glyphs;
  final TextPainter Function(TextPainter, int, int) titleFragment;
  final _BandLayout layout;
  @override
  void paint(Canvas canvas, Size size) {
    final fill = titleStyles.first;
    if (fill.width <= 0 || layout.rowHeight <= 0) return;
    final elapsed = motion.value;
    final step = fill.width + layout.fontSize * 0.20;
    final halfWidth = layout.halfWidth;
    final halfHeight = size.height / 2 + size.width * 0.11;
    final rows = (halfHeight / layout.rowHeight).ceil() + 1;
    final cover = layout.positionOf(_BandItem.cover, elapsed);
    final time = layout.showTime
        ? layout.positionOf(_BandItem.time, elapsed)
        : null;

    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(_bandAngle);
    for (var row = -rows; row <= rows; row++) {
      final origin = row * step * 0.43 + elapsed * layout.rowSpeed(row);
      final first = ((-halfWidth - origin) / step).floor();
      final last = ((halfWidth - origin) / step).floor();
      final y = layout.rowTop(row, elapsed);
      final containsCover = row == cover.row;
      final containsTime = row == time?.row;
      final gaps = containsCover || containsTime
          ? ([
              if (containsCover) _slot(cover.offset.dx, layout.coverSlotWidth),
              if (containsTime) _slot(time!.offset.dx, layout.timeSlotWidth),
            ]..sort((a, b) => a.left.compareTo(b.left)))
          : null;
      for (var index = first; index <= last; index++) {
        final style =
            Object.hash(layout.randomSeed, row, index) % titleStyles.length;
        final title = titleStyles[style];
        final offset = Offset(origin + index * step, y);
        if (gaps == null) {
          title.paint(canvas, offset);
        } else {
          _paintAroundSlots(canvas, title, offset, gaps);
        }
      }
    }
    canvas.restore();
  }

  _HorizontalSpan _slot(double center, double width) =>
      (left: center - width / 2, right: center + width / 2);

  void _paintAroundSlots(
    Canvas canvas,
    TextPainter title,
    Offset offset,
    List<_HorizontalSpan> gaps,
  ) {
    var left = double.negativeInfinity;
    for (final gap in gaps) {
      if (gap.right <= offset.dx) continue;
      if (gap.left >= offset.dx + title.width) break;
      _paintTitleInSpan(canvas, title, offset, left, gap.left);
      left = math.max(left, gap.right);
    }
    _paintTitleInSpan(canvas, title, offset, left, double.infinity);
  }

  void _paintTitleInSpan(
    Canvas canvas,
    TextPainter title,
    Offset offset,
    double left,
    double right,
  ) {
    final titleRight = offset.dx + title.width;
    if (right <= left || titleRight <= left || offset.dx >= right) return;
    if (offset.dx >= left && titleRight <= right) {
      title.paint(canvas, offset);
      return;
    }

    // Draw only complete grapheme runs beside the reserved space.
    var start = -1;
    var end = 0;
    var runLeft = double.infinity;
    void paintRun() {
      final fragment = titleFragment(title, start, end);
      if (fragment.width <= right - left) {
        final x = runLeft.clamp(left, right - fragment.width).toDouble();
        fragment.paint(canvas, Offset(x, offset.dy));
      }
      start = -1;
      runLeft = double.infinity;
    }

    for (final glyph in glyphs) {
      final glyphLeft = offset.dx + glyph.left;
      if (glyphLeft >= left && offset.dx + glyph.right <= right) {
        if (start < 0) start = glyph.start;
        end = glyph.end;
        runLeft = math.min(runLeft, glyphLeft);
      } else if (start >= 0) {
        paintRun();
      }
    }
    if (start >= 0) paintRun();
  }

  @override
  bool shouldRepaint(_TitleBands oldDelegate) => true;
}
