# SilkPlayer 播放窗口交互架构评估、根因深度剖析与重构修复执行清单 (v1.4.0 移交规范)

- 目标：彻底解决从 1.3.0 升级至 1.4.0 引入“顶栏双击最大化”后引发的拉伸、抖动、全屏退回异常、底栏误拖拽及触控板事件断流问题。
- 适用对象：接手修复的执行 AI Agent。请严格按照本文档分步执行，严禁引入未经验证的复杂中间层状态机。

---

## 一、 现状评估与演进混乱根因剖析

### 1.1 核心问题定性
当前窗口模块陷入混乱的根源，在于采用了“局部现象打补丁（Whack-A-Mole）”的演化方式，未能理清 macOS 下“视频长宽比锁定”与“窗口满屏最大化（Zoom）”之间的底层数学矛盾，并强行通过自建状态机与私有计算拦截 AppKit 原生转场，引发了连锁崩塌。

### 1.2 六大根因分解

1. **视频长宽比（Aspect Ratio）与桌面满屏最大化（Screen Zoom）的数学冲突**
   - 1.3.0 机制：播放器窗口在缩放时强制 `contentAspectRatio == effectiveAspectRatio`，长宽比与视频 100% 绑定。
   - 1.4.0 破坏点：双击顶栏直接粗暴执行 `window.setFrame(screen.visibleFrame)`。macOS 屏幕可用区域（通常为 16:10 或带刘海比例）几乎绝不等于视频比例（16:9 / 2.39:1 / 9:16 等）。
   - 次生故障：窗口比例与内容比例失配；用户稍拖动窗口边框 1 像素，`windowWillResize` 便强行拉回视频比例，产生剧烈跳跃抖动；暂停时 Metal 视口重绘错位。

2. **最大化（Zoom）与系统级全屏（Fullscreen）生命周期混淆**
   - 最大化铺满桌面后，若用户进入系统级全屏，AppKit 会缓存“当前最大化帧”作为退出全屏时的恢复目标。
   - 当用户退出全屏时，窗口直接落回最大化尺寸，无法回到原始居中播放尺寸，导致窗口被永久卡在最大化状态。后期试图覆写 `destinationFrameToExitFullScreen` 进一步破坏了系统转场时序。

3. **双击语义与区域判定缺乏状态隔离**
   - 观影沉浸态（HUD 隐藏）与交互态（HUD 激活）共用硬编码坐标（如 `loc.y >= bounds.height - 70`），且未校验 `player.isHUDVisible`。
   - 观影态下用户双击视频顶部本意是“进入全屏”，却被误拦截为“最大化”；全屏态下双击顶部甚至尝试触发“窗口最大化”，导致状态不同步。

4. **窗口拖拽（PerformDrag）越界捕获**
   - 底层 `MetalPlayerContainerView` 在 `mouseDragged` 中移动超过 3pt 时无差别调用 `window.performDrag(with: event)`。
   - 用户在底部进度条拖动（Scrubbing）或在控制栏空白处手滑微移时，整个播放器窗口被意外拖走。

5. **全局事件监听（Local Event Monitor）吞噬触控板原生管线**
   - `PlayerHUDView` 的 `setupMouseMonitor()` 使用全局监视器拦截了 `.scrollWheel`。为避免光标消失，曾粗暴写入 `return nil`，直接截断了 AppKit 响应链。
   - 位于底层的 `MetalPlayerContainerView.scrollWheel(with:)` 完全失效，双指左右精确 Scrubbing 与双指上下调音量沦为死代码。

6. **置顶（Always On Top）状态源分裂**
   - 顶栏图钉按钮读写 `AppSettings.shared.keepWindowOnTop`，菜单栏与窗口管理器读写 `PlayerWindowManager.isAlwaysOnTop`，两者未做单一事实源（SSOT）绑定，导致 UI 状态脱节。

---

## 二、 核心重构原则与架构技术方案

### 原则 1：确立“等比最大化（Aspect-Preserved Zoom）”为唯一标准
- 业界标准：参考 IINA 与 QuickTime Player，播放器窗口在双击顶栏或 Zoom 时，绝不拉满整个非等比屏幕，而是在当前屏幕的 `visibleFrame` 范围内计算保持视频固有长宽比的最大安全尺寸，并保持居中。
- 收益：彻底消除窗口拉伸与变形问题，`windowWillResize` 的等比计算逻辑对最大化与普通缩放完全自洽，退出最大化时还原精准对称。

### 原则 2：以 HUD 可见性为事件路由的一级分发网关
- 沉浸态（`player.isHUDVisible == false`）：除顶部原生 28pt 安全边距外，全屏/画布双击一律路由至 `handleDoubleClickAction()`（默认切换全屏），单击一律防抖触发播放/暂停。
- 交互态（`player.isHUDVisible == true`）：
  - 底部控制栏（`y <= 112`）：严禁触发窗口拖拽，严禁触发画布播放/暂停。
  - 顶栏中间区域（`y >= height - 64`）：双击触发等比最大化/还原（全屏态则退出全屏）；单击允许按住拖动窗口。
  - 左右控件区（绿红灯 `x <= 70`、快捷按钮 `x >= width - 160`）：放行给原生控件。

---

## 三、 执行 Agent 具体落地执行清单（按步骤操作）

### 步骤 0：清理残留代码与工作区
1. 清理工作区内临时生成的 `WindowGeometryCoordinator.swift` 及其引用，保证架构收敛至原生组件。
2. 保持窗口逻辑核心收敛在：
   - `Sources/SilkPlayer/App/PlayerWindowManager.swift`
   - `Sources/SilkPlayer/VideoView.swift`
   - `Sources/SilkPlayer/PlayerHUDView.swift`
   - `Sources/SilkPlayer/Player/EmptyPlaybackView.swift`

### 步骤 1：重构 `PlayerWindowManager.swift` 中的最大化与置顶逻辑

1. 统一置顶状态源：
```swift
public var isAlwaysOnTop: Bool {
    get { AppSettings.shared.keepWindowOnTop }
    set {
        AppSettings.shared.keepWindowOnTop = newValue
        applyAlwaysOnTop(newValue)
    }
}

public func toggleAlwaysOnTop() {
    isAlwaysOnTop = !isAlwaysOnTop
}

public func applyAlwaysOnTop(_ onTop: Bool) {
    for s in sessions {
        s.window?.level = onTop ? .floating : .normal
    }
}
```

2. 实现等比最大化（Aspect-Preserved Toggle Maximize）：
在 `PlayerWindowDelegate` 中完善逻辑，替代粗暴全屏 frame 赋值：
```swift
public func toggleMaximize(window: NSWindow) {
    guard !window.styleMask.contains(.fullScreen) else { return }
    let screen = window.screen ?? NSScreen.main
    guard let screenFrame = screen?.visibleFrame else { return }

    // 1. 若当前已处于等比最大化状态，平滑还原至预存普通尺寸
    if let saved = savedPreZoomFrame {
        isAdjustingWindowFrame = true
        defer { isAdjustingWindowFrame = false }
        window.setFrame(saved, display: true, animate: true)
        savedPreZoomFrame = nil
        return
    }

    // 2. 记录当前窗口普通尺寸
    savedPreZoomFrame = window.frame

    // 3. 闲置窗口（未加载视频）：居中至标准尺寸
    guard let player = self.player, player.videoWidth > 0, player.videoHeight > 0 else {
        isAdjustingWindowFrame = true
        defer { isAdjustingWindowFrame = false }
        window.setFrame(screenFrame, display: true, animate: true)
        return
    }

    // 4. 视频播放态：计算保持长宽比的最大安全尺寸
    let aspect = player.effectiveAspectRatio
    let maxContent = PlayerGeometry.maximumSafeContentSize(for: aspect, screenVisibleSize: screenFrame.size)
    let targetW = round(maxContent.width)
    let targetH = round(maxContent.height)
    let targetX = round(screenFrame.midX - targetW / 2)
    let targetY = round(screenFrame.midY - targetH / 2)
    let targetFrame = NSRect(x: targetX, y: targetY, width: targetW, height: targetH)

    isAdjustingWindowFrame = true
    defer { isAdjustingWindowFrame = false }
    window.setFrame(targetFrame, display: true, animate: true)
}

public func windowShouldZoom(_ window: NSWindow, toFrame newFrame: NSRect) -> Bool {
    toggleMaximize(window: window)
    return false
}
```

3. 原生全屏生命周期还原：
移除针对全屏退出的非标准尺寸计算覆盖，仅在 `windowWillEnterFullScreen` 时保存正常播放尺寸，在 `windowDidExitFullScreen` 时保障长宽比重新加锁：
```swift
public func windowWillEnterFullScreen(_ notification: Notification) {
    if let window = notification.object as? NSWindow {
        if savedPreZoomFrame == nil {
            savedPreZoomFrame = window.frame
        }
        window.contentAspectRatio = .zero
        window.aspectRatio = .zero
    }
}

public func windowDidExitFullScreen(_ notification: Notification) {
    player?.setFullscreenState(false)
    player?.applyContentAspectRatioLock()
}
```

### 步骤 2：重构 `VideoView.swift` 中的点击、双击与拖拽网关

在 `MetalPlayerContainerView` 中建立清晰的判定管线：

1. 引入拖拽保护标记：
```swift
private var canDragWindowFromCurrentMouseDown: Bool = false
```

2. 重写 `mouseDown(with:)`：
```swift
override public func mouseDown(with event: NSEvent) {
    let loc = self.convert(event.locationInWindow, from: nil)
    let b = bounds
    guard let window = self.window else {
        super.mouseDown(with: event)
        return
    }
    let isFullscreen = window.styleMask.contains(.fullScreen)
    canDragWindowFromCurrentMouseDown = false

    // 1. 窗口边缘 8pt 原生调整大小保护
    if !isFullscreen {
        let margin: CGFloat = 8.0
        if loc.x <= margin || loc.x >= b.width - margin || loc.y <= margin || loc.y >= b.height - margin {
            super.mouseDown(with: event)
            return
        }
    }

    // 抽屉与音量滑块判定
    let activeDrawerWidth: CGFloat = (playerCore?.isInspectorVisible == true) ? 348.0 :
        ((playerCore?.isPlaylistDrawerVisible == true) ? (PlaylistDrawerDimensions.drawerWidth(for: b.width, isFullscreen: isFullscreen) + 8.0) : 0.0)

    if let player = playerCore {
        // 抽屉外点击关闭抽屉
        if player.isPlaylistDrawerVisible || player.isInspectorVisible {
            let insideDrawer = (loc.x >= b.width - activeDrawerWidth) && (loc.y >= 96 && loc.y <= b.height - 64)
            if !insideDrawer {
                player.isPlaylistDrawerVisible = false
                player.isInspectorVisible = false
                return
            }
        }

        // 抽屉内部与右侧音量区放行
        if (activeDrawerWidth > 0 && loc.x >= b.width - activeDrawerWidth) ||
           (player.isVolumeHUDVisible && loc.x >= b.width - 80) {
            super.mouseDown(with: event)
            return
        }
    }

    guard let player = playerCore else { return }
    let topBarHeight: CGFloat = isFullscreen ? 52.0 : 64.0
    let isTopBarArea = (loc.y >= b.height - topBarHeight)
    let isBottomControlArea = (loc.y <= 112.0)

    // 2. HUD 激活态路由
    if player.isHUDVisible {
        // A. 底部控制栏：禁止任何画布暂停与窗口拖拽
        if isBottomControlArea {
            canDragWindowFromCurrentMouseDown = false
            return
        }

        // B. 顶栏区域
        if isTopBarArea {
            let isLeadingTrafficArea = !isFullscreen && loc.x <= 70.0
            let isTrailingActionArea = loc.x >= b.width - 160.0
            if isLeadingTrafficArea || isTrailingActionArea {
                super.mouseDown(with: event)
                return
            }

            // 顶栏中间区域双击：最大化/还原或退出全屏
            if event.clickCount >= 2 {
                pendingSingleClickWorkItem?.cancel()
                pendingSingleClickWorkItem = nil
                if isFullscreen {
                    player.toggleFullscreen()
                } else {
                    PlayerWindowManager.shared.toggleMaximize(window: window)
                }
                return
            }

            // 顶栏单击：允许拖拽窗口
            canDragWindowFromCurrentMouseDown = !isFullscreen
            dragInitialMouseScreenLocation = NSEvent.mouseLocation
            dragInitialWindowOrigin = window.frame.origin
            return
        }
    }

    // 3. 沉浸态（纯画面观影）或中间视频画面区域路由
    if window.firstResponder !== self {
        window.makeFirstResponder(self)
    }

    if event.clickCount >= 2 {
        pendingSingleClickWorkItem?.cancel()
        pendingSingleClickWorkItem = nil

        // 沉浸态下顶部 28pt 仍允许窗口最大化
        if !isFullscreen && !player.isHUDVisible && loc.y >= b.height - 28.0 {
            PlayerWindowManager.shared.toggleMaximize(window: window)
            return
        }

        self.handleDoubleClickAction()
        return
    }

    // 单击准备与画布拖拽授权
    canDragWindowFromCurrentMouseDown = !isFullscreen
    dragInitialMouseScreenLocation = NSEvent.mouseLocation
    dragInitialWindowOrigin = window.frame.origin
}
```

3. 重写 `mouseDragged(with:)` 与 `mouseUp(with:)`：
```swift
override public func mouseDragged(with event: NSEvent) {
    guard canDragWindowFromCurrentMouseDown,
          let window = self.window,
          !window.styleMask.contains(.fullScreen) else {
        super.mouseDragged(with: event)
        return
    }

    let current = NSEvent.mouseLocation
    let distance = hypot(current.x - dragInitialMouseScreenLocation.x, current.y - dragInitialMouseScreenLocation.y)
    if distance > 3.0 {
        pendingSingleClickWorkItem?.cancel()
        pendingSingleClickWorkItem = nil
        window.performDrag(with: event)
    }
}

override public func mouseUp(with event: NSEvent) {
    guard event.clickCount == 1 else { return }

    let current = NSEvent.mouseLocation
    let distance = hypot(current.x - dragInitialMouseScreenLocation.x, current.y - dragInitialMouseScreenLocation.y)
    if distance > 3.0 {
        pendingSingleClickWorkItem?.cancel()
        pendingSingleClickWorkItem = nil
        return
    }

    // 若 HUD 激活且点击落在顶栏或底栏，直接返回，避免误触发画面暂停
    if let player = playerCore, player.isHUDVisible {
        let loc = self.convert(event.locationInWindow, from: nil)
        let b = bounds
        let topH: CGFloat = window?.styleMask.contains(.fullScreen) == true ? 52.0 : 64.0
        if loc.y <= 112.0 || loc.y >= b.height - topH {
            return
        }
    }

    // 画面空白处防抖单击（0.16s）
    if AppSettings.shared.doubleClickAction == .none {
        self.playerCore?.togglePlayPause()
    } else {
        pendingSingleClickWorkItem?.cancel()
        let task = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            self.pendingSingleClickWorkItem = nil
            self.playerCore?.togglePlayPause()
        }
        self.pendingSingleClickWorkItem = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16, execute: task)
    }
}
```

### 步骤 3：修复 `PlayerHUDView.swift` 滚轮拦截与自动隐藏

1. 滚轮事件无条件放行：
在 `setupMouseMonitor()` 中，对 `.scrollWheel` 事件绝不返回 `nil`：
```swift
if event.type == .scrollWheel {
    Task { @MainActor in
        self.registerUserActivity()
    }
    return event // 完整放行给底层的 MetalPlayerContainerView 处理触控板手势
}
```

2. 光标与控制栏悬停保护：
在 `PlayerHUDView` 和 `PlayerCore` 的自动隐藏定时器（1.8s）触发时，判断鼠标当前位置：
- 若鼠标悬停在底部控制栏（`loc.y <= 112`）或顶部控制栏（`loc.y >= height - 64`），或者右侧抽屉处于展开状态，保持控制栏与光标常亮，不执行隐藏。

### 步骤 4：修复主页闲置窗口（`EmptyPlaybackView.swift`）

修改 `WindowDragCanvasView`：
```swift
public final class WindowDragCanvasView: NSView {
    private var initialMouseLocation: NSPoint = .zero

    override public func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override public func mouseDown(with event: NSEvent) {
        guard let window = self.window else { return }
        if event.clickCount == 2 {
            let loc = self.convert(event.locationInWindow, from: nil)
            if loc.y >= bounds.height - 52.0 {
                PlayerWindowManager.shared.toggleMaximize(window: window)
            } else if AppSettings.shared.doubleClickAction == .openFile {
                PlayerWindowManager.shared.openFilePicker()
            }
            return
        }
        initialMouseLocation = NSEvent.mouseLocation
    }

    override public func mouseDragged(with event: NSEvent) {
        guard let window = self.window, !window.styleMask.contains(.fullScreen) else { return }
        let current = NSEvent.mouseLocation
        if hypot(current.x - initialMouseLocation.x, current.y - initialMouseLocation.y) > 3.0 {
            window.performDrag(with: event)
        }
    }
}
```

---

## 四、 触控板事件的无设备测试与验证标准

由于本地缺少触控板硬件，执行 Agent 应遵循以下规范避免代码劣化：

1. **逻辑解耦保障**：
   - 必须保留 `MetalPlayerContainerView.scrollWheel(with:)` 中对 `event.hasPreciseScrollingDeltas` 的判断分支。
   - `hasPreciseScrollingDeltas == true` 为触控板逻辑（双指滑动）：
     - 判定 `dx` 与 `dy` 比例，实现水平 Scrubbing 与垂直音量调整的轴向锁定。
   - `hasPreciseScrollingDeltas == false` 为传统鼠标齿轮滚轮逻辑：
     - 直接执行单帧步进或音量加减。
   - 只要不吞噬事件且两条分支保持独立，触控板功能将百分之百保持设计行为。

2. **验证闭环**：
   - 运行工程测试：`swift test`（或通过 Xcode 对应 Scheme 运行）。
   - 重点验证 `Tests/SilkPlayerTests/GeometryAndTransformTests.swift` 中关于最大尺寸计算、多比例几何约束以及坐标逆变换测试全部通过。
   - 确保 `swift build` 编译输出 **0 Errors, 0 Warnings**。
