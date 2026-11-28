// Paints the repeating album grid without creating a widget for each cell.
import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'album_artwork_atlas.dart';
import 'album_grid_snapshot.dart';
import 'album_tile_motion.dart';
import 'portrait_tilt.dart';

typedef _Cell = (int row, int column);
typedef _GridRange = ({int left, int top, int right, int bottom});

class AlbumSpriteCanvas extends SingleChildRenderObjectWidget {
  const AlbumSpriteCanvas({
    super.key,
    super.child,
    required this.viewport,
    required this.tiltPadding,
    required this.transform,
    required this.atlas,
    required this.albumAt,
    required this.titleAt,
    required this.onTileSelected,
    required this.longPressAt,
    this.selected,
    this.hidden,
    this.liftedCells,
    this.tileMotion,
  });

  final Size viewport;
  final Offset tiltPadding;
  final TransformationController transform;
  final CanvasArtworkAtlas atlas;
  final Object Function(int row, int column) albumAt;
  final String Function(int row, int column) titleAt;
  final void Function(int row, int column) onTileSelected;
  final GestureLongPressStartCallback? Function(int row, int column)
  longPressAt;
  final (int, int)? selected;
  final (int, int)? hidden;
  // Non-null when the child is a viewport-sized overlay in scene coordinates.
  final Set<(int, int)>? liftedCells;
  final AlbumTileMotion? tileMotion;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderAlbumSprites(this, Directionality.of(context));

  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderProxyBox renderObject,
  ) => (renderObject as _RenderAlbumSprites).update(
    this,
    Directionality.of(context),
  );
}

class _RenderAlbumSprites extends RenderProxyBox {
  _RenderAlbumSprites(this._view, this._direction);

  AlbumSpriteCanvas _view;
  TextDirection _direction;
  final _gestures = <int, List<GestureRecognizer>>{};
  Map<Object, _Cell> _representatives = {};
  Map<_Cell, SemanticsNode> _semanticNodes = {};
  (_GridRange, _GridRange)? _semanticCoverage;

  void update(AlbumSpriteCanvas view, TextDirection direction) {
    final old = _view;
    final motionChanged = !identical(old.tileMotion, view.tileMotion);
    if (attached && motionChanged) _unlistenMotion(old.tileMotion);
    _view = view;
    if (attached && motionChanged) _listenMotion(view.tileMotion);
    _direction = direction;
    if (old.viewport != view.viewport ||
        (old.liftedCells == null) != (view.liftedCells == null)) {
      markNeedsLayout();
    }
    if (!identical(old.atlas, view.atlas)) _representatives.clear();
    _semanticCoverage = null;
    markNeedsPaint();
    markNeedsSemanticsUpdate();
  }

  void _listenMotion(AlbumTileMotion? motion) {
    motion?.addListener(markNeedsPaint);
    motion?.commits.addListener(_motionCommitted);
  }

  void _unlistenMotion(AlbumTileMotion? motion) {
    motion?.removeListener(markNeedsPaint);
    motion?.commits.removeListener(_motionCommitted);
  }

  void _motionCommitted() {
    _semanticCoverage = null;
    markNeedsSemanticsUpdate();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _listenMotion(_view.tileMotion);
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) =>
      constraints.constrain(_view.viewport);

  @override
  void performLayout() {
    size = computeDryLayout(constraints);
    child?.layout(
      _view.liftedCells != null
          ? BoxConstraints.tight(size)
          : const BoxConstraints.tightFor(
              width: albumGridExtent,
              height: albumGridExtent,
            ),
    );
  }

  static Offset _offset(_Cell cell) =>
      Offset(cell.$2 * albumGridExtent, cell.$1 * albumGridExtent);

  static const _tileSize = Size.square(albumGridExtent);

  Offset get _selectedOffset =>
      _view.selected == null || _view.liftedCells != null
      ? Offset.zero
      : _offset(_view.selected!);

  Rect _sceneViewport(Offset padding) {
    final matrix = _view.transform.value;
    final scale = matrix.getColumn(0).length;
    final x = matrix.entry(0, 3);
    final y = matrix.entry(1, 3);
    return Rect.fromLTRB(
      (-padding.dx - x) / scale,
      (-padding.dy - y) / scale,
      (size.width + padding.dx - x) / scale,
      (size.height + padding.dy - y) / scale,
    );
  }

  static _GridRange _intersections(Rect rect) => (
    left: (rect.left / albumGridExtent).floor(),
    top: (rect.top / albumGridExtent).floor(),
    right: (rect.right / albumGridExtent).ceil(),
    bottom: (rect.bottom / albumGridExtent).ceil(),
  );

  static _GridRange _centers(Rect rect) => (
    left: (rect.left / albumGridExtent - .5).ceil(),
    top: (rect.top / albumGridExtent - .5).ceil(),
    right: (rect.right / albumGridExtent - .5).ceil(),
    bottom: (rect.bottom / albumGridExtent - .5).ceil(),
  );

  @override
  void paint(PaintingContext context, Offset offset) {
    final viewport = _sceneViewport(_view.tiltPadding);
    final range = _intersections(viewport);
    if (owner?.semanticsOwner != null &&
        _semanticCoverage !=
            (range, _centers(_sceneViewport(-_view.tiltPadding)))) {
      markNeedsSemanticsUpdate();
    }

    final atlas = _view.atlas;
    final canvas = context.canvas;
    final motion = _view.tileMotion?.isActive == true ? _view.tileMotion : null;
    motion?.paintBehind(canvas, offset);
    // Keep atlas vertices near the origin even after a long pan.
    final origin = _offset((range.top, range.left));
    canvas.save();
    canvas.translate(offset.dx + origin.dx, offset.dy + origin.dy);
    atlas.begin();
    for (var row = range.top; row < range.bottom; row++) {
      for (var column = range.left; column < range.right; column++) {
        if ((row, column) == _view.hidden ||
            (motion != null && motion.owns((row, column)))) {
          continue;
        }
        atlas.add(
          _view.albumAt(row, column),
          _offset((row - range.top, column - range.left)),
        );
      }
    }
    atlas.draw(canvas);
    canvas.restore();
    motion?.paintAbove(canvas, offset);

    if (child != null &&
        (_view.liftedCells != null || _view.selected != _view.hidden)) {
      context.paintChild(child!, offset + _selectedOffset);
    }
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    final offset = _selectedOffset;
    transform.translateByDouble(offset.dx, offset.dy, 0, 1);
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    final viewportPosition = position;
    if (result is TiltEdgeHitTestResult) {
      position +=
          result.viewportDelta / _view.transform.value.getColumn(0).length;
    }
    if (child != null &&
        (_view.liftedCells != null || _view.selected != _view.hidden) &&
        result.addWithPaintOffset(
          offset: _selectedOffset,
          position: _view.liftedCells != null ? viewportPosition : position,
          hitTest: (result, local) => child!.hitTest(result, position: local),
        )) {
      return true;
    }
    result.add(BoxHitTestEntry(this, position));
    return true;
  }

  @override
  void handleEvent(PointerEvent event, covariant BoxHitTestEntry entry) {
    if (event is PointerDownEvent) {
      final row = (entry.localPosition.dy / albumGridExtent).floor();
      final column = (entry.localPosition.dx / albumGridExtent).floor();
      if ((row, column) == _view.hidden) return;
      final tap = TapGestureRecognizer(debugOwner: this)
        ..onTap = () => _view.onTileSelected(row, column);
      final longPress = _view.longPressAt(row, column);
      final recognizers = <GestureRecognizer>[
        tap,
        if (longPress != null)
          LongPressGestureRecognizer(debugOwner: this)
            ..onLongPressStart = longPress,
      ];
      _gestures[event.pointer] = recognizers;
      for (final recognizer in recognizers) {
        recognizer.addPointer(event);
      }
    } else if (event is PointerUpEvent || event is PointerCancelEvent) {
      // Let Flutter finish this pointer's gesture arena before releasing it.
      scheduleMicrotask(() => _disposeGesture(event.pointer));
    }
  }

  void _disposeGesture(int pointer) {
    final recognizers = _gestures.remove(pointer);
    if (recognizers == null) return;
    for (final recognizer in recognizers) {
      recognizer.dispose();
    }
  }

  @override
  void detach() {
    _unlistenMotion(_view.tileMotion);
    for (final pointer in _gestures.keys.toList()) {
      _disposeGesture(pointer);
    }
    super.detach();
  }

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    config.isSemanticBoundary = true;
    config.explicitChildNodes = true;
  }

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    if (_view.liftedCells != null || _view.selected != _view.hidden) {
      super.visitChildrenForSemantics(visitor);
    }
  }

  @override
  void assembleSemanticsNode(
    SemanticsNode node,
    SemanticsConfiguration config,
    Iterable<SemanticsNode> children,
  ) {
    final viewport = _sceneViewport(_view.tiltPadding);
    final inner = _sceneViewport(-_view.tiltPadding);
    final range = _intersections(viewport);
    final coverage = (range, _centers(inner));
    if (_semanticCoverage != coverage) {
      _semanticCoverage = coverage;
      _rebuildSemanticCells(viewport, inner, range);
    }
    super.assembleSemanticsNode(node, config, [
      ..._semanticNodes.values,
      ...children,
    ]);
  }

  void _rebuildSemanticCells(Rect viewport, Rect inner, _GridRange range) {
    final cells = <_Cell>[];
    final representatives = <Object, _Cell>{};
    final distances = <Object, double>{};
    final albumByCell = <_Cell, Object>{};
    final center = viewport.center;
    final groupRepeated = _view.selected == null && _view.hidden == null;
    for (var row = range.top; row < range.bottom; row++) {
      for (var column = range.left; column < range.right; column++) {
        final cell = (row, column);
        if (cell == _view.hidden || _view.liftedCells?.contains(cell) == true) {
          continue;
        }
        cells.add(cell);
        if (!groupRepeated) continue;
        final album = _view.albumAt(row, column);
        albumByCell[cell] = album;
        final cellCenter = _tileSize.center(_offset(cell));
        if (!inner.contains(cellCenter)) continue;
        final distance = _representatives[album] == cell
            ? -1.0
            : (cellCenter - center).distanceSquared;
        if (distance < (distances[album] ?? double.infinity)) {
          representatives[album] = cell;
          distances[album] = distance;
        }
      }
    }
    _representatives = representatives;
    final next = <_Cell, SemanticsNode>{};
    for (final cell in cells) {
      final representative = representatives[albumByCell[cell]];
      if (representative != null && representative != cell) continue;
      final semantics = _semanticNodes[cell] ?? SemanticsNode();
      final rect = _offset(cell) & _tileSize;
      final longPress = _view.longPressAt(cell.$1, cell.$2);
      final configuration = SemanticsConfiguration()
        ..isImage = true
        ..textDirection = _direction
        ..label = _view.titleAt(cell.$1, cell.$2)
        ..onTap = () => _view.onTileSelected(cell.$1, cell.$2);
      if (longPress != null) {
        configuration.onLongPress = () => longPress(
          LongPressStartDetails(
            globalPosition: localToGlobal(rect.center),
            localPosition: rect.center,
          ),
        );
      }
      semantics
        ..rect = rect
        ..updateWith(
          config: configuration,
          childrenInInversePaintOrder: const [],
        );
      next[cell] = semantics;
    }
    _semanticNodes = next;
  }

  @override
  void clearSemantics() {
    _semanticCoverage = null;
    _semanticNodes.clear();
    _representatives.clear();
    super.clearSemantics();
  }
}
