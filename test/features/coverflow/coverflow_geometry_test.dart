import 'package:flutter_test/flutter_test.dart';
import 'package:musaic/features/coverflow/coverflow_geometry.dart';

void main() {
  test('geometry preserves selected-cover width and neighboring spacing', () {
    final result = CoverFlowGeometry.calculate(
      indices: List.generate(15, (i) => i - 7),
      position: 0,
      size: 200,
    );
    expect(result.widths[0], 200);
    expect(result.widths[-1], 140);
    expect(result.widths[1], 140);
    expect(result.centers[1]! - result.centers[0]!, 176);
    expect(result.anchor, result.centers[0]);
  });

  test('the anchor interpolates continuously between adjacent cells', () {
    final result = CoverFlowGeometry.calculate(
      indices: [-2, -1, 0, 1, 2, 3],
      position: 0.5,
      size: 200,
    );
    expect(result.anchor, closeTo(
      (result.centers[0]! + result.centers[1]!) / 2,
      1e-10,
    ));
  });
}
