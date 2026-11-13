import 'package:musaic/ui/bottom_sheet/detents.dart';
import 'package:musaic/ui/bottom_sheet/types.dart';
import 'package:flutter_test/flutter_test.dart';

const screenHeight = 800.0;
const topInset = 50.0;

void main() {
  group('getDetentHeight', () {
    test('resolves percentage snap points as fractions of screen height', () {
      expect(
        getDetentHeight(
          BottomSheetDetent.percent('50%'),
          screenHeight,
          topInset,
        ),
        400,
      );
      expect(
        getDetentHeight(
          BottomSheetDetent.percent('90%'),
          screenHeight,
          topInset,
        ),
        720,
      );
    });

    test('resolves numeric snap points as fractions of screen height', () {
      expect(
        getDetentHeight(
          BottomSheetDetent.fraction(0.5),
          screenHeight,
          topInset,
        ),
        400,
      );
      expect(
        getDetentHeight(
          BottomSheetDetent.fraction(0.9),
          screenHeight,
          topInset,
        ),
        720,
      );
    });

    test('full detent subtracts top inset from screen height', () {
      expect(
        getDetentHeight(BottomSheetDetent.full, screenHeight, topInset),
        750,
      );
    });

    test('accepts numeric fractions and clamps to 0-1', () {
      expect(
        getDetentHeight(
          BottomSheetDetent.fraction(0.25),
          screenHeight,
          topInset,
        ),
        200,
      );
      expect(
        getDetentHeight(
          BottomSheetDetent.fraction(1.5),
          screenHeight,
          topInset,
        ),
        800,
      );
      expect(
        getDetentHeight(
          BottomSheetDetent.fraction(-0.2),
          screenHeight,
          topInset,
        ),
        0,
      );
    });

    test('accepts percentage strings', () {
      expect(
        getDetentHeight(
          BottomSheetDetent.percent('60%'),
          screenHeight,
          topInset,
        ),
        480,
      );
    });
  });

  group('getDetentTranslateY', () {
    test('returns screen height minus detent height', () {
      expect(
        getDetentTranslateY(
          BottomSheetDetent.percent('50%'),
          screenHeight,
          topInset,
        ),
        400,
      );
      expect(
        getDetentTranslateY(BottomSheetDetent.full, screenHeight, topInset),
        50,
      );
    });
  });

  group('findNearestDetentIndex', () {
    final detents = [
      BottomSheetDetent.percent('50%'),
      BottomSheetDetent.percent('90%'),
      BottomSheetDetent.full,
    ];

    test('picks the closest snap point by translateY', () {
      expect(findNearestDetentIndex(410, detents, screenHeight, topInset), 0);
      expect(findNearestDetentIndex(52, detents, screenHeight, topInset), 2);
      expect(findNearestDetentIndex(80, detents, screenHeight, topInset), 1);
    });
  });

  group('findDetentIndex', () {
    test('returns index when detent exists in list', () {
      expect(
        findDetentIndex([
          BottomSheetDetent.medium,
          BottomSheetDetent.large,
        ], BottomSheetDetent.large),
        1,
      );
    });

    test('returns 0 when detent is missing', () {
      expect(
        findDetentIndex([BottomSheetDetent.medium], BottomSheetDetent.full),
        0,
      );
    });
  });

  group('clampIndex', () {
    test('clamps index within detent count bounds', () {
      expect(clampIndex(2, 3), 2);
      expect(clampIndex(5, 3), 2);
      expect(clampIndex(-1, 3), 0);
    });

    test('returns 0 when there are no detents', () {
      expect(clampIndex(3, 0), 0);
    });
  });

  group('buildDynamicSheetHeight', () {
    test('sums content, handle, and bottom inset', () {
      expect(buildDynamicSheetHeight(200, screenHeight, topInset, 34, 25), 259);
    });

    test('caps height at screen minus top inset', () {
      expect(buildDynamicSheetHeight(900, screenHeight, topInset, 34, 25), 750);
    });
  });

  group('getTranslateYFromSheetHeight', () {
    test('positions sheet top from height', () {
      expect(getTranslateYFromSheetHeight(400, screenHeight), 400);
    });
  });

  group('buildDynamicSnapPoint', () {
    test('returns height as fraction of screen height', () {
      final point = buildDynamicSnapPoint(200, screenHeight, topInset, 34, 25);
      expect(point, isA<BottomSheetDetentFraction>());
      expect(
        (point as BottomSheetDetentFraction).fraction,
        closeTo(259 / 800, 1e-9),
      );
    });
  });

  group('mergeSnapPoints', () {
    test('returns snapPoints when dynamic sizing disabled', () {
      expect(mergeSnapPoints([BottomSheetDetent.medium], null, false), [
        BottomSheetDetent.medium,
      ]);
    });

    test('appends dynamic snap when enabled', () {
      final dynamic = BottomSheetDetent.fraction(0.4);
      expect(mergeSnapPoints([BottomSheetDetent.medium], dynamic, true), [
        BottomSheetDetent.medium,
        dynamic,
      ]);
    });
  });
}
