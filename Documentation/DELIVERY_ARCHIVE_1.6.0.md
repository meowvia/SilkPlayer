# SilkPlayer 1.6.0 交付成果与技术归档 (Delivery Archive)

本文档归档 SilkPlayer 1.6.0 版本全量开发成果、技术实现路径、测试验证数据及版本交付资产。

---

## 1. 核心待办实施成果归档

### 1.1 待办 1: HDR10 与杜比视界动态 EDR 高光软滚降色调映射 (提案 013，合并原 009)
- **目标与根因**:
  - 原渲染管线在逆 PQ 变换后直接乘以 `(10000.0 / 203.0)` 输出，未针对超过屏幕物理 EDR Headroom 的像素进行平滑压缩，导致 macOS 合成器硬截断，日光与白云严重过曝死白。
- **技术实现路径**:
  - 在 `SilkCoreKit` 的 `kernel.metal` 中实现 `applyDynamicEDRHighlightRollOff(linear_p3, headroom)`；
  - 严格以 ITU-R BT.2408 漫反射白电平（203 尼特，$Y \le 1.0$）为安全拐点，中低光 1:1 绝对保真直通；
  - 超高光区引入一阶导数连续的有理函数平滑滚降：
    $$\text{excess} = Y - \text{knee}$$
    $$\text{max\_excess} = \max(\text{headroom} - \text{knee}, 0.1)$$
    $$\text{compressed\_excess} = \text{max\_excess} \cdot \left(\frac{\text{excess}}{\text{excess} + \text{max\_excess}}\right)$$
    $$Y_{\text{mapped}} = \text{knee} + \text{compressed\_excess}$$
  - 基于加权感知亮度 $Y = 0.2093 R + 0.7216 G + 0.0691 B$ 计算压缩比并等比缩放 RGB 三通道，保护色相与向阳层次；
  - 在 `SilkMetalRenderView.swift` 中，将 `cachedEDRHeadroom` 动态注入 `doviPipelineState` (buffer 1) 与 `hdr10PipelineState` (buffer 0)；
  - 自动适配 SDR 屏幕（`headroom <= 1.05` 时安全拐点设为 0.75，避免 SDR 屏高光发灰或硬切）。
- **交付资产**:
  - `SilkCoreKit` Commit: `a491ae1`
  - 编译重新生成 `SilkCoreKit.xcframework` 并同步部署至 `SilkPlayer/Packages`。

---

### 1.2 待办 2: 偏好设置模块 macOS HIG 规范化全量重构 (提案 018)
- **目标与根因**:
  - 原设置窗口尺寸过大（540x680），依赖纵向滚动条，包含底层基础能力开关与冗余快捷键列表，存在非标准术语。
- **技术实现路径**:
  - 彻底收拢为 3 大标准顶级 Tab：通用（General）、播放（Playback）、关于（About）；
  - 视窗尺寸精准定格为标准 520 × 490 pt，采用标准表单两列键值排布，全 Tab 零纵向滚动条；
  - 100% 采用 macOS 官方标准界面术语，硬解、防爆音与外挂字幕同名加载全局默认启用；
  - 关于页面嵌入官方真实 AppIcon 矢量资产 `AboutAppIconView`，版本标识规范化为 `1.6.0 (Build 2026.11) · Universal Binary`。
- **交付资产**:
  - `SilkSettingsView.swift` 全量重构落地。

---

### 1.3 待办 3: 播放列表侧边拉手边框贴合与极简透明线框重构 (提案 019)
- **目标与根因**:
  - 原拉手采用实心深色毛玻璃材质，窗口模式存在 8pt 边距，犹如贴在影片上的创口贴。
- **技术实现路径**:
  - `PlaylistDrawerHandleTab` 底色设为 100% 镂空完全透明（`Color.clear`）；
  - `DrawerHandleBorderShape` 实现 1.0pt 顶/左/底三边单像素微轮廓线，右侧平齐闭合，无右边线；
  - `PlayerContainerView` 移除 `padding(.trailing, 8)`，窗口模式与全屏模式均 0pt 紧密贴合窗口边框；
  - 扁平微型指示三角固定为 9.5pt 高度与 2.0pt 进深，侵入画面深度压缩至 5.0pt，保留 20pt 交互热区。
- **交付资产**:
  - `SilkUnifiedDrawerView.swift` 与 `PlayerContainerView.swift` 落地。

---

### 1.4 待办 4: 智能静默更新检测、周级克制频控与无损在位覆盖安装 (提案 020)
- **目标与根因**:
  - 实现克制且闭环的端内更新生态，保障零侵扰观影与用户配置数据无损。
- **技术实现路径**:
  - 封装 `@Observable public final class UpdateService`；
  - 冷启动后台异步检测 GitHub 最新版本，并通过 `resolveDownloadURLString(version:assets:preferredArch:)` 解析 Release 资产列表，优先下载 `-universal.dmg` 通用镜像（兼容单架构包回退）；
  - 弹窗直观显示最新版本号（“发现新版本 x.x.x，是否立即更新？”），仅提供“是”与“否”；
  - 点击“否”记录时间戳，开启 7 天绝对静默门禁，期间冷启动不再弹窗；
  - 设置面板“关于”Tab 图标常驻 6pt 微型红点（不受“否”影响）；
  - 点击“是”端内下载匹配的 Universal DMG 镜像，唤起后台静默替换脚本，原子替换 `/Applications/SilkPlayer.app` 并重启，100% 保护所有应用支持数据与偏好配置。
- **交付资产**:
  - `Sources/SilkPlayer/Shared/UpdateService.swift`
  - `AppDelegate.swift` 冷启动异步触发
  - `Tests/SilkPlayerTests/PlaylistTests.swift` 新增 Test 61 语义版本与频控断言。

---

### 1.5 待办 5: 自动化测试抢焦隔离治理 (ISSUE-014)
- **目标与根因**:
  - 测试用例中无条件调用 `NSApp.activate` 与 `makeKeyAndOrderFront` 强抢系统焦点，导致用户前台观影视窗闪烁。
- **技术实现路径**:
  - 在 `PlayerWindowManager`、`PlayerCore` 与 `AppShellView` 的窗口激活与置前逻辑前增加 `PlayerWindowManager.isRunningTests` 判定；
  - 测试运行时跳过全局抢焦指令，仅保留数据与状态流转；
  - 实测连续执行两轮全量测试，前台播放器视窗保持持续置顶播放，零闪烁、零失焦。
- **交付资产**:
  - `PlayerWindowManager.swift`、`PlayerCore.swift`、`AppShellView.swift`
  - `Documentation/KNOWN_ISSUES.md` ISSUE-014 状态更新为已修复销项。

---

### 1.6 待办 6: 策略与文档用语全面治理
- **实施内容**:
  - 全面清理代码与文档中“纯本地”、“零联网”、“完全单机离线运行”、“无任何网络遥测”等绝对化词汇；
  - 统一替换为“原生轻量与极简设计，无内置广告与冗余后台常驻进程”；
  - 确立“历史版本永久免费不撤回”底线原则；
  - `Resources/Info.plist` 与 `CHANGELOG.md` 同步跃迁至 `1.6.0`。

---

### 1.7 待办 7: 窗口实时拉伸像素尺寸与画幅比例指示器 (提案 023)
- **目标与根因**:
  - 为满足用户官网截图、宣发排版与专业观影对像素级标准比例和统一尺寸的严苛需求，解决随手拉伸产生非标奇数像素与比例割裂感痛点。
- **技术实现路径**:
  - `PlayerWindowDelegate` 接入 `windowWillStartLiveResize`、`windowWillResize` 与 `windowDidEndLiveResize`；
  - 捕获当前实时帧尺寸与 AppKit 光标位置，注入 `PlayerCore` 状态机；
  - 封装 `WindowDimensionFormatter`，精准识别 `16:9`、`16:10`、`4:3`、`21:9`、`2.39:1`、`1:1`，并在对齐片源分辨率时提供 `100% 原尺寸` 徽章；
  - `WindowResizeDimensionHUD.swift` 实现极简等宽深色毛玻璃胶囊，安全视口内自适应贴近光标，松手后 0.35 秒平滑淡出，零遮挡观影。
- **交付资产**:
  - `Sources/SilkPlayer/Player/WindowResizeDimensionHUD.swift`
  - `PlayerWindowManager.swift`、`PlayerCore.swift`、`AppShellView.swift`
  - `Tests/SilkPlayerTests/PlaylistTests.swift` 新增 Test 62 格式化与画幅判定断言。

### 1.8 窗口比例菜单与 HUD/菜单栏问题收敛 (Proposal 027 · ISSUE-019 · ISSUE-020)
- **右键窗口比例子菜单 (Proposal 027 / GitHub Issue #6)**：
  - `VideoView.swift` (`MetalPlayerContainerView.buildContextMenu(for:)`) 与 `L10n.swift` (`windowSizeMenu` / `windowSizeReset`) 新增「窗口大小 / Window Size」子菜单，提供 `50%`、`75%`、`100%` 与「恢复默认 (`resetWindowSize()`)」，在全屏、纯音频（`!player.isAudioOnly`）或无已加载媒体时自动禁用，并按当前窗口包络与边界状态控制菜单勾选与置灰；
  - `PlayerModels.swift` (`PlayerGeometry.adaptiveVideoContentSize` / `windowPresetContentSize` / `windowPresetMenuState` / `WindowScalePresetState`) 与 `Player/PlayerCore+WindowGeometry.swift` 统一收敛旋转与百分比开窗尺寸逻辑，确保所有档位在桌面可用区内保持原片比例且零画面/字幕裁切，并修复 `fitWindow(scale:)` 的 `window.minSize` 临时释放/恢复、`.maximized` 状态经 `PlayerWindowDelegate.resetInteractiveModeToNormal()` 复位及百分比 OSD 反馈。
- **竖屏/极窄窗口底栏音量按钮重叠修复 (ISSUE-019)**：
  - `PlayerHUDView.swift` 在 `.minimal` 档位下隐藏底栏内联音量滑块，收紧边距与右侧间距，并在溢出菜单 (`moreMenuContent`) 补充静音开关；`PlaylistTests.swift` Test 63 同步更新断言 `HUDLayoutTier.minimal.showsVolumeSlider(isAudioOnly: false) == false`。
- **顶栏重名「窗口」菜单合并与冗余入口清理 (ISSUE-020)**：
  - `PlayerCommands.swift` 将独立 `CommandMenu(L10n.menuWindow)` 替换为 `CommandGroup(before: .windowList)` 归入系统标准窗口菜单，并移除冗余 `Menu(L10n.fitToVideo)` 及其废弃本地化字段。

---

## 2. 自动化测试验证基准
- **测试框架**: XCTest + Swift Testing 双引擎；
- **测试套件**: 全量回归测试通过（100% PASS，编译零告警）；
- **基准固化**:
  - `GeometryAndTransformTests`（7/7 通过）：几何边界约束、画幅自适应及右键百分比缩放（`50% / 75% / 100%`）与边界/全屏/纯音频门控测试（`testWindowPresetContentSizeAndBoundaryMenuGating`、`testFitWindowPercentageAndContextMenuStateGating`）；
  - `PlaylistRegressionTests`（Test 1-63 全部断言通过）：播放列表、双轨分流、自然排序、Metal 容错、`UpdateService` Universal 资产解析与校验、HUD 实时尺寸及 `.minimal` 音量隐藏断言；
  - `SwiftTestingSanityTests`（1/1 通过）：基础断言测试通过。

---

## 3. 正式发布安装镜像与 SHA-256 校验和
- **工程 Git 基准**:
  - 开源前端: `SilkPlayer`（应用构建源码 Commit `e751dd4`，分支 `feature/v1.6.0`）
  - 闭源内核: `SilkCoreKit`（Commit `1e49d6f`）
- **发布安装镜像**:
  - `SilkPlayer-1.6.0-universal.dmg` (Universal 通用双架构，Apple Silicon + Intel 64 位单镜像交付): `c332d4fa6f7cc56952a858eafeecce68885acd8bc69c031f8fcd09fd8cefe388`
- **动态库依赖审计 (@rpath)**:
  - 零宿主绝对路径泄漏，所有动态库严格限定在 `@rpath/` 与系统库路径，通过 `package_app.sh` 自动化签名与 Hardened Runtime 校验，Universal 单镜像打包完成。
- **本地应用状态**:
  - `/Applications/SilkPlayer.app` 经全新清理安装为 `1.6.0` Universal 双架构发行版本。

