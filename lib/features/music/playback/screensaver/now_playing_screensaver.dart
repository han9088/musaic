import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../../ui/bottom_sheet/bottom_sheet.dart';
import '../album_playback.dart';
import 'screensaver_view.dart';

class NowPlayingScreensaver extends StatefulWidget {
  const NowPlayingScreensaver({
    super.key,
    required this.playback,
    required this.enabled,
    required this.idleDelay,
    required this.child,
  });

  final AlbumPlayback playback;
  final bool enabled;
  final Duration idleDelay;
  final Widget child;

  @override
  State<NowPlayingScreensaver> createState() => _NowPlayingScreensaverState();
}

typedef _ScreenTrack = ({String artwork, String title});

class _NowPlayingScreensaverState extends State<NowPlayingScreensaver> {
  late final AppLifecycleListener _lifecycle;
  late bool _foreground;
  bool _routeAvailable = false;
  BottomSheetSheetStore? _sheets;
  Timer? _idleTimer;
  _ScreenTrack? _eligibleTrack;
  _ScreenTrack? _screenTrack;
  bool _keepAwake = false;
  Future<void> _wakeLockUpdate = Future.value();

  @override
  void initState() {
    super.initState();
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _foreground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    _lifecycle = AppLifecycleListener(
      onStateChange: (state) {
        _foreground = state == AppLifecycleState.resumed;
        _syncPlayback();
      },
    );
    widget.playback.addListener(_syncPlayback);
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _routeAvailable =
        ModalRoute.isCurrentOf(context) != false &&
        !MediaQuery.accessibleNavigationOf(context);
    final sheets = BottomSheetScope.maybeOf(context)?.sheetStore;
    if (_sheets != sheets) {
      _sheets?.removeListener(_syncPlayback);
      _sheets = sheets;
      _sheets?.addListener(_syncPlayback);
    }
    _syncPlayback();
  }

  @override
  void didUpdateWidget(NowPlayingScreensaver oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.playback != widget.playback) {
      oldWidget.playback.removeListener(_syncPlayback);
      widget.playback.addListener(_syncPlayback);
      _recordActivity();
    } else if (oldWidget.enabled != widget.enabled ||
        oldWidget.idleDelay != widget.idleDelay) {
      if (oldWidget.idleDelay != widget.idleDelay) {
        _idleTimer?.cancel();
        _idleTimer = null;
      }
      _syncPlayback();
    }
  }

  void _syncPlayback() {
    _ScreenTrack? next;
    if (widget.enabled &&
        _foreground &&
        _routeAvailable &&
        _sheets?.snapshot.isPresented != true) {
      final playback = widget.playback;
      if (playback.asset case final artwork? when playback.playing) {
        next = (artwork: artwork, title: playback.currentTitle ?? '');
      } else if (playback.buffering) {
        next = _screenTrack;
      }
    }

    _eligibleTrack = next;
    // Start before the idle delay because system auto-lock can be shorter.
    _setKeepAwake(next != null);
    if (next == null) {
      _idleTimer?.cancel();
      _idleTimer = null;
    } else if (_screenTrack == null) {
      _idleTimer ??= Timer(widget.idleDelay, () {
        _idleTimer = null;
        setState(() => _screenTrack = _eligibleTrack);
      });
    }
    if (_screenTrack != null && _screenTrack != next) {
      setState(() => _screenTrack = next);
    }
  }

  void _setKeepAwake(bool enable) {
    if (_keepAwake == enable) return;
    _keepAwake = enable;
    _wakeLockUpdate = _wakeLockUpdate.then((_) async {
      if (_keepAwake != enable) return;
      try {
        await WakelockPlus.toggle(enable: enable);
      } on MissingPluginException {
        // Hosts without a screen-lock plugin can still display the screensaver.
      } catch (error) {
        debugPrint(
          'Could not update screensaver wake lock: ${error.runtimeType}',
        );
      }
    });
  }

  void _recordActivity([PointerEvent? _]) {
    _idleTimer?.cancel();
    _idleTimer = null;
    if (_screenTrack != null) setState(() => _screenTrack = null);
    _syncPlayback();
  }

  bool _onKey(KeyEvent event) {
    if (event.synthesized || event is! KeyDownEvent) return false;
    if (event.logicalKey == LogicalKeyboardKey.mediaTrackNext ||
        event.logicalKey == LogicalKeyboardKey.mediaTrackPrevious) {
      return false;
    }
    final wasShowing = _screenTrack != null;
    _recordActivity();
    return wasShowing;
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    _sheets?.removeListener(_syncPlayback);
    widget.playback.removeListener(_syncPlayback);
    HardwareKeyboard.instance.removeHandler(_onKey);
    _lifecycle.dispose();
    _setKeepAwake(false);
    super.dispose();
  }

  ScreensaverView _trackView(_ScreenTrack track) {
    var position = widget.playback.currentPosition;
    return ScreensaverView(
      key: ValueKey(track),
      title: track.title,
      artwork: track.artwork,
      readPosition: () {
        final playback = widget.playback;
        if (_screenTrack == track && playback.playing) {
          position = playback.currentPosition;
        }
        return position;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final track = _screenTrack;
    return PopScope(
      canPop: track == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _screenTrack != null) _recordActivity();
      },
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: _recordActivity,
        onPointerMove: _recordActivity,
        onPointerUp: _recordActivity,
        onPointerHover: _recordActivity,
        onPointerSignal: _recordActivity,
        onPointerPanZoomStart: _recordActivity,
        onPointerPanZoomUpdate: _recordActivity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            TickerMode(
              enabled: track == null,
              child: ExcludeFocus(
                excluding: track != null,
                child: Offstage(offstage: track != null, child: widget.child),
              ),
            ),
            if (track != null)
              Semantics(
                onTap: _recordActivity,
                child: ColoredBox(
                  color: Colors.black,
                  child: AnimatedSwitcher(
                    duration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : const Duration(milliseconds: 320),
                    switchInCurve: Curves.easeInOut,
                    switchOutCurve: Curves.easeInOut,
                    child: _trackView(track),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
