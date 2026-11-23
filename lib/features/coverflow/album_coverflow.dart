// 文件职责：Cover Flow 的几何计算、输入处理与动效。

import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../artwork/artwork_renderer.dart';
import '../artwork/model/artwork_identity.dart';
import '../artwork/presentation/custom_artwork_menu.dart';
import 'camera/coverflow_camera_intro.dart';
import 'coverflow_flip_card.dart';
import 'coverflow_input.dart';
import 'coverflow_motion.dart';
import 'coverflow_geometry.dart';
import '../../services/album_haptics.dart';
import '../../ui/transitions/rect_flip_transition.dart';
import '../music/catalog/album_catalog_mapper.dart';
import '../music/catalog/album_track_list.dart';
import '../music/playback/album_play_button.dart';
import '../music/playback/album_playback.dart';

/// 封装或定义专辑封面流动相关类型与行为，负责Cover Flow 的几何计算、输入处理与动效。
class AlbumCoverFlow extends StatefulWidget {
  const AlbumCoverFlow({
    super.key,
    required this.albums,
    this.haptics,
    this.playback,
    this.xerox = false,
    this.initialPosition = 0,
    this.initialTilt = 0,
    this.onMotionChanged,
    this.retainedLandscapeViewport,
  });

  final double initialPosition;
  final double initialTilt;
  final void Function(double position, double tilt)? onMotionChanged;
  final Size? retainedLandscapeViewport;

  /// When provided, the caller owns preparation and disposal.
  final AlbumHaptics? haptics;
  final AlbumPlayback? playback;
  final bool xerox;

  final List<Map<String, dynamic>> albums;

  @override
  State<AlbumCoverFlow> createState() => _AlbumCoverFlowState();
}

/// 封装或定义专辑封面流动状态相关类型与行为，负责Cover Flow 的几何计算、输入处理与动效。
class _AlbumCoverFlowState extends State<AlbumCoverFlow>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final Ticker _ticker;
  late final AnimationController _flip;
  late final AlbumHaptics _haptics;
  late final CoverFlowMotion _motion;
  Size? _flipViewport;
  bool _flipCanStart = false;
  bool _flipDragging = false;
  double _flipStart = 0;
  double _flipTarget = 0;
  int _hapticIndex = 0;
  Duration? _lastHapticTime;

  bool get _flipEngaged => _flipDragging || _flip.value > 0;

  @override
  void initState() {
    super.initState();
    _motion = CoverFlowMotion(
      position: widget.initialPosition,
      tilt: widget.initialTilt,
    );
    _hapticIndex = _motion.position.round();
    _ticker = createTicker(_tick);
    _flip = AnimationController(
      vsync: this,
      duration: RectFlipTransition.duration,
    )..addStatusListener((_) => _syncFlipState());
    _haptics = widget.haptics ?? AlbumHaptics();
    WidgetsBinding.instance.addObserver(this);
    if (widget.haptics == null) unawaited(_haptics.prepare());
    if (_motion.tilt != 0 ||
        _motion.position != _motion.position.roundToDouble()) {
      _motion.target = _motion.position.roundToDouble();
      _wake();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final viewport = MediaQuery.sizeOf(context);
    if (_flipViewport != viewport && _flipEngaged) {
      _flipDragging = false;
      _flipTarget = 0;
      _flip.reset();
      _syncFlipState();
    }
    _flipViewport = viewport;
  }

  void _startFlip(DragStartDetails details) {
    if (!_flipCanStart || _motion.dragging || _flipDragging) return;
    _flipStart = _flip.value;
    _flip.stop();
    _flipDragging = true;
    _ticker.stop();
  }

  void _dragFlip(double dy, double travel) {
    if (!_flipDragging) return;
    _flip.value = (_flip.value - dy / travel).clamp(0.0, 1.0);
  }

  void _finishFlip(double travel, {double? velocity}) {
    if (!_flipDragging) return;
    _flipDragging = false;
    final distance = (_flip.value - _flipStart) * travel;
    final committed =
        velocity != null &&
        (distance.abs() >= 52 ||
            (distance.abs() >= 12 && -velocity * distance.sign >= 450));
    if (committed) _flipTarget = distance > 0 ? 1 : 0;
    _animateFlip();
  }

  void _closeFlip() {
    _flipTarget = 0;
    _animateFlip();
  }

  void _animateFlip() {
    if (MediaQuery.disableAnimationsOf(context)) {
      _flip.value = _flipTarget;
    } else if (_flipTarget == 0) {
      _flip.animateBack(0, curve: RectFlipTransition.curve);
    } else {
      _flip.animateTo(1, curve: RectFlipTransition.curve);
    }
    _syncFlipState();
  }

  void _syncFlipState() {
    if (!_flipDragging && _flip.isDismissed) _resumeStrip();
  }

  void _resumeStrip() {
    if (_flipEngaged || _flipTarget != 0 || _ticker.isActive) return;
    final center = _motion.position.roundToDouble();
    if (_motion.position == center &&
        _motion.tilt == 0 &&
        _motion.velocity == 0) {
      return;
    }
    _motion.velocity = 0;
    _settle(center);
  }

  void _wake() {
    if (!_ticker.isActive) {
      _motion.lastFrame = null;
      _ticker.start();
    }
  }

  void _tick(Duration time) {
    final frame = _motion.advance(
      time,
      reduced: MediaQuery.disableAnimationsOf(context),
    );
    if (!frame.changed) return;
    setState(() {});
    if (frame.settled) _ticker.stop();
    _notifyAlbumChange();
  }

  /// 更新相关状态并同步依赖方，用于Cover Flow 的几何计算、输入处理与动效。
  void _notifyAlbumChange() {
    widget.onMotionChanged?.call(_motion.position, _motion.tilt);
    final index = _motion.position.round();
    if (index == _hapticIndex) return;
    final movingLeft = index > _hapticIndex;
    _hapticIndex = index;
    final time = SchedulerBinding.instance.currentFrameTimeStamp;
    if (_lastHapticTime != null &&
        time - _lastHapticTime! < const Duration(milliseconds: 40)) {
      return;
    }
    _lastHapticTime = time;
    unawaited(
      _haptics.tick(
        movingLeft: movingLeft,
        strength: (_motion.velocity.abs() / 8).clamp(0.15, 1.0),
      ),
    );
  }

  void _settle(double target) {
    if (_flipEngaged) return;
    _motion.target = target;
    if (MediaQuery.disableAnimationsOf(context)) {
      setState(() {
        _motion.position = target;
        _motion.velocity = 0;
        _motion.tilt = 0;
        _motion.gestureTilt = 0;
      });
      _ticker.stop();
      _notifyAlbumChange();
    } else {
      _wake();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    unawaited(_haptics.setActive(state == AppLifecycleState.resumed));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (widget.haptics == null) unawaited(_haptics.dispose());
    _flip.dispose();
    _ticker.dispose();
    super.dispose();
  }

  Matrix4 _planeTransform(double width, double tilt) => Matrix4.identity()
    ..setEntry(3, 2, 0.88 / width)
    ..rotateY(tilt);

  Widget _image(Map<String, dynamic> album, double size) {
    final asset = album['asset'] as String;
    final rawIdentity = album['id'] as String?;
    return albumArtwork(
      asset,
      artworkIdentity: rawIdentity == null
          ? null
          : ArtworkIdentity(rawIdentity),
      width: size,
      height: size,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.medium,
      excludeFromSemantics: true,
      xerox: widget.xerox,
    );
  }

  @override
  Widget build(BuildContext context) {
    final selected =
        widget.albums[_motion.position.round() % widget.albums.length];
    final portrait =
        widget.retainedLandscapeViewport == null &&
        MediaQuery.orientationOf(context) == Orientation.portrait;
    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: CoverFlowCameraIntro(
        builder: (toggleCamera, decorateTitle) => SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final flowViewport =
                  widget.retainedLandscapeViewport ?? constraints.biggest;
              final size = CoverFlowGeometry.coverSize(flowViewport);
              final alignment = CoverFlowGeometry.alignment(
                portrait: portrait,
                height: constraints.maxHeight,
                coverSize: size,
                bottomPadding: bottomPadding,
              );
              final coverCenter = alignment.alongSize(constraints.biggest);
              final stride = size * 0.7 + 6;
              final center = _motion.position.round();
              final indices = List.generate(15, (i) => center + i - 7);
              final geometry = CoverFlowGeometry.calculate(
                indices: indices,
                position: _motion.position,
                size: size,
              );
              final widths = geometry.widths;
              final centers = geometry.centers;
              final anchor = geometry.anchor;
              final plane = _planeTransform(flowViewport.width, _motion.tilt);
              final source = Rect.fromCenter(
                center: coverCenter.translate(centers[center]! - anchor, 0),
                width: widths[center]!,
                height: widths[center]!,
              );
              final destination = portrait
                  ? CoverFlowFlipCard.destinationFor(
                      constraints.biggest,
                      source,
                    )
                  : null;
              final flipTravel =
                  source.center.dy - (destination?.center.dy ?? 0);
              return Semantics(
                label: '${selected['artist']}, ${selected['title']}',
                onIncrease: () => _settle(_motion.position.roundToDouble() + 1),
                onDecrease: () => _settle(_motion.position.roundToDouble() - 1),
                child: CoverFlowInput(
                  canStartInput: () => !_motion.dragging && !_flipEngaged,
                  onScroll: (delta, time) {
                    setState(() => _motion.scroll(delta, time, stride));
                    _wake();
                  },
                  onScrollEnd: () {
                    _motion.endScroll();
                    _settle(_motion.position.roundToDouble());
                  },
                  onStep: (direction) {
                    _motion.velocity = 0;
                    _settle(
                      (_motion.target ?? _motion.position.roundToDouble()) +
                          direction,
                    );
                  },
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onVerticalDragDown: destination == null
                        ? null
                        : (details) {
                            _flipCanStart =
                                _flip.value > 0 ||
                                source.contains(details.localPosition);
                          },
                    onVerticalDragStart: destination == null
                        ? null
                        : _startFlip,
                    onVerticalDragUpdate: destination == null
                        ? null
                        : (details) => _dragFlip(details.delta.dy, flipTravel),
                    onVerticalDragEnd: destination == null
                        ? null
                        : (details) => _finishFlip(
                            flipTravel,
                            velocity: details.primaryVelocity ?? 0,
                          ),
                    onVerticalDragCancel: destination == null
                        ? null
                        : () => _finishFlip(flipTravel),
                    onHorizontalDragStart: (details) {
                      if (_flipEngaged) return;
                      _motion.startDrag(details.sourceTimeStamp);
                      _wake();
                    },
                    onHorizontalDragUpdate: (details) {
                      if (!_motion.dragging || _flipEngaged) return;
                      setState(
                        () => _motion.updateDrag(
                          details.delta.dx,
                          details.sourceTimeStamp,
                          stride,
                        ),
                      );
                    },
                    onHorizontalDragEnd: (details) {
                      if (!_motion.dragging || _flipEngaged) return;
                      final shouldSettle = _motion.endDrag(
                        details.velocity.pixelsPerSecond.dx,
                        stride,
                      );
                      if (shouldSettle) {
                        _settle(_motion.position.roundToDouble());
                      }
                      _wake();
                    },
                    onHorizontalDragCancel: () {
                      if (!_motion.dragging || _flipEngaged) return;
                      _motion.cancelDrag();
                      _settle(_motion.position.roundToDouble());
                    },
                    child: Stack(
                      clipBehavior: Clip.hardEdge,
                      children: [
                        Positioned.fill(
                          child: Transform(
                            key: const ValueKey('cover-flow-plane'),
                            alignment: alignment,
                            transform: plane,
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                for (final index in indices)
                                  if (index != center || destination == null)
                                    _cover(
                                      index,
                                      widths[index]!,
                                      coverCenter.translate(
                                        centers[index]! - anchor,
                                        0,
                                      ),
                                    ),
                              ],
                            ),
                          ),
                        ),
                        if (destination != null)
                          Positioned.fill(
                            child: AnimatedBuilder(
                              animation: _flip,
                              builder: (context, child) {
                                final turn = CoverFlowFlipCard.turnCurve
                                    .transform(_flip.value);
                                final tilt = _motion.tilt * (1 - turn);
                                return Transform(
                                  alignment: alignment,
                                  transform: tilt == 0
                                      ? Matrix4.identity()
                                      : _planeTransform(
                                          flowViewport.width,
                                          tilt,
                                        ),
                                  child: child,
                                );
                              },
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  _cover(
                                    center,
                                    source.width,
                                    source.center,
                                    destination: destination,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        Positioned(
                          top: 6,
                          left: 20,
                          right: 20,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onLongPress: toggleCamera,
                            onTap: toggleCamera == null ? null : () {},
                            child: Center(
                              child: decorateTitle(
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      selected['artist'] as String,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Color(0xffbfc6ce),
                                        fontSize: 12,
                                      ),
                                    ),
                                    Text(
                                      selected['title'] as String,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _cover(int index, double size, Offset center, {Rect? destination}) {
    final album = widget.albums[index % widget.albums.length];
    final id = album['id'] as String?;
    final source = Rect.fromCenter(center: center, width: size, height: size);
    final reflection = SizedBox(
      height: size * CoverFlowFlipCard.reflectionFraction,
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.topCenter,
          maxHeight: size,
          // Keep the mask edge outside the cropped reflection.
          child: ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (rect) => const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x70ffffff), Color(0x00ffffff), Color(0x00ffffff)],
              stops: [0, CoverFlowFlipCard.reflectionFraction, 1],
            ).createShader(rect),
            child: Transform.flip(flipY: true, child: _image(album, size)),
          ),
        ),
      ),
    );
    final playingButton = _playButton(album, destination, size);
    final onLongPress = customArtworkMenuAction(
      context,
      album['asset'] as String,
      id == null ? null : ArtworkIdentity(id),
    );
    final card = GestureDetector(
      onLongPressStart: onLongPress,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: () => _settle(index.toDouble()),
              child: RepaintBoundary(
                child: Column(
                  children: [
                    _image(album, size),
                    if (destination == null)
                      reflection
                    else
                      FadeTransition(
                        opacity: ReverseAnimation(
                          _flip.drive(
                            CurveTween(curve: const Interval(0, 0.25)),
                          ),
                        ),
                        child: reflection,
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (playingButton != null)
            Positioned(
              left: 0,
              top: 0,
              width: size,
              height: size,
              child: IgnorePointer(
                ignoring: index != _motion.position.round(),
                child: AnimatedOpacity(
                  opacity: index == _motion.position.round() ? 1 : 0,
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 180),
                  curve: Curves.easeInOut,
                  child: playingButton,
                ),
              ),
            ),
        ],
      ),
    );
    return Positioned(
      key: ValueKey('cover-$index'),
      left: source.left,
      top: source.top,
      width: size,
      height: size * (1 + CoverFlowFlipCard.reflectionFraction),
      child: destination == null
          ? card
          : CoverFlowFlipCard(
              progress: _flip,
              source: source,
              destination: destination,
              back: Align(
                alignment: Alignment.topCenter,
                child: SizedBox.square(
                  dimension: size,
                  child: FittedBox(
                    // Lay out the back at its final size before scaling the card.
                    child: SizedBox.square(
                      dimension: destination.width,
                      child: GestureDetector(
                        // The camera only captures taps outside the card.
                        onTap: () {},
                        onLongPressStart: onLongPress,
                        child: albumHasSingleTrack(album)
                            ? _image(album, destination.width)
                            : AlbumTrackList(
                                album: album,
                                playback: widget.playback,
                                onClose: _closeFlip,
                              ),
                      ),
                    ),
                  ),
                ),
              ),
              child: card,
            ),
    );
  }

  Widget? _playButton(
    Map<String, dynamic> album,
    Rect? destination,
    double size,
  ) {
    final playback = widget.playback;
    if (playback == null) return null;
    final button = AlbumPlayButton(
      diameter: 48,
      asset: album['asset'] as String,
      title: album['title'] as String,
      artist: album['artist'] as String?,
      playback: playback,
    );
    if (destination == null) return button;
    return AnimatedBuilder(
      animation: _flip,
      child: button,
      builder: (context, child) => Transform.scale(
        scale:
            1 / CoverFlowFlipCard.scaleAt(_flip.value, size, destination.width),
        child: child,
      ),
    );
  }
}
