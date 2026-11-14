import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'adaptive mosaic layers reference a bitmap, not the adaptive icon itself',
    () {
      final icon = File(
        'android/app/src/main/res/mipmap-anydpi-v26/ic_launcher_mosaic.xml',
      ).readAsStringSync();
      expect(icon, isNot(contains('"@mipmap/ic_launcher_mosaic"')));
      expect(icon, contains('"@mipmap/ic_launcher_mosaic_foreground"'));
      final foreground = File(
        'android/app/src/main/res/mipmap-anydpi/ic_launcher_mosaic_foreground.xml',
      ).readAsStringSync();
      expect(foreground, isNot(contains('"@mipmap/ic_launcher_mosaic"')));
      expect(foreground, contains('"@mipmap/ic_launcher_mosaic_background"'));
      final background = File(
        'android/app/src/main/res/mipmap-anydpi/ic_launcher_mosaic_background.xml',
      ).readAsStringSync();
      expect(background, contains('"@drawable/musaic_mosaic"'));
      expect(
        File('android/app/src/main/res/drawable-nodpi/musaic_mosaic.png')
            .existsSync(),
        isTrue,
      );
    },
  );
}
