import 'package:musaic/ui/bottom_sheet/constants.dart';
import 'package:musaic/ui/bottom_sheet/push_direction.dart';
import 'package:musaic/ui/bottom_sheet/push_layout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('getPushLayoutProgress', () {
    test('bottom push interpolates from closed to open', () {
      expect(
        getPushLayoutProgress(800, 400, 800, PushDirectionJs.bottom, 50),
        0,
      );
      expect(
        getPushLayoutProgress(400, 400, 800, PushDirectionJs.bottom, 50),
        1,
      );
      expect(
        getPushLayoutProgress(600, 400, 800, PushDirectionJs.bottom, 50),
        closeTo(0.5, 1e-9),
      );
    });

    test('top push interpolates from -screenHeight to openY', () {
      expect(getPushLayoutProgress(-800, 0, 800, PushDirectionJs.top, 50), 0);
      expect(getPushLayoutProgress(0, 0, 800, PushDirectionJs.top, 50), 1);
    });
  });

  group('push scale helpers', () {
    test('pushInsetToScale shrinks by horizontal inset', () {
      expect(pushInsetToScale(400, 16), closeTo((400 - 32) / 400, 1e-9));
    });

    test('getPushScale at progress 1 matches inset', () {
      expect(
        getPushScale(400, 1),
        closeTo(pushInsetToScale(400, kPushHostHorizontalInset), 1e-9),
      );
    });
  });

  group('getPushHostOffset', () {
    test('bottom push returns negative offset', () {
      final offset = getPushHostOffset(
        400,
        800,
        400,
        1,
        PushDirectionJs.bottom,
        50,
        400,
      );
      expect(offset < 0, isTrue);
    });

    test('top push returns positive offset', () {
      final offset = getPushHostOffset(
        400,
        800,
        0,
        1,
        PushDirectionJs.top,
        50,
        400,
      );
      expect(offset > 0, isTrue);
    });
  });
}
