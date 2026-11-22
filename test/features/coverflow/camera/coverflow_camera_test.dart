import 'dart:async';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gal/gal_platform_interface.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musaic/features/coverflow/album_coverflow.dart';
import 'package:musaic/features/coverflow/camera/coverflow_photo.dart';
import 'package:musaic/features/coverflow/camera/coverflow_photo_preview.dart';
import 'package:musaic/features/coverflow/camera/coverflow_photo_viewer.dart';
import 'package:musaic/l10n/generated/app_localizations.dart';
import 'package:musaic/services/album_haptics.dart';

const _back = CameraDescription(
  name: 'back',
  lensDirection: CameraLensDirection.back,
  sensorOrientation: 90,
);

ui.Image _image(int width, int height, void Function(ui.Canvas) paint) {
  final recorder = ui.PictureRecorder();
  paint(ui.Canvas(recorder));
  final picture = recorder.endRecording();
  try {
    return picture.toImageSync(width, height);
  } finally {
    picture.dispose();
  }
}

Future<Uint8List> _png(ui.Image image) async {
  final data = (await image.toByteData(format: ui.ImageByteFormat.png))!;
  return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
}

class _Camera extends CameraPlatform {
  List<CameraDescription> cameras = const [_back];
  final settings = <MediaSettings>[];
  int disposed = 0;
  int captures = 0;
  Completer<void>? initializeGate;
  CameraException? openError;
  late Uint8List photo;

  @override
  Future<List<CameraDescription>> availableCameras() async => cameras;

  @override
  Future<int> createCameraWithSettings(
    CameraDescription description,
    MediaSettings mediaSettings,
  ) async {
    if (openError != null) throw openError!;
    settings.add(mediaSettings);
    return settings.length;
  }

  @override
  Future<void> initializeCamera(
    int cameraId, {
    ImageFormatGroup imageFormatGroup = ImageFormatGroup.unknown,
  }) async => initializeGate?.future;

  @override
  Stream<CameraInitializedEvent> onCameraInitialized(int cameraId) =>
      Stream.value(
        CameraInitializedEvent(
          cameraId,
          80,
          40,
          ExposureMode.auto,
          false,
          FocusMode.auto,
          false,
        ),
      );

  @override
  Stream<CameraErrorEvent> onCameraError(int cameraId) =>
      Stream<CameraErrorEvent>.multi((_) {});

  @override
  Stream<DeviceOrientationChangedEvent> onDeviceOrientationChanged() =>
      Stream.value(
        const DeviceOrientationChangedEvent(DeviceOrientation.landscapeLeft),
      );

  @override
  Widget buildPreview(int cameraId) => const ColoredBox(color: Colors.blue);

  @override
  Future<void> lockCaptureOrientation(
    int cameraId,
    DeviceOrientation orientation,
  ) async {}

  @override
  Future<void> unlockCaptureOrientation(int cameraId) async {}

  @override
  Future<XFile> takePicture(int cameraId) async {
    captures++;
    return XFile.fromData(photo, mimeType: 'image/png');
  }

  @override
  Future<void> dispose(int cameraId) async {
    disposed++;
  }
}

final class _Gallery extends GalPlatform {
  static const channel = MethodChannel('com.deskbtm.musaic/coverflow_photos');
  Uint8List? saved;
  Completer<void>? gate;
  Object? error;
  final deleted = <String>[];
  int count = 0;

  @override
  Future<bool> requestPermission({bool toAlbum = false}) async => true;

  Future<Object?> handle(MethodCall call) async {
    if (call.method == 'delete') {
      deleted.add(call.arguments as String);
      return true;
    }
    expect(call.method, 'save');
    saved = call.arguments as Uint8List;
    if (error != null) throw error!;
    await gate?.future;
    return 'photo-${++count}';
  }
}

void main() {
  late CameraPlatform previousCamera;
  late GalPlatform previousGallery;
  late _Camera camera;
  late _Gallery gallery;

  setUp(() {
    previousCamera = CameraPlatform.instance;
    previousGallery = GalPlatform.instance;
    CameraPlatform.instance = camera = _Camera();
    GalPlatform.instance = gallery = _Gallery();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_Gallery.channel, gallery.handle);
  });
  tearDown(() {
    CameraPlatform.instance = previousCamera;
    GalPlatform.instance = previousGallery;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_Gallery.channel, null);
  });

  Future<void> mount(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    final haptics = AlbumHaptics();
    addTearDown(haptics.dispose);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: AlbumCoverFlow(
            haptics: haptics,
            albums: const [
              {'asset': 'local:cover', 'artist': 'Artist', 'title': 'Album'},
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('thumbnail opens the saved photo and delete targets its id', (
    tester,
  ) async {
    final messenger = tester.binding.defaultBinaryMessenger;
    const player = MethodChannel('xyz.luan/audioplayers');
    const global = MethodChannel('xyz.luan/audioplayers.global');
    const globalEvents = MethodChannel('xyz.luan/audioplayers.global/events');
    var shutterPlays = 0;
    messenger.setMockMethodCallHandler(global, (_) async => null);
    messenger.setMockMethodCallHandler(globalEvents, (_) async => null);
    messenger.setMockMethodCallHandler(player, (call) async {
      final id = (call.arguments as Map)['playerId'];
      final events = MethodChannel('xyz.luan/audioplayers/events/$id');
      if (call.method == 'create') {
        messenger.setMockMethodCallHandler(events, (_) async => null);
        addTearDown(() => messenger.setMockMethodCallHandler(events, null));
      } else if (call.method == 'setSourceBytes') {
        await messenger.handlePlatformMessage(
          events.name,
          const StandardMethodCodec().encodeSuccessEnvelope({
            'event': 'audio.onPrepared',
            'value': true,
          }),
          (_) {},
        );
      } else if (call.method == 'resume') {
        shutterPlays++;
      }
      return null;
    });
    addTearDown(() {
      for (final channel in [player, global, globalEvents]) {
        messenger.setMockMethodCallHandler(channel, null);
      }
    });
    await mount(tester);
    final blue = _image(
      80,
      40,
      (canvas) => canvas.drawColor(Colors.blue, ui.BlendMode.src),
    );
    camera.photo = (await tester.runAsync(() => _png(blue)))!;
    blue.dispose();
    await tester.longPress(find.text('Album'));
    await tester.pumpAndSettle();
    expect(shutterPlays, 0);

    Future<void> openCapture() async {
      await tester.tapAt(const Offset(5, 60));
      final thumbnail = find.byType(CoverFlowPhotoPreview);
      for (var i = 0; i < 100 && thumbnail.evaluate().isEmpty; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
      }
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Open captured photo'));
      await tester.pumpAndSettle();
      expect(find.byType(CoverFlowPhotoViewer), findsOneWidget);
    }

    await openCapture();
    expect(camera.captures, 1);
    addTearDown(tester.view.resetPadding);
    tester.view.padding = const FakeViewPadding(left: 36, top: 18, right: 27);
    await tester.pump();
    final back = tester.getRect(find.bySemanticsLabel('Back'));
    final delete = tester.getRect(find.bySemanticsLabel('Delete photo'));
    expect(back.left, 60);
    expect(delete.right, 749);
    expect(back.top, 38);
    expect(delete.top, back.top);
    tester.view.resetPadding();
    await tester.pump(const Duration(seconds: 4));
    expect(find.byType(CoverFlowPhotoViewer), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Back'));
    await tester.pumpAndSettle();
    expect(find.byType(CoverFlowPhotoViewer), findsNothing);
    expect(gallery.deleted, isEmpty);

    await openCapture();
    expect(camera.captures, 2);
    await tester.tap(find.bySemanticsLabel('Delete photo'));
    await tester.pumpAndSettle();
    expect(gallery.deleted, ['photo-2']);
    expect(find.byType(CoverFlowPhotoViewer), findsNothing);
    expect(camera.captures, 2);
    expect(shutterPlays, 2);
    await tester.pumpWidget(const SizedBox.shrink());
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('title toggles the rear camera without changing album taps', (
    tester,
  ) async {
    await mount(tester);
    await tester.longPress(find.text('Album'));
    await tester.pumpAndSettle();
    expect(find.byType(CameraPreview), findsOneWidget);
    expect(camera.settings.single.enableAudio, false);
    await tester.tap(find.text('Album'));
    await tester.tapAt(const Offset(400, 200));
    await tester.pumpAndSettle();
    expect(camera.captures, 0);
    await tester.longPress(find.text('Album'));
    await tester.pumpAndSettle();
    expect(find.byType(CameraPreview), findsNothing);
    expect(camera.disposed, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets(
    'empty-space capture saves the camera, title, covers and reflection',
    (tester) async {
      await mount(tester);
      final blue = _image(
        80,
        40,
        (canvas) => canvas.drawColor(Colors.blue, ui.BlendMode.src),
      );
      camera.photo = (await tester.runAsync(() => _png(blue)))!;
      blue.dispose();
      gallery.gate = Completer<void>();
      await tester.longPress(find.text('Album'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(5, 60));
      await tester.pump();
      final flash = find.byWidgetPredicate(
        (widget) => widget is FadeTransition && widget.child is ColoredBox,
      );
      expect(
        tester.widget<FadeTransition>(flash).opacity.value,
        greaterThan(0.8),
      );
      for (var i = 0; i < 100 && gallery.saved == null; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
      }
      expect(gallery.saved, isNotNull);
      await tester.tapAt(const Offset(5, 60));
      expect(camera.captures, 1);
      final decoded = (await tester.runAsync(() async {
        final codec = await ui.instantiateImageCodec(gallery.saved!);
        final image = (await codec.getNextFrame()).image;
        codec.dispose();
        return image;
      }))!;
      expect(
        Size(decoded.width.toDouble(), decoded.height.toDouble()),
        const Size(800, 400),
      );
      final pixels = (await tester.runAsync(
        () => decoded.toByteData(format: ui.ImageByteFormat.rawRgba),
      ))!;
      List<int> rgb(int x, int y) => [
        for (var channel = 0; channel < 3; channel++)
          pixels.getUint8((y * decoded.width + x) * 4 + channel),
      ];
      expect(rgb(5, 60), [33, 150, 243]);
      expect(rgb(400, 300), [41, 41, 41]);
      expect(rgb(400, 350), isNot([33, 150, 243]));
      expect(
        [for (var x = 360; x < 440; x++) rgb(x, 30)[0]].any((red) => red > 200),
        true,
      );
      decoded.dispose();
      gallery.gate!.complete();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
      final preview = find.descendant(
        of: find.byType(CoverFlowPhotoPreview),
        matching: find.byType(RawImage),
      );
      expect(tester.getRect(preview), const Rect.fromLTWH(0, 0, 800, 400));
      await tester.pump(const Duration(milliseconds: 180));
      expect(tester.widget<FadeTransition>(flash).opacity.value, 0);
      expect(tester.getSize(preview).width, inExclusiveRange(104, 800));
      await tester.pump(const Duration(milliseconds: 181));
      const thumbnail = Rect.fromLTWH(684, 12, 104, 52);
      expect(tester.getRect(preview), thumbnail);
      await tester.pump(const Duration(milliseconds: 2999));
      expect(tester.getRect(preview), thumbnail);
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 115));
      final sliding = tester.getRect(preview);
      expect(sliding.left, greaterThan(thumbnail.left));
      expect(sliding.top, thumbnail.top);
      expect(sliding.size, thumbnail.size);
      await tester.pump(const Duration(milliseconds: 116));
      await tester.pump();
      expect(preview, findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('camera releases in background and reopens on resume', (
    tester,
  ) async {
    await mount(tester);
    await tester.longPress(find.text('Album'));
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pumpAndSettle();
    expect(camera.disposed, 1);
    expect(find.byType(CameraPreview), findsNothing);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(camera.settings, hasLength(2));
    expect(find.byType(CameraPreview), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(camera.disposed, 2);
  });

  testWidgets('leaving during initialization releases the pending camera', (
    tester,
  ) async {
    await mount(tester);
    camera.initializeGate = Completer<void>();
    await tester.longPress(find.text('Album'));
    await tester.pump();
    expect(camera.settings, hasLength(1));
    await tester.pumpWidget(const SizedBox.shrink());
    camera.initializeGate!.complete();
    await tester.pump();
    expect(camera.disposed, 1);
  });

  testWidgets('no camera returns to the black background with an error', (
    tester,
  ) async {
    camera.cameras = [];
    await mount(tester);
    await tester.longPress(find.text('Album'));
    await tester.pumpAndSettle();
    expect(camera.settings, isEmpty);
    expect(
      find.text('Could not open the camera. Please try again.'),
      findsOneWidget,
    );
    expect(find.byType(CameraPreview), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('desktop title does not open the camera', (tester) async {
    await mount(tester);
    await tester.longPress(find.text('Album'));
    await tester.pumpAndSettle();
    expect(camera.settings, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('denied camera permission leaves album browsing available', (
    tester,
  ) async {
    camera.openError = CameraException('CameraAccessDenied', 'Denied');
    await mount(tester);
    await tester.longPress(find.text('Album'));
    await tester.pumpAndSettle();
    expect(find.byType(CameraPreview), findsNothing);
    expect(
      find.text(
        'Allow camera access in system settings to use the live background.',
      ),
      findsOneWidget,
    );
    await tester.tapAt(const Offset(400, 200));
    await tester.pumpAndSettle();
    expect(camera.captures, 0);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a failed gallery save releases the shutter for retry', (
    tester,
  ) async {
    await mount(tester);
    final blue = _image(
      80,
      40,
      (canvas) => canvas.drawColor(Colors.blue, ui.BlendMode.src),
    );
    camera.photo = (await tester.runAsync(() => _png(blue)))!;
    blue.dispose();
    gallery.error = PlatformException(code: 'PERMISSION_DENIED');
    await tester.longPress(find.text('Album'));
    await tester.pumpAndSettle();
    for (var attempt = 0; attempt < 2; attempt++) {
      gallery.saved = null;
      await tester.tapAt(const Offset(5, 60));
      for (var i = 0; i < 100 && gallery.saved == null; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
      }
      expect(gallery.saved, isNotNull);
      await tester.pumpAndSettle();
      gallery.error = null;
    }
    expect(camera.captures, 2);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('photo uses the preview crop and preserves transparent overlay', (
    tester,
  ) async {
    final background = _image(120, 80, (canvas) {
      canvas.drawColor(Colors.blue, ui.BlendMode.src);
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, 20, 80),
        ui.Paint()..color = Colors.green,
      );
      canvas.drawRect(
        const Rect.fromLTWH(100, 0, 20, 80),
        ui.Paint()..color = Colors.green,
      );
    });
    final overlay = _image(160, 80, (canvas) {
      canvas.drawRect(
        const Rect.fromLTWH(60, 20, 40, 40),
        ui.Paint()..color = Colors.red,
      );
    });
    final pixels = (await tester.runAsync(() async {
      final result = await composeCoverFlowPhoto(
        cameraBytes: await _png(background),
        previewSize: const Size(80, 80),
        overlay: overlay,
      );
      try {
        return await result.toByteData(format: ui.ImageByteFormat.rawRgba);
      } finally {
        result.dispose();
      }
    }))!;
    List<int> rgb(int x, int y) => [
      for (var channel = 0; channel < 3; channel++)
        pixels.getUint8((y * 160 + x) * 4 + channel),
    ];
    expect(rgb(5, 40), [33, 150, 243]);
    expect(rgb(155, 40), [33, 150, 243]);
    expect(rgb(80, 40), [244, 67, 54]);
    overlay.dispose();
    background.dispose();
  });
}
