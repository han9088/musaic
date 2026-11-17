import 'dart:math' as math;

/// The numerical model for Cover Flow swipes, coasting, tilt, and settling.
/// UI, haptics, and ticker ownership stay in AlbumCoverFlow.
class CoverFlowMotion {
  CoverFlowMotion({required this.position, required this.tilt})
      : gestureTilt = tilt;

  static const friction = 1.8;
  static const dragSensitivity = 1.12;
  static const settlingRate = 10.0;
  static const maxTilt = 0.66;
  static const tiltDeadZone = 200.0;
  static const shortSwipeMinDistance = 20.0;
  static const rapidSwipeInterval = Duration(milliseconds: 350);

  double position;
  double velocity = 0;
  double tilt;
  double dragDistance = 0;
  double gestureTilt;
  double? target;
  bool dragging = false;
  Duration? lastFrame;
  Duration? lastDrag;
  Duration? lastShortSwipe;
  double shortSwipeDirection = 0;
  int shortSwipeCount = 0;
  Duration? lastReleaseTime;
  double lastReleaseDirection = 0;
  double coastGain = 1;

  bool continuesShortSwipes(Duration? time) {
    final previous = lastShortSwipe;
    if (time == null ||
        previous == null ||
        dragDistance.sign != shortSwipeDirection) {
      return false;
    }
    final interval = time - previous;
    return interval > Duration.zero && interval <= rapidSwipeInterval;
  }

  void updateGestureTilt(double dx, Duration? time) {
    dragDistance += dx;
    final rapidSwipes =
        shortSwipeCount >= 2 &&
        dragDistance.abs() >= shortSwipeMinDistance &&
        continuesShortSwipes(time);
    if (gestureTilt != 0) {
      if (dx != 0 &&
          (dx * gestureTilt < 0 ||
              dragDistance.abs() > tiltDeadZone ||
              rapidSwipes)) {
        gestureTilt = dx.sign * maxTilt;
      }
    } else if (dragDistance.abs() > tiltDeadZone || rapidSwipes) {
      gestureTilt = dragDistance.sign * maxTilt;
    }
  }

  void recordShortSwipe() {
    if (dragDistance.abs() >= shortSwipeMinDistance &&
        dragDistance.abs() <= tiltDeadZone) {
      shortSwipeCount = continuesShortSwipes(lastDrag)
          ? (shortSwipeCount + 1).clamp(1, 3)
          : 1;
      lastShortSwipe = lastDrag;
      shortSwipeDirection = dragDistance.sign;
    } else {
      shortSwipeCount = 0;
      lastShortSwipe = null;
    }
  }

  ({bool changed, bool settled}) advance(
    Duration time, {
    required bool reduced,
  }) {
    final previous = lastFrame;
    lastFrame = time;
    if (previous == null) return (changed: false, settled: false);
    final dt = ((time - previous).inMicroseconds / 1000000).clamp(0.0, 0.032);
    if (!dragging) {
      if (target == null && velocity.abs() < 0.35) {
        target = position.roundToDouble();
      }
      final currentTarget = target;
      if (currentTarget == null) {
        final effectiveFriction = friction / coastGain;
        final decay = math.exp(-effectiveFriction * dt);
        position += velocity * (1 - decay) / effectiveFriction;
        velocity *= decay;
      } else {
        // The original critically damped settling formula.
        final error = position - currentTarget;
        final c = velocity + settlingRate * error;
        final decay = math.exp(-settlingRate * dt);
        position = currentTarget + (error + c * dt) * decay;
        velocity = (velocity - settlingRate * c * dt) * decay;
      }
    }
    final desiredTilt = reduced || target != null ? 0.0 : gestureTilt;
    final tiltResponse = dragging ? 10.0 : 6.0;
    tilt += (desiredTilt - tilt) * (1 - math.exp(-tiltResponse * dt));
    if (!dragging &&
        target != null &&
        (position - target!).abs() < 0.001 &&
        velocity.abs() < 0.01 &&
        tilt.abs() < 0.001) {
      position = target!;
      velocity = 0;
      tilt = 0;
      gestureTilt = 0;
      return (changed: true, settled: true);
    }
    return (changed: true, settled: false);
  }
}
