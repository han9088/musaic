// 文件职责：专辑封面来源解析、图片解码、缓存及 Xerox 处理。

const xeroxResolutions = [64, 128, 256, 512];

/// 执行当前模块中的Xerox分辨率操作，用于专辑封面来源解析、图片解码、缓存及 Xerox 处理。
int xeroxResolution(double physicalExtent, {int? current}) {
  if (!physicalExtent.isFinite || physicalExtent <= 0) return current ?? 128;
  if (current == null) {
    return xeroxResolutions.firstWhere(
      (resolution) => physicalExtent <= resolution,
      orElse: () => xeroxResolutions.last,
    );
  }

  var resolution = current;
  while (resolution < xeroxResolutions.last &&
      physicalExtent > resolution * 1.35) {
    resolution =
        xeroxResolutions[xeroxResolutions.indexOf(resolution) + 1];
  }
  while (resolution > xeroxResolutions.first &&
      physicalExtent < resolution * 0.65) {
    resolution =
        xeroxResolutions[xeroxResolutions.indexOf(resolution) - 1];
  }
  return resolution;
}
