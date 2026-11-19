/// Discrete source-image decode sizes, in physical pixels.
/// Keeping this list small avoids creating a new ImageCache entry for every zoom.
const artworkDecodeResolutions = [256, 512, 1024];

/// Chooses a discrete decode size so continuous canvas scaling does not create
/// a new ImageCache key every frame.
/// Selects the smallest decode size that covers the requested physical extent.
///
/// [current] enables hysteresis: upgrades and downgrades use different
/// thresholds so continuous canvas scaling does not oscillate between LODs.
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

  // Move up only after 135% of the current tier; move down below 65%.
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
