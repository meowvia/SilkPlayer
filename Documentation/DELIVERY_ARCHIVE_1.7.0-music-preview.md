# SilkPlayer 1.7.0-music-preview 阶段交付与未决问题归档 (Preview Delivery Archive)

本文档归档分支 `feature/music-mode-revamp` 在 `1.7.0-music-preview` 预览阶段已完成的代码改动、自动化测试与实机构建结果。根据产品规划，`feature/music-mode-revamp` 分支当前暂定冻结于本预览基线，**不随 `1.6.0–1.9.0` 版本部署更新，初步拟定于 `2.0.0` 发布**（状态栏常驻入口构想已归档至 `Documentation/FEATURE_PROPOSALS.md` 提案 `025`）。

---

## 1. 工程基准与预览构建资产

- **开源前端 (`SilkPlayer`)**:
  - 本地路径: `/Volumes/2T/Projects/SilkPlayer/SilkPlayer`
  - 分支: `feature/music-mode-revamp`
  - 最新 Commit: `786ee5230b314a0cfcec2ee3b9e0cc264ba52cbc`（工作区含未提交修改，详见第 2 节）
- **闭源内核 (`SilkCoreKit`)**:
  - 本地路径: `/Volumes/2T/Projects/SilkPlayer/SilkCoreKit`
  - 分支: `main`
  - 最新 Commit: `1e49d6f59141a3eca140f31b896e68c1ef5eec36`（当前工作区干净，未在本阶段改动）
- **提交作者标准**: `meowvia <meowvia@users.noreply.github.com>`
- **预览构建产物 (`--app-only` 单架构本地预览版，未生成发布级 Universal DMG)**:
  - 应用包路径: `/Volumes/2T/Projects/SilkPlayer/SilkPlayer/build/SilkPlayer.app`
  - 本机安装路径: `/Applications/SilkPlayer.app`
  - 可执行文件 SHA-256 (`Contents/MacOS/SilkPlayer`): `d1c11c8882a1386ae4e2c2e292e358f8110b4ebe4495d4bcd449faa337c0cdbb`
  - 动态库依赖审计 (`@rpath`): 通过（所有动态库严格限定在 `@rpath` 或系统框架，无宿主绝对路径泄漏，`SilkCoreKit.framework` 静态链接入可执行文件）
  - 代码签名校验: Ad-hoc 签名通过（`valid on disk`，`satisfies its Designated Requirement`）
  - 备注: 使用 `./scripts/package_app.sh 1.7.0-music-preview arm64 --app-only` 构建，当前安装包内 `Info.plist` 的 `CFBundleShortVersionString` 仍保持 `1.6.0`；正式发版前需补齐版本号更新与 Universal DMG 打包流程。

---

## 2. 本阶段实施内容与未提交工作区变更

自 Commit `786ee52` 起，以下 14 个代码/测试文件及配套文档已在工作区完成修改并通过编译与单元测试（视频模式原生全屏、平铺与缩放行为保持不变）：

1. **音乐模式紧凑收起尺寸与磁吸阈值调整**
   - 文件: `Sources/SilkPlayer/Player/MusicModeGeometry.swift`、`Sources/SilkPlayer/App/PlayerWindowManager.swift`、`Tests/SilkPlayerTests/MusicModeTests.swift`
   - 变更: 将收起态高度由 `290/300 pt` 下调至 `collapsedStandardHeight = 224.0`、`collapsedExtendedHeight = 232.0`；折叠/展开拖拽阈值调整为 `370.0 / 330.0`，反向拖拽滞回阈值调整为 `280.0 / 420.0`。

2. **进度条悬停预览卡片隔离 (`PlayerScrubberView`)**
   - 文件: `Sources/SilkPlayer/HUD/PlayerScrubberView.swift`、`Sources/SilkPlayer/Player/MusicModeView.swift`
   - 变更: 为 `PlayerProgressSection` 与 `PlayerScrubberView` 增加 `showsHoverPreview: Bool = true` 与 `compactScrubberHeight: CGFloat? = nil` 默认参数；音乐模式下传入 `showsHoverPreview: false` 与 `compactScrubberHeight: isCollapsed ? 18 : 20`，消除进度条悬停视频缩略图预览及无效缩略图请求，视频模式默认行为保持不变。

3. **音乐模式纵向拉伸尺寸比例 HUD 禁用 (`PlayerWindowManager`)**
   - 文件: `Sources/SilkPlayer/App/PlayerWindowManager.swift`
   - 变更: 在 `PlayerWindowDelegate` 新增 `shouldShowResizeDimensionHUD(isAudioOnly:)`（返回 `!isAudioOnly`），仅在纯音频模式下于 `windowWillStartLiveResize` 与 `updateResizeHUD` 隐藏 `WindowResizeDimensionHUD`，视频模式保持开启。

4. **半透明 Liquid Glass 背景、4pt 顶部缝隙修复与跨边框 Notch 居中**
   - 文件: `Sources/SilkPlayer/Player/MusicModeView.swift`、`Sources/SilkPlayer/App/AppShellView.swift`
   - 变更:
     - `AppShellView.rootMinHeight` 在 `player.isAudioOnly` 分支由 `max(200, collapsedStandardHeight - 40)` 调整为 `140.0`；
     - `musicBackgroundLayer` 由内层 `ZStack` 移至外层 `GeometryReader` 的 `.background { musicBackgroundLayer }`，补充 `.frame(maxWidth: .infinity, maxHeight: .infinity).ignoresSafeArea(.all)` 并移除 `RoundedRectangle(cornerRadius: 10).strokeBorder(...)`；
     - 将 `MusicQueueBorderNotch`（`28×7 pt` 圆角胶囊配 `7.5×3.5 pt` 三角 `MusicNotchTriangle`）在 `heroCard` 底边与 `queueSectionCard` 顶边的对齐方式由固定 `.offset(y: ±3.5)` 改为 `.alignmentGuide(.bottom/.top) { d in d[VerticalAlignment.center] }`；
     - 将 `MusicWindowDragCanvas` 铺设于根视图（保留顶部与底部 `6.0 pt` 纵向调整热区）以及 `topChromeBar`、`heroCard`、`bottomControlSection` 的空白交互背景中。

5. **顶栏右上角按钮精简与退出高度闭环 (`ISSUE-015`, `ISSUE-016`)**
   - 文件: `Sources/SilkPlayer/Player/MusicModeView.swift`、`Sources/SilkPlayer/App/AppDelegate.swift`、`Sources/SilkPlayer/App/PlayerWindowManager.swift`、`Tests/SilkPlayerTests/MusicModeTests.swift`
   - 变更:
     - 音乐模式顶栏保留置顶 (`pin`) 与退出回主页 (`xmark`) 按钮，移除 `info.circle` 按钮；取消点击置顶触发的 `showOSD` 与 `MusicCircleIconButton` 悬停提示，消除对歌名及音频格式胶囊的遮挡；
     - 音乐模式底栏上一曲/下一曲按钮悬停提示由完整曲名收拢为标准文案（`上一首 (Cmd+Left)` / `下一首 (Cmd+Right)` 等精简状态文案），避免长曲名撑宽气泡造成遮挡，视频模式保持不变；
     - `AppDelegate` 退出与 `PlayerWindowDelegate.windowWillClose` 统一调用 `player.stop(resetUI: false, preserveAudioMode: true)`，阻止关闭前将 `isAudioOnly` 复位导致 `rootMinHeight` 回弹至 `200 + 28 = 228 pt`。

6. **收起态底部折叠槽对齐与长副标题间距修复 (`MusicModeView`)**
   - 文件: `Sources/SilkPlayer/Player/MusicModeView.swift`
   - 变更: 将 `if isCollapsed` 包裹于 `Group` 内并在外层直接挂接 `.alignmentGuide(.bottom) { d in d[VerticalAlignment.center] - 2.5 }`，避免 SwiftUI `_ConditionalContent` 吞掉对齐引导线导致折叠槽内陷；同时收紧收起态 `heroCard` 中间栏间距（`spacing: 2.5`、`.padding(.vertical, 1)`、`top: 8 / bottom: 9`）及 `MusicQueueBorderNotch` 热区高度（`15 pt`），在长歌手/专辑副标题下保留约 `15 pt` 净空。

7. **随机播放加权冷却、重排保序与状态持久化 (`PlaylistManager`)**
   - 文件: `Sources/SilkPlayer/Playlist/PlaylistManager.swift`、`Sources/SilkPlayer/App/PlayerWindowManager.swift`、`Sources/SilkPlayer/App/AppShellView.swift`、`Sources/SilkPlayer/App/AppDelegate.swift`、`Sources/SilkPlayer/Settings/AppSettings.swift`、`Tests/SilkPlayerTests/MusicModeTests.swift`
   - 变更:
     - 引入 `weightedShuffledIndices(from:)`（无放回 Efraimidis-Spirakis 加权随机置换），在滑动冷却窗口 `min(N-2, max(1, min(N/2, 100)))` 内对最近播放或手动选曲按四次方衰减权重压制（最低 `0.0005`），对同路径重复项施加 `0.0002` 权重，并对最近 `min(4, count - 1)` 曲执行头部防立即回头保护；
     - 在 `selectIndex(_:)` 手动切歌干预时记录切离曲目与新选曲目路径，并对剩余 `currentShuffleQueue` 重新按加权冷却重排；
     - 为 `sortAudioItems` 与 `moveAudioItem` 增加 `remapIndexSequence` / `finalizeAudioReorder` 索引映射，重排或拖动队列时保留 `audioShuffleQueue` 与播放历史，不再重置随机周期；
     - 在 `saveToStorage()` / `restoreFromStorage()` / `clearStorage()` 中按音视频分类与统一队列持久化 UUID 映射后的洗牌队列、播放历史及最近播放路径序列（上限 `500` 条），并通过 `PlayerWindowSession.playlist` 与 `AppDelegate.persistActiveSessionsBeforeExit()` 在退出前落盘、修复 `AppSettings.dualPlaylistMode` 避免覆盖窗口独立播放状态；
     - 新增 5 项 `@MainActor` 单元测试覆盖整周期不重复、手动切歌冷却与防回头、排序/移动保序、冷重启恢复及同路径去重冷却。

8. **音乐模式窗口防平铺最大化与折叠态高度自愈 (`PlayerCore+WindowGeometry`, `MusicModeView`, `PlayerWindowManager`)**
   - 文件: `Sources/SilkPlayer/PlayerCore.swift`、`Sources/SilkPlayer/Player/PlayerCore+WindowGeometry.swift`、`Sources/SilkPlayer/Player/MusicModeView.swift`、`Sources/SilkPlayer/App/AppShellView.swift`、`Sources/SilkPlayer/App/PlayerWindowManager.swift`、`Tests/SilkPlayerTests/MusicModeTests.swift`
   - 变更:
     - `configureMusicModeChrome(on:)` 在 `macOS 15.0+` 下为 `collectionBehavior` 注入 `.fullScreenDisallowsTiling`，并在退出音乐模式进入视频/首页时通过 `restoreStandardWindowChrome(on:)` 恢复标准集合行为；
     - `PlayerWindowDelegate.windowWillResize` 将 `player?.isAudioOnly == true` 判断提前至 `frameSize == screenFrame.size` 等屏幕铺满旁路之前，阻止系统尺寸重置或异常拉满信号逃逸音乐模式锁宽限高；在 `!inLiveResize && isMusicQueueCollapsed` 分支严格锁死返回 `(lockedW, collapsedH)`；
     - `setMusicQueueCollapsed(_:animated:)` 在收起态改为同步切换 (`animate: false`) 消除多帧渐变期间的空白灰屏闪烁，并为 `applyAudioWindowGeometry` 与 `setMusicQueueCollapsed` 补充 `isApplyingAudioWindowGeometry` 守卫；同时在 `windowDidResize` 与 `windowDidEndLiveResize` 统一调用 `enforceAudioModeWindowBoundsIfNeeded(on:screenFrame:)`，确保折叠态若被系统撑开至 `614×500 pt` 能自动自愈回 `224/232 pt`；
     - 新增 3 项 `@MainActor` 单元测试验证屏幕尺寸旁路拦截、折叠态异常高度自愈与 Chrome/Tiling 标记切回。

9. **音乐模式 `.eventTracking` 无平铺拖拽与视频/主界面起手快甩优化 (`ISSUE-017`)**
   - 文件: `Sources/SilkPlayer/Player/PlayerCore+WindowGeometry.swift`、`Sources/SilkPlayer/Player/MusicModeView.swift`、`Sources/SilkPlayer/App/PlayerWindowManager.swift`、`Sources/SilkPlayer/VideoView.swift`、`Sources/SilkPlayer/Player/EmptyPlaybackView.swift`、`Tests/SilkPlayerTests/MusicModeTests.swift`
   - 变更:
     - 在 `MusicWindowDragCoordinator` 移除 `window.performDrag(with:)` 及临时 `.resizable` 锁（彻底避开 macOS `WindowManager` 对桌面左右/顶部边缘平铺及 `tilingPosition` 的接管），改为 `beginDrag(on:with:)` 同步事件追踪循环（`window.trackEvents` `.eventTracking` 模式 + `NSEvent.isMouseCoalescingEnabled = false` + 队列清仓 + `CATransaction.setDisableActions(true)` + 基于 `screenGrabLocation` 与实时 `NSEvent.mouseLocation` 的原生无四边锁死 `setFrameOrigin`）；在 `PlayerWindowManager` `didChangeScreenNotification` 监听中跳过拖拽期重排并延迟到松手后适配新屏幕，同时删除不再需要的私有约束刷新选择器；
     - 优化 `MetalPlayerContainerView` (`VideoView.swift`) 与 `WindowDragCanvasView` (`EmptyPlaybackView.swift`)：保留点击/双击防抖阈值并在 `mouseDown` 缓存 `pendingDragMouseDownEvent`，跨过阈值后改传原始 `.leftMouseDown` 事件给 `window.performDrag(with:)`，消除快甩起手时的固定抓点偏移同时保留视频/空载窗口原生系统平铺能力，并将该项登记于 `KNOWN_ISSUES.md` 待同步合入 `1.7.0` 正式版（`main` 分支）；
     - 新增 `testMusicWindowDragCoordinatorTranslatesOriginAndAppliesMoveWithoutTiling` 与 `testPurgeSavedWindowFrameAutosaveRemovesAllPlayerWindowKeys`。

10. **冷启动默认尺寸防护与禁用 `WindowGroup` 桌面平铺持久化恢复 (`ISSUE-018`)**
    - 文件: `Sources/SilkPlayer/SilkPlayerApp.swift`、`Sources/SilkPlayer/App/AppShellView.swift`、`Sources/SilkPlayer/App/PlayerWindowManager.swift`、`Sources/SilkPlayer/App/AppDelegate.swift`
    - 变更:
      - 在 `SilkPlayerApp.init()`、`AppShellView.handleWindowAcquired`、`PlayerWindowDelegate.windowWillClose` 与 `AppDelegate.persistActiveSessionsBeforeExit` 统一清理所有 `NSWindow Frame playerWindow-*` 持久化键（`NSWindow.removeFrame(usingName:)`），并在窗口接入后设置 `window.isRestorable = false` 与 `window.setFrameAutosaveName("")`，防止 SwiftUI 自动保存的 `tilingState`（含视频/空载模式手动平铺状态）在冷启动时覆盖空窗口默认尺寸；
      - 在 `AppShellView.handleWindowAcquired` 初次居中设置 `960 × 540` 后增加一次主队列复核修正，避免首次窗口呈现阶段被滞后同步的缓存尺寸拉满。

---

## 3. 自动化测试与最新构建验证数据

- **全量单元测试 (`swift test`，最终代码编辑后执行)**:
  - `SilkPlayerTests.xctest`: 38/38 通过（0 失败，0 跳过）
    - `GeometryAndTransformTests`: 5/5 passed
    - `MusicModeTests`: 32/32 passed（含 Shuffle 加权冷却 5 项、防平铺/折叠高度自愈 3 项、`MusicWindowDragCoordinator` `.eventTracking` 无平铺平移 1 项及 `purgeSavedWindowFrameAutosave` 1 项）
    - `PlaylistRegressionTests`: 1/1 passed
  - `SwiftTestingSanityTests`: 1/1 passed
- **构建签名与资产校验 (`/Applications/SilkPlayer.app`)**:
  - `./scripts/package_app.sh 1.7.0-music-preview arm64 --app-only`（`d1c11c8882a1386ae4e2c2e292e358f8110b4ebe4495d4bcd449faa337c0cdbb`）编译（0 警告）、静态库耦合、动态库 `@rpath` 审计与 `codesign --verify --deep --strict` 全部通过；
  - `./scripts/install_to_applications.sh` 已保留用户现有播放列表与配置覆盖安装至 `/Applications/SilkPlayer.app`；前序同分支解锁桌面实测（收起态 `614×224 pt` 长副标题对齐截图 `verify_notch_collapsed.png` 及交互回归）已确认视觉居中与窗口生命周期稳定。

---

## 4. 已闭环与追踪事项 (`KNOWN_ISSUES.md`)

1. **`ISSUE-015` (已闭环)**: 保留 `pin` + `xmark`、移除 `info.circle`，取消点击置顶 OSD 与悬停遮挡气泡。
2. **`ISSUE-016` (已闭环)**: 解锁桌面视觉/手势/视频回归全项通过，并修复退出时 `stop()` 触发 `228 pt` 反弹的生命周期问题。
3. **`ISSUE-017` 与 `ISSUE-018` (预览版已根治 / `1.7.0` 正式版待合入主线项)**: 音乐模式改为 `.eventTracking` 本地追踪拖拽以彻底脱离 `WindowManager` 边缘/顶部平铺同时消除旧版滞后与边界锁死；同时将视频模式与空载画布 `pendingDragMouseDownEvent` 起手快甩优化（`ISSUE-017`）及全窗口冷启动持久化隔离确保稳定居中 `960 × 540`（`ISSUE-018`）登记待合入 `1.7.0` 主线正式版。
