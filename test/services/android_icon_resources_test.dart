import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('text and primary vinyl icons use the renamed Android resources', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();
    expect(manifest, contains('@mipmap/ic_launcher_text'));
    expect(manifest, contains('@mipmap/ic_launcher_vinyl_primary'));

    final text = File(
      'android/app/src/main/res/mipmap-anydpi-v26/ic_launcher_text.xml',
    ).readAsStringSync();
    expect(text, contains('@mipmap/ic_launcher_text_foreground'));
    expect(text, contains('@mipmap/ic_launcher_text_background'));

    final vinylPrimary = File(
      'android/app/src/main/res/mipmap-anydpi-v26/ic_launcher_vinyl_primary.xml',
    ).readAsStringSync();
    expect(
      vinylPrimary,
      contains('@mipmap/ic_launcher_vinyl_primary_foreground'),
    );
    expect(
      vinylPrimary,
      contains('@mipmap/ic_launcher_vinyl_primary_background'),
    );

    for (final density in ['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi']) {
      for (final name in ['text', 'vinyl_primary']) {
        for (final suffix in ['', '_background', '_foreground', '_round']) {
          expect(
            File(
              'android/app/src/main/res/mipmap-$density/ic_launcher_$name$suffix.webp',
            ).existsSync(),
            isTrue,
          );
        }
      }
    }
  });

  for (final name in ['mosaic', 'vinyl']) {
    test('adaptive $name layers reference a bitmap, not the adaptive icon itself', () {
      final icon = File(
        'android/app/src/main/res/mipmap-anydpi-v26/ic_launcher_$name.xml',
      ).readAsStringSync();
      expect(icon, isNot(contains('"@mipmap/ic_launcher_$name"')));
      expect(icon, contains('"@mipmap/ic_launcher_${name}_foreground"'));
      if (name == 'vinyl') {
        expect(icon, contains('"@color/ic_launcher_vinyl_background"'));
        expect(
          File(
            'android/app/src/main/res/mipmap-anydpi/ic_launcher_vinyl_foreground.xml',
          ).existsSync(),
          isFalse,
        );
        expect(
          File('android/app/src/main/res/mipmap-anydpi/ic_launcher_vinyl.xml')
              .existsSync(),
          isFalse,
        );
        for (final density in ['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi']) {
          for (final suffix in ['', '_foreground']) {
            expect(
              File(
                'android/app/src/main/res/mipmap-$density/ic_launcher_vinyl$suffix.webp',
              ).existsSync(),
              isTrue,
            );
          }
        }
        return;
      }
      final foreground = File(
        'android/app/src/main/res/mipmap-anydpi/ic_launcher_${name}_foreground.xml',
      ).readAsStringSync();
      expect(foreground, isNot(contains('"@mipmap/ic_launcher_$name"')));
      expect(foreground, contains('"@mipmap/ic_launcher_${name}_background"'));
      final background = File(
        'android/app/src/main/res/mipmap-anydpi/ic_launcher_${name}_background.xml',
      ).readAsStringSync();
      expect(background, contains('"@drawable/musaic_$name"'));
      expect(
        File('android/app/src/main/res/drawable-nodpi/musaic_$name.png')
            .existsSync(),
        isTrue,
      );
    });
  }
}
