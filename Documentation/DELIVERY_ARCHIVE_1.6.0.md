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
  - 视窗尺寸精准定格为标准 520 × 400 pt，采用标准表单两列键值排布，全 Tab 零纵向滚动条；
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
  - 冷启动后台异步检测 GitHub 最新版本；
  - 弹窗直观显示最新版本号（“发现新版本 x.x.x，是否立即更新？”），仅提供“是”与“否”；
  - 点击“否”记录时间戳，开启 7 天绝对静默门禁，期间冷启动不再弹窗；
  - 设置面板“关于”Tab 图标常驻 6pt 微型红点（不受“否”影响）；
  - 点击“是”端内下载架构匹配的 DMG 镜像，唤起后台静默替换脚本，原子替换 `/Applications/SilkPlayer.app` 并重启，100% 保护所有应用支持数据与偏好配置。
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

## 2. 自动化测试验证基准
- **测试框架**: XCTest + Swift Testing 双引擎；
- **测试套件**: 全量 61 项回归测试套件全量通过（100% PASS）；
- **基准固化**:
  - Test 1-60：几何约束、播放列表、双轨分流、自然排序、Metal 容错等全部绿灯；
  - Test 61：UpdateService 语义版本对比与 7 天静默频控测试绿灯；
  - SwiftTestingSanityTests：基准测试绿灯。
