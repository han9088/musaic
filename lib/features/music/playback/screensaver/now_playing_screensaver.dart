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
    required this.child,
  });

  final AlbumPlayback playback;
  final bool enabled;
  final Widget child;

  @override
  State<NowPlayingScreensaver> createState() => _NowPlayingScreensaverState();
}

class _NowPlayingScreensaverState extends State<NowPlayingScreensaver> {
  static const _idleDelay = Duration(minutes: 1);

  late final AppLifecycleListener _lifecycle;
  late bool _foreground;
  bool _routeAvailable = false;
  BottomSheetSheetStore? _sheets;
  Timer? _idleTimer;
  String? _eligibleArtwork;
  String? _screenArtwork;
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
    } else if (oldWidget.enabled != widget.enabled) {
      _syncPlayback();
    }
  }

  void _syncPlayback() {
    String? next;
    if (widget.enabled &&
        _foreground &&
        _routeAvailable &&
        _sheets?.snapshot.isPresented != true) {
      final playback = widget.playback;
      if (playback.playing) {
        next = playback.asset;
      } else if (_screenArtwork != null && playback.buffering) {
        next = playback.asset ?? _screenArtwork;
      }
    }

    _eligibleArtwork = next;
    // Start before the idle delay because system auto-lock can be shorter.
    _setKeepAwake(next != null);
    if (next == null) {
      _idleTimer?.cancel();
      _idleTimer = null;
    } else if (_screenArtwork == null) {
      _idleTimer ??= Timer(_idleDelay, () {
        _idleTimer = null;
        setState(() => _screenArtwork = _eligibleArtwork);
      });
    }
    if (_screenArtwork != null && _screenArtwork != next) {
      setState(() => _screenArtwork = next);
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
    if (_screenArtwork != null) setState(() => _screenArtwork = null);
    _syncPlayback();
  }

  bool _onKey(KeyEvent event) {
    if (event.synthesized || event is! KeyDownEvent) return false;
    final wasShowing = _screenArtwork != null;
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

  @override
  Widget build(BuildContext context) {
    final artwork = _screenArtwork;
    return PopScope(
      canPop: artwork == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _screenArtwork != null) _recordActivity();
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
              enabled: artwork == null,
              child: ExcludeFocus(
                excluding: artwork != null,
                child: Offstage(offstage: artwork != null, child: widget.child),
              ),
            ),
            if (artwork != null)
              Semantics(
                onTap: _recordActivity,
                child: ListenableBuilder(
                  listenable: widget.playback,
                  builder: (context, _) => ScreensaverView(
                    title: widget.playback.currentTitle ?? '',
                    artwork: artwork,
                    readPosition: () => widget.playback.currentPosition,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
