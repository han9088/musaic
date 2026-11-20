// 文件职责：独立管理原图解码与 Xerox 输出的细节层级选择。

/// 原图解码档位。使用离散档位，避免连续缩放制造大量 ImageCache 条目。
const artworkDecodeResolutions = [256, 512, 1024];

/// Xerox 输出档位，与原图解码档位独立。
const xeroxResolutions = [64, 128, 256, 512];

/// 选择覆盖目标物理像素的最小原图解码档位。
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

/// 选择 Xerox 光栅输出档位。与原图解码采用相同的迟滞策略，但拥有独立档位。
int xeroxResolution(double physicalExtent, {int? current}) {
  if (!physicalExtent.isFinite || physicalExtent <= 0) return current ?? 128;
  if (current == null || !xeroxResolutions.contains(current)) {
    return xeroxResolutions.firstWhere(
      (value) => physicalExtent <= value,
      orElse: () => xeroxResolutions.last,
    );
  }

  var resolution = current;
  while (resolution < xeroxResolutions.last &&
      physicalExtent > resolution * 1.35) {
    resolution = xeroxResolutions[xeroxResolutions.indexOf(resolution) + 1];
  }
  while (resolution > xeroxResolutions.first &&
      physicalExtent < resolution * 0.65) {
    resolution = xeroxResolutions[xeroxResolutions.indexOf(resolution) - 1];
  }
  return resolution;
}

/// 一次布局测量得到的两种独立 LOD 结果。
class ArtworkLodSelection {
  const ArtworkLodSelection({
    required this.originalDecodeResolution,
    required this.xeroxResolution,
  });

  final int originalDecodeResolution;
  final int xeroxResolution;
}

/// LOD 策略是纯计算层，不读取缓存、不持有图片，也不发起任务。
class ArtworkLodManager {
  const ArtworkLodManager();

  static const instance = ArtworkLodManager();

  ArtworkLodSelection select(
    double physicalExtent, {
    int? currentOriginalDecodeResolution,
    int? currentXeroxResolution,
  }) => ArtworkLodSelection(
    originalDecodeResolution: artworkDecodeResolution(
      physicalExtent,
      current: currentOriginalDecodeResolution,
    ),
    xeroxResolution: xeroxResolution(
      physicalExtent,
      current: currentXeroxResolution,
    ),
  );
}
