# SilkPlayer 2.0.2 交付成果与技术归档 (Delivery Archive)

本文档归档 SilkPlayer 2.0.2 紧急稳定性热修复补丁版本全量开发成果、技术实现路径、验证数据与交付资产。

---

## 1. 核心缺陷实施成果归档

### 1.1 双击全屏 Space 转场 WindowServer 驱动死锁彻底根治 (P0)
- **目标与根因**:
  - 用户在高刷新率（ProMotion 120Hz）或多显示器环境下双击全屏时，触发系统级假死，约 10 秒后 macOS 强制注销并退回登录界面（WindowServer 被系统看门狗强杀）。
  - 根因分析：
    1. 自 1.5.0（提交 `5d3bd2c`）引入“暂停拉伸即时刷新”机制以来，内核 `SilkMetalRenderView.swift` 的 `layout()` 与 `setFrameSize()` 无条件调用 `updateMetalGeometryAndRedraw()` -> `renderCurrentFrameImmediately()`；
    2. 该逻辑未做播放态（`isPlaying`）与全屏转场判定。当 AppKit 执行跨 Space 全屏平滑缩放动画时，主线程以 120Hz/60Hz 高频调用 `layout()` 并向 `CAMetalLayer` 同步请求 `nextDrawable()`；
    3. 与此同时，后台解码线程以 60fps 持续调用 `render()` 争抢同一个 `nextDrawable()`；
    4. 在 macOS WindowServer 重新分配 Space 显示表面的瞬态，主线程因 3 个 Drawable 耗尽而挂起等待 WindowServer 释放图层缓冲区，而 WindowServer 正挂起等待主线程完成当前帧布局，形成经典的环形相互死锁（Circular Deadlock）；
    5. 互锁超时后，macOS 看门狗对 `WindowServer` 发出 `SIGKILL` 强杀，导致整个用户桌面会话瓦解。
- **技术实现路径**:
  - 在 `SilkCoreKit/Sources/SilkCoreKit/Engine/SilkMetalRenderView.swift` 中：
    - 将布局重算（`updateMetalGeometry()`）与即时渲染（`renderCurrentFrameImmediately()`）彻底解耦；
    - `layout()` 与 `setFrameSize()` 严格仅更新 `layer.contentsScale`、`layer.drawableSize` 及线程安全尺寸记录，严禁在主线程触碰 `nextDrawable()`；
    - 仅在非遮挡且显式调用 `updateMetalGeometryAndRedraw()` 时触发即时渲染；
    - 在 `render(pixelBuffer:...)` 帧提交前加入 `layer.drawableSize` 正值防御门禁（`dSize.width > 0, dSize.height > 0`），杜绝在零尺寸或过渡脏尺寸下执行 `nextDrawable()`；
  - 在 `SilkPlayer/Sources/SilkPlayer/PlayerCore.swift` 中：
    - 彻底剔除在 `toggleFullscreen()` 入口调用的未公开私有分屏约束方法 `_doUpdateTilingConstraintsImmediately`，消除进入全屏转场前与系统窗口管理器产生的时序竞争。

### 1.2 字幕同屏防重叠与关闭状态持久化
- **目标与根因**:
  - 用户在播放内嵌 ASS 特效字幕视频（如《复仇者联盟4》）时，人物姓名介绍与主对话台词发生同屏严重重叠叠字，且在控制栏菜单中点击“关闭字幕”后无法生效。
  - 根因分析：
    1. `SilkSubtitleParser` 历史实现仅映射 `\an8` 为顶部，将 `\an7`（左上）与 `\an9`（右上）退化为默认底部；同时 `SubtitleOverlayView` 强制将所有文本字幕定位在同一个屏幕中心绝对坐标 `(viewW / 2.0, targetCenterY)` 上，导致多字幕同时生效时在正中心“叠罗汉”；
    2. `refreshTracks()` 在每次执行时，若检测到 `selectedSubtitleInfo == nil` 且开启了自动选轨，会强制执行 `autoSelectEmbedSubtitle` 抓取第 1 轨重新赋值并命令底层播放器继续解码，导致用户显式关闭操作被瞬时覆盖。
- **技术实现路径**:
  - 在 `SilkCoreKit/Sources/SilkCoreKit/Engine/SilkSubtitleModel.swift` 与 `SilkDemuxer.swift` 中增加 `parseASSPosition`，完整解析 `\an7`-`\an9`（顶部）、`\an4`-`\an6`（中部）、`\an1`-`\an3`（底部）九宫格对齐；
  - 在 `SilkPlayer/Sources/SilkPlayer/Player/SubtitleOverlayView.swift` 中重构文本字幕渲染容器为自适应垂直堆叠（`VStack(spacing: 6)`），同屏多字幕自然上下排开，彻底根除叠字；
  - 在 `SilkPlayer/Sources/SilkPlayer/PlayerCore.swift` 中引入 `isSubtitleDisabledByUser` 用户显式状态锁，彻底杜绝 `refreshTracks()` 越权自动回选。

---

## 2. 交付资产与校验和 (Delivery Assets & Checksums)

- **应用版本**: `2.0.2`
- **目标分支**: `release/2.0.0`（与 `main` 主干保持严格同步）
- **分支与代码基准**:
  - 前端开源工程 (LGPL-3.0): `SilkPlayer/SilkPlayer` 分支 `release/2.0.0` (commit `28bf914`) / `main`
  - 闭源内核工程 (Proprietary): `SilkPlayer/SilkCoreKit` 分支 `release/2.0.0` (commit `82e0442`)
- **通用安装镜像**: `SilkPlayer-2.0.2-universal.dmg` (24,133,558 字节，约 23MB)
- **SHA-256 校验和**:
  ```
  7d3e2e379ad9aaf863ee5c12069afa57720b5dbe231e20362b8bd7b51c64f30d
  ```
- **架构支持**: Universal Fat Binary (`arm64` + `x86_64`)
- **动态库依赖审计**: 100% `@rpath` 隔离与 Apple 原生系统框架，零外部宿主泄漏路径
- **代码签名与沙箱**: Ad-hoc inside-out codesign + entitlements 严格校验通过
- **自动化回归测试**: 65 项核心几何、窗口生命周期、HUD、播放器状态机与字幕生命周期回归测试 100% 通过（0 失败）
