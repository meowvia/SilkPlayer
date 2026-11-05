# SilkPlayer 已知问题与缺陷追踪 (Known Issues & Bug Tracker)

本文档为 SilkPlayer 项目缺陷定点追踪记录表，用于规范登记用户报障、测试复现与内部发现的缺陷。

---

## 缺陷索引表 (Issue Index)

| 缺陷编号 | 缺陷摘要 | 影响模式 / 模块 | 严重程度 | 当前状态 | 发现版本 |
| :--- | :--- | :--- | :--- | :--- | :--- |
| ISSUE-001 | 音频模式下倍速播放未生效 | 纯音频播放 / SilkCoreKit (SilkAudioEngine) | Medium | 已修复 (v1.2.0) | v1.1.0 |
| ISSUE-002 | 随机播放无记忆抽样与近距离高频重播缺陷 | 播放列表与音频随机 / SilkPlayer (PlaylistManager) | Medium | 已修复 (v1.2.0) | v1.1.0 |
| ISSUE-003 | 音频模式窗口适配不良与垂直重叠穿模 | 界面布局 / SilkPlayer (AudioArtworkView & PlayerHUDView) | Medium | 已修复 (v1.2.0) | v1.1.0 |
| ISSUE-004 | 窗口几何与交互状态机重构（解决多处约束冲突） | 核心架构 / PlayerWindowManager & WindowGeometry | High | 已修复 (v1.2.0) | v1.1.0 |
| ISSUE-005 | 视频窗口被物理完全遮挡时 Metal 阻塞导致音频断流 | 渲染与解复用 / SilkCoreKit (SilkMetalRenderView & Engine) | Low | 已修复 (v1.2.0) | v1.1.0 |
| ISSUE-006 | 局域网 SMB / 外置存储极窄缓冲导致偶发丢帧 PPT 与音画失步 | 引擎解复用与同步 / SilkCoreKit (SilkPlayerEngine) | Medium | 已修复 (v1.2.0) | v1.1.0 |
| ISSUE-007 | 暂停态音频拖拽 Seek 时钟偏移与硬件采样单调累加缺陷 | 纯音频播放 / SilkCoreKit (SilkAudioEngine) | High | 已修复 (v1.3.0) | v1.2.0 |
| ISSUE-008 | macOS Dock 栏图标边缘暗部与 Dock 底色融合导致视觉偏小 | 视觉设计与图标 / SilkPlayer (Resources) | Medium | 已修复 (v1.3.0) | v1.2.0 |
| ISSUE-009 | 外置存储 (ORICO/USB/SMB/NAS) 播放 4K 10-bit HEVC 拖拽后音画不同步与饥饿重锚失效缺陷 | 解复用与主时钟同步 / SilkCoreKit (SilkAudioEngine & SilkPlayerEngine) | High | 已修复 (v1.4.0) | v1.3.0 |
| ISSUE-010 | 发布镜像动态链接库绝对路径泄露与 Intel 兼容加载头失配致外部机型闪退 | 构建与打包发布 / SilkPlayer (package_app.sh & Packages) | Critical | 已修复 (v1.4.0-fix) | v1.4.0 |
| ISSUE-011 | 音频模式下手动调整播放窗口尺寸引起边框弹跳与高频振荡抖动 | 窗口交互与几何约束 / SilkPlayer (PlayerWindowManager) | Medium | 待修复 (排期 v1.5.0) | v1.4.0 |

---

## ISSUE-001: 音频模式下倍速播放未生效

### 1. 缺陷现象
- 在纯音频播放模式下（播放 MP3、FLAC、APE、WAV、AAC、ALAC、OGG 等音频格式），用户通过播控栏 UI、快捷键或菜单调整播放倍速（如 0.5x、1.25x、1.5x、2.0x）后：
  1. OSD 正常提示倍速已切换（例如显示“播放倍速 2.00x”）；
  2. 实际音频播放速率完全保持 1.0x 原始速度输出，音高与语速无任何变化；
  3. 播放进度条与时间戳推进速度亦保持 1.0x 物理时间推进，倍速设置完全不生效。

### 2. 根因深度剖析

#### 2.1 上层调用与底层变量脱节
- 前端 [`PlayerCore.swift`](file:///Volumes/2T/SilkPlayer/Sources/SilkPlayer/PlayerCore.swift) 在 `setSpeed(_ targetSpeed: Double)` 中将倍速赋值给 `playerLayer?.player.playbackRate`；
- 内核 [`SilkPlayerLayer.swift`](file:///Volumes/2T/SilkCoreKit/Sources/SilkCoreKit/Engine/SilkPlayerLayer.swift) 将属性转发给 `SilkPlayerEngine.setPlaybackRate(_ rate: Double)`；
- [`SilkPlayerEngine.swift`](file:///Volumes/2T/SilkCoreKit/Sources/SilkCoreKit/Engine/SilkPlayerEngine.swift) 接收到速率后，仅更新了原子时钟变量 `self.playbackRate`，**未将该速率同步下发给 `audioEngine` (`SilkAudioEngine`)**。

#### 2.2 SilkAudioEngine 缺少速率控制与时间伸缩算法
- 底层音频输出组件 [`SilkAudioEngine.swift`](file:///Volumes/2T/SilkCoreKit/Sources/SilkCoreKit/Engine/SilkAudioEngine.swift) 采用 CoreAudio `AudioQueue` (`AudioQueueRef`) 输出 PCM 音频；
- `SilkAudioEngine` 未暴露任何设置回放速率的接口，且从未对 `AudioQueue` 调用 `AudioQueueSetParameter(aq, kAudioQueueParam_PlayRate, ...)`；
- `AudioQueue` 默认不支持原生保调时间伸缩（Time-Pitch Stretching），若未显式启用 `kAudioQueueProperty_TimePitchAlgorithm`（如 `kAudioQueueTimePitchAlgorithm_TimeDomain` 或 `kAudioQueueTimePitchAlgorithm_Spectral`），即使改变速率亦可能引起变调或无法生效。

#### 2.3 纯音频时钟完全依赖未变速的 AudioQueue
- 纯音频模式下，画面无视频帧，播放时钟由 [`SilkPlayerEngine.swift`](file:///Volumes/2T/SilkCoreKit/Sources/SilkCoreKit/Engine/SilkPlayerEngine.swift) 的 `startAudioClockLoop()` 驱动；
- 该循环以 ~25Hz 读取 `audio.currentAudioTime` 作为主时钟推进 `currentTime` 并通知 UI；
- 由于 `AudioQueue` 硬件输出恒定运行在 1.0x 物理采样率，`audio.currentAudioTime` 每物理秒仅推进 1.0 秒，导致画面进度条、黑胶唱片旋转周期及时间戳与声音一同锁死在 1.0x 速率。

### 3. 修复方案设计与技术路径

#### 3.1 闭源内核 SilkCoreKit 改造 (SilkAudioEngine.swift)
1. 为 `SilkAudioEngine` 增加 `public func setPlaybackRate(_ rate: Double)` 接口；
2. 在 `createAudioQueue()` 初始化时配置时间伸缩属性：
   - 启用 `kAudioQueueProperty_TimePitchAlgorithm`，设置为 `kAudioQueueTimePitchAlgorithm_TimeDomain`（兼顾低 CPU 功耗与语音保调质感）；
   - 开启 `kAudioQueueProperty_TimePitchBypass = 0`；
3. 在 `setPlaybackRate` 中调用 `AudioQueueSetParameter(aq, kAudioQueueParam_PlayRate, AudioUnitParameterValue(rate))`；
4. 当音频队列重构或 seek 恢复时，保持当前 `playbackRate` 的延续性。

#### 3.2 引擎联动 (SilkPlayerEngine.swift)
1. 在 `SilkPlayerEngine.setPlaybackRate(_ rate: Double)` 中，增加 `audioEngine.setPlaybackRate(clampedRate)` 的联动调用；
2. 在打开新音频流及 seek 重锚点后，确保向 `audioEngine` 补发当前已设定的倍速。

### 4. 落地销项记录
- **落地版本**: **v1.2.0**
- **落地验证**: `SilkAudioEngine.swift` 与 `SilkPlayerEngine.swift` 完成 `setPlaybackRate` 变速保调联动（`kAudioQueueTimePitchAlgorithm_TimeDomain`），纯音频时钟循环同步响应回放速率，0.25x~4.0x 变速保调测试与 52 项自动化回归套件全量通过。

---

## ISSUE-002: 随机播放无记忆抽样与近距离高频重播缺陷 (Shuffle Memoryless Sampling & Repeat Bias)

### 1. 缺陷现象与用户体验痛点
- 在歌单开启随机播放（`.shuffle`）模式后：
  1. 频繁在极短间隔内（如刚听过 1~3 首歌后）再次随机到同一首刚刚播完的曲目，形成 `A -> B -> A` 或 `A -> B -> C -> A` 的高频循环；
  2. 用户主观感知“随机极不均匀”，小歌单（10~30 首）中大量曲目长期未被随机到，而部分曲目反复高频登场；
  3. 用户在随机播放中点击“上一曲”（`moveToPrevious`），无法回退至刚才播放的曲目，而是再次触发不可预期的随机跳转，且 `previousItem` 恒定返回 `nil`。

### 2. 根因深度剖析

#### 2.1 无记忆独立抽样 (Memoryless Sampling) 与生日悖论 (Birthday Paradox)
- 在 [`PlaylistManager.swift`](file:///Volumes/2T/SilkPlayer/Sources/SilkPlayer/Playlist/PlaylistManager.swift#L120-L133) 中，`ensureShuffleCandidate()` 每次生成候选下一曲时，直接调用无状态独立的 `Int.random(in: 0..<items.count)`：
  ```swift
  var nextIdx = Int.random(in: 0..<items.count)
  if nextIdx == currentIndex {
      nextIdx = (nextIdx + 1) % items.count
  }
  nextShuffleIndex = nextIdx
  ```
- 系统完全未维护已播历史（Played History），亦无全量打乱牌堆（Fisher-Yates Shuffled Deck）；
- 刚播完的歌曲在下一次抽取中仅被排除了一次（`currentIndex`），但在随后的每一次切歌中，它立即重新获得与其他未播歌曲完全相同的概率（$\frac{1}{N-1}$）；
- 根据概率论“生日悖论”，在 $N=15$ 的歌单中，仅需随机播放 4~5 首歌，遭遇重复曲目的概率即超过 50%；在 $N=10$ 的歌单中，重复率更是急剧升高，导致用户明显感到“总是那几首歌在打转”。

#### 2.2 相邻下一曲概率翻倍 (Distribution Bias)
- 上述代码中，当随机数不幸命中 `currentIndex` 时，直接通过 `(nextIdx + 1) % items.count` 修正；
- 这一处理直接导致原歌单中排在当前歌曲后一位的曲目（`currentIndex + 1`）获得了自身原生概率加溢出概率的双倍权重（抽中概率高达 $\frac{2}{N}$），打破了均匀随机分布。

#### 2.3 导航逻辑缺失历史回溯栈 (History Stack)
- [`PlaylistManager.swift`](file:///Volumes/2T/SilkPlayer/Sources/SilkPlayer/Playlist/PlaylistManager.swift#L78-L79) 中，`previousItem` 在 `.shuffle` 模式下直接写死为 `return nil`；
- 在 `moveToPrevious()` 中，再次执行了一遍独立的伪随机生成，破坏了用户对“返回上一曲听完”的预期。

### 3. 修复方案设计与技术路径 (Fisher-Yates 洗牌与历史回溯栈)

#### 3.1 引入 Fisher-Yates 洗牌序列队列 (Shuffled Queue Cycle)
1. 切换至随机播放或当前轮次全部耗尽时，基于当前歌单生成一个完整的 Fisher-Yates 打乱索引序列；
2. 确保洗牌序列的第一首不与刚刚正在播放的最后一首相连；
3. 播放器严格沿着该序列推进下一曲，确保整个歌单的 $N$ 首歌曲必须且仅被播放一次；
4. 序列全部消费完毕后，自动触发下一轮全新洗牌（无缝重排且边界防重）。

#### 3.2 建立播放历史栈 (History Backstack)
1. 维护 `private var playHistory: [Int] = []`；
2. `moveToNext()` 与 `handleNaturalEOF()` 将当前索引压入历史栈；
3. `moveToPrevious()` 从历史栈弹出并精准回跳至上一首听过的真实曲目，同时令 `previousItem` 返回历史栈顶元素。

### 4. 落地销项记录
- **落地版本**: **v1.2.0**
- **落地验证**: `PlaylistManager.swift` 实装 Fisher-Yates 洗牌队列（`videoShuffleQueue` / `audioShuffleQueue` / `unifiedShuffleQueue`）与独立历史回溯栈（`currentPlayHistory`），彻底消除无记忆独立抽样与相邻重复缺陷；`upcomingItem` 确立纯只读幂等属性，消除死循环重绘卡死；`PlaylistTests.swift` 专项洗牌回归测试全绿通过。

---

## ISSUE-003: 音频模式窗口适配不良与垂直重叠穿模 (Audio Mode Window Adaptation & Vertical Collision)

### 1. 缺陷现象与实机截图复现
- 用户实机截图中，窗口处于较扁的长宽比（横向宽、纵向偏扁）下：
  1. **歌名与进度条穿模重叠**：正在播放歌名文本（如“张宇-月亮惹的祸”）被播控栏的蓝色时间进度条（`PlayerProgressSection`）直接从正中间水平穿切穿过，滑块（Thumb Dot）直接与歌名首字重叠，文字严重受遮挡且破坏可读性；
  2. **“下一首”预告位置狭窄受挤压**：“下一首：S.H.E - Super Star”提示被硬性挤压在进度条与底部主播放/暂停按键的局促夹缝中；
  3. **黑胶唱片与光冕上下安全区不足**：黑胶唱片及共振光冕（Resonance Corona）直径固定且绝对居中，不仅外圈光晕几乎贴紧顶部红黄绿按钮与顶栏快捷键，且下边缘直接压迫到进度条区域；
  4. **唱机唱针缺失**：唱臂/唱针在当前窗口比例或布局中未被渲染或被完全挤出视口。

### 2. 根因深度剖析

#### 2.1 双层独立渲染未建立安全区避让 (Safe Area Inset)
- [`AudioArtworkView.swift`](file:///Volumes/2T/SilkPlayer/Sources/SilkPlayer/Player/AudioArtworkView.swift#L67-L153) 采用全局居中容器（`VStack(spacing: 28) { FloatingVinylDiscView; VStack { mediaTitle; nextTrackPreview } }`），其中心点对齐的是整个窗口的绝对物理中轴；
- 与此同时，[`PlayerHUDView.swift`](file:///Volumes/2T/SilkPlayer/Sources/SilkPlayer/PlayerHUDView.swift#L48-L55) 的底部播控区（含进度条与播放按键）常驻在窗口底部，高度占用约 80~95pt；
- `AudioArtworkView` 在计算下部垂直间距时，完全没有为底部的 HUD 预留避让底边距（Bottom HUD Inset），导致其下方附带的歌名和下一曲文字恰好落在 HUD 进度条的正上方同一 Y 轴坐标区间。

#### 2.2 黑胶盘片尺寸缺乏对窗口高度的动态自适应约束
- 在高度偏扁的窗口下，黑胶盘片直径与共振光冕未根据可用高度动态按比例缩紧，仍然占据大面积纵向空间，强行把下方的歌名推挤至视口底端。

#### 2.3 音频模式缺乏专属的默认窗口几何记忆与最小高度保护
- 音频起播时若继承了前序视频播放的 16:9 扁平宽屏窗口几何，或者用户在调整窗口时未受最小高度与纵横比软约束限制，窗口很容易被拉成扁长条，从而直接暴露垂直空间的层叠穿模缺陷。

### 3. 修复方案设计与技术路径

#### 3.1 底部 HUD 安全区解耦与避让
1. 在 `AudioArtworkView` 容器中引入顶部安全内缩 `58pt` 与底部安全内缩 `108pt`，为常驻 HUD 预留明确避让空间，使黑胶唱片、专辑封面、歌名与下一曲整体处于安全视口内居中呈现；
2. 进度条与歌名彻底解耦，歌名悬浮于进度条上方并保持清晰的安全间距。

#### 3.2 黑胶与封面尺寸多维自适应缩放
1. 封面与黑胶尺寸由单一宽度约束改造为宽高双维自适应（`computeCoverCardSize` 与 `vinylDiameter`）；
2. 在窗口偏矮或偏窄时自动按比例等比缩紧，确保歌名、下一首与播控条层次分明。

#### 3.3 音频模式专属窗口几何与最小尺寸保护
1. 进入纯音频模式时提供专用的 520x520 居中规格，保证优雅方正视感；
2. 施加 `minAudioSize = 380x380` 最小尺寸保护，防止窗口过度扁平切断内容。

### 4. 落地销项记录
- **落地版本**: **v1.2.0**
- **落地验证**: `AudioArtworkView.swift` 引入 `topSafeInset: 58.0` 与 `bottomSafeInset: 108.0` 安全区隔离，`computeCoverCardSize` 实现宽高双维自适应，黑胶光冕与歌名文本彻底解除与 HUD 进度条重叠碰撞；`PlayerCore+WindowGeometry.swift` 设立 380x380 最小尺寸门禁，音频视口穿模问题已彻底闭环。

---

## ISSUE-004: 窗口几何与交互管理架构统一（状态机重构与约束收拢）

### 1. 架构复盘：为什么窗口交互需要重构为单一状态机？

回顾项目演进历史，窗口系统经历了多轮分散修补：
1. 为了支持竖屏视频旋转，增加了朝向尺寸记忆逻辑；
2. 为了支持 macOS 15 Sequoia 分屏平铺，在 `windowWillResize` 中增加了容差启发式分支；
3. 为了防止 Dock 栏遮挡与全屏贴边，增加了边界夹紧限制；
4. 为了支持纯音频播放，临时增加了 1:1 等比正方形缩放拦截与尺寸保护；
5. 为了消除切歌时的黑屏闪烁，又打上了状态保留补丁。

**核心问题**：
每一次修改都是“针对单一症状打局部补丁”，没有从根源上建立一套严密的**单一窗口几何状态机（Single Window Geometry State Machine）**。缺乏统一状态机治理，导致多处约束相互覆盖，破坏了窗口缩放与模式切换的稳定性。

### 2. 根因剖析：四大系统性架构缺陷

#### 2.1 多头仲裁与权力分散（Multiple Conflicting Authorities）
窗口几何的决策权被割裂散落在四个完全独立的模块中，缺乏单一权威仲裁源：
- [`PlayerWindowManager.swift`](file:///Volumes/2T/SilkPlayer/Sources/SilkPlayer/App/PlayerWindowManager.swift)：负责初始窗口创建、会话挂载、全屏切换；
- `PlayerWindowDelegate`：在 `windowWillResize`、`windowDidResize` 中拦截系统拉伸，强行注入平铺判断与音频 1:1 判断；
- [`PlayerCore+WindowGeometry.swift`](file:///Volumes/2T/SilkPlayer/Sources/SilkPlayer/Player/PlayerCore+WindowGeometry.swift)：在业务层保存 `lastPortraitContentSize`、`lastLandscapeContentSize`，并在收到媒体元数据后反向去调用 `window.setFrame`；
- SwiftUI View 树（`PlayerContainerView`、`AudioArtworkView`、`PlayerHUDView`）：各自通过 `GeometryReader` 假设自己占据全部可用空间，互不知晓对方占用的安全区高宽。

四个仲裁源各自依据局部信息作出假设，发生时序交织时产生灾难性的相互打架。

#### 2.2 异步生命周期时序脱节（Lifecycle Timing Race）
- 底层媒体流解析（FFmpeg/VideoToolbox）是异步完成的（`openAsync`）；
- 窗口创建与呈现是同步触发的；
- 当 `PlayerCore.updateMediaInfo()` 判定进入音频模式并执行 `applyAudioWindowGeometry()` 时，由于宿主窗口尚在绑定过程中，`hostWindow ?? NSApp.keyWindow` 大概率为 `nil`，导致尺寸适配静默失效，窗口保留了上一次视频或默认的 16:9 扁平尺寸；
- 一旦窗口就绪，`wasAudioMode` 已经被置为 `true`，后续再也没有机会主动纠正窗口几何。

#### 2.3 动态拉伸拦截与初始静态状态脱节
- `PlayerWindowDelegate.windowWillResize` 中编写了大量精细的约束（如音频 1:1 约束、平铺自适应约束）；
- **致命缺陷**：这些约束**只在用户亲手去拖拽窗口边缘时才被动触发**。如果用户不拖拽窗口（例如直接双击打开音频文件），窗口就会保持错误的初始几何，委托里的规则完全形同虚设。

#### 2.4 内容视图缺乏全局安全区契约（Missing Inset Contract）
- 界面组件被动地在同一个全屏容器里重叠；
- `AudioArtworkView` 以为整个窗口都是它的画布，直接绝对居中；
- `PlayerHUDView` 以为底部 90pt 永远只是盖在视频黑边上；
- 双方没有任何内边距（Padding/Inset）协商机制，窗口一旦偏扁，视口内的元素必然发生垂直穿模碰撞。

#### 2.5 SwiftUI 根视图隐式 Auto Layout 强锁（第三方 P0 级重大审计发现）
- 在 [`AppShellView.swift`](file:///Volumes/2T/SilkPlayer/Sources/SilkPlayer/App/AppShellView.swift) 中，视图层最外层硬编码了 `.frame(minWidth: 640, minHeight: 360)`；
- 在 macOS 的 `NSHostingController` 与 `NSWindow` 协同机制下，SwiftUI 根视图的 `minWidth: 640` 会直接转化为底层 `NSWindow` 的物理 Auto Layout 内部约束；
- 这导致尽管 `PlayerGeometry.minimumContentSize` 为竖屏视频计算出了 280pt 最小宽度，或者在 `applyAudioWindowGeometry` 中试图将纯音频窗口缩小至 520×520（甚至 380×380），窗口宽度依然被底层的 640pt 强行卡死，彻底解开了竖屏和音频窗口无法自由缩小的谜团。

#### 2.6 后台解码线程与主线程 AppKit 布局竞态（第三方 P1 级审计发现）
- 在 [`SilkPlayerEngine.swift`](file:///Volumes/2T/SilkCoreKit/Sources/SilkCoreKit/Engine/SilkPlayerEngine.swift) 的 `performScrubSeek()` 和 `performExactSeek()` 中，后台队列 `demuxQueue` 直接同步调用了 `self.renderView.render(...)`；
- `SilkMetalRenderView.render` 内部读取了 `layer.bounds` 并修改了 `layer.drawableSize = expectedDrawableSize`；
- 当用户在主线程调整窗口大小时（触发 `NSView.layout()` 并写 `drawableSize`），后台解码线程与主线程并发读写 `CAMetalLayer` 的几何属性，违反了 AppKit / CoreAnimation 的线程安全契约，是偶发画面撕裂或渲染死锁的隐性真凶。

---

### 3. 系统性重构蓝图（彻底终结补丁治理）

坚决停止一切局部打补丁行为，在后续版本中实施系统性重构：

#### 3.1 确立单一窗口几何仲裁器 (`WindowGeometryCoordinator`)
- 废弃 `PlayerCore+WindowGeometry.swift` 中的散落方法；
- 将所有关于窗口 Frame、MinSize、MaxSize、AspectRatio、Screen Clamping 的读写权限**100% 收拢至唯一的 `WindowGeometryCoordinator`**；
- 窗口只有唯一一个出口来执行 `window.setFrame`。

#### 3.2 建立严格显式状态机 (`WindowPresentationState`)
定义完备的场景模式联合枚举：
```swift
public enum WindowPresentationState: Equatable {
    case idle
    case video(aspectRatio: CGFloat, orientation: VideoOrientation)
    case audio(coverType: AudioCoverType)
    case fullscreen(previousState: Box<WindowPresentationState>)
    case systemTiled(quadrant: TileQuadrant)
}
```
每次状态变更（如视频转音频、旋转、退出全屏、进入平铺），统一由状态机执行标准转移函数：
`transition(to newState: WindowPresentationState, animated: Bool)`，同步完成窗口尺寸、比例锁、最小尺寸与安全区的统一切换。

#### 3.3 引入视图安全区总线 (`WindowContentInsets`)
- 窗口管理器统一计算并向下广播安全区环境值（`EnvironmentValues.playerHUDInsets`）；
- `AudioArtworkView` 等内部视图严格基于 `SafeArea` 进行几何布局，从布局引擎层保证歌名、进度条、唱片绝不可能发生物理重叠。

#### 3.4 建立全状态转移矩阵自动化测试（State Transition Matrix Tests）
- 编写专门的窗口状态转移矩阵测试用例：
  - `video(16:9) -> audio` 状态转换验证；
  - `audio -> video(9:16)` 状态转换验证；
  - `systemTiled -> normal` 状态恢复验证；
  - 极端小屏/多屏切换约束验证；
- 只有当状态转移矩阵所有路径 100% 自动化断言通过，才允许交付窗口功能。

---

### 4. 第三方方案协同落地机制 (Collaborative Execution Framework)

依据用户指令，确立“**外部架构方案评审 + 本地代码定点落地与回归测试**”的协同推进机制：

1. **方案输入与对齐**：
   第三方提供具体修改方案后，全量导入进行交叉比对；
2. **可行性审计报告**：
   本地 AI 结合 Swift 6 严格并发契约、AppKit / Metal 线程安全约束、物理架构隔离红线及 52 项回归测试套件进行逐行推演，输出审计与微调建议；
3. **分层定点落地**：
   - 内核层修复：涉及 Seek 线程与 Metal 渲染竞态的逻辑，严格在 `/Volumes/2T/SilkCoreKit` 独立修改并重新构建 `SilkCoreKit.xcframework`；
   - 前端层重构：移除 `AppShellView.swift` 中的 `.frame(minWidth: 640)`，实现 `WindowGeometryCoordinator` 单一仲裁器与 `WindowPresentationState` 状态重放机制；
4. **自动化回归与实机闭环**：
   本地运行 `./scripts/run_tests.sh` 确保 52 项不变量测试 100% 满血绿勾通过，绝不留死角。

### 5. 落地销项记录
- **落地版本**: **v1.2.0**
- **落地验证**: `AppShellView.swift` 移除外层 `minWidth: 640` 隐式 Auto Layout 强锁，`PlayerGeometry` 接管 16:9 / 竖屏 280pt / 音频 380pt 最小尺寸仲裁；后台解码线程与 Metal 渲染读写解耦，核心约束冲突与时序竞争全面闭环，自动化回归测试套件全量通过。

---

## ISSUE-005: 视频窗口被物理完全遮挡时 Metal 阻塞导致音频断流 (Occlusion Audio Starvation)

### 1. 缺陷现象
- 在播放 MP4 等带视频轨的媒体时，若播放器处于后台且被其他全屏无边框或大面积不透明窗口（如全屏 Chrome、全屏 IDE）**100% 物理完全遮挡覆盖**（非最小化至 Dock），播放器可能在数秒内丢失声音。
- 将遮挡窗口移开恢复画面可见后，播放进度可能发生跳变或音频重新恢复。
- 该现象具有严苛触发条件：必须是未最小化状态下的 100% 屏幕像素完全遮挡（触发 `window.occlusionState.contains(.visible) == false`）。

### 2. 根因链条分析 (Root Cause Chain)
1. **Metal 驱动层阻塞**：
   在 [`SilkMetalRenderView.swift`](file:///Volumes/2T/SilkCoreKit/Sources/SilkCoreKit/Engine/SilkMetalRenderView.swift) 中，`render(pixelBuffer:...)` 直接调用 `layer.nextDrawable()`。
   当 macOS WindowServer 检测到窗口被其他不透明全屏窗口 100% 物理遮挡时，CAMetalLayer 无法呈现到物理显示器，`nextDrawable()` 会被驱动阻塞（最长约 1 秒）；
2. **渲染线程停顿**：
   [`SilkPlayerEngine.swift`](file:///Volumes/2T/SilkCoreKit/Sources/SilkCoreKit/Engine/SilkPlayerEngine.swift) 中的 `videoQueue` 循环在等待 `renderView.render` 完成，导致视频帧消费停滞；
3. **解复用背压触发死锁**：
   未消费的视频包在 `videoPacketQueue` 中迅速堆积至硬编码上限 `maxVideoPackets = 24`。
   `startDemuxLoop()` 检测到 `count >= maxVideoPackets`，进入 `continue` 降频等待循环，**停止从容器中调用 `demuxer.readPacket()` 读包**；
4. **音频缓冲区耗尽断音**：
   解复用暂停后，音频解码器同样无法接收到新的音频包。底层 `SilkAudioEngine` 的 16 个 AudioQueue Buffer（约 0.64 秒音频数据）播放耗尽后，产生物理静音断流。

### 3. 修复方案设计与技术路径
- **内核层修复 (SilkCoreKit)**：
  1. 在 `SilkMetalRenderView.render` 顶部加入窗口遮挡状态守卫：
     ```swift
     if let window = self.window, !window.occlusionState.contains(.visible) {
         return // 窗口完全被遮挡时跳过 Metal 提交，避免 nextDrawable 阻塞
     }
     ```
  2. 在 `SilkPlayerEngine` 的 `videoLoop` 中，若检测到窗口完全不可见，保持时间戳基准推进并以丢弃渲染模式消费 `videoPacketQueue`，确保解复用器持续读取音频数据。

### 4. 落地销项记录
- **落地版本**: **v1.2.0**
- **落地验证**: `SilkMetalRenderView.swift` 接入 `window.occlusionState.contains(.visible)` 遮挡守卫，窗口 100% 物理遮挡时跳过 Metal 提交以避免 `nextDrawable` 驱动级挂起；`SilkPlayerEngine` 在遮挡下保持丢弃渲染并维持解复用喂饱音频缓冲区，遮挡静音缺陷已彻底闭环并通过自动化回归测试。

---

## ISSUE-006: 局域网 SMB / 外置存储极窄缓冲导致偶发丢帧 PPT 与音画失步缺陷 (Network Stream Buffer Starvation & A/V Sync Desync)

### 1. 缺陷现象与实机复现
- **复现环境**：Mac mini M4 管理机通过 SMB 协议挂载局域网 NAS（Debian 业务机）共享盘播放 4K 影片（如 `/Volumes/HDD2T/影音娱乐/电影/4k.mkv`，HEVC 3840×1608 24fps，E-AC-3 5.1）；
- **故障特征**：在连续播放至特定进度（如 45分51秒附近）时，画面突然出现类似 PPT 的严重掉帧卡顿，伴随音画脱节；
- **关键特征**：
  1. 片源经 VideoToolbox 硬件硬解实测完全健康（0 decode errors，硬解速率达 3.44x~4.02x），且本地拖拽跳转（Seek）秒开流畅毫无卡顿；
  2. 用户执行暂停 2~3 秒后重新点播放，画面与声音立刻恢复 100% 丝滑同步。

### 2. 根因深度剖析

#### 2.1 极窄视频缓冲池无法吸收 SMB 协议的微观交互延迟
- 在 [`SilkPlayerEngine.swift`](file:///Volumes/2T/SilkCoreKit/Sources/SilkCoreKit/Engine/SilkPlayerEngine.swift#L105) 中，视频包缓冲上限被硬编码为：
  `private let maxVideoPackets = 24`
- 24 个视频包在 24fps 电影中**仅相当于 1.0 秒的数据余量**；
- 尽管局域网物理带宽高达 2.5Gbps，但 SMB 属于“一问一答（Request-Request RPC）”网络文件系统，加上 NAS 机械硬盘的物理寻道延迟与系统元数据刷新，偶发会出现 100~300 毫秒的网络等待；
- 1.0 秒的极窄缓冲区瞬间被掏空（`videoPacketQueue.isEmpty`），导致前台视频消费直接断流。

#### 2.2 激进的音画同步追赶逻辑引发恶性连环跳帧（PPT 假象）
- 在 `SilkPlayerEngine.swift` 的渲染循环中（L972~988）：
  - 播放器以硬件 CoreAudio 作为主时钟，一旦视频帧因网络等待比音频时钟慢了 `> 40ms`，代码直接执行 `continue` **丢弃当前渲染帧**（试图追赶时间）；
  - 若落后 `> 250ms`，代码强行调用 `audio.reanchor(to: pts)` 反复重设时钟；
- 这种粗暴的“落后即扔”机制导致了一旦网络抖动，播放器在一秒内连续扔掉十几张画面，主观视觉直接沦为“一秒只跳两三帧的 PPT”，并且导致声音与画面严重脱节。

#### 2.3 暂停动作具有“重新蓄水与时钟归零对齐”的特殊性
- 用户点击暂停时，前台停止以 24fps 消耗数据，后台网络解复用线程在数秒内迅速将缓冲池重新打满；
- 恢复播放时，CoreAudio 声卡时钟执行重置（`AudioDeviceStart -> start time resolved`），将音频硬件时钟与当前视频帧重新强行拉平在同一起跑线，因此暂停后再播能够瞬间自愈。

### 3. 修复方案设计与技术路径
- **内核层优化 (SilkCoreKit)**：
  1. **引入向前预读大缓冲区 (Buffer Ahead)**：
     - 将网络流媒体与外挂磁盘的视频包队列从 24 包放宽至 **300 包（约 10 秒+ 缓冲）**，彻底熨平 SMB 局域网协议抖动与机械硬盘寻道延迟；
  2. **废除暴力丢帧，引入平滑微调变速追赶 (Rate Shifting)**：
     - 当视频落后音频 40~150ms 时不再粗暴丢帧，采用阻尼与动态速率平滑追赶；
  3. **预加载状态指示 (Buffer Health Indicator)**：
     - 在 HUD 进度条底层支持显示灰色缓冲加载条，加载状态直观可感知。

### 4. 落地销项记录
- **落地版本**: **v1.2.0**
- **落地验证**: `SilkPlayerEngine.swift` 将 `maxVideoPackets` 扩展至 300 包，实装平滑同步追赶机制；局域网 SMB 挂载 NAS 播放 4K 10-bit HEVC 丢帧 PPT 与音画失步问题彻底闭环，通过自动化回归测试。

---

## ISSUE-007: 暂停态音频拖拽 Seek 时钟偏移与硬件采样单调累加缺陷

### 1. 缺陷现象
- 在纯音频播放时，用户在暂停状态下拖拽时间进度条（Seek）至任意位置，松开鼠标或恢复播放后：
  1. 音频输出位置与进度条指示产生微秒至百毫秒级固定偏移；
  2. 多次连续拖拽后，时钟基准出现单调累加漂移。

### 2. 根因剖析
- `SilkAudioEngine` 采用 CoreAudio `AudioQueue` 驱动时钟。在暂停状态下，声卡物理采样时钟 `AudioQueueGetCurrentTime` 并未因暂停而停止流逝；
- 当执行 `reanchor(to:)`、`decodeAndEnqueue` 或 `notifySeek` 时，代码将目标 PTS 直接绑定为锚点，而未扣除从硬件声卡启动至当前时刻已经流逝的物理硬件采样数（`currentPhysicalSampleTimeElapsed`）；
- 每次在暂停态 Seek 时，锚点时钟都会叠加一层未扣除的硬件流逝采样偏移；
- 另外在 `SilkPlayerEngine.performScrubSeek` 中，以 20Hz 极高频率调用 `audioEngine.notifySeek`，导致频繁重置时钟。

### 3. 修复方案设计与技术路径
- **内核层修复 (`SilkAudioEngine.swift`)**：
  1. 新增 `currentPhysicalSampleTimeElapsedLocked()`，精准读取并返回当前 CoreAudio 硬件队列已流逝的物理采样数；
  2. 在 `reanchor(to:)`、`decodeAndEnqueue` 与 `notifySeek` 中，将基准时间戳对齐调整为 `pts - (Double(elapsedSamples) / sampleRate)`，彻底扣除硬件声卡物理流逝，确保无论暂停多久拖拽，起播时刻的时间戳与音频硬件输出严格绝对对齐；
  3. 在 `SilkPlayerEngine.performScrubSeek` 中移除冗余的 20Hz 频繁时钟重设，仅在最终松手 Seek 时执行单次高精度时间对齐。

### 4. 落地销项记录
- **落地版本**: **v1.3.0**
- **落地验证**: `SilkCoreKit`（commit `7baeb84`）实装硬件采样流逝补偿算法，`SilkPlayer` v1.3.0 验证暂停态 Seek 时钟严格对齐，单调累加漂移缺陷彻底闭环。

---

## ISSUE-008: macOS Dock 栏图标边缘暗部与 Dock 底色融合导致视觉偏小缺陷

### 1. 缺陷现象
- 用户反馈在 macOS 浅色与深色 Dock 栏中，SilkPlayer 应用图标相较于系统原生应用（如 Safari、Music、Finder）或其他第三方标准应用，在主观视觉上明显偏小。

### 2. 根因深度剖析
- **几何尺寸完全达标**：实测 `AppIcon.icns` 中包含的各尺寸图标，其实际圆角矩形（Squircle）在 1024×1024 画布下精确占据 824×824 像素，完全符合 Apple macOS Human Interface Guidelines（HIG）标准网格与外包围盒规范；
- **边缘暗色与低对比度引发光学错觉**：
  1. SilkPlayer 采用科技深色调设计，Squircle 背景最外层边界的像素亮度极低（RGBA 约为 `[26, 30, 42, 255]`，亮度仅约 30）；
  2. macOS 深色模式下的 Dock 栏背景亦为磨砂深灰底色（亮度约 20~40）。当二者重叠时，由于图标外圈缺乏足够对比度与轮廓高光，人眼视网膜自动将外层暗区判定为“Dock 背景的一部分”；
  3. 人眼焦点仅能辨识中央面积约 635×668 的亮色图形部分，直接产生了“图标比其他自带明亮底色或边框高光应用小约 25%”的显著光学错觉。

### 3. 优化方案设计与实施
- **视觉设计与材质调校**：
  1. **内轮廓环境光高光 (Inner Rim Highlight)**：基于标准 824×824 Squircle 物理边界，增加符合 macOS 设计语言的 2~3px 渐变微光内描边（顶部环境光白半透明 ~0.50，底部漫反射微光 ~0.20），平滑抗锯齿过渡；
  2. **消除与深色 Dock 粘连**：即便在 100% 纯黑背景或暗色磨砂 Dock 栏下，该内轮廓高光依然能清晰勾勒出完整的 824×824 物理圆角矩形边界，使整体视觉光学体量与其他主流应用达成 1:1 的饱满视觉平衡；
  3. 重建 `Resources/AppIcon_1024.png`，并使用 Apple 原生 `iconutil -c icns` 重新生成覆盖 16x16 至 512x512@2x 全分辨率的 `Resources/AppIcon.icns`。

### 4. 落地销项记录
- **落地版本**: **v1.3.0**
- **落地验证**: `AppIcon.icns` 增加内轮廓高光（Inner Rim Highlight），消除深色 Dock 栏磨砂背景粘连与视觉偏小光学错觉，全套 16x16 至 512x512@2x 图标资源已更新并实机验证通过。

---

## ISSUE-009: 外置存储 (ORICO/USB/SMB/NAS) 播放 4K 10-bit HEVC 拖拽后音画不同步与饥饿重锚失效缺陷 (External Storage 4K HEVC A/V Desync & Starvation Re-anchor Bug)

### 1. 缺陷现象与环境表现

- **报障环境**：用户使用外置硬盘（如 ORICO 硬盘盒通过 USB 直连，或局域网 NAS 通过 SMB/NFS 挂载至 macOS `/Volumes/<Share>`）播放 4K 10-bit HEVC 高码率视频片源（如 50~100 Mbps REMUX / Web-DL）；
- **用户行为与复合触发诱因**：
  1. 用户在视频起播初期拖动进度条（Seek）跳转跳过片头；
  2. 随后用户静置观看，因播放器未向 macOS 申请电源断言（参见 ISSUE-010 / 电源管理缺陷），Mac 闲置 2~5 分钟后自动进入屏幕休眠与锁屏；
  3. 系统锁屏引发外置 USB 硬盘进入 APM 低功耗休眠或盘片停转，导致解复用 I/O 瞬间彻底中断；
  4. 用户唤醒电脑并解锁屏幕后，外置磁盘重新起转伴随数秒 I/O 挂起，此时画面与声音发生数十秒甚至数分钟的严重固定时间差（音画完全不同步）。
- **对比排查结论（为何作者本地 SMB 环境无法复现）**：
  - 作者本地测试环境（Mac mini M4 经 2.5Gbps 全双工连通 PVE 宿主机 VM102 NAS）吞吐极高、且测试过程始终处于交互活跃态，屏幕从未进入锁屏休眠；
  - 局域网千兆/2.5G 高速网络下，音频队列缓冲水位始终充裕，从未发生缓冲区打空断水（Starvation，即 `freeBuffers.count == buffers.count`）；
  - 因此，作者环境从未触发过“断流后重新拉起声卡”的异常路径，现有管线在正常连续播放与交互拖拽下表现稳定丝滑；该缺陷高度依赖“系统休眠锁屏 / 外置磁盘停转 -> 音频缓冲打空断流 -> 唤醒后异常恢复”这一特定复合工况。

---

### 2. 根因深度剖析

#### 2.1 饥饿恢复重锚逻辑被拦截 (isAnchorPtsSet 守卫副作用)
- 在内核 `SilkAudioEngine.swift` 中，前期提交（commit `7cf51c8`）为了防止 seek 过程中 pre-roll 解码出的连续音频包反复污染 `startPts`，增加了 `isAnchorPtsSet` 布尔守卫；
- 然而在 `decodeAndEnqueue(packet:)` 中：
  ```swift
  let shouldStart = isPlayingState && !isAudioQueueStarted && (queued >= 4)
  if shouldStart {
      isAudioQueueStarted = true
      if !isAnchorPtsSet {
          if let elapsed = currentPhysicalSampleTimeElapsedLocked() {
              startPts = pts - elapsed
          } else {
              startPts = pts
          }
          isAnchorPtsSet = true
      }
  }
  ```
- **关键缺陷**：当用户 Mac 锁屏休眠或外置盘停转唤醒导致音频缓冲彻底耗尽（Starvation，即 `freeBuffers.count == buffers.count`）后，`isAudioQueueStarted` 被置为 `false`；
- 当解复用器恢复读取并灌入新音频数据时，`shouldStart` 再次为 `true`。但由于 `isAnchorPtsSet` 仍为起播/拖拽时置下的 `true`，**重锚逻辑被直接拦截跳过**；
- `startPts` 依然保持着锁屏或休眠前的陈旧时间戳，而硬件声卡时钟 `currentPhysicalSampleTimeElapsedLocked()` 已单调累加了休眠与停顿期间的物理流逝；
- 导致 `currentAudioTime` 计算值与实际写入硬件队列的音频帧 PTS 彻底脱节，产生等同于 I/O 停顿物理时长的永久时间偏差。

#### 2.2 起播与 Seek 预冲刺双端门禁失衡 (Dual-Readiness Barrier 缺失)
- 4K 10-bit HEVC 视频关键帧数据量庞大（单个 I 帧及伴随 NALU 往往达到 500KB~2MB），在容器内与音频流交织距离较远；
- 在 `SilkPlayerEngine.performExactSeek` 中：
  1. 解复用器向后检索视频关键帧并循环读取最多 120 个 packet；
  2. 在外置盘机械寻道或 SMB RPC 往返延迟下，前 120 个包中解析到的有效音频包极少（不足 4 个 buffer，未达到起播门槛 `queued >= 4`）；
  3. `performExactSeek` 完成关键帧落地后，立即将 `clockState.isSeeking` 置为 `false`，视频渲染循环 `videoRenderLoop` 随即全速运转；
  4. 此时音频硬件队列尚未启动（`audio.hasAudioOutputStarted == false`），视频主时钟降级为本地系统墙上时钟（`wallClockStart`），视频帧开始按照绝对物理时间推进渲染；
  5. 数百毫秒后外置盘完成解复用并填满 4 个音频 buffer，音频硬件队列正式启动，`hasAudioOutputStarted` 突变为 `true`；
  6. 视频渲染循环的主时钟瞬间从已推进数百毫秒的系统墙上时钟强行切换回刚刚起步的 `audio.currentAudioTime`；
  7. 视频时钟差值 `diff = (pts - masterTime)` 瞬间产生 `+0.300s ~ +0.800s` 的正向跳变；
  8. 视频渲染循环进入 `while diff > 0.002` 的微秒等待，因单次最多等待 240ms 超时推出，导致视频连续多帧严重丢帧降速（类似慢动作），直到视频与音频被动拉扯对齐，造成强烈的卡顿与失步感知。

#### 2.3 音轨切换未联动文件指针微距重寻 (selectTrack 物理偏移)
- 在 `SilkPlayerEngine.selectTrack(id:mediaType:)` 中，切换音频轨时：
  ```swift
  demuxer.selectTrack(id: id, mediaType: mediaType)
  if mediaType == .audio, let aPar = demuxer.audioCodecParameters {
      let curTime = self.currentTime
      audioEngine.close()
      _ = audioEngine.open(codecParameters: aPar, timeBase: demuxer.audioTimeBase)
      audioEngine.notifySeek(targetTime: curTime)
      if isPlaying { audioEngine.play() }
  }
  ```
- **核心缺陷**：该逻辑仅重置了音频解码器与 AudioQueue，**完全没有通知底层的 FFmpeg `AVFormatContext` 重新定位物理文件读取位置**；
- 解复用器仍然停留在前一个音轨的流读取位置之后，导致新音轨解码到的首批 packet 并非位于 `curTime`，而是处于流中不可预测的物理偏移点，造成切换多音轨后的物理时延失步。

---

### 3. 多介质挂载环境特征矩阵分析

针对用户可能采用的不同挂载方式，其底层 I/O 特征与对播放引擎的冲击评估如下：

| 挂载类型 | 典型场景 | I/O 特征与延迟分布 | 播放引擎主要受挫点 |
| :--- | :--- | :--- | :--- |
| **直连外置移动硬盘 (USB/Type-C)** | ORICO/绿联等硬盘盒（SATA/NVMe） | 吞吐高（100~1000MB/s），但伴随硬盘休眠（APM Spin-down）唤醒延迟（2~4秒）及 USB 控制芯片队列抖动 | Seek 时触发物理盘起转，`av_read_frame` 瞬间阻塞 1~3 秒；极易触发音频队列 Starvation。 |
| **局域网网络存储 (SMB/CIFS)** | macOS Finder 挂载局域网 NAS 共享目录 | 单次 `fseek`/`fread` 受 SMB2/3 RPC 往返时延（RTT 1~10ms）与 Wi-Fi 抖动影响；无系统级预取缓存 | 4K HEVC 关键帧检索需频繁随机 seek，网络 I/O 抖动导致视频包到达不均，音频队列频繁断水。 |
| **网络文件系统 (NFS)** | 极客级局域网 NFSv4 挂载 | RPC 吞吐稳定，但在高并发或瞬时断连时呈阻塞式挂起 | 需具备严格的中断回调（`interrupt_callback`）与缓冲水位弹性熔断机制。 |
| **片头拖拽 Seek (Early Scrub)** | 播放初始 5~15 秒内拖拽进度条 | 容器元数据刚解析完毕，系统文件缓存尚未建立，解复用与 VideoToolbox 解码器处于冷启动状态 | 视频关键帧落地迅速但音频交织包尚未读足，极易触发视频先跑、音频晚起的时钟撕裂。 |

---

### 4. 修复方案设计与技术路径（极简微创原则）

为了防止“过度重构破坏现有稳定管线”，本修复方案严格奉行**定点微创（Minimal Invasive Surgery）**原则：绝对不重构正常的视频主渲染循环与成熟的快速 Scrub 解码逻辑，仅在断流恢复点与前端生命周期处注入针对性防护。

#### 4.1 前端切断诱发源：接入电源断言阻止闲置锁屏 (`PlayerCore.swift`)
- **根因切除**：彻底解决用户静置观看时 macOS 自动锁屏与外置硬盘 APM 停转休眠问题；
- **实现方案**：
  1. 在 `PlayerCore.play()` 时，申请系统活动断言：
     - 视频模式：`ProcessInfo.processInfo.beginActivity([.idleDisplaySleepDisabled, .userInitiated], reason: "SilkPlayer Video Playback")`；
     - 纯音频模式：`ProcessInfo.processInfo.beginActivity([.idleSystemSleepDisabled, .userInitiated], reason: "SilkPlayer Audio Playback")`；
  2. 在 `PlayerCore.pause()` / `stop()` 时即刻释放断言；
  3. 从根本上切断“播放中无人触碰 -> 自动锁屏黑屏 -> 硬盘休眠停转”的始发链条。

#### 4.2 内核引入饥饿状态机与隔离重锚 (`SilkAudioEngine.swift`)
- **原则**：100% 保留 commit `7cf51c8` 对 Seek pre-roll 重复赋值的保护，仅对“完全断流打空”的异常场景开放重锚；
- **实现方案**：
  1. 增加显式饥饿标识 `private var isStarved: Bool = false`；
  2. 当且仅当缓冲区全部打空（`freeBuffers.count == buffers.count`，即发生物理断流）时，置 `isStarved = true` 与 `isAudioQueueStarted = false`；
  3. 当新音频数据注满触发 `shouldStart` 时，执行条件判定：
     ```swift
     if !isAnchorPtsSet || isStarved {
         if let elapsed = currentPhysicalSampleTimeElapsedLocked() {
             startPts = pts - elapsed
         } else {
             startPts = pts
         }
         seekAnchorPts = pts
         isAnchorPtsSet = true
         isStarved = false
     }
     ```
  4. **零回归保证**：正常连续播放与正常 Seek 时 `isStarved` 恒为 `false`，完全走原有经过验证的高速通路；仅当遭遇休眠唤醒或外置盘严重卡顿时，才触发该自愈重锚逻辑，使声卡时钟与新帧 PTS 瞬间拉平。

#### 4.3 音轨切换强制微距 Seek 重定位 (`SilkPlayerEngine.swift`)
- 在 `selectTrack(id:mediaType:)` 切换音频轨时，强制调用 `self.requestSeek(to: self.currentTime, exact: true)`；
- 刷新底层 `AVFormatContext` 读取指针，确保新音轨物理对齐，仅在用户主动切音轨时触发一次，对正常回放零侵入。

---

### 5. 验收标准与测试矩阵

1. **外置磁盘 Seek 验证**：
   - 使用 USB 外置机械盘/移动 SSD 播放 4K 10-bit HEVC 片源；
   - 在片头 5 秒、片中各处连续执行 5 次拖拽跳转，要求音频与视频在 0.3 秒内同步出声出画，口型完全一致，无慢动作卡顿；
2. **多音轨无缝切换验证**：
   - 播放双音轨/多音轨片源，在播放过程中快速切换音轨，验证声音切换平滑且音画保持绝对同步；
   - 验证切换后播放器时间轴无不可逆漂移；
3. **全量自动化测试基线**：
   - 运行 `./scripts/run_tests.sh` 确保现存 54 项全量测试 100% 保持全绿通过。

---

### 6. 实施与闭环验证 (v1.4.0)
- **SilkAudioEngine**: `isStarved` 饥饿状态机自愈重锚逻辑已实装并合并；
- **PlayerCore**: `ProcessInfo.processInfo.beginActivity([.idleDisplaySleepDisabled, .userInitiated])` 播放防休眠断言已接入；
- **SilkPlayerEngine**: 音轨切换强制微距 Seek 重定位已合入；
- **测试结果**: 自动化回归套件全量通过，外置存储播放 4K HEVC 拖拽音画失步与断流饥饿重锚问题已彻底闭环解决。

---

## ISSUE-010: 发布镜像动态链接库绝对路径泄露与 Intel 兼容加载头失配致外部机型闪退

### 1. 缺陷现象
- 用户在非编译机的外部 Mac（包括 Apple Silicon M 系列芯片与 Intel 架构机型）上下载并安装 v1.4.0 初始发布镜像后，双击应用图标直接闪退，并弹出系统级错误弹窗：
  > “SilkPlayer”因为出现问题而无法打开。请与开发者联系，以确保 SilkPlayer 可以配合此 macOS 版本使用。你可能需要重新安装该应用程序……【忽略】【报告……】
- M 芯片用户反馈 arm64 安装包闪退，而转译运行 x86_64 安装包却能正常打开，造成“两个架构包搞反”的严重体验困扰；老款 Intel 机型（如 MBP 2018 macOS 15）同样无法打开。

### 2. 根因分析
1. **arm64 动态库硬编码绝对路径**：
   - 早期打包的 `Libavcodec.framework` 等依赖库内，`LC_LOAD_DYLIB` 记录了编译宿主机的物理磁盘路径 `/Volumes/2T/SilkPlayer_LGPL_Build/install/lib/...`，未清洗为 `@rpath` 相对寻址；
   - 外部机器因无此路径，`dyld` 动态加载失败直接触发 `dyld_fatal_error` 终止进程；而编译机物理存在该路径，本地测试时直接命中，造成“测试通过”的严重假象。
2. **双架构最低系统基线（macOS 14.0+）对齐与文档口径失配**：
   - SilkPlayer 强依赖 Swift 6 原生 Observation 响应式框架（macOS 14.0+），双架构编译参数统一对齐 `--triple "${ARCH}-apple-macosx14.0"`；此前移交文档曾误写“minos 12.0”，导致对老旧系统兼容范围产生虚假预期。
3. **打包脚本缺少深度物理断言与双重校验门禁**：
   - 打包脚本此前仅简单通过 grep 拦截特定目录，未强制白名单判定非系统库 100% `@rpath` 化；
   - 挂载 DMG 仅验证了 `.app` 目录存在，未再次复核挂载介质内部二进制依赖；
   - 缺少对 GitHub Releases 线上已发布资产与本地 DMG 的自动 SHA-256 校验链。

### 3. 修复措施与闭环规范
1. **底层动态库彻底清洗与重定位**：
   - 使用 `install_name_tool` 对所有 XCFramework 内部依赖库重构，全面绑定为 `@rpath` 相对寻址；
   - 统一明确双架构物理最低系统基准为 macOS 14.0。
2. **打包脚本合入刚性门禁断言 (`package_app.sh`)**：
   - 引入动态依赖白名单审计函数 `audit_bundle_dependencies`：凡非系统框架（非 `/System/Library/`、`/usr/lib/`）且未以 `@rpath/` 开头，直接 `exit 1` 熔断中止；
   - DMG 制作完成后，自动挂载并对其内部的 `.app` 再次执行全量依赖审计与深度代码签名复核；
   - 打包末尾自动输出本地 DMG 的 SHA-256 校验码。
3. **新增发布资产自动化校验脚本 (`scripts/verify_release_asset.sh`)**：
   - 自动拉取 GitHub Releases 资产元数据（`digest`），与本地构建产物及桌面产物逐项比对 SHA-256，确保 100% 对齐。
4. **发布版本缓存规避**：
   - 修复后的发布镜像追加 `-fix` 标识，避免 GitHub Fastly CDN 与浏览器本地缓存继续分发旧有错误文件。
5. **纪律升格**：
   - 升格为 `AI_HANDOFF_INSTRUCTION.md` 之【铁律 5：发版打包物理隔离断言与动态库自闭环校验纪律】。

### 4. 落地销项记录
- **落地版本**: **v1.4.0-fix**
- **落地验证**: 双架构所有嵌入二进制依赖库经 `install_name_tool` 100% `@rpath` 化并完成签名；`package_app.sh` 接入依赖路径白名单审计刚性门禁；`verify_release_asset.sh` 线上与本地 DMG SHA-256 达成 100% MATCH 对齐；外部机型双架构冷启动运行闪退问题彻底闭环。

---

## ISSUE-011: 音频模式下手动调整播放窗口尺寸引起边框弹跳与高频振荡抖动

### 1. 缺陷现象
- 在纯音频播放模式下（播放 MP3、FLAC、APE、WAV 等无视频轨媒体），用户尝试通过鼠标手动拖拽调整播放窗口尺寸时，发生剧烈的边框弹跳与高频抽搐抖动：
  1. **单向边框拖拽**：纯水平拉拽左/右边框，或纯垂直拉拽上/下边框时，窗口在用户提议的目标尺寸与基准尺寸之间以 60Hz/120Hz 极高频率反复横跳（交替振荡）；
  2. **四角边框拖拽**：在对角线方向拖拽时，只要位移在水平与垂直轴产生微小速率不均，窗口尺寸会在宽度驱动与高度驱动之间突变跳跃；
  3. 用户主观感知窗口边缘“卡死、抗拒拉伸、剧烈抽搐”。

### 2. 根因分析
1. **未对 `window.inLiveResize` 实时交互态解耦**：
   - 在 [`PlayerWindowManager.swift`](file:///Volumes/2T/Projects/SilkPlayer/SilkPlayer/Sources/SilkPlayer/App/PlayerWindowManager.swift#L830-L848) 的 `PlayerWindowDelegate.windowWillResize(_:to:)` 中，纯音频分支（第 831 行）置于通用 `if window.inLiveResize` 之前；
   - 视频播放模式在实时拖拽中放行双轴尺寸提议，仅作安全范围钳制；而音频模式在每一帧拖拽回调中均强行介入 `1:1` 等比正方形重算（`NSSize(width: round(targetSide), height: round(targetSide))`）。
2. **单向拖拽时的 Delta 竞争死循环 (交替振荡)**：
   - 当用户单向拉拽（如水平右边框）时，AppKit 传入的 `frameSize` 提议仅宽度递增，高度保持初始值 $H_0$；
   - **奇数帧**：当前窗口尺寸为 $(W_0, H_0)$，鼠标拉到 $W_1$。计算得 `deltaW = |W_1 - W_0|`，`deltaH = 0`。因 `deltaW > deltaH`，判定宽度占优，窗口被拉大至 $(W_1, W_1)$；
   - **偶数帧**：当前窗口变为 $(W_1, W_1)$，鼠标微动至 $W_2$。AppKit 提议仍为 $(W_2, H_0)$。此时 `deltaW = |W_2 - W_1|`（微小），而 `deltaH = |H_0 - W_1|`（显著更大）。条件 `deltaH > deltaW && deltaH > 1.0` 命中，算法误判为高度占优，强制选用 $H_0$ 作为目标边长，窗口瞬时坍塌回 $(H_0, H_0)$；
   - 导致窗口在拉大与坍塌之间死循环交替震荡，形成肉眼可见的高频高振幅抖动。
3. **渲染层具备自适应能力，无强加正方形约束的物理必要性**：
   - [`AudioArtworkView.swift`](file:///Volumes/2T/Projects/SilkPlayer/SilkPlayer/Sources/SilkPlayer/Player/AudioArtworkView.swift#L24-L40) 基于 `GeometryReader` 动态计算安全边距，封面与唱片均采用 `.aspectRatio(contentMode: .fit)` 居中渲染；
   - 无论窗口处于正方形或长方形，画面均能自适应居中，无画面拉伸或溢出风险。

### 3. 规划修复方案 (排期 v1.5.0)
1. **实时交互与静态规整解耦**：
   - 在 `PlayerWindowDelegate.windowWillResize` 中，若 `window.inLiveResize == true`，顺应用户鼠标指针轨迹放行双轴尺寸提议；
   - 仅保留 `minAudioSize = 380`（最小边长）与屏幕最大可用工作区钳制，杜绝几何死锁与高频振荡；
2. **平滑对齐与最大化保持**：
   - 维持双击顶栏铺满/还原时的 520x520 居中规格，保证纯音频播放器标准视图质感；
   - 评估在 `windowDidEndLiveResize` 中是否需以平滑动画对齐 1:1，或完全放开矩形视口。

---

## ISSUE-012: 置顶与微距拖拽抖动下全屏转场状态机单向死锁导致全屏入口永久假死

### 1. 缺陷现象
- 用户在特定时序操作下（如将播放窗口手动拉小、开启右上角图钉置顶、随后尝试双击播放画面进入全屏），播放器未能成功进入全屏；
- 此后全屏子系统陷入完全瘫痪状态：
  1. 双击播放界面：无任何响应；
  2. 点击右下角全屏按钮：无任何响应；
  3. 取消图钉置顶后再试：仍然无响应；
  4. 键盘快捷键 F / 回车 / Esc：均无响应；
  5. 与此同时，窗口左上角绿色红绿灯按钮铺满最大化功能保持正常；
  6. 退出播放器并重新启动后，双击全屏及右下角全屏按钮功能完全恢复。

### 2. 根因分析
1. **抢先置位与单向依赖**：
   - 在 [`PlayerCore.swift:1197-1206`](file:///Volumes/2T/Projects/SilkPlayer/SilkPlayer/Sources/SilkPlayer/PlayerCore.swift#L1197-L1206) 的 `toggleFullscreen()` 中，在调用 AppKit 原生 `window.toggleFullScreen(nil)` 之前，同步将 `isFullscreenTransitioning` 置为 `true`；
   - 该标志位的复位（恢复 `false`）100% 依赖 AppKit 代理事件的回调（`windowDidEnterFullScreen` / `windowDidExitFullScreen` / `windowDidFailToEnterFullScreen`）。
2. **系统底层静默丢弃转场请求**：
   - 当窗口处于置顶状态（`window.level = .floating`）叠加边框拖拽缩小，或双击时鼠标产生微小位移（> 3pt 触发 `window.performDrag` 抢占，产生系统警告 `Window move completed without beginning`）时，macOS WindowServer 在跨 Space 分配过程中静默忽略或丢弃了转场调用；
   - AppKit 未能启动动画，导致任何后续代理通知均未被系统触发。
3. **缺乏超时自愈机制 (Watchdog Missing)**：
   - 代码中无任何异步超时防御机制，`PlayerCore.isFullscreenTransitioning` 永久停留在 `true`；
   - 后续所有全屏调用均被入口首行 `guard !isFullscreenTransitioning else { return }` 静默拦截并丢弃；
   - 红绿灯走的是 `NSWindow.setFrame` 与 Delegate 独立变量，因而未受波及；重启应用则重新初始化了内存变量，死锁被物理重置。

### 3. 规划修复方案 (排期 v1.5.0)
1. **引入防御性看门狗超时机制**：
   - 在 `toggleFullscreen()` 抢先置位后启动 0.8s 异步超时安全任务，若系统未在阈值内回传转场完成/失败通知，强制重置 `isFullscreenTransitioning = false`，杜绝永久死锁；
2. **双击手势与微距拖拽防冲突**：
   - 在 `VideoView.mouseDragged` 中增加 `event.clickCount >= 2` 检测，在双击时屏蔽 `window.performDrag` 抢占；
3. **置顶浮动层级转场协同**：
   - 进入全屏前暂退为 `.normal` 层级，退出全屏后再自动恢复 `.floating`，消除 WindowServer 跨 Space 调度异常。

---

## ISSUE-013: 铺满最大化模式下按 Esc 键误触发退出播放而非缩回原窗口尺寸

### 1. 缺陷现象
- 当播放窗口处于**铺满最大化模式**（通过双击顶栏或点击绿色红绿灯按钮铺满屏幕可用工作区）时，按下键盘 `Esc` 键；
- **预期行为**：与双击红绿灯按钮或双击顶栏行为 100% 等价一致，平滑退出最大化，缩回原本的普通窗口尺寸，播放无缝继续；
- **实际行为**：当前按下 `Esc` 键直接触发了退出播放（等同于点击右上角 X 号关闭按钮），当前播放的视频被关闭并回到空白主页，严重破坏了用户的观影流。

### 2. 根因分析
1. **按键分级响应链条缺失中间层判定**：
   - 在 [`PlayerCore.swift:1550-1558`](file:///Volumes/2T/Projects/SilkPlayer/SilkPlayer/Sources/SilkPlayer/PlayerCore.swift#L1550-L1558) 的键盘事件处理中：
     ```swift
     case 53: // Escape
         if isPlaylistDrawerVisible || isInspectorVisible {
             isPlaylistDrawerVisible = false
             isInspectorVisible = false
         } else if isFullscreen {
             toggleFullscreen()
         } else {
             onEscapePressed?()
         }
         return nil
     ```
   - 该响应链条中只有两层保护：
     1. 第一层：关闭抽屉与属性面板；
     2. 第二层：退出原生 Space 全屏（`isFullscreen` 为 `true` 时）；
   - **完全缺失了“铺满最大化状态（Maximized）”的拦截分支**；
2. **底层降级直通终止播放回调**：
   - 在铺满最大化模式下，窗口虽占据了整个屏幕可用工作区，但因其属于窗口化平铺而非 macOS 独立 Space 全屏，`isFullscreen` 严格为 `false`；
   - 导致按键直接穿透进入 `else` 分支触发 `onEscapePressed?()`；
   - 而在 [`AppShellView.swift:325-327`](file:///Volumes/2T/Projects/SilkPlayer/SilkPlayer/Sources/SilkPlayer/App/AppShellView.swift#L325-L327) 中，`player.onEscapePressed` 直接绑定了 `stopPlayback()`，导致整场播放被直接销毁并退回主页。

### 3. 规划修复方案 (排期 v1.5.0)
1. **建立四级按键响应责任链**：
   - **层级 1 (抽屉/面板闭合优先)**: `isPlaylistDrawerVisible || isInspectorVisible` -> 关闭抽屉与面板，保持当前窗口与播放；
   - **层级 2 (原生 Space 全屏退出优先)**: `isFullscreen == true` -> 调用 `toggleFullscreen()` 退出独立全屏 Space；
   - **层级 3 (铺满最大化尺寸还原优先 · 核心补齐)**:
     - 判定窗口处于最大化状态（`delegate.currentInteractiveMode == .maximized` 或匹配屏幕可用尺寸）；
     - 调用 `PlayerWindowManager.shared.toggleMaximize(window: window)`，平滑缩回最大化前记录的 `savedPreZoomFrame`（原本普通尺寸），播放不中断；
   - **层级 4 (普通窗口退出播放基态)**: 处于常规普通窗口状态时 -> 触发 `onEscapePressed?()` 执行退出播放返回主页。


