# 音乐 Provider

`lib/services/music/music_provider.dart` 是页面之外的统一服务接口，
涵盖授权、能力查询、专辑搜索、资料库分页、专辑详情/曲目及播放控制。
模型不依赖 Apple Music SDK；资源引用保留 provider、catalog/library、资源类型和 storefront。
Provider 不持有页面状态，也不替换现有 MockAlbumCache、AlbumPlayback 或首页数据。

## Apple Music

依赖同级仓库 `../apple_music_kit/packages/apple_music_kit`，其他机器需保持此目录关系。
未来在应用装配层按需创建并通过构造函数传入使用方：

```dart
import 'package:apple_music_kit/apple_music_kit.dart';
import 'package:musaic/services/music/apple_music_provider.dart';
import 'package:musaic/services/music/music_provider.dart';

final MusicProvider provider = AppleMusicProvider(
  client: AppleMusicClient(config: AppleMusicConfig(
    appName: 'Musaic',
    // Android/Web: developerTokenProvider 由服务端签发 Token 的实现提供。
  )),
);
// 仅在明确启用真实音源后执行；当前应用未调用这些代码。
await provider.initialize();
// requestAuthorization() 单独由用户操作触发。
```

- Provider 独占传入的 client，结束使用时调用 `dispose()`；依照 SDK 默认行为，释放连接不会主动停止原生播放。
- 初始化不等于已授权或可播放，使用前读取 `authorizationStatus()` 和 `capabilities()`；能力包含不可用原因。
- `searchAlbums` 每次最多 25 条，当前 SDK 不提供搜索翻页参数；资料库通过返回的 `nextCursor` 逐页读取，null 表示结束。cursor 只用于同一 Provider 的资料库。
- `album()` 加载 catalog 专辑及其曲目。当前 SDK 没有 library 专辑详情方法，因此明确抛出 UnsupportedError，不把资料库 ID 当目录 ID。
- `play()` 接收歌曲/专辑引用，替换队列并自动播放。错误及播放流错误保留 SDK 原始异常；Apple Music 的 MusicKitException 提供 code、details、retryAfter，不吞掉授权/订阅/网络错误。
- macOS 暂无该库的实现，不应创建真实 Apple Music 会话。现有 mock 功能继续运行。

## 后续联调前准备（本次未启用）

- iOS：库要求最低 iOS 16，项目最低版本已同步。需开通 App ID 的 MusicKit 服务并配置签名权限，添加 `NSAppleMusicUsageDescription`；需要后台播放时配置 Audio 后台模式。
- Android：将 Apple MusicKit 授权与播放 AAR 放到项目外，通过 `MUSICKIT_ANDROID_SDK_DIR` 指定。未提供 SDK 时插件仍可构建，但调用会报告 sdkUnavailable。
- Android/Web 的开发者 Token 由后端提供，客户端不能存放 Apple 私钥。iOS 可使用系统自动 Token。
- 本次仅添加抽象和适配器，未连接 UI、未授权、未访问真实音乐服务、未执行平台构建或真机联调。

边界测试在 `test/services/music/apple_music_provider_test.dart`，使用独立内存平台替身，不修改应用 mock 数据。

## 按需动态封面

`provider.animatedArtwork(album.reference)` 单独获取目录专辑的动态封面，不改变
`album()`、搜索、资料库或静态封面的行为。返回不可修改的列表，每项包含
`layout`（square / portrait / unknown）和原始 `videoUrl`，没有动态封面时返回空列表。
未知规格保留视频地址，不猜测尺寸；Apple 专属字段不暴露到通用模型。

Apple 适配器调用库的 `catalog.getAlbumAnimatedArtwork`，优先使用引用的 storefront，
缺失时查询当前账户地区，不硬编码美国。资料库专辑必须先解析为目录专辑；
错误原样抛出，不把授权、网络或不支持错误当成空结果。

复用库内相同专辑/地区的在途请求合并，不增加第二层缓存或持久化视频地址。
SDK 没有已完成结果缓存，Provider 也不下载视频或创建播放器。此入口尚未接入页面。
库中的 `editorialVideo` 属实验性能力；普通开发者 Token、各地区返回及视频播放
仍未经过真实服务联调。iOS/Android/Web 的请求由 SDK 负责，macOS 仍不支持。
