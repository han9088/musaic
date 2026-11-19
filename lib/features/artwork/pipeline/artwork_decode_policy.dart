const artworkDecodeResolutions = [256, 512, 1024];

/// Chooses a discrete decode size so continuous canvas scaling does not create
/// a new ImageCache key every frame.
int artworkDecodeResolution(double physicalExtent, {int? current}) {
  if (!physicalExtent.isFinite || physicalExtent <= 0) {
    return current ?? 512;
  }
  if (current == null || !artworkDecodeResolutions.contains(current)) {
    return artworkDecodeResolutions.firstWhere(
      (value) => physicalExtent <= value,
      orElse: () => artworkDecodeResolutions.last,
    );
  }

  var resolution = current;
  while (resolution < artworkDecodeResolutions.last &&
      physicalExtent > resolution * 1.35) {
    resolution = artworkDecodeResolutions[
        artworkDecodeResolutions.indexOf(resolution) + 1];
  }
  while (resolution > artworkDecodeResolutions.first &&
      physicalExtent < resolution * 0.65) {
    resolution = artworkDecodeResolutions[
        artworkDecodeResolutions.indexOf(resolution) - 1];
  }
  return resolution;
}
