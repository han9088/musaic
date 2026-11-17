import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'tooling targets the real activity without a duplicate desktop entry',
    () {
      final manifest = File('android/app/src/main/AndroidManifest.xml')
          .readAsStringSync();
      final activity = RegExp(r'<activity\b[^>]*>[\s\S]*?</activity>')
          .allMatches(manifest)
          .single
          .group(0)!;
      expect(activity, contains('android:name=".MainActivity"'));
      expect(activity, contains('android.intent.action.MAIN'));
      expect(activity, contains('android.intent.category.LAUNCHER'));
      expect(activity, contains('<data android:scheme="musaic-tooling"/>'));
      final aliases = RegExp(
        r'<activity-alias\b[^>]*>[\s\S]*?</activity-alias>',
      ).allMatches(manifest).map((match) => match.group(0)!).toList();
      expect(aliases, hasLength(5));
      for (final name in [
        'default',
        'MusaicMosaic',
        'MusaicVinyl',
        'MusaicVinylWhite',
        'MuasicXerox',
      ]) {
        final alias = aliases.singleWhere(
          (alias) => alias.contains('MainActivity.$name"'),
        );
        expect(alias, contains('android:targetActivity=".MainActivity"'));
        expect(alias, contains('android.intent.action.MAIN'));
        expect(alias, contains('android.intent.category.LAUNCHER'));
        expect(alias, isNot(contains('<data ')));
      }
      for (final variant in ['debug', 'profile', 'release']) {
        final overlay = File('android/app/src/$variant/AndroidManifest.xml');
        if (overlay.existsSync()) {
          expect(overlay.readAsStringSync(), isNot(contains('removeAll')));
        }
      }
    },
  );
}
