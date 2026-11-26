import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musaic/features/artwork/presentation/album_color_family.dart';

void main() {
  test('groups shades into simple broad color families', () async {
    final index = AlbumColorFamilyIndex();
    final darkGreen = {'id': 'green-a', 'asset': 'remote:green-a'};
    final lightGreen = {'id': 'green-b', 'asset': 'remote:green-b'};
    final cyan = {'id': 'cyan', 'asset': 'remote:cyan'};
    final blue = {'id': 'blue', 'asset': 'remote:blue'};
    index.register(darkGreen, const Color(0xff185a32));
    index.register(lightGreen, const Color(0xff62ad76));
    index.register(cyan, const Color(0xff28b4b2));
    index.register(blue, const Color(0xff2255bb));
    await Future<void>.delayed(Duration.zero);

    expect(index.familyOf(darkGreen)?.label, '绿色');
    expect(index.familyOf(lightGreen), index.familyOf(darkGreen));
    expect(index.familyOf(cyan)?.label, '青色');
    expect(index.familyOf(blue)?.label, '蓝色');
    expect(index.availableFamilies, hasLength(3));
    index.dispose();
  });

  test('shows only families present in current artwork data', () async {
    final index = AlbumColorFamilyIndex();
    final green = {'id': 'green', 'asset': 'remote:green'};
    index.register(green, const Color(0xff229944));
    await Future<void>.delayed(Duration.zero);
    expect(index.availableFamilies, hasLength(1));
    expect(index.availableFamilies.single.label, '绿色');
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
