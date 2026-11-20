# MUSAIC 专辑墙图片管线与 Xerox 模式技术方案

> **当前网络缓存实现：** IO 平台直接使用 `flutter_cache_manager`
> 保存原图，再由 `FileImage` 解码；Web 回退为 `NetworkImage`。
> 原图与 Xerox PNG 使用独立缓存。
>
> **当前 Demo：** Mock 专辑图片使用 `AssetImage`；未来正式接入 Apple
> Music 后，网络 Artwork URL 才是主要来源。方案必须同时支持
> Asset、Network、File，不能把 Mock 阶段误当成正式网络图片架构。

## 1. 目标与核心原则

MUSAIC 需要一套统一 Artwork
图片管线：原图负责下载、解码和普通显示；Xerox
在后台生成独立位图并持久化；开启 Xerox
时，通过音乐源切换同款动效，将原图资源替换为处理后的位图。

核心原则：

1.  Xerox 是独立图片资源，不是显示阶段实时叠加的滤镜。
2.  原图保留在原始资源缓存中，以便关闭 Xerox 时恢复；但 Xerox
    模式下原图必须退出渲染树，不得隐藏在底层继续绘制。
3.  不全量处理无限画布。只处理已经请求/加载的图片，当前可视区域优先，周边有限
    overscan 次之。
4.  下载缓存、解码缓存、Xerox 结果缓存分层管理。
5.  缓存 miss 是正常情况：自动从原图重新生成 Xerox。
6.  失败时绝不在 Xerox 模式闪回彩色原图。
7.  最大限度保持现有 Shader、裁切、颗粒、画布、Cover
    Flow、传感器倾斜和音乐源切换效果。

## 2. 图片来源与身份

  ---------------------------------------------------------------------------------
  来源                    当前/未来用途              Provider
  ----------------------- -------------------------- ------------------------------
  `AssetImage`            当前 Demo / Mock 专辑封面  `AssetImage`

  Apple Music Artwork URL 正式接入后的主要图片来源   缓存文件的 `FileImage`

  本地音乐封面            本地音乐目录               `FileImage`

  Xerox 处理结果          第二种显示资源             `ui.Image` / `RawImage`
  ---------------------------------------------------------------------------------

不要继续使用含义模糊的 `asset` 字段同时表示 Asset、URL、File
路径。建议逐步引入：

-   `ArtworkIdentity`：稳定的专辑/Artwork 身份。
-   `ArtworkSource`：Asset、Network、File 等来源。
-   `ArtworkVersion`：源图片更新标识，如
    URL、ETag、文件修改时间或数据源版本。
-   `ArtworkImageRequest`：来源、目标解码尺寸、DPR、fit/crop
    等显示参数。

同一张专辑在 Grid、Cover Flow、倒影和布局过渡中，必须尽量复用相同
Artwork 身份和底层图片资源。

## 3. 原图缓存：使用 `flutter_cache_manager`

### 3.1 网络原图

IO 平台通过 `OriginalArtworkCache` 下载或读取原图文件，再返回
`FileImage`；不额外引入网络图片 Widget：

-   磁盘缓存原始下载文件，避免反复下载。
-   使用稳定 `cacheKey`，建议由 Artwork ID + 图片版本构成。
-   配置缓存目录、过期时间、最大缓存对象数和请求 Headers。
-   同一 Artwork 的并发请求去重。
-   不要为每个 URL 创建一个 CacheManager 实例。

`OriginalArtworkCache` 管理原图磁盘缓存，目前上限 600 个对象，
stalePeriod 为 45 天。刷新失败时允许读取仍存在的过期文件。

`flutter_cache_manager` 解决网络图片加载和磁盘文件缓存，不替代 MUSAIC
自己的 LOD、解码尺寸、视口预加载、Xerox 处理和资源生命周期管理。

### 3.2 Asset 与 File

-   当前 Mock `AssetImage` 直接使用 Flutter Asset
    Provider，不复制到网络缓存。
-   本地音乐继续使用 `FileImage` 或统一 Resolver 返回的 File Provider。
-   三种来源最终进入统一的解码、预加载和 Xerox 生成管线。

### 3.3 两套磁盘缓存

1.  **Original Artwork Disk Cache**：网络原图文件，由
    `OriginalArtworkCache` 管理。
2.  **Xerox Raster Disk Cache**：Shader 生成的处理结果，使用独立
    CacheManager/文件缓存管理。

可以复用 `flutter_cache_manager` 的文件缓存能力，但 Xerox
结果必须和原图缓存逻辑隔离。如果直接调用 CacheManager API，应在
`pubspec.yaml` 显式声明直接依赖，不依赖传递依赖。

Web 的缓存行为与
iOS/Android/桌面不同，需单独验证浏览器缓存和持久化能力。

## 4. 图片解码尺寸与 LOD

### 4.1 解码尺寸

可以在 缓存文件的 `FileImage`、`AssetImage` 或 `FileImage`
外层使用 Flutter `ResizeImage`，控制解码阶段的像素尺寸。

目标解码尺寸根据 Tile 逻辑尺寸、画布 scale、设备 DPR
计算。使用离散档位，不要在每一帧缩放时生成新的 ResizeImage/cache key。

建议初始档位，最终以真机 Profile 调整：

  LOD                 尺寸 用途
  ---------- ------------- -------------------------
  Preview        256 × 256 普通画布、小尺寸 Tile
  Standard       512 × 512 常规显示
  High         1024 × 1024 Cover Flow / 大倍率放大

不要在原图下载完成时生成全部
LOD。先生成常规显示需要的基础尺寸，其他分辨率按需升级。

### 4.2 LOD 切换

1.  根据目标物理像素选择离散 LOD。
2.  使用滞回阈值，避免在档位边界来回抖动。
3.  缩放期间继续显示当前图片。
4.  缩放停止约 120ms 后提交新 LOD 请求（延迟可 Profile 调整）。
5.  新图片准备完成后才替换旧图片。
6.  Xerox 模式下只能 Xerox → Xerox，不能切回彩色原图。
7.  用 generation/request token 防止旧请求覆盖新请求。

Apple Music Artwork URL
若支持指定尺寸，可请求接近需求的服务端尺寸；尽量一份磁盘原图，多种内存解码尺寸，不要每个
LOD 都重复下载。

## 5. Xerox 后台处理

### 5.1 触发时机

  来源                   触发时机
  ---------------------- -------------------------------------------
  `AssetImage` Mock      首次进入可视区域并成功解码后，后台入队
  Apple Music 网络图片   下载完成/磁盘命中且原图可读取后，后台入队
  本地 File              文件可读取、图片请求成功后入队
  新进入视口的图片       原图加载后按优先级入队

不要为了 Xerox 预先下载整个 Apple Music
曲库。网络图片仍只按可视区域和有限预加载范围请求；下载完成后再触发处理。

### 5.2 处理流程

``` text
Artwork Source
    ↓
原图下载/加载
    ↓
Original Disk Cache / Flutter ImageCache
    ↓
XeroxJobScheduler
    ↓
XeroxRasterizer
    ↓
现有 FragmentShader
    ↓
PictureRecorder / Picture.toImage
    ↓
独立 Xerox ui.Image
    ├── Xerox Memory Cache（LRU）
    └── Xerox Disk Cache（持久化）
```

Shader 只用于生成位图。进入 Xerox
模式后，拖动和缩放只显示位图，不再实时执行 Shader。

保留当前参数，不擅自改变算法：

-   Edge：`0.9`
-   Contrast：`32`
-   Smooth：`0`
-   Grain：`0.5`
-   Invert：保持当前配置

每个并发 Raster 任务使用独立 FragmentShader 实例，不允许并发修改同一个
Shader 的 Uniform。

### 5.3 Xerox 持久化

-   内存位图先交付显示，再串行编码和写盘，不占用 Raster 并发名额。
-   待写队列只保存 Key，长度不超过 Raster 队列上限；已淘汰的图片跳过。
-   处理中的写盘持有独立图片句柄，缓存淘汰不能提前释放该句柄。
-   PNG 写入独立 Xerox Disk Cache。
-   App 重启后优先读取 PNG 并解码成 `ui.Image`。
-   磁盘命中不应重新运行 Shader。
-   文件名由稳定 Cache Key 生成，不直接使用 URL。
-   损坏文件、读取失败、版本不匹配时删除旧结果并重新生成。

初期建议 PNG 无损保存，避免有损压缩破坏 Xerox 颗粒和边缘质感。

## 6. 可视区域优先：绝不全量处理

复用现有
`InteractiveViewer.builder`、`AlbumGridSnapshot`、可视区域计算和
`PortraitTilt.overscan`，不要另建一套无限画布虚拟化系统。

处理优先级：

1.  当前可视区域：最高优先级。
2.  有限 overscan：包含传感器倾斜范围及拖动方向前方少量区域。
3.  其他已经下载/加载的图片：只有队列和内存预算允许才处理。
4.  远处未请求图片：不下载、不解码、不生成 Xerox。

调度要求：

-   队列有上限，不能无限堆积。
-   同一 Artwork + LOD + 参数的任务去重。
-   队列满或任务被抢占时，仍挂载的组件按 120～960ms 退避重试；
    请求变化和组件销毁会取消重试，真实解码失败仍有界停止。
-   overscan 解析或 Raster 失败不取消可视区域准备；可见资源失败仍阻止交接。
-   可视区域任务优先于预加载。
-   快速拖动时取消未开始且已过期的低优先级任务。
-   网络下载、图片解码、GPU Raster 分别限流。
-   初始可从网络 2～4、解码 2～4、GPU Raster 1～2
    个并发开始，最终通过真机 Profile 调整。

## 7. Xerox 缓存体系

### 7.1 两级缓存

  层级                 内容         职责
  -------------------- ------------ ------------------------
  Xerox Disk Cache     PNG 文件     跨 App 重启复用
  Xerox Memory Cache   `ui.Image`   快速显示，避免重复解码

内存缓存采用有预算的 LRU。预算按设备能力配置，不把固定 96MB
当作所有平台标准。图片内存成本可先按 `width × height × 4` 估算，实际
GPU/引擎开销需 Profile。

### 7.2 Cache Key

不能只用 URL。建议包含：

``` text
ArtworkIdentity
+ ArtworkVersion
+ XeroxAlgorithmVersion
+ Edge / Contrast / Smooth / Grain / Invert
+ Resolution
+ Fit / Crop
```

例如：

``` text
album-123_v2_xerox-v1_512_edge09_contrast32_smooth0_grain05
```

源图片版本或算法版本变化时，旧结果自动失效。

### 7.3 Lease 与释放

-   正在显示的 `ui.Image` 必须通过 Lease/引用计数固定。
-   LRU 不得释放仍被 Widget/动画使用的图片。
-   新图完成替换后再释放旧 Lease。
-   淘汰时正确调用 `ui.Image.dispose()`。
-   取消任务后晚到的结果必须释放，不能写回当前 UI。
-   缓存超预算时可暂时超过预算以保护正在使用的图片，Lease
    释放后再淘汰非活跃条目。

## 8. 点击 Xerox：资源替换与飞出/飞入

复用音乐源切换的 Tile 动画，不另造不一致的动画。

### 8.1 开启

1.  点击 BottomSheet 的 Xerox 按钮。
2.  锁定当前可视区域快照，包含必要 overscan。
3.  检查每张可视专辑的 Xerox 内存/磁盘缓存。
4.  缓存 miss 时立即从原图生成 Xerox。
5.  等待本次可视区域所有必需 Xerox 图片准备成功。
6.  原始图片 Tile 按音乐源切换的原有出场动画飞出。
7.  原动画 handoff 时刻统一切换全局显示模式为 Xerox。
8.  Xerox Tile 按相同进场动画飞入。
9.  动画完成后原图 Widget 从 Xerox 模式渲染树移除。

准备期间保留原始画面；不要提前隐藏。当前可视区域尽量原子切换，避免半屏彩色、半屏
Xerox。

### 8.2 关闭

1.  确认可视区域原图资源可用。
2.  Xerox Tile 飞出。
3.  handoff 时切换回 Original。
4.  原图 Tile 飞入。
5.  动画结束后释放不再需要的临时 Lease，但缓存可保留。

### 8.3 动画约束

-   复用 `SourceTileMotion.exit` / `SourceTileMotion.enter`
    和音乐源切换现有 phase/timing。
-   保持 `exit → handoff → enter`。
-   不改变现有时长、缓动、透视、位移、透明度和错落节奏。
-   开启：原图飞出，Xerox 位图飞入；关闭则反向。
-   模式切换期间暂停干扰视觉连续性的画布惯性，结束后恢复。

### 8.4 其他模式

Grid、Cover Flow、倒影、布局过渡共享同一份 Artwork 资源，不允许每个
Widget 各自生成 Xerox。

音乐源切换发生在 Xerox 模式下时，目标音乐源当前可视区域的 Xerox
图片也必须提前准备；未准备好不能显示彩色原图。

## 9. 缓存 miss 与失败兜底

### 9.1 缓存 miss 是正常路径

``` text
Xerox Memory Cache
    ↓ miss
Xerox Disk Cache
    ↓ miss
Original Artwork Source
    ↓
XeroxRasterizer
    ↓
写入 Disk Cache + Memory Cache
    ↓
显示 RawImage
```

### 9.2 短暂失败

-   对可恢复的解码/GPU/IO 错误自动重试一次。
-   重试次数有上限，不允许无限循环。
-   同一失败请求去重，不能每帧重试。
-   记录失败 Cache Key，避免每次 rebuild 重复提交。
-   图片来源或版本变化后允许重新尝试。

### 9.3 仍然失败

**开启 Xerox 时：**

-   当前可视区域准备失败，不提交 handoff。
-   取消本次模式切换，保留原始模式。
-   给出错误反馈，允许稍后重试。
-   不允许出现一部分彩色、一部分 Xerox。

**已经处于 Xerox 模式时：**

-   新进入视口的图片可暂时使用已有低分辨率 Xerox 图。
-   没有 Xerox 版本且处理失败，显示中性占位图。
-   绝不能回退到原始彩色图片。
-   新资源版本或用户重试可重新触发处理。

旧音乐源、旧专辑、旧 LOD
的异步结果不能覆盖新结果。页面销毁、切换资源后，未开始任务应取消；晚到的图片结果必须释放。

## 10. Xerox 模式显示规则

  场景                  正确行为
  --------------------- --------------------------------------------
  内存缓存命中          直接 `RawImage`
  内存 miss、磁盘 hit   读 PNG 并解码成 `ui.Image`
  内存/磁盘都 miss      从原图重新运行 Shader
  缩放                  直接缩放现有 Xerox 位图
  LOD 升级              后台生成更高清 Xerox，完成后 Xerox → Xerox
  新 Tile 进入视口      查缓存，miss 后后台处理
  处理失败              中性占位，不显示彩色原图
  关闭 Xerox            切回 Original Provider

Xerox 模式不再采用原图 + `CustomPainter`
叠加显示。显示阶段只选择原图或处理后的位图；Shader 只在 Rasterizer
内执行。

开启 Xerox 后，可在底部面板选择黑白、暖米白、浅沙色、灰绿或雾蓝。每种纸色
搭配一组深墨色，整个封面视图共用这组颜色。显示端对现有灰度位图做颜色映射，
配色不参与资源请求和缓存键，也不生成彩色副本。

## 11. 推荐模块职责

采用 feature-first：`lib/pages/home/` 只保留 `home_page.dart` 与
`home_sheet.dart`，负责页面入口、布局装配和事件接线。Artwork 模式的状态、
资源准备、过渡时间线和请求规划归属 Artwork 功能，不能因首页使用它们就放入页面目录。

``` text
lib/features/artwork/
├── model/
│   ├── artwork_identity.dart
│   ├── artwork_source.dart
│   └── artwork_request.dart
├── source/
│   └── artwork_resolver.dart
├── pipeline/
│   ├── artwork_image_pipeline.dart
│   ├── artwork_decode_policy.dart
│   ├── artwork_prefetch_scheduler.dart
│   └── xerox_background_processor.dart
├── cache/
│   ├── artwork_network_cache_manager.dart
│   └── artwork_memory_policy.dart
├── mode/
│   ├── artwork_mode_controller.dart
│   └── artwork_mode_transition.dart
├── presentation/
│   └── directory_artwork.dart
├── xerox/
│   ├── xerox_config.dart
│   ├── xerox_shader_renderer.dart
│   ├── xerox_rasterizer.dart
│   ├── xerox_raster_request.dart
│   ├── xerox_raster_cache.dart
│   ├── xerox_disk_cache.dart
│   ├── xerox_job_scheduler.dart
│   ├── xerox_visible_artwork_planner.dart
│   └── xerox_artwork.dart
└── artwork_renderer.dart
```

`mode/` 拥有 Original 与 Xerox 的切换流程及临时 Lease；`xerox/` 负责
Xerox 请求规划、处理、缓存和显示。视口尺寸与封面映射由调用方传入，功能层不依赖页面。
音乐源与 Artwork 模式共用的 `SourceTileMotion` 位于
`lib/ui/transitions/source_tile_motion.dart`；各功能保留自己的过渡状态机。

文件可按项目实际复杂度合并，不要机械增加
Manager/Controller。核心是职责清晰、依赖方向明确、资源所有权唯一。

## 12. 测试与验收

### 来源与缓存

-   [ ] Mock `AssetImage` 正常显示并触发后台 Xerox。
-   [ ] Apple Music URL 使用 `flutter_cache_manager` 和自定义原图
    CacheManager。
-   [ ] 本地 File 正常显示和处理。
-   [ ] 网络缓存命中不重复下载。
-   [ ] Xerox 磁盘缓存命中不重复运行 Shader。
-   [ ] 原图更新/算法版本变化使旧 Xerox 缓存失效。

### 后台处理

-   [ ] 只处理可视区域和有限 overscan。
-   [ ] 原图下载/加载后后台入队。
-   [ ] 任务有界、去重、可视区域优先。
-   [ ] 队列取消、失败、页面 dispose 均正确释放资源。

### 模式切换

-   [ ] 开启：原图飞出，Xerox 位图飞入。
-   [ ] 关闭：Xerox 飞出，原图飞入。
-   [ ] 复用音乐源切换的动画参数和时序。
-   [ ] 可视区域准备完成后再统一 handoff。
-   [ ] 不出现半屏彩色、半屏 Xerox。
-   [ ] Xerox 模式原图不在渲染树中。
-   [ ] 新 Tile、音乐源切换时不闪回彩色原图。

### 缩放与失败

-   [ ] 缩放不重复执行 Shader。
-   [ ] LOD 只在 Xerox 位图之间切换。
-   [ ] 新 LOD 未完成时保留旧 Xerox。
-   [ ] 旧请求不能覆盖新请求。
-   [ ] 缓存 miss 自动处理原图。
-   [ ] 解码或 GPU 短暂失败最多重试一次；队列拥塞按退避机制恢复。
-   [ ] 永久失败不会无限重试。
-   [ ] Xerox 模式失败显示中性占位，不显示原图。

### 视觉与设备

-   [ ] Edge 0.9、Contrast 32、Smooth 0、Grain 0.5 保持一致。
-   [ ] 裁切、倒影、圆角、布局和动画不变。
-   [ ] 传感器倾斜行为不变。
-   [ ] 在 60Hz / 120Hz 设备验证缩放与切换。
-   [ ] Profile 网络、解码、GPU Raster、帧耗时和内存峰值。

## 13. 当前 GitHub 实施状态

相关分支与 PR：

-   Xerox
    重构分支：[`codex/xerox-raster-mode-transition`](https://github.com/han9088/musaic/tree/codex/xerox-raster-mode-transition)
-   Draft PR：[#2](https://github.com/han9088/musaic/pull/2)
-   基础分支：`codex/musaic-architecture-performance-gpt6`

当前代码已实现：统一 Asset/Network/Directory Resolver、网络原图文件缓存、
原图与 Xerox 独立 LOD、Xerox 内存 LRU 与 PNG 磁盘缓存、有限并发和优先级调度、
后台预生成、Original ↔ Xerox 模式过渡，以及资源 Lease 生命周期管理。

2026-11-20 修复：

- 队列拥塞或抢占后退避恢复；永久解码失败不无限重试。
- overscan 坏图不阻止可见资源交接；可见资源失败仍保留原模式。
- 模式交接时重置 LOD 状态，与本次预热档位一致。
- 各解码入口保留原始宽高比，再由 BoxFit 执行显示裁切。
- 位图先交付显示，PNG 编码和写盘通过有界 Key 队列串行执行。
- Xerox 缓存键升级至 xerox-raster-v3，使旧的拉伸结果失效。

本地验证：flutter analyze 无问题；flutter test 共 242 个测试全部通过，
其中 12 个新增测试覆盖本次修复。iPhone 18 Pro / iOS 27.2 模拟器的
两个集成测试通过：开关、拖动、0.4～2.5 倍缩放、Mock 2、Cover Flow，
以及网络缓存去重、版本失效、断网读取和 PNG 恢复均通过；检查到的
最多 151 个可见封面全部就绪，Xerox 模式无原图组件残留。
普通入口启动和热重启检查也已通过。

未验证：真机 60Hz/120Hz 帧耗时、GPU 和内存峰值、跨进程重启恢复，
以及 Apple Music 真实账号和线上目录的完整验收。PNG 从新缓存实例恢复
与真实 App 进程重启必须分别报告。

**不要把内存 LRU
描述成持久化磁盘缓存；不要把新增测试代码描述成测试已通过。未运行的验证必须明确标记为未验证。**

------------------------------------------------------------------------

## 14. 最终目标

MUSAIC 的最终图片系统应做到：

-   网络原图使用 `flutter_cache_manager` 与 `FileImage`；Asset/File 继续使用 Flutter
    对应 Provider。
-   Flutter ImageCache + `ResizeImage` 管理解码尺寸与内存复用。
-   MUSAIC 自己管理 LOD、可视区域优先、预加载和任务调度。
-   原图加载/下载后后台生成 Xerox，并写入独立持久化缓存。
-   Xerox 模式只显示处理后的位图，缩放不再实时运行 Shader。
-   缓存 miss 自动重新处理；失败时有界重试和明确兜底，绝不闪回彩色原图。
-   开关 Xerox 复用音乐源切换的原图飞出、目标图片飞入动画。
-   Grid、Cover Flow、倒影和布局过渡共享 Artwork 资源。

**最终原则：下载与基础缓存复用成熟能力；LOD、视口调度和 Xerox 资源管理由
MUSAIC
掌控。图片处理在后台完成，显示阶段只切换资源，不执行昂贵的实时处理。**
