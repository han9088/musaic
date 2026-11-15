import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final name in ['mosaic', 'vinyl']) {
    test('adaptive $name layers reference a bitmap, not the adaptive icon itself', () {
      final icon = File(
        'android/app/src/main/res/mipmap-anydpi-v26/ic_launcher_${name}.xml',
      ).readAsStringSync();
      expect(icon, isNot(contains('"@mipmap/ic_launcher_${name}"')));
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
      expect(foreground, isNot(contains('"@mipmap/ic_launcher_${name}"')));
      expect(foreground, contains('"@mipmap/ic_launcher_${name}_background"'));
      final background = File(
        'android/app/src/main/res/mipmap-anydpi/ic_launcher_${name}_background.xml',
      ).readAsStringSync();
      expect(background, contains('"@drawable/musaic_${name}"'));
      expect(
        File('android/app/src/main/res/drawable-nodpi/musaic_${name}.png')
            .existsSync(),
        isTrue,
      );
    });
  }
}
