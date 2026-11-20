import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';

const _channel = MethodChannel('com.deskbtm.musaic/coverflow_photos');

Future<String> saveCoverFlowPhoto(Uint8List bytes) async {
  // Gal handles the storage permission on Android 9 and older.
  if (defaultTargetPlatform == TargetPlatform.android &&
      !await Gal.requestPermission()) {
    throw PlatformException(code: 'storagePermissionDenied');
  }
  return (await _channel.invokeMethod<String>('save', bytes))!;
}

Future<bool> deleteCoverFlowPhoto(String assetId) async =>
    (await _channel.invokeMethod<bool>('delete', assetId))!;
