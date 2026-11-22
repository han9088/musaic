import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../services/music/music_models.dart';
import '../../../ui/widgets/frosted_control_surface.dart';
import 'album_playback.dart';
import 'now_playing_capsule.dart';

class NowPlayingControls extends StatefulWidget {
  const NowPlayingControls({
    super.key,
    required this.playback,
    required this.visible,
    required this.onOpenSheet,
    this.companion,
    this.companionVisible = false,
  });

  final AlbumPlayback? playback;
  final bool visible;
  final VoidCallback onOpenSheet;
  final Widget? companion;
  final bool companionVisible;

  @override
  State<NowPlayingControls> createState() => _NowPlayingControlsState();
}

enum _PullDirection {
  left,
  right;

  bool get forward => this == right;
}

class _NowPlayingControlsState extends State<NowPlayingControls> {
  static const _companionRevealDelay = Duration(seconds: 1);
  static const _horizontalThreshold = 26.0;
  static const _seekDelay = Duration(milliseconds: 420);
  static const _seekInterval = Duration(milliseconds: 300);

  Timer? _seekTimer;
  Timer? _companionRevealTimer;
  MusicReference? _track;
  _PullDirection? _direction;
  bool _seeking = false;
  bool _didSeek = false;
  bool _hideCompanion = false;
  bool _returning = false;

  _PullDirection? _horizontalDirection(Offset delta) {
    final horizontal = delta.dx.abs();
    if (horizontal < _horizontalThreshold || horizontal <= delta.dy.abs()) {
      return null;
    }
    return delta.dx > 0 ? _PullDirection.right : _PullDirection.left;
  }

  void _updatePull(Offset delta) {
    final direction = _horizontalDirection(delta);
    if (!_returning && _hideCompanion && _direction == direction) return;
    if (direction != null) _track ??= widget.playback?.currentTrack;
    _seekTimer?.cancel();
    setState(() {
      _direction = direction;
      _seeking = false;
      _hideCompanion = true;
      _returning = false;
    });
    if (direction != null) {
      _seekTimer = Timer(_seekDelay, () => _beginSeeking(direction));
    }
  }

  void _beginSeeking(_PullDirection direction) {
    setState(() {
      _seeking = true;
      _didSeek = true;
    });
    final playback = widget.playback;
    final track = _track;
    if (playback == null || track == null || playback.currentTrack != track) {
      return;
    }
    playback.seekStep(forward: direction.forward);
    _seekTimer = Timer.periodic(_seekInterval, (timer) {
      if (playback.currentTrack == track) {
        playback.seekStep(forward: direction.forward);
      } else {
        timer.cancel();
      }
    });
  }

  bool _endPull(Offset? delta) {
    final direction = delta == null ? null : _horizontalDirection(delta);
    final playback = widget.playback;
    final consumed = _didSeek;
    final canSkip = _track != null && _track == playback?.currentTrack;
    _seekTimer?.cancel();
    _track = null;
    _didSeek = false;
    _returning = _hideCompanion;
    if (!consumed && canSkip && direction != null) {
      playback!.skip(forward: direction.forward);
      return true;
    }
    return consumed;
  }

  void _finishReturn() {
    if (!_returning) return;
    final delayCompanion = _hideCompanion && widget.companion != null;
    setState(() {
      _resetPull();
      _hideCompanion = delayCompanion;
    });
    if (delayCompanion) {
      _companionRevealTimer = Timer(_companionRevealDelay, () {
        _companionRevealTimer = null;
        setState(() => _hideCompanion = false);
      });
    }
  }

  void _cancelCompanionReveal() {
    _companionRevealTimer?.cancel();
    _companionRevealTimer = null;
  }

  void _resetPull() {
    _seekTimer?.cancel();
    _cancelCompanionReveal();
    _track = null;
    _direction = null;
    _seeking = false;
    _didSeek = false;
    _hideCompanion = false;
    _returning = false;
  }

  @override
  void didUpdateWidget(NowPlayingControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.visible || widget.playback != oldWidget.playback) _resetPull();
  }

  @override
  void dispose() {
    _seekTimer?.cancel();
    _cancelCompanionReveal();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final icon = switch ((_direction, _seeking)) {
      (_PullDirection.left, false) => PhosphorIcons.skipBackFill,
      (_PullDirection.right, false) => PhosphorIcons.skipForwardFill,
      (_PullDirection.left, true) => PhosphorIcons.rewindFill,
      (_PullDirection.right, true) => PhosphorIcons.fastForwardFill,
      (null, _) => null,
    };
    return FrostedControlPair(
      primaryVisible: widget.visible,
      companion: widget.companion,
      companionVisible: widget.companionVisible,
      hideCompanion: _hideCompanion,
      onPrimaryPress: _cancelCompanionReveal,
      onPrimaryPullUp: widget.onOpenSheet,
      onPrimaryPullUpdate: _updatePull,
      onPrimaryPullEnd: _endPull,
      onPrimaryPullSettled: _finishReturn,
      primary: NowPlayingCapsule(
        playback: widget.playback,
        visible: widget.visible,
        onOpenSheet: widget.onOpenSheet,
        pullFeedbackIcon: icon,
      ),
    );
  }
}
