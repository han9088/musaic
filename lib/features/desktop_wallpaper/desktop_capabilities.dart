// 文件职责：描述当前桌面会话的壁纸与托盘恢复能力。

final class DesktopCapabilities {
  const DesktopCapabilities({
    required this.wallpaper,
    required this.trayHost,
    required this.trayRevision,
  });

  static const unavailable = DesktopCapabilities(
    wallpaper: false,
    trayHost: false,
    trayRevision: 0,
  );

  /// macOS 与 Windows 沿用现有能力，不查询 Linux 专属原生接口。
  static const standardDesktop = DesktopCapabilities(
    wallpaper: true,
    trayHost: true,
    trayRevision: 0,
  );

  final bool wallpaper;
  final bool trayHost;

  /// Linux 托盘宿主重新注册时递增，用于重建已失去注册关系的图标。
  final int trayRevision;

  factory DesktopCapabilities.fromMessage(Object? message) {
    if (message case {
      'wallpaper': final bool wallpaper,
      'trayHost': final bool trayHost,
      'trayRevision': final int trayRevision,
    }) {
      return DesktopCapabilities(
        wallpaper: wallpaper,
        trayHost: trayHost,
        trayRevision: trayRevision,
      );
    }
    return unavailable;
  }

  @override
  bool operator ==(Object other) =>
      other is DesktopCapabilities &&
      wallpaper == other.wallpaper &&
      trayHost == other.trayHost &&
      trayRevision == other.trayRevision;

  @override
  int get hashCode => Object.hash(wallpaper, trayHost, trayRevision);
}
