// 文件职责：根据目标物理像素为原始专辑封面选择离散解码尺寸。

/// 原图只使用有限的解码档位，避免连续缩放产生大量 ImageCache 条目。
const artworkDecodeResolutions = [256, 512, 1024];

/// 选择能够覆盖目标物理尺寸的最小解码档位。
///
/// [current] 表示当前正在使用的档位；升级和降级采用不同阈值，
/// 防止缩放停留在边界附近时反复切换解码尺寸。
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
