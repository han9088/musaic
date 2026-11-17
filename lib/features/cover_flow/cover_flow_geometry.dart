/// Shared cover positions for the settled Cover Flow and its layout transition.
/// Keeps the original width curve, spacing, and interpolated center anchor.
class CoverFlowGeometry {
  const CoverFlowGeometry._();

  static ({Map<int, double> widths, Map<int, double> centers, double anchor})
  calculate({
    required List<int> indices,
    required double position,
    required double size,
  }) {
    assert(indices.length >= 2);
    final widths = <int, double>{
      for (final index in indices)
        index: size * (0.7 + 0.3 * (1 - (index - position).abs()).clamp(0.0, 1.0)),
    };
    final centers = <int, double>{indices.first: 0};
    for (var i = 1; i < indices.length; i++) {
      final previous = indices[i - 1];
      final current = indices[i];
      centers[current] =
          centers[previous]! + (widths[previous]! + widths[current]!) / 2 + 6;
    }
    final lower = position.floor();
    final fraction = position - lower;
    final anchor =
        centers[lower]! * (1 - fraction) + centers[lower + 1]! * fraction;
    return (widths: widths, centers: centers, anchor: anchor);
  }
}
