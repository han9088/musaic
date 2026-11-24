// Copyright (c) 2026 MUSAIC. All rights reserved.

import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:version/version.dart';

import 'appcast.dart';
import 'update_context.dart';
import 'update_os.dart';
import 'update_store_controller.dart';
import 'update_version_info.dart';

/// 一次更新检查的统一结果。更新说明保留数据源原始内容，不在核心层渲染。
class UpdateCheckResult {
  const UpdateCheckResult({
    required this.versionInfo,
    required this.installedVersion,
    required this.updateAvailable,
    required this.mandatoryUpdate,
    required this.sourcePlatform,
  });

  final UpdateVersionInfo versionInfo;
  final Version installedVersion;
  final bool updateAvailable;
  final bool mandatoryUpdate;
  final String sourcePlatform;

  Version? get latestVersion => versionInfo.appStoreVersion;
  Version? get minimumVersion => versionInfo.minAppVersion;
  String? get releaseNotes => versionInfo.releaseNotes;
  String? get releaseNotesRaw => versionInfo.releaseNotes;
  String? get storeUrl => versionInfo.appStoreListingURL;
  bool get criticalUpdate => versionInfo.isCriticalUpdate == true;
}

/// 更新检查器：只处理更新源、版本判断、非 UI 策略和应用生命周期。
/// 不创建 Widget、弹窗、按钮，也不依赖 BuildContext。
class MusaicUpdateChecker with WidgetsBindingObserver {
  MusaicUpdateChecker({
    http.Client? client,
    UpdateStoreController? storeController,
    MusaicUpdateOS? upgraderOS,
    this.countryCode,
    this.languageCode,
    this.minimumSupportedVersion,
    this.debugLogging = false,
    this.clientHeaders,
    this.checkOnResume = true,
    this.durationUntilAlertAgain = const Duration(days: 3),
    this.onUpdateChecked,
  }) : client = client ?? http.Client(),
       upgraderOS = upgraderOS ?? MusaicUpdateOS(),
       storeController = storeController ?? UpdateStoreController();

  static const _ignoredVersionKey = 'musaic_updater.ignoredVersion';
  static const _lastAlertedAtKey = 'musaic_updater.lastAlertedAt';
  static const _lastAlertedVersionKey = 'musaic_updater.lastAlertedVersion';

  final http.Client client;
  final Map<String, String>? clientHeaders;
  final UpdateStoreController storeController;
  final MusaicUpdateOS upgraderOS;
  final String? countryCode;
  final String? languageCode;
  final String? minimumSupportedVersion;
  final bool debugLogging;
  final bool checkOnResume;
  final Duration durationUntilAlertAgain;

  /// 应用从后台恢复并完成检查后回调；由宿主决定如何展示。
  final ValueChanged<UpdateCheckResult>? onUpdateChecked;

  UpdateCheckResult? currentResult;
  Version? _ignoredVersion;
  Version? _lastAlertedVersion;
  DateTime? _lastAlertedAt;
  bool _observingLifecycle = false;

  /// 初始化持久化策略状态、执行首次检查，并可选监听应用恢复。
  Future<UpdateCheckResult> initialize({
    PackageInfo? packageInfo,
    bool observeLifecycle = true,
  }) async {
    await loadSavedSettings();
    if (observeLifecycle && checkOnResume && !_observingLifecycle) {
      WidgetsBinding.instance.addObserver(this);
      _observingLifecycle = true;
    }
    return check(packageInfo: packageInfo);
  }

  /// 自动识别平台：Android 使用 Google Play，iOS 使用 App Store。
  /// 桌面端/Web 可通过 UpdateStoreController 注入 AppcastUpdateSource。
  Future<UpdateCheckResult> check({PackageInfo? packageInfo}) async {
    final info = packageInfo ?? await PackageInfo.fromPlatform();
    if (info.packageName.isEmpty) {
      throw StateError('无法获取应用 packageName / bundleId。');
    }

    final installed = Version.parse(info.version);
    final locale = PlatformDispatcher.instance.locale;
    final country = countryCode ??
        (locale.countryCode?.isNotEmpty == true ? locale.countryCode : 'US');
    final language = languageCode ??
        (locale.languageCode.isNotEmpty ? locale.languageCode : 'en');

    final store = storeController.getUpdateStore(upgraderOS);
    if (store == null) {
      throw UnsupportedError('当前平台未配置更新数据源：' + upgraderOS.current);
    }

    final context = UpdateCheckContext(
      client: client,
      clientHeaders: clientHeaders,
      debugLogging: debugLogging,
      packageInfo: info,
      upgraderOS: upgraderOS,
    );
    final versionInfo = await store.getVersionInfo(
      state: context,
      installedVersion: installed,
      country: country,
      language: language,
    );

    final configuredMinimum = minimumSupportedVersion == null
        ? null
        : Version.parse(minimumSupportedVersion!);
    final minimum = configuredMinimum ?? versionInfo.minAppVersion;
    final mandatory = versionInfo.isCriticalUpdate == true ||
        (minimum != null && installed < minimum);
    final latest = versionInfo.appStoreVersion;

    final result = UpdateCheckResult(
      versionInfo: versionInfo,
      installedVersion: installed,
      updateAvailable: latest != null && installed < latest,
      mandatoryUpdate: mandatory,
      sourcePlatform: upgraderOS.current,
    );
    currentResult = result;
    return result;
  }

  /// 是否低于最低支持版本，或命中 Appcast Critical Update。
  bool get isBlocked {
    final result = currentResult;
    return result != null && result.mandatoryUpdate;
  }

  /// 是否应该向用户提供更新入口。只返回策略结果，不负责 UI。
  bool shouldOfferUpdate({bool showOnlyMandatoryUpdates = false}) {
    final result = currentResult;
    if (result == null || !result.updateAvailable) return false;
    if (result.mandatoryUpdate) return true;
    if (showOnlyMandatoryUpdates) return false;
    return !isPromptCooldownActive && !isCurrentVersionIgnored;
  }

  bool get isCurrentVersionIgnored {
    final latest = currentResult?.latestVersion;
    return latest != null && _ignoredVersion == latest;
  }

  bool get isPromptCooldownActive {
    final result = currentResult;
    final lastAt = _lastAlertedAt;
    if (result == null || lastAt == null) return false;
    if (_lastAlertedVersion != null &&
        result.latestVersion != null &&
        _lastAlertedVersion != result.latestVersion) {
      return false;
    }
    return DateTime.now().difference(lastAt) < durationUntilAlertAgain;
  }

  /// 用户选择忽略当前版本时调用。该方法只持久化版本，不执行任何 UI 操作。
  Future<void> ignoreCurrentVersion() async {
    final latest = currentResult?.latestVersion;
    if (latest == null) return;
    _ignoredVersion = latest;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_ignoredVersionKey, latest.toString());
  }

  /// 宿主展示更新信息后调用，用于记录提醒时间和版本。
  Future<void> recordUpdatePromptShown() async {
    final latest = currentResult?.latestVersion;
    _lastAlertedAt = DateTime.now();
    _lastAlertedVersion = latest;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastAlertedAtKey, _lastAlertedAt!.toIso8601String());
    await prefs.setString(_lastAlertedVersionKey, latest?.toString() ?? '');
  }

  /// 读取此前保存的忽略版本和提醒状态。
  Future<void> loadSavedSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final ignored = prefs.getString(_ignoredVersionKey);
    final lastVersion = prefs.getString(_lastAlertedVersionKey);
    final lastAt = prefs.getString(_lastAlertedAtKey);

    _ignoredVersion = _tryParseVersion(ignored);
    _lastAlertedVersion = _tryParseVersion(lastVersion);
    if (lastAt != null) {
      _lastAlertedAt = DateTime.tryParse(lastAt);
    }
  }

  /// 清除本插件保存的忽略版本和提醒时间。
  Future<void> clearSavedSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_ignoredVersionKey);
    await prefs.remove(_lastAlertedAtKey);
    await prefs.remove(_lastAlertedVersionKey);
    _ignoredVersion = null;
    _lastAlertedAt = null;
    _lastAlertedVersion = null;
  }

  static Version? _tryParseVersion(String? value) {
    if (value == null || value.isEmpty) return null;
    try {
      return Version.parse(value);
    } on FormatException {
      return null;
    }
  }

  /// 仅在应用恢复前台时检查；错误交由宿主捕获，不伪装成“已是最新”。
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && checkOnResume) {
      _checkOnResume();
    }
  }

  Future<void> _checkOnResume() async {
    try {
      final result = await check();
      onUpdateChecked?.call(result);
    } catch (error) {
      if (debugLogging) {
        print('musaic_updater: resume check failed: $error');
      }
    }
  }

  /// 释放生命周期观察者。HTTP Client 由调用方提供时不自动关闭。
  void dispose() {
    if (_observingLifecycle) {
      WidgetsBinding.instance.removeObserver(this);
      _observingLifecycle = false;
    }
  }

  /// 便捷创建 Appcast 数据源，适用于自分发版本。
  static UpdateStoreController appcastController({
    required String appcastUrl,
    String? operatingSystemVersion,
    Appcast? appcast,
  }) {
    AppcastUpdateSource createSource() => AppcastUpdateSource(
      appcastURL: appcastUrl,
      osVersion: operatingSystemVersion,
      appcast: appcast,
    );

    return UpdateStoreController(
      onAndroid: createSource,
      oniOS: createSource,
      onMacOS: createSource,
      onWindows: createSource,
      onLinux: createSource,
      onWeb: createSource,
      onFuchsia: createSource,
    );
  }
}
