import 'package:flutter_test/flutter_test.dart';
import 'package:musaic/features/artwork/pipeline/artwork_lod_manager.dart';

void main() {
  test('original and Xerox share one discrete resolution ladder', () {
    expect(artworkResolutions, [64, 128, 256, 512, 1024]);
    expect(selectArtworkResolution(40), 64);
    expect(selectArtworkResolution(100), 128);
    expect(selectArtworkResolution(180), 256);
    expect(selectArtworkResolution(400), 512);
    expect(selectArtworkResolution(900), 1024);
    expect(selectArtworkResolution(1600), 1024);
  });

  test('invalid physical sizes use the same safe default', () {
    expect(selectArtworkResolution(0), defaultArtworkResolution);
    expect(selectArtworkResolution(double.nan), defaultArtworkResolution);
    expect(
      selectArtworkResolution(double.infinity),
      defaultArtworkResolution,
    );
    expect(selectArtworkResolution(double.nan, current: 512), 512);
  });

  test('shared policy uses the same hysteresis thresholds', () {
    expect(selectArtworkResolution(300, current: 256), 256);
    expect(selectArtworkResolution(400, current: 256), 512);
    expect(selectArtworkResolution(350, current: 512), 512);
    expect(selectArtworkResolution(300, current: 512), 256);
  });

  test('reuse requires matching initial and hysteresis selections', () {
    const manager = ArtworkLodManager();
    expect(manager.hasSameSelections(100, 101), isTrue);
    expect(manager.hasSameSelections(127, 129), isFalse);
    expect(selectArtworkResolution(83), selectArtworkResolution(84));
    expect(manager.hasSameSelections(83, 84), isFalse);
  });

  test('LOD manager applies the shared policy to both resource paths', () {
    const manager = ArtworkLodManager();

    final initial = manager.select(400);
    expect(initial.originalDecodeResolution, 512);
    expect(initial.xeroxResolution, 512);

    final invalid = manager.select(double.nan);
    expect(invalid.originalDecodeResolution, defaultArtworkResolution);
    expect(invalid.xeroxResolution, defaultArtworkResolution);

    // 两条资源路径保留各自当前档位，但使用完全相同的选择规则。
    // 处于滞回区间时允许暂时保留不同的历史档位。
    final hysteresis = manager.select(
      340,
      currentOriginalDecodeResolution: 256,
      currentXeroxResolution: 512,
    );
    expect(hysteresis.originalDecodeResolution, 256);
    expect(hysteresis.xeroxResolution, 512);
  });
}
