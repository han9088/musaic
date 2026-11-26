# Linux 桌面支持

Linux 使用 GTK 3 Runner，托盘通过 `tray_manager` 的 StatusNotifierItem 后端接入桌面面板。窗口恢复、关窗留后台、退出和 X11 壁纸逻辑均位于 `linux/runner/`，不改动 macOS、Windows 的原生窗口实现。

## 构建环境

使用 `mise.toml` 固定的 Flutter 版本。项目现有的 `apple_music_kit` 路径依赖仍要求在 `musaic` 同级目录放置 `apple_music_kit` 仓库；Indiebase 的 Git 依赖也需要相应读取权限。

Ubuntu / Debian 开发依赖：

```sh
sudo apt-get install -y \
  clang cmake ninja-build pkg-config \
  libgtk-3-dev libstdc++-12-dev liblzma-dev \
  libx11-dev libxi-dev \
  libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev
```

音频运行依赖包含 GStreamer 以及实际音频格式对应的解码器。应用的刻度音使用 M4A / AAC，Ubuntu / Debian 可安装：

```sh
sudo apt-get install -y \
  gstreamer1.0-plugins-good gstreamer1.0-libav
```

其他发行版安装上述库的对应软件包。`tray_manager 0.8.3` 直接使用 D-Bus StatusNotifierItem，不需要额外引入 Ayatana AppIndicator 开发库。

```sh
mise install
mise exec -- flutter pub get
mise exec -- flutter run -d linux
mise exec -- flutter build linux --release
```

构建产物位于 `build/linux/<architecture>/release/bundle/`。分发时保留整个目录，包含可执行文件、`lib/` 和 `data/`；不要单独拷贝可执行文件。系统仍需提供 GTK、GStreamer 及对应编解码插件。

## 托盘与窗口生命周期

- 菜单复用应用已有的中英文文案，切换应用语言时更新菜单标题。
- 只有桌面面板实际注册了 StatusNotifier 宿主，且托盘图标创建成功后，关闭窗口才会隐藏到后台。
- 没有托盘宿主时，关闭窗口维持正常退出行为。GNOME 通常需要 AppIndicator / StatusNotifier 扩展；KDE Plasma 等桌面通常已经提供托盘宿主。
- 面板退出或扩展被停用时，隐藏窗口或壁纸窗口会恢复为普通窗口，避免失去操作入口。
- 面板重新出现时，重建并重新注册托盘图标。使用 D-Bus 事件监听，不定时轮询。
- 托盘的「退出 Musaic」会真正退出进程，不会再次触发关窗留后台。
- Linux 不自动启用现有的全局快捷键配置，避免把 macOS / Windows 的快捷键注册流程直接带到 Wayland 授权门户。

## 壁纸能力范围

**X11：**运行时检查窗口管理器的 EWMH 能力。支持时，将同一个 GTK 窗口切换为桌面类型，禁用输入和窗口装饰，并在恢复时还原窗口属性与位置。Flutter View 和 Engine 保持原有实例，不复制画布或音频会话，也不重建渲染引擎。

桌面层叠由窗口管理器决定，桌面图标管理器也可能拥有自己的不透明背景窗口。实际显示效果需要在目标桌面环境确认；应用不会修改桌面全局设置或关闭桌面图标服务。

**Wayland：**普通窗口、托盘菜单、后台运行与恢复均可使用；「设置成壁纸」保持禁用。普通 Wayland 窗口不能通过 X11 的窗口类型提示进入桌面层；不同合成器对 Layer Shell 的支持也不同。本实现不强制切换会话、不启用 XWayland，也不为此重新创建 Flutter Engine。

## 人工验证重点

1. 在有 StatusNotifier 宿主的桌面启动，确认托盘图标和中英文菜单；切换语言后菜单随之更新。
2. 关闭主窗口，再从托盘恢复；从托盘退出后确认进程结束。
3. 在无托盘宿主的桌面关闭主窗口，确认应用正常退出。
4. 窗口隐藏时重启桌面面板或停用托盘扩展，确认主窗口自动恢复；面板重新出现后确认托盘恢复。
5. 在受支持的 X11 会话进入壁纸模式，确认点击穿透、原窗口恢复、音频与画布状态延续；检查显示器变化和快速切换时的恢复行为。
6. 在 Wayland 会话确认壁纸菜单禁用，普通窗口、托盘和退出仍可操作。
7. 回归 macOS / Windows 托盘与壁纸；Android / iOS / Web 不应初始化 Linux 窗口能力查询或原生托盘。

## 参考资料

- [Flutter：Linux 开发环境](https://docs.flutter.dev/platform-integration/linux/setup)
- [tray_manager 0.8.3](https://pub.dev/packages/tray_manager/versions/0.8.3)
- [audioplayers_linux 4.3.0 构建依赖](https://github.com/bluefireteam/audioplayers/blob/audioplayers_linux-v4.3.0/packages/audioplayers_linux/linux/CMakeLists.txt)
- [GStreamer M4A demuxer](https://gstreamer.freedesktop.org/documentation/isomp4/qtdemux.html)
- [GStreamer AAC decoder](https://gstreamer.freedesktop.org/documentation/libav/avdec_aac.html)
- [GTK 窗口类型提示](https://docs.gtk.org/gtk3/method.Window.set_type_hint.html)
- [GTK Layer Shell 支持范围](https://github.com/wmww/gtk-layer-shell#supported-desktops)
