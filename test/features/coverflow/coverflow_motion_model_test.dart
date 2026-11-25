import 'package:flutter_test/flutter_test.dart';
import 'package:musaic/features/coverflow/coverflow_motion.dart';

void main() {
  test('Cover Flow motion keeps settled position and tilt', () {
    final motion = CoverFlowMotion(position: 2, tilt: 0);
    motion.target = 2;
    expect(motion.advance(Duration.zero, reduced: false).changed, isFalse);
    final frame = motion.advance(
      const Duration(milliseconds: 16),
      reduced: false,
    );
    expect(frame.changed, isTrue);
    expect(frame.settled, isTrue);
    expect(motion.position, 2);
    expect(motion.tilt, 0);
  });

  test('short swipe detection remains direction and cadence sensitive', () {
    final motion = CoverFlowMotion(position: 0, tilt: 0);
    motion.dragDistance = 30;
    motion.lastDrag = const Duration(milliseconds: 100);
    motion.recordShortSwipe();
    expect(motion.shortSwipeCount, 1);
    motion.dragDistance = 35;
    motion.lastDrag = const Duration(milliseconds: 300);
    motion.recordShortSwipe();
    expect(motion.shortSwipeCount, 2);
    motion.dragDistance = -30;
    motion.lastDrag = const Duration(milliseconds: 350);
    motion.recordShortSwipe();
    expect(motion.shortSwipeCount, 1);
  });
}
