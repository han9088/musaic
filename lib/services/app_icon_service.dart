// 文件职责：应用级服务、平台适配与辅助能力。

import 'package:dynamic_app_icon_flutter_plus/dynamic_app_icon_flutter_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 封装或定义应用图标choice相关类型与行为，负责应用级服务、平台适配与辅助能力。
enum AppIconChoice {
  vinylPrimary('MusaicVinylPrimary', 'assets/branding/vinyl_primary.png'),
  text('MusaicText', 'assets/branding/text.png'),
  mosaic('MusaicMosaic', 'assets/branding/mosaic.png'),
  vinyl('MusaicVinyl', 'assets/branding/vinyl.png'),
  vinylWhite('MusaicVinylWhite', 'assets/branding/vinyl_white.png'),
  mosaicXerox('MuasicMosaiclXerox', 'assets/branding/mosaic_xerox.png');

  const AppIconChoice(this.nativeName, this.previewAsset);

  final String? nativeName;
  final String previewAsset;
}

/// 封装或定义应用图标快照相关类型与行为，负责应用级服务、平台适配与辅助能力。
typedef AppIconSnapshot = ({bool supported, AppIconChoice current});

/// 封装或定义应用图标服务相关类型与行为，负责应用级服务、平台适配与辅助能力。
class AppIconService {
  const AppIconService();

  /// 执行当前模块中的choices操作，用于应用级服务、平台适配与辅助能力。
  Iterable<AppIconChoice> get choices => AppIconChoice.values.where(
    (choice) =>
        choice != AppIconChoice.vinylWhite ||
        (!kIsWeb &&
            (defaultTargetPlatform == TargetPlatform.iOS ||
                defaultTargetPlatform == TargetPlatform.android ||
                defaultTargetPlatform == TargetPlatform.macOS)),
  );

  /// 读取并恢复所需数据或资源，用于应用级服务、平台适配与辅助能力。
  Future<AppIconSnapshot> read() async {
    if (kIsWeb ||
        !const [
          TargetPlatform.iOS,
          TargetPlatform.android,
          TargetPlatform.macOS,
        ].contains(defaultTargetPlatform) ||
        !await DynamicAppIconFlutterPlus.supportsAlternateIcons) {
      return (supported: false, current: AppIconChoice.vinylPrimary);
    }
    final available = await DynamicAppIconFlutterPlus.getAvailableIcons();
    for (final choice in choices) {
      final nativeName = _nativeName(choice);
      if (nativeName != null && !available.contains(nativeName)) {
        throw StateError(
          'The $nativeName alternate icon is not configured',
        );
      }
    }
    final name = await DynamicAppIconFlutterPlus.getAlternateIconName();
    return (
      supported: true,
      current: AppIconChoice.values.firstWhere(
        (choice) => _nativeName(choice) == name,
      ),
    );
  }

  /// 应用选择并更新对应状态，用于应用级服务、平台适配与辅助能力。
  Future<void> change(AppIconChoice choice) async {
    try {
      await DynamicAppIconFlutterPlus.setAlternateIconName(
        _nativeName(choice),
        showAlert: true,
        deferUntilBackground: false,
      );
    } on PlatformException {
      // 与 Live 模式类似，iOS 回调失效后，只有操作系统再次确认才能接受结果。
      if (!kIsWeb &&
          defaultTargetPlatform == TargetPlatform.iOS &&
          await DynamicAppIconFlutterPlus.getAlternateIconName() ==
              _nativeName(choice)) {
        return;
      }
      rethrow;
    }
  }

  String? _nativeName(AppIconChoice choice) {
    if (choice == AppIconChoice.vinylPrimary) {
      return null;
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return choice.nativeName;
    }
    return choice.nativeName;
  }
}
