import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musaic/features/artwork/presentation/album_color_family.dart';

void main() {
  test('creates only hue groups represented by actual artwork colors', () async {
    final index = AlbumColorFamilyIndex();
    final redA = {'id': 'red-a', 'asset': 'remote:red-a'};
    final redB = {'id': 'red-b', 'asset': 'remote:red-b'};
    final blue = {'id': 'blue', 'asset': 'remote:blue'};
    index.register(redA, const Color(0xffa02020));
    index.register(redB, const Color(0xffff7777));
    index.register(blue, const Color(0xff2255bb));
    await Future<void>.delayed(Duration.zero);
    expect(index.availableFamilies, hasLength(2));
    expect(index.familyOf(redA), index.familyOf(redB));
    expect(index.familyOf(redA), isNot(index.familyOf(blue)));
    expect(index.organize([blue, redA, redB], index.familyOf(redA)), [redA, redB]);
    index.dispose();
  });

  test('does not expose colors absent from the catalog', () async {
    final index = AlbumColorFamilyIndex();
    final green = {'id': 'green', 'asset': 'remote:green'};
    index.register(green, const Color(0xff229944));
    await Future<void>.delayed(Duration.zero);
    expect(index.availableFamilies, hasLength(1));
    expect(index.availableFamilies.single.label, contains('绿'));
    index.dispose();
  });

  test('neutral family exists only when neutral artwork exists', () async {
    final index = AlbumColorFamilyIndex();
    final neutral = {'id': 'neutral', 'asset': 'remote:neutral'};
    index.register(neutral, const Color(0xff888888));
    await Future<void>.delayed(Duration.zero);
    expect(index.availableFamilies, hasLength(1));
    expect(index.availableFamilies.single.isNeutral, isTrue);
    index.dispose();
  });
}
