import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musaic/services/app_icon_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('flutter_dynamic_icon');
  const service = AppIconService();

  test('white vinyl is available only where its native icon is configured', () {
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    expect(service.choices, contains(AppIconChoice.vinylWhite));
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(service.choices, contains(AppIconChoice.vinylWhite));
    for (final platform in [TargetPlatform.macOS]) {
      debugDefaultTargetPlatformOverride = platform;
      expect(service.choices, isNot(contains(AppIconChoice.vinylWhite)));
      expect(service.choices, contains(AppIconChoice.vinyl));
      expect(service.choices, contains(AppIconChoice.xerox));
    }
  });

  for (final code in ['ICON_CHANGE_PENDING', 'ICON_WRITE_FAILED']) {
    test(
      'macOS read does not report a selection when restore returns $code',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        messenger.setMockMethodCallHandler(channel, (call) async {
          switch (call.method) {
            case 'mSupportsAlternateIcons':
              return true;
            case 'mGetAvailableIcons':
              return <String>[
                'MusaicMosaic',
                'MusaicVinyl',
                'MusaicVinylWhite',
                'MuasicXerox',
              ];
            case 'mGetAlternateIconName':
              throw PlatformException(code: code);
            default:
              throw MissingPluginException();
          }
        });
        addTearDown(() {
          messenger.setMockMethodCallHandler(channel, null);
          debugDefaultTargetPlatformOverride = null;
        });
        await expectLater(
          service.read(),
          throwsA(
            isA<PlatformException>().having(
              (error) => error.code,
              'code',
              code,
            ),
          ),
        );
      },
    );
  }

  test('macOS Finder write errors are surfaced to the caller', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'mSetAlternateIconName') {
        throw PlatformException(code: 'ICON_WRITE_FAILED');
      }
      throw MissingPluginException();
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(channel, null);
      debugDefaultTargetPlatformOverride = null;
    });
    await expectLater(
      service.change(AppIconChoice.classic),
      throwsA(
        isA<PlatformException>().having(
          (error) => error.code,
          'code',
          'ICON_WRITE_FAILED',
        ),
      ),
    );
  });

  test(
    'reads the primary icon and confirms an invalidated iOS callback',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      var didSetIcon = false;
      messenger.setMockMethodCallHandler(channel, (call) async {
        switch (call.method) {
          case 'mSupportsAlternateIcons':
            return true;
          case 'mGetAvailableIcons':
            return <String>[
              'MusaicMosaic',
              'MusaicVinyl',
              'MusaicVinylWhite',
              'MuasicXerox',
            ];
          case 'mGetAlternateIconName':
            return null;
          case 'mSetAlternateIconName':
            expect((call.arguments as Map)['iconName'], isNull);
            expect((call.arguments as Map)['deferUntilBackground'], isFalse);
            didSetIcon = true;
            throw PlatformException(code: 'callback_invalidated');
          default:
            throw MissingPluginException();
        }
      });
      addTearDown(() {
        messenger.setMockMethodCallHandler(channel, null);
        debugDefaultTargetPlatformOverride = null;
      });
      expect(await service.read(), (
        supported: true,
        current: AppIconChoice.classic,
      ));
      await service.change(AppIconChoice.classic);
      expect(didSetIcon, isTrue);
    },
  );

  for (final platform in [TargetPlatform.android, TargetPlatform.macOS]) {
    test('discovers icons and restores primary on $platform', () async {
      debugDefaultTargetPlatformOverride = platform;
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final calls = <String>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call.method);
        switch (call.method) {
          case 'mSupportsAlternateIcons':
            return true;
          case 'mGetAvailableIcons':
            return <String>[
              'MusaicMosaic',
              'MusaicVinyl',
              'MusaicVinylWhite',
              'MuasicXerox',
            ];
          case 'mGetAlternateIconName':
            return null;
          case 'mSetAlternateIconName':
            expect((call.arguments as Map)['iconName'], isNull);
            expect((call.arguments as Map)['deferUntilBackground'], isFalse);
            return null;
          default:
            throw MissingPluginException();
        }
      });
      addTearDown(() {
        messenger.setMockMethodCallHandler(channel, null);
        debugDefaultTargetPlatformOverride = null;
      });
      expect(await service.read(), (
        supported: true,
        current: AppIconChoice.classic,
      ));
      await service.change(AppIconChoice.classic);
      expect(calls, contains('mGetAvailableIcons'));
      expect(calls, contains('mSetAlternateIconName'));
    });
  }
}
