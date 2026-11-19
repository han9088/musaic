import 'package:flutter_test/flutter_test.dart';
import 'package:musaic/features/artwork/pipeline/artwork_decode_policy.dart';

void main() {
  test('selects discrete original-image decode sizes', () {
    expect(artworkDecodeResolution(180), 256);
    expect(artworkDecodeResolution(400), 512);
    expect(artworkDecodeResolution(900), 1024);
    expect(artworkDecodeResolution(1600), 1024);
  });

  test('uses hysteresis to avoid LOD oscillation near a boundary', () {
    expect(artworkDecodeResolution(300, current: 256), 256);
    expect(artworkDecodeResolution(400, current: 256), 512);
    expect(artworkDecodeResolution(350, current: 512), 512);
    expect(artworkDecodeResolution(300, current: 512), 256);
  });
}
