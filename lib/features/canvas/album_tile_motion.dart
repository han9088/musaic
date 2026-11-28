// 文件职责：调度画布磁贴动效，并在同一绘制流程中提交专辑格位。
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../artwork/presentation/album_color_family.dart';
import 'album_folder_reveal.dart';
import 'album_grid_snapshot.dart';
import 'album_tile_motion_artwork.dart';

typedef _Album = Map<String, dynamic>;
typedef _Pair = (AlbumGridCell, AlbumGridCell);

enum _Effect { flip, swap, folder }

class AlbumTileMotion extends ChangeNotifier {
  AlbumTileMotion({
    required TickerProvider vsync,
    required this.albumAt,
    required this.albumKey,
    required this.familyOf,
    required this.isProtected,
    required this.borrowCover,
    required this.isCurrent,
    required this.commit,
  }) {
    _ticker = vsync.createTicker(_tick);
    _playOrder.shuffle(_random);
  }

  static const _duration = Duration(milliseconds: 1800);
  static const _motionCurve = Cubic(.4, 0, .2, 1);
  static const _attemptIntervalMinMs = 1200;
  static const _attemptIntervalMaxMs = 1700;
  static const _overlapChance = .50;
  static const _thirdEffectChance = .02;
  static const _maxLayoutAttempts = 4;
  // 参考是 600px 透视及 12px/24px 阴影，相对于演示的 200px 磁贴。
  static const _eyeDistance = albumGridExtent * 3;
  static const _shadowOffset = albumGridExtent * .06;
  static const _shadowBlur = albumGridExtent * .12;
  static const _depthStart = .22;
  static const _depthEnd = .78;
  static const _lowerScale = .85;
  static const _upperScale = 1.22;

  final _Album Function(AlbumGridCell) albumAt;
  final Object Function(_Album) albumKey;
  final AlbumColorFamily? Function(_Album) familyOf;
  final bool Function(AlbumGridCell) isProtected;
  final AlbumTileMotionCover? Function(_Album) borrowCover;
  final bool Function() isCurrent;
  final void Function(AlbumGridCell, _Album) commit;
  final commits = ValueNotifier<Set<AlbumGridCell>>(const {});
  final _random = math.Random();
  final _playOrder = _Effect.values.toList();
  final _runs = <_Effect, _Run>{};
  final _owned = <AlbumGridCell>{};
  final _shadow = Paint();
  late final Ticker _ticker;
  Timer? _attemptTimer;
  Timer? _folderHold;
  Duration _elapsed = Duration.zero;
  Rect _viewport = Rect.zero;
  Matrix4? _sceneToViewport;
  AlbumGridCell? _visibleAnchor;

  void updateViewport(Size viewport, Matrix4 sceneToViewport) {
    _viewport = Offset.zero & viewport;
    _sceneToViewport = sceneToViewport;
    if (viewport.isEmpty) {
      pause();
      return;
    }
    var cancelled = false;
    for (final effect in _Effect.values) {
      final run = _runs[effect];
      if (run == null || run.cells.every(_isVisible)) continue;
      _end(run);
      cancelled = true;
    }
    if (cancelled) notifyListeners();
    if (_visibleAnchor == null || !_isVisible(_visibleAnchor!)) {
      final visible = _visibleCells.iterator;
      _visibleAnchor = visible.moveNext() ? visible.current : null;
    }
    if (_visibleAnchor == null) {
      pause();
    } else {
      _arm();
    }
  }

  bool _isVisible(AlbumGridCell cell) =>
      AlbumGridSnapshot.isFullyVisible(cell, _viewport, _sceneToViewport!);

  Iterable<AlbumGridCell> get _visibleCells =>
      AlbumGridSnapshot.fullyVisibleCells(_viewport, _sceneToViewport!);

  void _arm() {
    if (_visibleAnchor == null || _attemptTimer != null) return;
    final delay =
        _attemptIntervalMinMs +
        _random.nextInt(_attemptIntervalMaxMs - _attemptIntervalMinMs + 1);
    _attemptTimer = Timer(Duration(milliseconds: delay), () {
      _attemptTimer = null;
      try {
        _tryNextEffect();
      } finally {
        _arm();
      }
    });
  }

  void _tryNextEffect() {
    if (!isCurrent()) {
      pause();
      return;
    }
    final visible = _visibleCells.toList();
    if (visible.isEmpty || _runs.length == _Effect.values.length) return;
    final overlapChance = _runs.length == 2
        ? _thirdEffectChance
        : _overlapChance;
    if (_runs.isNotEmpty && _random.nextDouble() >= overlapChance) return;

    // 优先尝试最久没播的类型，成功播放后才移到末尾。
    for (var i = 0; i < _playOrder.length; i++) {
      final effect = _playOrder[i];
      if (_runs.containsKey(effect)) continue;
      _tryStart(effect, visible);
      if (_runs.containsKey(effect)) {
        _playOrder.add(_playOrder.removeAt(i));
        return;
      }
    }
  }

  bool _available(AlbumGridCell cell, _Effect effect) =>
      !isProtected(cell) &&
      !_owned.contains(cell) &&
      !_neighbors(cell).any(_owned.contains) &&
      !_conflictsWithFolder(cell, effect);

  bool _conflictsWithFolder(AlbumGridCell cell, _Effect effect) {
    if (_runs.isEmpty) return false;
    if (effect != _Effect.folder && !_runs.containsKey(_Effect.folder)) {
      return false;
    }
    final area = _paintArea(cell, effect);
    // 用完整轨迹的保守范围预留透视外沿及阴影，包括斜邻格的交角。
    return _runs.values.any(
      (run) =>
          (effect == _Effect.folder || run.effect == _Effect.folder) &&
          run.cells.any(
            (other) => area.overlaps(_paintArea(other, run.effect)),
          ),
    );
  }

  static Rect _paintArea(AlbumGridCell cell, _Effect effect) {
    final margin = switch (effect) {
      _Effect.flip => .11,
      _Effect.swap => .36,
      _Effect.folder => .14,
    };
    return albumGridRect(cell).inflate(albumGridExtent * margin);
  }

  static Iterable<AlbumGridCell> _neighbors(AlbumGridCell cell) sync* {
    final (row, column) = cell;
    yield (row - 1, column);
    yield (row + 1, column);
    yield (row, column - 1);
    yield (row, column + 1);
  }

  bool _different(_Album a, _Album b) =>
      albumKey(a) != albumKey(b) && a['asset'] != b['asset'];

  int? _colorCost(_Album album, AlbumGridCell cell, [AlbumGridCell? other]) {
    final family = familyOf(album);
    if (family == null) return null;
    var cost = 0;
    for (final neighbor in _neighbors(cell)) {
      if (neighbor == other) continue;
      final adjacent = albumAt(neighbor);
      if (!_different(album, adjacent)) return null;
      if (family == familyOf(adjacent)) cost++;
    }
    return cost;
  }

  void _tryStart(_Effect effect, List<AlbumGridCell> visible) {
    final cells = visible.where((cell) => _available(cell, effect)).toList()
      ..shuffle(_random);
    if (cells.isEmpty) return;
    final pool = <Object, _Album>{};
    if (effect != _Effect.swap) {
      // 专辑夹的目标仍须完整可见，内页可借用屏幕边缘已加载的封面。
      final candidates = effect == _Effect.folder
          ? AlbumGridSnapshot.intersectingCells(_viewport, _sceneToViewport!)
          : cells;
      for (final cell in candidates) {
        final album = albumAt(cell);
        if (effect == _Effect.folder || familyOf(album) != null) {
          pool[albumKey(album)] = album;
        }
      }
    }
    final covers = <_Album, AlbumTileMotionCover?>{};
    bool ready(_Album album) =>
        (covers.containsKey(album)
            ? covers[album]
            : covers[album] = borrowCover(album)) !=
        null;
    try {
      final plan = switch (effect) {
        _Effect.flip => _planFlip(cells, pool.values, ready),
        _Effect.swap => _planSwap(cells, ready),
        _Effect.folder => _planFolder(
          cells,
          pool.values.toList()..shuffle(_random),
          ready,
        ),
      };
      if (plan == null) return;
      assert(
        plan.cells.every(
          (cell) => _isVisible(cell) && _available(cell, effect),
        ),
      );
      assert(plan.albums.every((album) => covers[album] != null));
      final faces = [for (final album in plan.albums) covers.remove(album)!];
      final run = _Run(
        effect,
        plan.cells,
        plan.albums,
        faces,
        _ticker.isActive ? _elapsed : Duration.zero,
        folder: effect == _Effect.folder ? AlbumFolderReveal() : null,
      );
      // 占用格位及其邻接色系判断在同一同步阶段完成。
      _runs[effect] = run;
      _owned.addAll(run.cells);
      _syncTicker();
      notifyListeners();
    } catch (error) {
      debugPrint('Album tile motion could not start: $error');
    } finally {
      for (final cover in covers.values) {
        cover?.release();
      }
    }
  }

  ({List<AlbumGridCell> cells, List<_Album> albums})? _planFolder(
    List<AlbumGridCell> cells,
    List<_Album> pool,
    bool Function(_Album) ready,
  ) {
    if (pool.length < AlbumFolderReveal.panelCount) return null;
    for (final cell in cells.take(_maxLayoutAttempts)) {
      final front = albumAt(cell);
      if (!ready(front)) continue;
      final albums = [front];
      final usedFamilies = {familyOf(front)};
      final adjacentFamilies = {
        for (final neighbor in _neighbors(cell)) familyOf(albumAt(neighbor)),
      };
      while (albums.length < AlbumFolderReveal.panelCount) {
        final next = _pickCover(pool, ready, (album) {
          if (albums.any((used) => !_different(used, album))) return null;
          final family = familyOf(album);
          if (family == null) return 2;
          return (usedFamilies.contains(family) ? 3 : 0) +
              (adjacentFamilies.contains(family) ? 1 : 0);
        });
        if (next == null) break;
        albums.add(next);
        usedFamilies.add(familyOf(next));
      }
      if (albums.length == AlbumFolderReveal.panelCount) {
        return (cells: [cell], albums: albums);
      }
    }
    return null;
  }

  ({List<AlbumGridCell> cells, List<_Album> albums})? _planFlip(
    List<AlbumGridCell> cells,
    Iterable<_Album> pool,
    bool Function(_Album) ready,
  ) {
    for (final cell in cells.take(_maxLayoutAttempts)) {
      final front = albumAt(cell);
      if (familyOf(front) == null) continue;
      final back = _pickCover(pool, ready, (album) {
        if (!_different(front, album)) return null;
        final cost = _colorCost(album, cell);
        return cost == null
            ? null
            : cost + (familyOf(front) == familyOf(album) ? 1 : 0);
      });
      if (back != null && ready(front)) {
        return (cells: [cell], albums: [front, back]);
      }
    }
    return null;
  }

  ({List<AlbumGridCell> cells, List<_Album> albums})? _planSwap(
    List<AlbumGridCell> cells,
    bool Function(_Album) ready,
  ) {
    final available = cells.toSet();
    final pairs = <_Pair>[
      for (final cell in cells) ...[
        if (available.contains((cell.$1, cell.$2 + 1)))
          (cell, (cell.$1, cell.$2 + 1)),
        if (available.contains((cell.$1 + 1, cell.$2)))
          (cell, (cell.$1 + 1, cell.$2)),
      ],
    ]..shuffle(_random);
    ({List<AlbumGridCell> cells, List<_Album> albums})? best;
    var bestCost = 1 << 30;
    for (final (first, second) in pairs) {
      final a = albumAt(first);
      final b = albumAt(second);
      if (!_different(a, b)) continue;
      final firstCost = _colorCost(b, first, second);
      final secondCost = _colorCost(a, second, first);
      if (firstCost == null || secondCost == null) continue;
      final cost =
          firstCost + secondCost + (familyOf(a) == familyOf(b) ? 1 : 0);
      if (cost >= bestCost || !ready(a) || !ready(b)) continue;
      bestCost = cost;
      best = _random.nextBool()
          ? (cells: [first, second], albums: [a, b])
          : (cells: [second, first], albums: [b, a]);
      if (cost == 0) break;
    }
    return best;
  }

  _Album? _pickCover(
    Iterable<_Album> pool,
    bool Function(_Album) ready,
    int? Function(_Album) costOf,
  ) {
    _Album? best;
    var bestCost = 1 << 30;
    for (final album in pool) {
      final cost = costOf(album);
      if (cost == null || cost >= bestCost || !ready(album)) continue;
      best = album;
      bestCost = cost;
      if (cost == 0) break;
    }
    return best;
  }

  void _tick(Duration elapsed) {
    if (!isCurrent()) {
      pause();
      return;
    }
    _elapsed = elapsed;
    final changed = <AlbumGridCell>{};
    for (final effect in _Effect.values) {
      final run = _runs[effect];
      if (run == null) continue;
      if (!run.cells.every(_isVisible)) {
        _end(run);
        continue;
      }
      final folder = run.folder;
      if (folder != null) {
        if (_folderHold != null) continue;
        final age = folder.age;
        if (age < AlbumFolderReveal.duration) {
          run.progress = AlbumFolderReveal.opennessAt(age);
          if (age >= AlbumFolderReveal.openEnd &&
              age < AlbumFolderReveal.closeStart) {
            // 停留时只保留一张静止画面，定时唤醒同一个 Ticker 合拢。
            _folderHold = Timer(AlbumFolderReveal.closeStart - age, () {
              _folderHold = null;
              _syncTicker();
            });
            _syncTicker();
          }
          continue;
        }
      } else {
        final age = elapsed - run.start;
        if (age < _duration) {
          run.progress = _motionCurve.transform(
            age.inMicroseconds / _duration.inMicroseconds,
          );
          continue;
        }
        commit(run.cells.first, run.albums.last);
        if (effect == _Effect.swap) commit(run.cells.last, run.albums.first);
        changed.addAll(run.cells);
      }
      _end(run, afterPaint: true);
    }
    if (changed.isNotEmpty) commits.value = changed;
    notifyListeners();
  }

  void _syncTicker() {
    final needsFrames =
        _runs.isNotEmpty && (_folderHold == null || _runs.length > 1);
    if (!needsFrames) {
      _ticker.stop();
    } else if (!_ticker.isActive) {
      _elapsed = Duration.zero;
      _ticker.start();
    }
  }

  void _end(_Run run, {bool afterPaint = false}) {
    _runs.remove(run.effect);
    _owned.removeAll(run.cells);
    if (run.folder != null) {
      _folderHold?.cancel();
      _folderHold = null;
    }
    _syncTicker();
    if (afterPaint) {
      SchedulerBinding.instance.addPostFrameCallback((_) => run.release());
    } else {
      run.release();
    }
  }

  void pause() {
    _visibleAnchor = null;
    _attemptTimer?.cancel();
    _attemptTimer = null;
    if (_runs.isEmpty) return;
    // 生命周期离开时同步撤销临时图层，并释放所有格位占用。
    for (final run in _runs.values.toList()) {
      _end(run);
    }
    notifyListeners();
  }

  bool get isActive => _runs.isNotEmpty;

  bool owns(AlbumGridCell cell) => _owned.contains(cell);

  void paintBehind(Canvas canvas, Offset offset) {
    final swap = _runs[_Effect.swap];
    if (swap != null) _paintSwap(canvas, offset, swap, raised: false);
  }

  void paintAbove(Canvas canvas, Offset offset) {
    final flip = _runs[_Effect.flip];
    if (flip != null) _paintFlip(canvas, offset, flip);
    final swap = _runs[_Effect.swap];
    if (swap != null) _paintSwap(canvas, offset, swap, raised: true);
    final folder = _runs[_Effect.folder];
    if (folder != null) {
      folder.folder!.paint(
        canvas,
        albumGridRect(folder.cells.first).shift(offset),
        folder.progress,
        folder.covers,
      );
    }
  }

  void _paintSwap(
    Canvas canvas,
    Offset offset,
    _Run run, {
    required bool raised,
  }) {
    final from = albumGridRect(raised ? run.cells.last : run.cells.first)
        .shift(offset);
    final to = albumGridRect(raised ? run.cells.first : run.cells.last)
        .shift(offset);
    final move = ((run.progress - _depthStart) / (_depthEnd - _depthStart))
        .clamp(0.0, 1.0);
    final depth = run.progress < _depthStart
        ? run.progress / _depthStart
        : ((1 - run.progress) / (1 - _depthEnd)).clamp(0.0, 1.0);
    final scale = lerpDouble(1, raised ? _upperScale : _lowerScale, depth)!;
    final rect = Rect.fromCenter(
      center: Offset.lerp(from.center, to.center, move)!,
      width: albumGridExtent * scale,
      height: albumGridExtent * scale,
    );
    if (raised && depth > 0) {
      _shadow
        ..color = const Color(0xff000000).withValues(alpha: .65 * depth)
        ..maskFilter = MaskFilter.blur(
          BlurStyle.normal,
          _shadowBlur * depth / 2,
        );
      canvas.drawRect(rect.shift(Offset(0, _shadowOffset * depth)), _shadow);
    }
    run.paint(raised ? 1 : 0, canvas, rect);
  }

  void _paintFlip(Canvas canvas, Offset offset, _Run run) {
    final center = albumGridRect(run.cells.first).center + offset;
    final back = run.progress >= .5;
    // 越过 90° 时换面，背面补偿 180°，到位时为正向封面。
    final angle = (back ? 1 - run.progress : -run.progress) * math.pi;
    final matrix = Matrix4.identity()
      ..setEntry(3, 2, -1 / _eyeDistance)
      ..rotateY(angle);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.transform(matrix.storage);
    run.paint(
      back ? 1 : 0,
      canvas,
      Rect.fromCenter(
        center: Offset.zero,
        width: albumGridExtent,
        height: albumGridExtent,
      ),
    );
    canvas.restore();
  }

  @override
  void dispose() {
    pause();
    _ticker.dispose();
    commits.dispose();
    super.dispose();
  }
}

class _Run {
  _Run(
    this.effect,
    this.cells,
    this.albums,
    this.covers,
    this.start, {
    this.folder,
  });

  final _Effect effect;
  final List<AlbumGridCell> cells;
  final List<_Album> albums;
  final List<AlbumTileMotionCover> covers;
  final Duration start;
  final AlbumFolderReveal? folder;
  double progress = 0;

  void paint(int index, Canvas canvas, Rect rect) =>
      covers[index].paint(canvas, rect);

  void release() {
    for (final cover in covers) {
      cover.release();
    }
  }
}
