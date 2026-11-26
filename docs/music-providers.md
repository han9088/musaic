# 音乐 Provider

`lib/services/music/music_provider.dart` 是页面之外的统一服务接口，
涵盖授权、能力查询、专辑搜索、资料库分页、专辑详情/曲目及播放控制。
模型不依赖 Apple Music SDK；资源引用保留 provider、catalog/library、资源类型和 storefront。
Provider 不持有页面状态，也不替换现有 MockAlbumCache、AlbumPlayback 或首页数据。

## Apple Music

Apple Music Kit 源码位于仓库内的 `packages/apple_music_kit/`，应用依赖入口
`packages/apple_music_kit/packages/apple_music_kit`。
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

## 本地系统音乐库 Provider

```dart
import 'package:musaic/services/music/local_music_provider.dart';

final local = LocalMusicProvider();
await local.initialize(); // 不弹窗、不扫描、不创建播放器
final access = await local.authorizationStatus();
// 用户主动选择本地音乐源时调用：
await local.requestAuthorization();
final page = await local.libraryAlbums(limit: 25);
// await local.play([page.items.first.reference]);
// await local.refreshLibrary(); // 系统曲库变更后显式刷新
// await local.dispose();
```

使用现有 MusicProvider 接口，已接入首页音乐源选择。系统查询和权限由本地 musaic_query 负责，应用不再维护第二套原生查询通道。
Android 查询 MediaStore 音乐条目，直接播放系统返回的 content URI；Android 13+ 仅申请
READ_MEDIA_AUDIO，旧版仅申请 READ_EXTERNAL_STORAGE（maxSdkVersion 32）。
iOS 使用 MPMediaLibrary 授权和 MPMediaQuery 读取已在设备上的音乐；
NSAppleMusicUsageDescription 已声明，不包含云端曲目。
不申请照片、视频、写入或全盘管理权限，不触发 Apple Music 订阅授权。
应用仅在 Android/iOS 提供系统曲库入口。插件权限接口返回 bool，未授权统一映射 denied（不区分尚未询问和系统限制），仅用户主动操作时请求权限。

原生查询在后台线程执行，Dart 分组、排序和查找表构建通过 compute 在独立 isolate 执行，索引按系统 album ID 分组，保留标题、艺人、时长，
不会把同名专辑误合并。首次读取才扫描，合并并发扫描；列表分页复用内存索引，
但系统查询和内存索引仍是全库规模。refreshLibrary 显式重建索引。
权限被撤回后不再返回缓存列表。文件删除、权限变化、无法解码会正常报错。

复用 audioplayers，第一次 play 才创建一个播放器。支持队列、暂停/恢复、定位、
前后切歌和结束自动下一首；命令串行执行，错误通过 Future 和播放状态反馈。
startIndex 指向传入的歌曲/专辑项目，专辑展开为可播放曲目。
受 DRM 保护或没有可播放本地地址的曲目标记 playable=false，单独播放时明确拒绝，
专辑队列跳过不可播放曲目；不绕过 Apple Music 或其他 App 的保护。

暂不读取封面图片、动态封面、歌词，不提供系统库写入、锁屏控制或无缝播放。
真实设备的授权弹窗、iOS ipod-library URL 及 Android 本地文件播放尚未联调。
测试替身接在 musaic_query 的真实通道，验证权限、DRM、查询合并、分页复用和刷新。系统索引只保留内存快照，不写入目录音乐数据库。
Android 无文件路径的 content URI 同样可播放。仓库固定使用 `packages/audioplayers_android`
本地补丁（上游 5.3.0），后台通过 ContentResolver 打开 AssetFileDescriptor，向现有
MediaPlayer 传入描述符及真实 offset/length。无需查询 `_data`、下载或复制整首音频，
未知长度使用描述符重载；继续使用异步 prepare。一个工作线程、最多 16 个排队请求，
同一播放器的新请求替换旧请求；停止、释放、销毁会取消待处理请求，迟到描述符立即关闭。
当前描述符在切歌或释放时关闭，权限撤回、文件消失和提供者错误正常向调用方报错。
不响应取消的外部提供者可能延迟后续打开，但不会阻塞 UI 或让旧结果覆盖新歌曲。
此入口使用 MediaPlayer 模式；不把整首歌曲载入 SoundPool。

## 首页音乐源入口

Bottom sheet 提供“示例音乐（Mock）”和“本地音乐”。每次启动默认 mock，不记忆上次选择；
未主动选择本地前，不创建本地 Provider、不请求权限、不扫描。
选择本地后显式授权并扫描，全部读取成功才提交切换；取消、拒绝或失败保留当前音乐源。
扫描中禁止重复切换；空库也可成功切换，首页显示空状态，不用 mock 冒充扫描结果。
重新扫描会重新创建本地会话；切回 mock 时释放本地播放器。

首页画布、CoverFlow 和已有播放按钮消费选中的音源。原 mock 数据及交互保持原样；
本地专辑使用系统标题/艺人，无封面时显示统一唱片占位图，现有布局和物理参数不变。
播放状态由本地 Provider 回传，拒绝播放或加载失败会提示，不能只切换按钮图案伪装播放。

### musaic_query 接入验证（2026-11-15）

应用 analyze 无问题，全量 165 项测试通过；Android 18 项原生测试及 debug 构建通过。
iOS 模拟器构建、启动和热重启通过，未验证真机音乐库授权与播放。
批量替身测试使用 4,099 首歌曲、412 个专辑，构建及分页约 88 ms，仅查询一次歌曲列表，
不读取封面；这是本机测试耗时，不代表设备读取速度或峰值内存。
应用使用本地 musaic_query 包；插件保留原版权声明和 LICENSE。

### Android content URI 播放修复验证

应用 analyze 无问题，166 项应用测试通过；应用通道测试验证无路径 URI 原样传递、
暂停及定位，原生 6 项 Robolectric 测试验证后台打开、偏移/长度、未知长度、授权失效、
文件消失、取消及迟到描述符关闭、新请求替换、16 项等待上限和销毁完成全部请求。
不查询文件路径，不复制文件；描述符重复用于重新准备时提供者打开次数仍为 1。
没有连接 Android 真机，也没有可用 Android 模拟器，本轮未验证实际解码与发声。
Android debug 构建与 24 项原生测试通过，iOS 模拟器构建、启动及热重启通过。

### content URI 播放复查（2026-11-16）

切歌、加载中暂停和销毁先打断正在进行的加载，再进入命令队列，不再等待旧 URI 打开。
加载分为停止、设置上下文、准备源和恢复，每一步检查取消，迟到结果不能触发旧歌曲恢复。
加载中暂停后恢复会重新准备源；此时的定位请求保留到准备完成后执行。
原生切换在打开新 URI 前释放旧播放器和描述符，新 URI 权限失败不会让旧歌曲继续播放。
准备或释放抛错仍关闭源描述符；MediaPlayer reset 抛错仍执行 release；释放后的准备和
完成回调不能修改当前歌曲。原生错误详情使用可序列化字符串。
等待上限涵盖工作队列和已打开但尚未交给主线程的描述符，最多 17 项未交付请求。
外部提供者忽略取消仍可能拖延后续打开，但旧结果会关闭，不会覆盖新歌曲。

本轮 analyze 无问题，169 项应用测试通过；播放器 13 项原生测试、查询插件 18 项
原生测试及 Android debug 构建通过。回归使用迟到结果和主动失败的测试替身，
验证取消不会等待旧源、释放异常也关闭描述符、旧回调不影响新源、交付前最多 17 项请求。
尚未验证 Android 真机上的外部文件提供者、实际解码与中途撤销权限行为。
iOS 模拟器构建、启动与热重启通过；该检查不代表 Android content URI 真机播放验证。
