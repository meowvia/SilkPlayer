# SilkPlayer 2.0.0 交付成果与技术归档 (Delivery Archive)

本文档归档 SilkPlayer 2.0.0 里程碑版本全量开发成果、技术架构、测试验证数据及交付资产。

---

## 1. 架构总览与双轨制模式

SilkPlayer 2.0.0 确立了统一版本号、双轨制能力交付的架构基准：
1. **单一版本号体系**:
   - 统一使用 `2.0.0`（杜绝 `-pro` 字符串后缀）；
   - 在应用内根据用户授权状态动态激活专业版能力集（社区免费模式 vs 专业增强模式）；
2. **前后端架构分离**:
   - **开源前端 (`SilkPlayer`)**: 遵循 LGPL-3.0，包含原生播放器视窗、标准 Controls、基础快捷键与播放列表；
   - **闭源内核 (`SilkCoreKit`)**: 自研 Metal 色彩映射引擎、局域网 SMB/NFS 索引引擎、独立折叠音乐模式与就地授权激活系统。

---

## 2. 核心实施成果清单

### 2.1 独立两段式折叠音乐模式视窗 (提案 024)
- **实现模块**: `SilkCoreKit/MusicMode/SilkMusicModeView.swift` & `SilkPlayer/Player/MusicModeView.swift`；
- **核心能力**:
  - 188pt 极简聚焦态与 420pt 展开列表态之间平滑折叠；
  - 物理仿真黑胶视图 (`FloatingVinylDiscView`) 配合 `AudioVisualizerHaloView` 动态声学光环；
  - 支持状态栏常驻微型播控与 Dock 栏静默隐匿 (提案 025)。

### 2.2 全新高质感「冰蓝」与四色主题矩阵 (提案 028)
- **实现模块**: `SilkCoreKit/Pro/SilkLibraryTheme.swift`、`SilkCoreKit/Pro/SilkProLibraryView.swift`、`SilkSettingsView.swift`；
- **核心能力**:
  - 基于原生 `behindWindow` 毛玻璃透光底板与深渊冷青渐变，主点缀色采用液态电光冰青（`#00DCFA`）；
  - 主标题对比度达 19.5:1，次级文本达 9.4:1，全面满足 WCAG AAA 顶级标准；
  - 支持深灰、冰蓝、暖白、青瓷 4 套视觉主题。

### 2.3 局域网 SMB / NFS 影视媒体库 (提案 017 & 029)
- **实现模块**: `SilkCoreKit/Pro/SilkProLibraryView.swift`、`SilkLANSourceManager.swift`；
- **核心能力**:
  - 原生支持 SMB 2/3、NFS 自动服务发现与远程挂载；
  - 多季剧集卡片智能聚合与在架切集抽屉（Season Switcher）；
  - 电影/剧集折叠分类卡片与 iCloud 进度云端同步。

### 2.4 全格式音频解复用与多声道软限幅
- **实现模块**: `SilkCoreKit/Engine/SilkAudioEngine.swift`、`SilkDemuxer.swift`、`Universal FFmpeg`；
- **核心能力**:
  - Universal FFmpeg 编入 `dts`、`dtshd`、`truehd`、`mlp` 完整编解码库；
  - 10MB 前置探测缓冲区彻底消除标准 PCM 假阳性误判；
  - `applySoftLimiter` 平滑软限幅器杜绝立体声下混 DAC 削顶爆音；
  - 离散 5.1 / 7.1 声道 Float32 LPCM 无损直通。

### 2.5 交互细节优化与社区 Issue 闭环
- **实现模块**: `PlayerHUDView.swift`、`PlayerScrubberView.swift`、`SilkUnifiedDrawerView.swift`、`AppShellView.swift`；
- **核心能力**:
  - 播放列表 ⌘F 即时搜索与拼音首字母过滤 (提案 022)；
  - 外挂字幕 Subs 子目录递归扫描 (提案 008)；
  - 影院级纯透明悬浮播控栏，移除深灰大底框 (提案 021)；
  - 起手快甩拖拽平滑跟手 (ISSUE-017)；
  - 多屏扩展全屏防光标唤醒 (ISSUE-021 / GitHub Issue #7)；
  - 竖屏短视频关闭后视窗横屏居中复位 (ISSUE-022 / GitHub Issue #9)；
  - 冷启动桌面平铺隔离 (ISSUE-018)。

### 2.6 媒体库单行紧凑重构、继续观看微交互与批量运维闭环
- **实现模块**: `SilkCoreKit/Pro/SilkProLibraryView.swift`、`SilkCoreKit/Shared/SilkCoreUIShared.swift`、`SilkMetadataScraperService.swift`；
- **核心能力**:
  - 顶栏单行化与历史冗余清理：彻底移除第一行 Scope 过滤条（全部/电影/剧集/未看/继续观看），将动态题材流（首标签更名为【全部】）与右侧排序菜单、片源总数统计合并为单行紧凑工具栏，回收 36pt 垂直可视空间；
  - 继续观看微交互联动：日常态悬停在单卡右上角显示微透 `✕` 按钮一键移出续播，批量管理模式下显示选择勾选框支持多选；
  - 批量管理运维扩展与安全防呆：底部浮动条补齐「重置进度」、「移出媒体库（仅删索引）」与「删除源文件…（警示红 + 废纸篓二次确认弹窗）」；
  - 双击红绿灯栏窗口最大化与恢复：顶栏拖拽基底注入双击事件触发 `window?.zoom(nil)`；
  - Cloudflare Pages 边缘网关集成：生产端点 `https://silkplayer.com/api/tmdb` 与 `/api/poster` 免代理直连反代与 30 天边缘强缓存。

### 2.7 沉浸式影片详情页、微型快播重构、iCloud 跨设备同步控制与偏好滚动修复
- **实现模块**: `SilkCoreKit/Pro/SilkMediaDetailView.swift`、`SilkCoreKit/Pro/SilkProLibraryView.swift`、`SilkCoreKit/Pro/SilkCloudSyncService.swift`、`SilkPlayer/Settings/SilkSettingsView.swift`、`SilkPlayer/Settings/AppSettings.swift`；
- **核心能力**:
  - 沉浸式电影详情页闭环：构建 `SilkMediaDetailView`，支持毛玻璃背景环境光照、2:3 高清海报立体投影、TMDB 评分与剧情长简介、音画规格徽章（4K/HDR10/DV/音频声道/文件体积），提供【立即/继续播放】、【从头播放】与 ESC/返回按键路由；
  - 海报卡片悬停交互重构：移除卡片中央大播放按钮，悬停呈现轻微上浮（-2.5pt）与光影过渡；单击卡片进入详情页，右上角悬浮 24x24 半透明微型播放键实现单点直播，保留双击直接起播；
  - iCloud 跨设备同步知情权与控制权：在「设置 → 局域网」新增「iCloud 跨设备播放同步」开关与「清空云端…」擦除动作，彻底消除云端静默重现数据的困惑；
  - 偏好设置播放页零滚动优化：微调行高（28pt/27pt）与内边距，使播放设置 10 项控制项在 490pt 标准窗口内 100% 完整可视，彻底消除纵向滚动条。

### 2.8 媒体库全生命周期性能优化落地（海报缓存预算、环境光降采样、SQLite 页缓存主动释放）
- **实现模块**: `SilkCoreKit/Pro/SilkProLibraryView.swift`、`SilkCoreKit/Pro/SilkMediaDetailView.swift`、`SilkCoreKit/Pro/SilkMediaLibraryEngine.swift`、`SilkPlayer/App/AppShellView.swift`；
- **核心能力**:
  - 海报缓存硬性配额管控：为 `SilkPosterCache` 注入 `countLimit = 250` 与 `totalCostLimit = 120MB` 硬性预算上限，并在网络缓存加载、本地图片解码全链路计算真实像素字节开销（`width * height * 4`），消除大库海量海报滚动内存无上限累积隐患；
  - 环境光模糊底板次采样降噪：在 `SilkMediaDetailView` 详情背景毛玻璃绘制中，将海报纹理强制以 120px 硬件降采样后送入高斯模糊管线，纹理显存消耗降低 90% 以上，彻底根除高分辨率位图全屏模糊导致的瞬时 GPU 计算峰值；
  - SQLite 页缓存与 Lookaside 主动释放：在 `SilkLibraryDatabase` 增加 `shrinkMemory()`，并在全量/增量扫库完成、关闭播放返回媒体库生命周期事件中主动触发 `sqlite3_db_cacheflush` 与 `PRAGMA shrink_memory;`，主动归还 10~25MB 驻留内存给系统；
  - 静态视窗零 GPU 损耗审计确认：验证播放器停止与视窗切换生命周期，Metal 渲染管线 `playerLayer` 在退出播放时彻底解除并销毁，媒体库静态浏览与详情页常驻态维持 0% GPU 损耗与极低 CPU 负载（<0.5%）。

### 2.9 媒体库详情交互重构、自适应窗口与返回交互闭环
- **实现模块**: `SilkCoreKit/Pro/SilkMediaDetailView.swift`、`SilkCoreKit/Pro/SilkMediaLibraryEngine.swift`、`SilkCoreKit/Pro/SilkProLibraryView.swift`、`SilkPlayer/App/AppShellView.swift`、`SilkPlayer/PlayerHUDView.swift`、`SilkPlayer/HUD/HUDControlButtons.swift`；
- **核心能力**:
  - 剧集网格架构重构与彩虹圈 Hang 彻底根除：废除行内抽屉与嵌套动态行，全面迁移为虚拟化原生 `LazyVGrid`，彻底杜绝连续点击触发 SwiftUI `StackLayout` 递归死锁；
  - 媒体库详情双栏响应式布局与智能推荐引擎：实现左侧 2/3 详情（海报、规格、剧情简介、选集网格）+ 右侧 1/3「你可能还喜欢」智能关联推荐（融合流派 Jaccard、历史偏好、系列作关联、评分年代等多维加权算法，稳定推荐 6-8 部）；
  - 剧集选集播放卡片体验升级：将选集微型按钮解耦升级为 30×30 pt 独立高对比度圆形播放按键，单击即播，双击卡片任意区域直达起播；
  - 播放器与媒体库物理层级完全解耦：废除播放中常驻底层媒体库的 `ZStack` 冲突设计，恢复 `if isPlaying` 互斥挂载，播放视频时窗口 100% 独占给视频渲染，彻底恢复 `applyAdaptiveWindowGeometry()` 窗口比例原生自适应，消除左右异常立柱黑边；
  - 数据层状态驱动详情页还原：在 `SilkMediaLibraryEngine` 维护 `activeDetailPath`，播放结束退出后自动干净重载详情页，避免 View 偏移错位与白屏 Bug，并实时同步最新播放进度；
  - 播放器右上角退出交互优化：彻底移除容易混淆的微型 `✕` 圆形按钮（杜绝误触 macOS 红色关闭灯退出整个 App），原位替换为高质感毛玻璃 `[ ‹ 返回 ]` 胶囊按钮，左上角保持格式信息清爽通透。

### 2.10 交互体验深度调优与全屏手势收拢
- **实现模块**: `SilkCoreKit/Pro/SilkMediaDetailView.swift`、`SilkCoreKit/Pro/SilkProLibraryView.swift`、`SilkPlayer/Player/PlayerContainerView.swift`、`SilkPlayer/VideoView.swift`；
- **核心能力**:
  - 详情页顶栏控件去冗余：移除影片/剧集详情页右上角冗余的圆形 `x` 关闭按钮，仅保留左侧层级明确的 `[ ‹ 返回媒体库 ]` 药丸胶囊与全局 ESC 快捷键，消除双向视线干扰；
  - 智能推荐算法去自身片源污染：重构候选集预过滤逻辑，当前条目为剧集时严格排除同剧集名称的所有分集，当前条目为电影时严格排除同名及相同 TMDB ID 的同源条目，确保推荐列表 100% 为异源影片；
  - 全屏播放列表交互防误触与纯手动收拢：彻底废除全屏模式下右边缘 28pt 隐形 Hover 感应区及侧拉手悬停自动展开机制，恢复与窗口化完全一致的手动交互规范，杜绝光标移向右上角点击「‹ 返回」时误触发列表弹开；
  - 抽屉外部点击优先收回且绝对防穿透：当播放列表或检查器处于展开状态时，无论当前正在播放还是暂停，点击画面空白视口的首要特权 100% 锁定为“关闭抽屉”，`mouseUp` 精准拦截该次点击事件，严禁穿透触发 `togglePlayPause()`；
  - 媒体库首页「继续观看」方案 A 落地：横向滚动视图注入双侧渐变羽化遮罩（Mask），消除窗口缩小时卡片的物理硬截断感；卡片升级为带 34×48pt 微缩海报、片名/剧集小标题、悬停播放覆盖与微进度条的流体圆角卡片，完美融入媒体库整体质感，海报墙本体坚决不挂载播放进度条；
  - 触控板交互 Apple HIG 原生标准对齐：核实确认 macOS 原生进度条基于单指按压/轻点拖拽及辅助功能三指拖移规范（`DragGesture`），双指滑动仅作为视口级平滑快进/快退手势，保持系统级纯粹原生规范。

### 2.11 多主题一致性收拢、详情防穿透、按键防误杀与本地 .NFO 引擎落地
- **实现模块**: `SilkCoreKit/Pro/SilkLibraryTheme.swift`、`SilkCoreKit/Pro/SilkMediaDetailView.swift`、`SilkCoreKit/Pro/SilkMusicModeView.swift`、`SilkCoreKit/Shared/SilkCoreUIShared.swift`、`SilkCoreKit/Pro/SilkNFOParser.swift`、`SilkCoreKit/Pro/SilkMediaLibraryEngine.swift`、`SilkPlayer/App/PlayerWindowManager.swift`、`SilkPlayer/App/AppShellView.swift`、`SilkPlayer/HUD/PlayerScrubberView.swift`；
- **核心能力**:
  - 详情页不透明基底与防穿透：在 `SilkLibraryTheme` 新增 `solidBackgroundBase`，在 `SilkMediaDetailView` 根节点、全屏环境光底板及模态弹窗注入 100% 遮罩基底，彻底阻断冰蓝等半透明主题下媒体库海报穿透显现；
  - 青瓷浅色主题全链路修复：`SilkMusicModeView` 与 `PlayerScrubberView` 判断统一收口为 `isLightTheme`，青瓷主题进入音乐模式与进度条正确呈现松绿强调色与浅底暗字；
  - AppKit 模态弹窗焦点框抑制器：实现底层 `SilkSheetFocusRingSuppressor`（`NSViewRepresentable`），挂载弹窗时将 `window.initialFirstResponder` 置空并递归将所有子视图 `focusRingType` 置为 `.none`，彻底消除局域网挂载等弹窗弹出时右上角取消按钮的系统默认蓝色高亮框；
  - 快捷键速查表与偏好设置外观联动：`ShortcutsCheatsheetView` 移除硬编码系统蓝，注入主题 `accentColor` 与 `effectiveNSAppearance`；设置页文本色收口为 `primaryTextColor` / `secondaryTextColor` 并对齐强调色；
  - 详情页「从头播放」按钮修复：`SilkMediaDetailView.onPlay` 增加 `forceFromBeginning: Bool` 参数，点击从头播放时强制重置 `resumeTime = 0.0` 并调用 `AppSettings.shared.savePosition(position: 0)` 清除本地断点缓存；
  - 详情页 Esc 与 Space 全局拦截放行：`PlayerWindowManager.setupGlobalKeyMonitor()` 在 `activeDetailPath != nil` 时直接放行 Space 与 Esc，`SilkMediaDetailView` 挂载 `@FocusState` 与聚焦捕获，使空格起播与 Esc 关闭详情稳定生效；
  - 后台听歌外部双击视频恢复 Dock 栏：`PlayerWindowManager.openExternalFiles` 与 `requestNewWindow` 在唤起视窗时检测后台听歌态，自动触发 `SilkStatusBarManager.shared.exitBackgroundMode()` 恢复 `.regular` 激活策略与 Dock / Cmd+Tab 呈现；
  - 弹窗与详情页 Cmd+W 防误杀：重构 `closePlaybackOrReturnToEmpty()` 执行顺序，优先检测活动窗口 `attachedSheet` 并分发 `cancelOperation:` 关闭弹窗，次级检测详情页并退出返回海报墙，绝不误杀主窗口；
  - 海报卡片手势冲突消除：移除卡片上的 `count: 2` 双击手势，卡片仅保留即时响应的单击操作（进详情或批量勾选），消除 300~400ms 固有双击判定卡顿，批量连点不再被吞；起播统一由右上角悬浮播放按键承接；
  - 本地 .NFO 元数据解析引擎：构建轻量宽松 XML 解析器 `SilkNFOParser`（兼容 Kodi / Jellyfin / Emby / TinyMediaManager 规范），扫库时自动关联 `<stem>.nfo`、`movie.nfo`、`tvshow.nfo`，将剧情简介、年代、评分、标签等直接沉淀入 SQLite，实现无网络无 API Key 环境下海报与详情的完整呈现。

### 2.12 免费版纯音频基准（100% 继承 1.7.0）与 Pro 独立音乐模式彻底解耦
- **实现模块**: `SilkPlayer/PlayerModels.swift`、`SilkPlayer/PlayerCore.swift`、`SilkPlayer/Player/PlayerCore+WindowGeometry.swift`、`SilkPlayer/App/PlayerWindowManager.swift`、`SilkPlayer/Player/PlayerContainerView.swift`、`SilkPlayer/App/PlayerCommands.swift`；
- **核心能力**:
  - **显式播放呈现状态机**: 引入 `PlaybackPresentationMode` (`.idle`, `.video`, `.standardAudio`, `.proMusic`) 与 `isProMusicModeActive` 统一判定源，严禁在全局散落裸用 `isAudioOnly` 触发 Pro 音乐模式逻辑；
  - **视窗几何与拖拽缩放解耦**: 免费版纯音频模式 100% 继承 1.7.0 几何策略（`inLiveResize` 双轴自由平滑放行，最小 380×380，非拖拽 1:1 等比吸附；彻底切断 520pt 强制锁宽与磁吸高度拦截，杜绝边框回弹抖动）；
  - **播放列表抽屉交互完全恢复**: 免费版音频播放全面放行右侧边框悬浮抽屉拉手（`<`）、快捷键 `P` 与 `⌘P`，绝不因音频模式被屏蔽拦截；
  - **界面纯净与零侵入**: 唱盘视图恢复 1.7.0 纯净黑胶与标题排版，移除临时入侵性胶囊控件；HUD 顶栏剔除误放的 Pro 状态栏按钮；画布空白处单击直接响应播放/暂停。

---

## 3. 验证与构建交付资产

- **版本号**: `2.0.0`
- **芯片架构**: Universal Binary (`arm64` + `x86_64`)
- **发布镜像物理路径**:
  `/Volumes/2T/Projects/SilkPlayer/SilkPlayer/build/SilkPlayer-2.0.0-universal.dmg`
- **SHA-256 校验和**: `f593aec2ff77d2471f01c21857b480ec3da1e689ee29fc836b9bac7b583b7020`
- **动态库依赖审计**: `@rpath` 依赖审计 100% 通过（无宿主绝对路径泄漏）；
- **代码签名**: Ad-hoc 深度代码签名校验通过。

### 3.1 官方开发与测试激活凭据 (Official Dev Test License Key)
- **凭据格式**: Ed25519 签名离线令牌 (`SILK1` 规范)
- **绑定硬件指纹**: `bd8cae35ac6eb3d8a0b50bf112f30eeb` (当前 Mac Mini 管理机 `IOPlatformUUID` SHA-256 指纹)
- **授权方案**: `SilkPlayer Pro` 永久买断版（`maxDevices: 3`, `deviceCount: 1`, 无过期限制）
- **KeyId / 掩码**: `dev_local_20261112` / `SILK-PRO1-TEST-DEV`
- **官方测试激活码原文**:
```
SILK1.eyJodyI6ImJkOGNhZTM1YWM2ZWIzZDhhMGI1MGJmMTEyZjMwZWViIiwidiI6MSwicGxhbiI6IlNpbGtQbGF5ZXIgUHJvIiwia2V5SWQiOiJkZXZfbG9jYWxfMjAyNjExMTIiLCJtYXNrIjoiU0lMSy1QUk8xLVRFU1QtREVWIiwiZGV2aWNlQ291bnQiOjEsIm1heERldmljZXMiOjMsImlhdCI6MTc5NDQ1Njc3OC45Mjc5MDF9.IFgrwR2JzHdZFVxxAbBDWnZjoIEnBGHcua2h1uQFImvI33N065zPOSnOvQiuo9nlb_0NFFkaCHVQMxnVMUN5Cw
```

