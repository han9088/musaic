import 'package:flutter/widgets.dart';

/// Paper and ink colors shared by every Xerox cover in the view.
enum XeroxPalette {
  original(Color(0xffffffff), Color(0xff000000)),
  ivory(Color(0xffe8e4cf), Color(0xff393933)),
  sand(Color(0xffe7d7b5), Color(0xff45341f)),
  sage(Color(0xffd9ded3), Color(0xff3d453a)),
  mist(Color(0xffd9e2e7), Color(0xff34444d));

  const XeroxPalette(this.paper, this.ink);

  final Color paper;
  final Color ink;

  // Gray is the same in all three channels. Use R and keep alpha intact.
  static final _filters = {
    for (final palette in values.skip(1))
      palette: ColorFilter.matrix([
        ..._channel(palette.paper.r, palette.ink.r),
        ..._channel(palette.paper.g, palette.ink.g),
        ..._channel(palette.paper.b, palette.ink.b),
        0,
        0,
        0,
        1,
        0,
      ]),
  };

  static List<double> _channel(double paper, double ink) => [
    paper - ink,
    0,
    0,
    0,
    ink * 255,
  ];

  ColorFilter? get filter => _filters[this];
}

/// Only the Xerox display widgets subscribe to palette changes.
class XeroxPaletteScope extends InheritedNotifier<ValueNotifier<XeroxPalette>> {
  const XeroxPaletteScope({
    super.key,
    required super.notifier,
    required super.child,
  });

  static XeroxPalette of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<XeroxPaletteScope>()
          ?.notifier
          ?.value ??
      XeroxPalette.original;
}
