// 文件职责：统一管理原图解码与 Xerox 输出共用的分辨率档位和 LOD 选择策略。

/// 原图解码和 Xerox 输出共用同一套离散分辨率档位。
///
/// 使用统一档位可以让相同物理显示尺寸在相同 LOD 状态下得到相同分辨率，
/// 同时避免连续缩放产生大量不同尺寸的 ImageCache 和 Raster Cache 条目。
const artworkResolutions = <int>[64, 128, 256, 512, 1024];

/// 物理尺寸无效且没有可沿用档位时，统一回退到中间档位。
const defaultArtworkResolution = 256;

/// 根据目标物理像素和当前档位选择分辨率。
///
/// 首次选择时取能够覆盖目标尺寸的最小档位；
/// 已有档位时使用统一的升级和降级迟滞阈值，减少缩放边界附近的反复切换。
///
/// 原图解码和 Xerox 输出分别保存自己的 current，但都必须调用本策略，
/// 因此策略规则一致，资源状态仍然可以独立管理。
int selectArtworkResolution(double physicalExtent, {int? current}) {
  if (!physicalExtent.isFinite || physicalExtent <= 0) {
    if (current != null && artworkResolutions.contains(current)) {
      return current;
    }
    return defaultArtworkResolution;
  }

  if (current == null || !artworkResolutions.contains(current)) {
    return artworkResolutions.firstWhere(
      (resolution) => physicalExtent <= resolution,
      orElse: () => artworkResolutions.last,
    );
  }

  var resolution = current;
  var index = artworkResolutions.indexOf(resolution);

  // 放大超过当前档位的 1.35 倍才升级。
  while (index < artworkResolutions.length - 1 &&
      physicalExtent > resolution * 1.35) {
    index++;
    resolution = artworkResolutions[index];
  }

  // 缩小到当前档位的 0.65 倍以下才降级。
  while (index > 0 && physicalExtent < resolution * 0.65) {
    index--;
    resolution = artworkResolutions[index];
  }

  return resolution;
}

/// 一次布局测量得到的原图解码与 Xerox 输出分辨率。
///
/// 两个值由同一策略计算，但保留独立字段，避免把原图输入尺寸与 Xerox
/// 最终输出尺寸混为一谈。
class ArtworkLodSelection {
  const ArtworkLodSelection({
    required this.originalDecodeResolution,
    required this.xeroxResolution,
  });

  final int originalDecodeResolution;
  final int xeroxResolution;
}

/// 纯 LOD 策略入口，不读取缓存、不持有图片，也不发起处理任务。
class ArtworkLodManager {
  const ArtworkLodManager();

  static const instance = ArtworkLodManager();

  /// Both existing covers and newly visible covers keep their original LOD.
  bool hasSameSelections(double first, double second) =>
      first == second ||
      (selectArtworkResolution(first) == selectArtworkResolution(second) &&
          artworkResolutions.every(
            (current) =>
                selectArtworkResolution(first, current: current) ==
                selectArtworkResolution(second, current: current),
          ));

  ArtworkLodSelection select(
    double physicalExtent, {
    int? currentOriginalDecodeResolution,
    int? currentXeroxResolution,
  }) => ArtworkLodSelection(
    originalDecodeResolution: selectArtworkResolution(
      physicalExtent,
      current: currentOriginalDecodeResolution,
    ),
    xeroxResolution: selectArtworkResolution(
      physicalExtent,
      current: currentXeroxResolution,
    ),
  );
}
