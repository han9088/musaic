import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../services/audio/musaic_sound.dart';
import '../../../services/coverflow_photo_library.dart';
import '../../../services/diagnostics/diagnostic_log.dart';
import 'coverflow_photo.dart';
import 'coverflow_photo_preview.dart';
import 'coverflow_photo_viewer.dart';

/// Owns the camera background and saving the composed scene; the builder owns UI.
class CoverFlowCameraScene extends StatefulWidget {
  const CoverFlowCameraScene({super.key, required this.builder});

  final Widget Function(VoidCallback? toggleCamera) builder;

  static bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);

  @override
  State<CoverFlowCameraScene> createState() => _CoverFlowCameraSceneState();
}

class _CoverFlowCameraSceneState extends State<CoverFlowCameraScene>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  final _overlayKey = GlobalKey();
  late final _flash = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 150),
    value: 1,
  );
  late final _flashOpacity = _flash.drive(Tween(begin: 0.85, end: 0.0));
  CameraController? _camera;
  ({ui.Image image, String assetId})? _photoPreview;
  Future<void> _closing = Future.value();
  bool _enabled = false;
  bool _opening = false;
  bool _saving = false;
  int _generation = 0;
  Future<MusaicSound?>? _shutter;

  bool get _resumed =>
      WidgetsBinding.instance.lifecycleState == null ||
      WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)
        ?.showSnackBar(SnackBar(content: Text(message)));
  }

  void _toggle() {
    if (_saving) return;
    setState(() => _enabled = !_enabled);
    if (_enabled) {
      unawaited(_open());
    } else {
      unawaited(_close());
    }
  }

  Future<void> _open() async {
    if (_opening || !_enabled || !_resumed) return;
    _opening = true;
    final generation = ++_generation;
    CameraController? pending;
    try {
      await _closing;
      final cameras = await availableCameras();
      if (!mounted || generation != _generation || !_enabled) return;
      if (cameras.isEmpty) {
        throw CameraException('NoCamera', 'No camera is available.');
      }
      final description = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      pending = CameraController(
        description,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await pending.initialize();
      if (!mounted || generation != _generation || !_enabled || !_resumed) {
        return;
      }
      // AVFoundation already plays the shutter sound on iOS.
      if (defaultTargetPlatform == TargetPlatform.android) {
        _shutter ??= _prepareShutter();
      }
      setState(() {
        _camera = pending;
        pending = null;
      });
      diagnosticLog.record(DiagnosticEvent.cameraOpened);
    } catch (error, stack) {
      if (mounted && generation == _generation && _enabled) {
        setState(() => _enabled = false);
        final l10n = AppLocalizations.of(context);
        final denied =
            error is CameraException && error.code.startsWith('CameraAccess');
        diagnosticLog.record(
          switch (error) {
            _ when denied => DiagnosticEvent.cameraAccessDenied,
            CameraException(code: 'NoCamera') =>
              DiagnosticEvent.cameraUnavailable,
            _ => DiagnosticEvent.cameraOpenFailed,
          },
          error: error,
          stack: stack,
        );
        _message(
          denied ? l10n.coverFlowCameraDenied : l10n.coverFlowCameraFailed,
        );
        debugPrint('Cover Flow camera: $error\n$stack');
      }
    } finally {
      if (pending != null) await _release(pending!);
      _opening = false;
      if (mounted && _enabled && _resumed && _camera == null) {
        unawaited(_open());
      }
    }
  }

  Future<void> _close() {
    _generation++;
    _clearPhotoPreview();
    _flash.value = 1;
    final camera = _camera;
    _camera = null;
    if (camera != null) _closing = _release(camera);
    return _closing;
  }

  Future<void> _release(CameraController camera) async {
    try {
      await camera.dispose();
    } catch (error) {
      debugPrint('Cover Flow camera cleanup: $error');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_enabled && _camera == null) unawaited(_open());
    } else if (_camera != null) {
      setState(() => unawaited(_close()));
    }
  }

  Size _previewSize(CameraValue value) {
    final size = value.previewSize!;
    final orientation =
        value.lockedCaptureOrientation ?? value.deviceOrientation;
    return switch (orientation) {
      DeviceOrientation.landscapeLeft ||
      DeviceOrientation.landscapeRight => size,
      _ => Size(size.height, size.width),
    };
  }

  void _clearPhotoPreview() {
    _photoPreview?.image.dispose();
    _photoPreview = null;
  }

  Future<void> _viewPhoto() async {
    final photo = _photoPreview;
    if (photo == null) return;
    final image = photo.image.clone();
    setState(_clearPhotoPreview);
    final route = MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) =>
          CoverFlowPhotoViewer(image: image, assetId: photo.assetId),
    );
    try {
      await Navigator.of(context).push(route);
      await route.completed;
    } finally {
      image.dispose();
    }
  }

  Future<MusaicSound?> _prepareShutter() async {
    final player = MusaicSound();
    try {
      await player.prepare('assets/sounds/camera_shutter.wav');
      return player;
    } catch (error) {
      debugPrint('Cover Flow shutter sound unavailable: $error');
      await _disposeShutter(player);
      return null;
    }
  }

  Future<void> _playShutter() async {
    final player = await _shutter;
    if (!mounted || !_resumed || _camera == null) return;
    try {
      await player?.start();
    } catch (error) {
      debugPrint('Cover Flow shutter sound: $error');
    }
  }

  Future<void> _disposeShutter(MusaicSound? player) async {
    try {
      await player?.dispose();
    } catch (error) {
      debugPrint('Cover Flow shutter sound cleanup: $error');
    }
  }

  Future<void> _capture() async {
    final camera = _camera;
    if (_saving || camera == null || !camera.value.isInitialized) return;
    _saving = true;
    if (_photoPreview != null) setState(_clearPhotoPreview);
    if (!MediaQuery.disableAnimationsOf(context)) _flash.forward(from: 0);
    if (_shutter != null) unawaited(_playShutter());
    ui.Image? overlay;
    ui.Image? composed;
    XFile? photo;
    try {
      await camera.lockCaptureOrientation();
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted || !identical(camera, _camera)) return;
      final boundary =
          _overlayKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      final previewSize = _previewSize(camera.value);
      overlay = await boundary.toImage(
        pixelRatio: MediaQuery.devicePixelRatioOf(context),
      );
      photo = await camera.takePicture();
      final image = await composeCoverFlowPhoto(
        cameraBytes: await photo.readAsBytes(),
        previewSize: previewSize,
        overlay: overlay,
      );
      composed = image;
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      if (png == null) {
        throw StateError('Could not encode the Cover Flow photo.');
      }
      final assetId = await saveCoverFlowPhoto(
        png.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes),
      );
      diagnosticLog.record(DiagnosticEvent.cameraPhotoSaved);
      if (mounted && _enabled) {
        setState(() => _photoPreview = (image: image, assetId: assetId));
        composed = null;
      }
      unawaited(HapticFeedback.mediumImpact());
    } catch (error, stack) {
      diagnosticLog.record(
        DiagnosticEvent.cameraPhotoFailed,
        error: error,
        stack: stack,
      );
      if (mounted) {
        _message(AppLocalizations.of(context).coverFlowPhotoSaveFailed);
      }
      debugPrint('Cover Flow photo: $error\n$stack');
    } finally {
      overlay?.dispose();
      composed?.dispose();
      if (identical(camera, _camera)) {
        try {
          await camera.unlockCaptureOrientation();
        } catch (error) {
          debugPrint('Cover Flow capture orientation cleanup: $error');
        }
      }
      if (photo != null && photo.path.isNotEmpty) {
        try {
          await File(photo.path).delete();
        } on FileSystemException catch (error) {
          debugPrint('Cover Flow temporary photo cleanup: $error');
        }
      }
      _saving = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_close());
    if (_shutter case final shutter?) {
      unawaited(shutter.then(_disposeShutter));
    }
    _flash.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final camera = _camera;
    final photoPreview = _photoPreview;
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Colors.black),
        if (camera != null)
          Positioned.fill(
            child: IgnorePointer(
              child: ValueListenableBuilder<CameraValue>(
                valueListenable: camera,
                builder: (context, value, _) => ClipRect(
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox.fromSize(
                      size: _previewSize(value),
                      child: CameraPreview(camera),
                    ),
                  ),
                ),
              ),
            ),
          ),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: camera == null ? null : _capture,
          child: RepaintBoundary(
            key: _overlayKey,
            child: widget.builder(
              CoverFlowCameraScene.supported ? _toggle : null,
            ),
          ),
        ),
        if (photoPreview != null)
          CoverFlowPhotoPreview(
            key: ObjectKey(photoPreview.image),
            image: photoPreview.image,
            reduceMotion: MediaQuery.disableAnimationsOf(context),
            label: AppLocalizations.of(context).coverFlowPhotoPreview,
            onTap: _viewPhoto,
            onDismissed: () => setState(_clearPhotoPreview),
          ),
        if (camera != null)
          IgnorePointer(
            child: FadeTransition(
              opacity: _flashOpacity,
              child: const ColoredBox(color: Colors.white),
            ),
          ),
      ],
    );
  }
}
