import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('tooling targets the real activity without a duplicate desktop entry', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    final activity = manifest.substring(
      manifest.indexOf('<activity\n'),
      manifest.indexOf('</activity>'),
    );
    expect(activity, contains('android:name=".MainActivity"'));
    expect(activity, contains('android.intent.action.MAIN'));
    expect(activity, contains('android.intent.category.LAUNCHER'));
    expect(activity, contains('<data android:scheme="musaic-tooling"/>'));
    final aliases = manifest.substring(manifest.indexOf('<activity-alias'));
    expect(aliases, contains('MainActivity.default'));
    expect(aliases, contains('MainActivity.MusaicMosaic'));
    expect(aliases, isNot(contains('<data ')));
    for (final variant in ['debug', 'profile', 'release']) {
      final overlay = File('android/app/src/$variant/AndroidManifest.xml');
      if (overlay.existsSync()) {
        expect(overlay.readAsStringSync(), isNot(contains('removeAll')));
      }
    }
  });
}
