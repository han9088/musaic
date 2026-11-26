# apple_music_kit（中文说明）

Apple MusicKit 的 Flutter 插件 —— 授权、曲库搜索、用户资料库与播放，
覆盖 **iOS、Android、Web** 三端，全部使用 Apple 官方 SDK。

- **iOS** — Swift + Apple MusicKit（`MusicAuthorization`、
  `ApplicationMusicPlayer`、`MusicCatalogSearchRequest`、
  `MusicLibraryRequest`、`MusicDataRequest`）
- **Android** — Apple 官方 Android MusicKit SDK（authentication +
  playback AAR，需本地配置，见下文）
- **Web** — MusicKit JS v3（官方 CDN 自动加载，`dart:js_interop` +
  `package:web` 现代互操作）

> **本项目为第三方开源项目，与 Apple 无关，也未获 Apple 授权或认可。**
> "Apple Music"、"MusicKit" 等为 Apple Inc. 的商标。所有使用须遵守
> Apple Developer Program License Agreement、MusicKit 文档及 App Store
> Review Guidelines。

## 快速开始

完整 API 用法（含可编译验证的代码片段）见
[README.md — Usage](../README.md#usage)。核心流程：

```dart
final music = AppleMusicClient(
  config: AppleMusicConfig(
    appName: '我的音乐',
    developerTokenProvider: 我的服务器TokenProvider(), // 实现 DeveloperTokenProvider
  ),
);

await music.initialize();

// 1. 请求授权
final status = await music.authorization.request();

// 2. 搜索
final result = await music.catalog.search(
  '周杰伦',
  types: {MusicResourceType.song},
);

// 3. 播放
await music.player.setQueue(result.songs!.items.map((s) => s.ref).toList());
await music.player.play();

// 4. 监听状态（新订阅者立即收到最新快照）
music.player.states.listen((state) => print(state.status));

// 5. 释放（不会停止共享的底层播放）
await music.dispose();
```

### Mock 模式（无需任何 Apple 凭据）

```dart
import 'package:apple_music_kit/mock.dart';

void main() {
  if (kDebugMode) installMusicKitMock();
  runApp(const MyApp());
}
```

Mock 会明确标注自己不是真实 MusicKit，绝不冒充真实播放。

## 平台配置

### iOS
1. App ID 开启 **MusicKit** App Service。
2. `Info.plist` 添加：

   ```xml
   <key>NSAppleMusicUsageDescription</key>
   <string>用于播放你的音乐资料库和搜索。</string>
   ```

3. 后台播放需开启 **Audio** Background Mode（插件不会擅自修改你的
   Xcode 工程）。
4. 最低部署目标 **iOS 16.0**（结构化 `MusicLibraryRequest` 要求 iOS 16）。

播放使用 `ApplicationMusicPlayer.shared`（应用级播放器，不会劫持系统
Music App 的队列）。**模拟器编译通过 ≠ 播放验证通过**，真实播放与授权
测试必须用真机 + 已登录 Apple Music 的 Apple ID。

### Android
Apple 的 Android MusicKit SDK 不通过 Maven 分发，需自行下载并本地接入：

1. 从 [developer.apple.com/download/all/](https://developer.apple.com/download/all/)
   下载（搜索 **MusicKit**，需 Apple Developer 账号），需要
   `musickitauth.aar` 和 `musickitplayback.aar`。
2. 放入本地目录，如 `~/sdks/musickit-android/`。
3. 配置环境变量后构建：

   ```bash
   export MUSICKIT_ANDROID_SDK_DIR=~/sdks/musickit-android
   flutter build apk
   ```

**没有 SDK 时应用仍可构建运行**，但所有 MusicKit 调用会快速失败并返回
`sdkUnavailable` 错误（附带上述配置指引）——绝不伪装成功。

### Web
1. 必须 **HTTPS**（localhost 也算安全上下文）。
2. 插件自动从官方 CDN 加载 MusicKit JS v3，无需修改 `index.html`；
   若 CSP 拦截需放行 `js-cdn.music.apple.com`。
3. `authorize()` 必须由真实用户手势（按钮点击）触发，浏览器会拦截
   程序化弹窗。
4. 生成 developer token 时配置允许的来源（origin）。

## 安全要点

- Developer token（JWT）必须由**你的服务器**用 .p8 私钥签发，私钥
  绝不进客户端。
- 通过 `DeveloperTokenProvider` 注入；内置 `CachingDeveloperTokenProvider`
  支持缓存、按 JWT `exp` 提前刷新、并发请求去重（single-flight）。
- iOS 上省略 provider 即可让 MusicKit 自动管理 token。
- Music user token 由各平台 SDK 管理，插件不暴露。
- 任何日志与错误详情都不包含 token。

## 能力检测

```dart
final caps = await music.capabilities.get();
if (!caps.canSeek.supported) {
  print(caps.canSeek.reason.name); // 如 authorizationRequired
}
```

能力区分「结构上不支持」「SDK 缺失」「未授权」「无订阅」四种原因。

## 错误处理

所有失败统一为 `MusicKitException`，20 个稳定错误码（见
`MusicKitErrorCode`），并提供 `userMessage` 用户可读文案。

## 已知限制（诚实申报）

详见 [known-limitations.md](known-limitations.md)。要点：

- 本仓库已验证：全部 Dart 包 analyze/test 通过（49 个测试）、iOS
  真机 SDK 编译、Android fallback 构建、Web dart2js 构建。
- **未验证**（需外部条件）：iOS 真机播放/授权、Android 完整运行时
  （需 AAR + Apple Music app + 真机）、Web 各浏览器实测、Music user
  token 端到端流程。
- iOS 授权状态无系统推送（MusicKit 限制），通过订阅变化通知 +
  重新读取覆盖常见场景。
- Web 后台标签页音频会被浏览器挂起；`canPlayInBackground` 如实报告
  不支持。

## 许可

BSD-3-Clause，见 [LICENSE](../LICENSE)。
