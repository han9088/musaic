// 文件职责：专辑封面来源解析、图片解码、缓存及 Xerox 处理。

/// Discrete source-image decode sizes, in physical pixels.
/// Keeping this list small avoids creating a new ImageCache entry for every zoom.
const artworkDecodeResolutions = [256, 512, 1024];

/// 执行当前模块中的封面图解码分辨率操作，用于专辑封面来源解析、图片解码、缓存及 Xerox 处理。
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

  // 放大超过当前档位的 135% 才升级，缩小低于当前档位的 65% 才降级。
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
