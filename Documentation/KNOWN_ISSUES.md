# SilkPlayer 已知问题与缺陷追踪 (Known Issues & Bug Tracker)

本文档为 SilkPlayer 项目缺陷定点追踪记录表，用于规范登记用户报障、测试复现与内部发现的缺陷。

---

## 缺陷索引表 (Issue Index)

| 缺陷编号 | 缺陷摘要 | 影响模式 / 模块 | 严重程度 | 当前状态 | 发现版本 |
| :--- | :--- | :--- | :--- | :--- | :--- |
| ISSUE-001 | 音频模式下倍速播放未生效 | 纯音频播放 / SilkCoreKit (SilkAudioEngine) | Medium | 已修复 (v1.2.0-dev) | v1.1.0 |
| ISSUE-002 | 随机播放无记忆抽样与近距离高频重播缺陷 | 播放列表与音频随机 / SilkPlayer (PlaylistManager) | Medium | 已修复 (v1.2.0-dev) | v1.1.0 |
| ISSUE-003 | 音频模式窗口适配不良与垂直重叠穿模 | 界面布局 / SilkPlayer (AudioArtworkView & PlayerHUDView) | Medium | 已修复 (v1.2.0-dev) | v1.1.0 |
| ISSUE-004 | 窗口几何与交互管理架构碎片化（改此失彼顽疾） | 核心架构 / PlayerWindowManager & WindowGeometry | High | 核心病灶已解除 (v1.2.0-dev) | v1.1.0 |
| ISSUE-005 | 视频窗口被物理完全遮挡时 Metal 阻塞导致音频断流 | 渲染与解复用 / SilkCoreKit (SilkMetalRenderView & Engine) | Low | 已修复 (v1.2.0-dev) | v1.1.0 |
| ISSUE-006 | 局域网 SMB / 外置存储极窄缓冲导致偶发丢帧 PPT 与音画失步 | 引擎解复用与同步 / SilkCoreKit (SilkPlayerEngine) | Medium | 已修复 (v1.2.0-dev) | v1.1.0 |

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

#### 3.3 交付验证结果
1. 在 `/Volumes/2T/Projects/SilkCoreKit` 重新构建 `SilkCoreKit.xcframework`；
2. 同步二进制至 `/Volumes/2T/Projects/SilkPlayer/Packages` 并运行 52 项自动化回归测试套件全量通过；
3. AudioQueue 配置 TimePitch 算法，0.25x~4.0x 变速保调正常生效。

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

### 3. 下个版本优化方案 (参考行业成熟洗牌机制)

#### 3.1 引入 Fisher-Yates 洗牌序列队列 (Shuffled Queue Cycle)
1. 切换至随机播放或当前轮次全部耗尽时，基于当前歌单生成一个完整的 Fisher-Yates 打乱索引序列；
2. 确保洗牌序列的第一首不与刚刚正在播放的最后一首相连；
3. 播放器严格沿着该序列推进下一曲，确保整个歌单的 $N$ 首歌曲必须且仅被播放一次；
4. 序列全部消费完毕后，自动触发下一轮全新洗牌（无缝重排且边界防重）。

#### 3.2 建立播放历史栈 (History Backstack)
1. 维护 `private var playHistory: [Int] = []`；
2. `moveToNext()` 与 `handleNaturalEOF()` 将当前索引压入历史栈；
3. `moveToPrevious()` 从历史栈弹出并精准回跳至上一首听过的真实曲目，同时令 `previousItem` 返回历史栈顶元素。

#### 3.3 交付与回归验证
1. 在 `PlaylistTests.swift` 中补充针对随机洗牌周期无重复性、相邻防重与上一曲精准回跳的历史栈单元测试；
2. 验证与现有 `upcomingItem` 提前 0ms 预取和下一曲指示器的完美对齐；
3. 修复在 SwiftUI `@Observable` 视图求值期间调用 `upcomingItem` 误触发 `ensureShuffleCandidate()` 导致的死循环重绘卡死，确立 `upcomingItem` 纯只读幂等属性。

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

### 3. 下个版本优化方案 (计划实施路径)

#### 3.1 底部 HUD 安全区解耦与避让
1. 在 `AudioArtworkView` 容器底部显式施加 `padding(.bottom, 90)`（或动态传入底部 HUD 实际高度），使黑胶盘体、歌名与下一曲整体在“HUD 之上的安全视口”内居中呈现；
2. 进度条与歌名彻底分离，歌名悬浮于进度条上方并保持清晰的安全间距（建议 16pt+）。

#### 3.2 黑胶与光冕直径多维自适应缩放
1. 黑胶直径由原来的固定宽度约束改造为宽高双维自适应：
   `diameter = min(geometry.size.width * 0.45, (geometry.size.height - hudHeight) * 0.55, 260)`；
2. 在窗口偏矮时黑胶自动按比例缩小，确保歌名、下一首、进度条层次分明。

#### 3.3 音频模式专属窗口比例与最小尺寸门禁
1. 进入纯音频模式时，提供专用的优雅默认尺寸（如 `580 × 460`，更接近唱片机方形质感）；
2. 设置音频模式最小窗口保护（如 `minWidth: 460, minHeight: 380`），防止极限扁平时内容被切掉。

---

## ISSUE-004: 窗口几何与交互管理架构碎片化（“改此失彼”顽疾剖析与统一状态机重构纲领）

### 1. 深度反思：为什么窗口交互一直处于“改这里、丢那里”的恶性循环？

回顾项目演进历史，窗口系统经历了多轮分散修补：
1. 为了支持竖屏视频旋转，增加了朝向尺寸记忆逻辑；
2. 为了支持 macOS 15 Sequoia 分屏平铺，在 `windowWillResize` 中增加了容差启发式分支；
3. 为了防止 Dock 栏遮挡与全屏贴边，增加了边界夹紧限制；
4. 为了支持纯音频播放，临时增加了 1:1 等比正方形缩放拦截与尺寸保护；
5. 为了消除切歌时的黑屏闪烁，又打上了状态保留补丁。

**核心问题**：
每一次修改都是“针对单一症状打局部补丁”，没有从根源上建立一套严密的、数学自洽的**单一窗口几何状态机（Single Window Geometry State Machine）**。这种“头痛医头、脚痛医脚”的补丁式治理，必然导致修好 A 的同时踩碎 B，顾及了 C 却丢掉了 D，严重透支了稳定性与用户信任。

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
`transition(to newState: WindowPresentationState, animated: Bool)`，原子级完成窗口尺寸、比例锁、最小尺寸与安全区的同步切换。

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

### 4. 第三方深度协同落地机制 (Collaborative Execution Framework)

依据用户指令，播放窗口顽疾正式确立“**第三方出谋划策把脉开方 + 本地 AI 交叉评估落地主刀**”的协同推进机制：

1. **方案输入与对齐**：
   第三方提供具体修改方案后，全量导入进行交叉比对；
2. **可行性审计报告**：
   本地 AI 结合 Swift 6 严格并发契约、AppKit / Metal 线程安全约束、物理架构隔离红线及 52 项回归测试套件进行逐行推演，输出审计与微调建议；
3. **分层定点落地**：
   - 内核层修复：涉及 Seek 线程与 Metal 渲染竞态的逻辑，严格在 `/Volumes/2T/SilkCoreKit` 独立修改并重新构建 `SilkCoreKit.xcframework`；
   - 前端层重构：移除 `AppShellView.swift` 中的 `.frame(minWidth: 640)`，实现 `WindowGeometryCoordinator` 单一仲裁器与 `WindowPresentationState` 状态重放机制；
4. **自动化回归与实机闭环**：
   本地运行 `./scripts/run_tests.sh` 确保 52 项不变量测试 100% 满血绿勾通过，绝不留死角。

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

### 3. 下个版本修复方案 (Planned for Next Release)
- **内核层修复 (SilkCoreKit)**：
  1. 在 `SilkMetalRenderView.render` 顶部加入窗口遮挡状态守卫：
     ```swift
     if let window = self.window, !window.occlusionState.contains(.visible) {
         return // 窗口完全被遮挡时跳过 Metal 提交，避免 nextDrawable 阻塞
     }
     ```
  2. 在 `SilkPlayerEngine` 的 `videoLoop` 中，若检测到窗口完全不可见，保持时间戳基准推进并以丢弃渲染模式消费 `videoPacketQueue`，确保解复用器持续读取音频数据；
- **交付排期**：
  已在内核版本 v1.2.0 (`SilkCoreKit`) 完成修复并导出部署，通过 52 项回归测试。

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

### 3. 修复方案设计与技术路径 (Planned for Next Release)
- **内核层优化 (SilkCoreKit)**：
  1. **引入向前预读大缓冲区 (Buffer Ahead)**：
     - 将网络流媒体与外挂磁盘的视频包队列从 24 包（1.0 秒）放宽至 **120~240 包（5~10 秒缓冲）**；
     - 4K HEVC 压缩包 10 秒仅占用约 5~30MB 内存，对 Mac 毫无负担，能 100% 熨平局域网协议抖动与机械硬盘寻道停顿；
  2. **废除暴力丢帧，引入平滑微调变速追赶 (Rate Shifting)**：
     - 当视频落后音频 40~150ms 时，不再粗暴丢弃画面，而是采用人耳无法感知的微调变速（如 1.05x 播放速率或帧呈现间隔阻尼调整）平滑追赶时钟；
  3. **预加载状态指示 (Buffer Health Indicator)**：
     - 在 HUD 进度条底层支持显示灰色缓冲加载条，让网络加载状态直观可感知。
- **交付排期**：已在内核版本 v1.2.0 (`SilkCoreKit`) 完成缓冲池拓宽至 180 包与平滑同步优化，通过 52 项回归测试。
