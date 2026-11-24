// Copyright (c) 2024-2025 Larry Aasen. All rights reserved.

import 'dart:async';

import 'package:version/version.dart';

import 'appcast.dart';
import 'itunes_search_api.dart';
import 'play_store_search_api.dart';
import 'update_os.dart';
import 'update_context.dart';
import 'update_version_info.dart';

abstract class UpdateStore {
  Future<UpdateVersionInfo> getVersionInfo({
    required UpdateCheckContext state,
    required Version installedVersion,
    required String? country,
    required String? language,
  });
}

class AppStoreUpdateSource extends UpdateStore {
  @override
  Future<UpdateVersionInfo> getVersionInfo({
    required UpdateCheckContext state,
    required Version installedVersion,
    required String? country,
    required String? language,
  }) async {
    if (state.packageInfo == null) return UpdateVersionInfo();

    String? appStoreListingURL;
    Version? appStoreVersion;
    bool? isCriticalUpdate;
    Version? minAppVersion;
    String? releaseNotes;

    final iTunes = ITunesSearchAPI();
    iTunes.debugLogging = state.debugLogging;
    iTunes.client = state.client;
    iTunes.clientHeaders = state.clientHeaders;
    final response = await (iTunes.lookupByBundleId(
      state.packageInfo!.packageName,
      country: country,
      language: language,
    ));

    if (response != null) {
      final version = iTunes.version(response);
      if (version != null) {
        try {
          appStoreVersion = Version.parse(version);
        } catch (e) {
          if (state.debugLogging) {
            print(
              'upgrader: AppStoreUpdateSource.appStoreVersion "$version" exception: $e',
            );
          }
        }
      }
      appStoreListingURL = iTunes.trackViewUrl(response);
      releaseNotes ??= iTunes.releaseNotes(response);
      minAppVersion = iTunes.minAppVersion(response);
      if (minAppVersion != null) {
        if (state.debugLogging) {
          print('upgrader: AppStoreUpdateSource.minAppVersion: $minAppVersion');
        }
      }
    }

    final versionInfo = UpdateVersionInfo(
      installedVersion: installedVersion,
      appStoreListingURL: appStoreListingURL,
      appStoreVersion: appStoreVersion,
      isCriticalUpdate: isCriticalUpdate,
      minAppVersion: minAppVersion,
      releaseNotes: releaseNotes,
    );
    if (state.debugLogging) {
      print('upgrader: AppStoreUpdateSource: version info: $versionInfo');
    }
    return versionInfo;
  }
}

class GooglePlayUpdateSource extends UpdateStore {
  @override
  Future<UpdateVersionInfo> getVersionInfo({
    required UpdateCheckContext state,
    required Version installedVersion,
    required String? country,
    required String? language,
  }) async {
    if (state.packageInfo == null) return UpdateVersionInfo();
    final id = state.packageInfo!.packageName;
    final playStore = PlayStoreSearchAPI(
      client: state.client,
      clientHeaders: state.clientHeaders,
    );
    playStore.debugLogging = state.debugLogging;

    String? appStoreListingURL;
    Version? appStoreVersion;
    bool? isCriticalUpdate;
    Version? minAppVersion;
    String? releaseNotes;

    final response = await playStore.lookupById(
      id,
      country: country,
      language: language,
    );
    if (response != null) {
      final version = playStore.version(response);
      if (version != null) {
        try {
          appStoreVersion = Version.parse(version);
        } catch (e) {
          if (state.debugLogging) {
            print(
              'upgrader: GooglePlayUpdateSource.appStoreVersion "$version" exception: $e',
            );
          }
        }
      }

      appStoreListingURL ??= playStore.lookupURLById(
        id,
        language: language,
        country: country,
      );
      releaseNotes ??= playStore.releaseNotes(response);
      final mav = playStore.minAppVersion(response);
      if (mav != null) {
        try {
          final minVersion = mav.toString();
          minAppVersion = Version.parse(minVersion);

          if (state.debugLogging) {
            print('upgrader: GooglePlayUpdateSource.minAppVersion: $minAppVersion');
          }
        } catch (e) {
          if (state.debugLogging) {
            print('upgrader: GooglePlayUpdateSource.minAppVersion exception: $e');
          }
        }
      }
    }

    final versionInfo = UpdateVersionInfo(
      installedVersion: installedVersion,
      appStoreListingURL: appStoreListingURL,
      appStoreVersion: appStoreVersion,
      isCriticalUpdate: isCriticalUpdate,
      minAppVersion: minAppVersion,
      releaseNotes: releaseNotes,
    );
    if (state.debugLogging) {
      print('upgrader: GooglePlayUpdateSource: version info: $versionInfo');
    }
    return versionInfo;
  }
}

class AppcastUpdateSource extends UpdateStore {
  AppcastUpdateSource({
    required this.appcastURL,
    this.appcast,
    this.osVersion,
  });

  final String appcastURL;
  final Appcast? appcast;

  /// The operating system version string (e.g. `'14.0.0'`).
  /// When `null` or unparseable, defaults to `Version(0, 0, 0)`.
  final String? osVersion;

  AppcastItem? _bestItem;

  /// The best matching appcast item from the most recent [getVersionInfo] call.
  ///
  /// This value is intended to be read only after awaiting [getVersionInfo].
  /// It is `null` before any lookup has completed or when no suitable appcast
  /// item is found for the current version check.
  AppcastItem? get bestItem => _bestItem;

  @override
  Future<UpdateVersionInfo> getVersionInfo({
    required UpdateCheckContext state,
    required Version installedVersion,
    required String? country,
    required String? language,
  }) async {
    String? appStoreListingURL;
    Version? appStoreVersion;
    bool? isCriticalUpdate;
    String? releaseNotes;

    Version parsedOsVersion;
    try {
      parsedOsVersion = osVersion?.isNotEmpty == true
          ? Version.parse(osVersion!)
          : Version(0, 0, 0);
    } catch (e) {
      parsedOsVersion = Version(0, 0, 0);
      if (state.debugLogging) {
        print(
          'upgrader: AppcastUpdateSource: could not parse osVersion "$osVersion": $e',
        );
      }
    }

    final localAppcast =
        appcast ??
        Appcast(
          client: state.client,
          clientHeaders: state.clientHeaders,
          upgraderOS: state.upgraderOS,
          osVersion: parsedOsVersion,
          currentAppVersion: installedVersion,
        );
    await localAppcast.parseAppcastItemsFromUri(appcastURL);
    if (state.debugLogging) {
      var count = localAppcast.items == null ? 0 : localAppcast.items!.length;
      print('upgrader: AppcastUpdateSource item count: $count');
    }
    final criticalUpdateItem = localAppcast.bestCriticalItem();
    final criticalVersion = criticalUpdateItem?.versionString ?? '';

    _bestItem = null;
    final bestItem = localAppcast.bestItem();
    if (bestItem != null &&
        bestItem.versionString != null &&
        bestItem.versionString!.isNotEmpty) {
      _bestItem = bestItem;

      if (state.debugLogging) {
        print(
          'upgrader: AppcastUpdateSource best item version: '
          '${bestItem.versionString}',
        );
        print(
          'upgrader: AppcastUpdateSource critical update item version: '
          '${criticalUpdateItem?.versionString}',
        );
      }

      try {
        if (criticalVersion.isNotEmpty &&
            installedVersion < Version.parse(criticalVersion)) {
          isCriticalUpdate = true;
        }
      } catch (e) {
        if (state.debugLogging) {
          print(
            'upgrader: AppcastUpdateSource: getVersionInfo could not parse version info $e',
          );
        }
      }

      if (bestItem.versionString != null) {
        try {
          appStoreVersion = Version.parse(bestItem.versionString!);
        } catch (e) {
          if (state.debugLogging) {
            print(
              'upgrader: AppcastUpdateSource: best item version could not be parsed: '
              '${bestItem.versionString}',
            );
          }
        }
      }

      appStoreListingURL = bestItem.fileURL;
      releaseNotes = bestItem.itemDescription;
    }

    final versionInfo = UpdateVersionInfo(
      installedVersion: installedVersion,
      appStoreListingURL: appStoreListingURL,
      appStoreVersion: appStoreVersion,
      isCriticalUpdate: isCriticalUpdate,
      releaseNotes: releaseNotes,
    );
    if (state.debugLogging) {
      print('upgrader: AppcastUpdateSource: version info: $versionInfo');
    }
    return versionInfo;
  }
}

/// A controller that provides the store details for each platform.
class UpdateStoreController {
  /// Creates a controller that provides the store details for each platform.
  UpdateStoreController({
    this.onAndroid = onAndroidStore,
    this.onFuchsia,
    this.oniOS = onIOSStore,
    this.onLinux,
    this.onMacOS,
    this.onWeb,
    this.onWindows,
  });

  final UpdateStore Function()? onAndroid;
  final UpdateStore Function()? onFuchsia;
  final UpdateStore Function()? oniOS;
  final UpdateStore Function()? onLinux;
  final UpdateStore Function()? onMacOS;
  final UpdateStore Function()? onWeb;
  final UpdateStore Function()? onWindows;

  UpdateStore? getUpdateStore(MusaicUpdateOS upgraderOS) {
    switch (upgraderOS.currentOSType) {
      case MusaicUpdateOSType.android:
        return onAndroid?.call();
      case MusaicUpdateOSType.fuchsia:
        return onFuchsia?.call();
      case MusaicUpdateOSType.ios:
        return oniOS?.call();
      case MusaicUpdateOSType.linux:
        return onLinux?.call();
      case MusaicUpdateOSType.macos:
        return onMacOS?.call();
      case MusaicUpdateOSType.web:
        return onWeb?.call();
      case MusaicUpdateOSType.windows:
        return onWindows?.call();
    }
  }

  static UpdateStore onAndroidStore() => GooglePlayUpdateSource();
  static UpdateStore onIOSStore() => AppStoreUpdateSource();
}
