# SilkPlayer 窗口与交互事件链彻底排雷及回归 1.3.0 基线移交规范

## 一、 核心问题自省与当前所有交互 Bug 全面揭底

在对比了 `1.3.0` 稳定基线与 `1.4.0` 当前 HEAD 的所有 UI 视图层级后，查明导致当前窗口交互出现**一连串严重问题**（包括但不限于：退出全屏变最大化并侵入 Dock、双击顶栏和画布经常失灵、拖拽窗口卡死或不动、自动最大化后再双击顶栏无法缩小、右键菜单呼不出）的**7 大致命真凶**如下：

---

### 致命问题 1：`PlayerHUDView.swift` 拆散了顶层 `allowsHitTesting`，把整个视频画面和顶栏全部挡死！（1.4.0 引入的头号大雷）
- **1.3.0 稳定代码**：
  在 `1.3.0` 中，`PlayerHUDView` 的整个 `VStack`（包含 `topBar`、`Spacer()`、`bottomControls`）外层写的是：
  ```swift
  .opacity(isControlsVisible && player.isHUDVisible ? 1.0 : 0.0)
  .allowsHitTesting(isControlsVisible && player.isHUDVisible)
  ```
- **1.4.0 破坏点**：
  为了加一个全屏右上角时钟（`FullscreenClockView`），1.4.0 把外层 `VStack` 的 `.allowsHitTesting` 删掉了，改成了只在部分子视图上加，而 **`topBar` 的 `HStack`、中间的 `Spacer()`、以及左上角的 `specBadgesRow`（HDR / 4K / HEVC / METAL 胶囊）处于 HitTesting 开启状态**！
- **灾难性后果**：
  1. **顶栏左半边（规格徽章区）和中间被 SwiftUI 的 `HStack` 吞掉鼠标事件**：用户在顶栏双击想最大化、或者按住顶栏想拖动窗口时，鼠标事件直接被上层的 SwiftUI `PlayerHUDView` 拦截吞噬，**底层的 `MetalPlayerContainerView (VideoView)` 根本收不到 `mouseDown`！**
  2. **右键菜单与画布手势在特定区域失灵**：`PlayerContainerView` 中 `PlayerHUDView` 的 `.zIndex(20)` 高于 `VideoView`，任何没有显式设置 `.allowsHitTesting(false)` 的容器区域都会拦截底层 `VideoView` 的单击、双击、拖拽和右键菜单。

---

### 致命问题 2：`HUDControlButtons.swift` 新增的 `HUDMicroTooltipModifier` 使用 `.onHover` 破坏了按钮点击与父层事件穿透！
- **1.4.0 破坏点**：
  1.4.0 给所有顶部和底部按钮加上了 `.hudTooltip(...)`（`HUDMicroTooltipModifier`），内部套了一层 `.onHover` 和 `.overlay`。
- 在 macOS SwiftUI（`NSHostingView`）中，当 `PlayerHUDView` 浮在 `VideoView`（`NSViewRepresentable`）上方时，不当的 `ZStack/HStack` 容器布局配合 `.onHover` 会生成全尺寸的 `NSTrackingArea`，导致鼠标点击和双击事件在 SwiftUI 托管层被截胡。

---

### 致命问题 3：双击全屏后，再双击退出全屏，变成“最大且侵入 Dock 底部的窗口”！
- **真凶链条**：
  1. **为什么变成最大化？**
     在 `PlayerWindowDelegate.windowWillResize(_:to:)` 中，当双击进入全屏（或退出全屏）的瞬间，AppKit 在 `window.styleMask.contains(.fullScreen)` 为 `false` 的过渡帧，向 `windowWillResize` 传入了整块物理屏幕尺寸 `screen.frame.size`（例如 `1920 × 1080`，包含菜单栏和 Dock 栏的物理全屏尺寸）。
     此时代码走到了第 764 行：
     ```swift
     if !window.inLiveResize && isTilingOrSnapSize(frameSize, screenFrame: screenFrame)
     ```
     而 `isTilingOrSnapSize` 中有一句：
     ```swift
     if abs(size.width - screenFrame.width) <= tolerance { return true }
     ```
     因为物理全屏宽度 `1920` 等于 `screen.visibleFrame.width` (`1920`)，**`isTilingOrSnapSize` 竟然把 AppKit 的全屏过渡动画帧误判成了“macOS 15 窗口分屏吸附”！**
     紧接着第 779 行按 16:9 算出了 `1920 × 1080` 并返回给 AppKit！导致进入全屏前的原始窗口尺寸被篡改成了 `1920 × 1080`，退出全屏时的目标尺寸也被强行锁死在 `1920 × 1080`！
  2. **为什么底部直接侵入 Dock 栏？**
     因为 `1920 × 1080` 是整块物理屏幕的高度（`screen.frame.height`），比扣掉 Dock 栏和菜单栏的可用工作区高度 `screen.visibleFrame.height`（如 `1005`）高出了整整 75pt！
     而在退出全屏动画期间，`windowDidResize` 看到窗口顶部超出了 `screenFrame.maxY`，执行了：
     ```swift
     curFrame.origin.y = max(screenFrame.minY, screenFrame.maxY - curFrame.height)
     window.setFrame(curFrame, display: true, animate: false)
     ```
     这不仅在半途打断了 AppKit 的退出全屏动画，还把高 `1080` 的窗口塞进了高 `1005` 的可用区里，导致窗口底部直接穿透 `screenFrame.minY` 压进 Dock 栏底下！

---

### 致命问题 4：`toggleMaximize`（双击顶栏最大化）存在“无法缩小”的死锁逻辑！
- **真凶代码**：
  在 `PlayerWindowDelegate.toggleMaximize(window:)` 中，只靠 `if let saved = savedPreZoomFrame` 来判断当前是否已经最大化！
- **死锁场景**：
  1. 如果视频打开时（或用户手动拉大后）窗口本来就已经很大（接近或等于最大等比尺寸），此时 `savedPreZoomFrame` 为 `nil`。用户双击顶栏想把窗口**缩小**回普通尺寸（如 `960 × 540`），结果 `toggleMaximize` 把当前的大尺寸存进了 `savedPreZoomFrame`，然后又把窗口设成了同样的大尺寸——**双击顶栏完全没有任何反应！再双击还是大窗口！**
  2. 如果用户在最大化状态下进入全屏再退出，或者触发了一次 `windowDidEndLiveResize` 清空了 `savedPreZoomFrame`，此后双击顶栏就再也无法缩小回标准窗口了！

---

### 致命问题 5：`EmptyPlaybackView`（空闲主页）的中央 Logo 挡死了拖拽，且外围 12pt 空白区双击和拖拽断层！
- **真凶代码**：
  在 `EmptyPlaybackView.swift` 中：
  1. `WindowDragGestureView().padding(12)` 留出了 12pt 的边距，而在 `WindowDragCanvasView.mouseDown` 里**又判断了一次 `margin: 8.0`**！这意味着距离窗口边缘 `0 ~ 20pt` 的巨大一圈范围内，既不能拖动窗口，双击顶部（距离顶部 20pt 内）也完全没反应！
  2. 在 `WindowDragCanvasView.mouseDragged` 中，调用 `window.performDrag(with: event)` 时传入的是 `mouseDragged` 的 `event`，且没有重置状态；在部分 macOS 版本下，`performDrag` 连续在每个 `mouseDragged` 帧被重复触发会导致窗口跳跃或卡顿。

---

### 致命问题 6：`VideoView.swift` 在 `mouseDown` 中拦截了底部 112pt 和顶部 64pt，却导致 SwiftUI 控件与底层 NSView 抢事件！
- **真凶代码**：
  1. 在 `PlayerHUDView` 中，由于 `bottomControls` 只是一排文字和按钮，按钮之间的空白缝隙如果没有背景拦截，点击就会穿透到 `VideoView.mouseDown`；而如果被 `PlayerHUDView` 的透明层挡住，画布中間区域的双击和拖拽又会失效。
  2. 在 `VideoView.mouseDragged` 中，`window.performDrag(with: event)` 传入的是 `mouseDragged` 事件，且没有在触发一次 `performDrag` 后立即 `canDragWindowFromCurrentMouseDown = false` 终止后续 `mouseDragged` 重入！在 macOS AppKit 中，`window.performDrag(with: event)` 会开启系统级模态拖拽循环，如果在同一次按下期间重复重入调用，会导致拖拽失灵或鼠标释放后状态错乱。

---

### 致命问题 7：`PlayerContainerView` 右侧拉手 `PlaylistDrawerHandleTab` 占满全屏 Frame 拦截了整个画面的鼠标事件！
- **真凶代码（极其隐蔽的巨雷！）**：
  看 `Sources/SilkPlayer/Player/PlayerContainerView.swift` 第 146~157 行：
  ```swift
  PlaylistDrawerHandleTab(
      isDrawerVisible: player.isPlaylistDrawerVisible,
      drawerWidth: drawerWidth
  ) { ... }
  .frame(maxWidth: .infinity, maxHeight: .infinity)
  .opacity(player.isHUDVisible || isHoveringRightEdge || player.isPlaylistDrawerVisible ? 1.0 : 0.0)
  .zIndex(26)
  ```
  以及 `AppShellView.swift` 第 96~106 行！
  来看 `PlaylistDrawerHandleTab` 的内部实现（`SilkUnifiedDrawerView.swift` 第 588 行）：
  ```swift
  public var body: some View {
      HStack {
          Spacer()
          Button(action: action) { ... }
          .allowsHitTesting(!isDrawerVisible)
      }
  }
  ```
  - 注意：`PlaylistDrawerHandleTab` 的 `.zIndex(26)` 是整个播放器里**最高**的（比 `PlayerHUDView` 的 20 和 `VideoView` 的 0 都高），而且它设置了 `.frame(maxWidth: .infinity, maxHeight: .infinity)`！
  - 更可怕的是：在沉浸态（`player.isHUDVisible == false`）下，它只设置了 `.opacity(0.0)`，**根本没有设置 `.allowsHitTesting(false)`**！即便隐藏了，那个无形的按钮依然浮在右侧可点击！

---

## 二、 彻底修复方案（一次性根除所有 7 大问题，回归 1.3.0 般丝滑）

请执行 AI Agent 严格按照以下 **5 个文件的完整修改指令** 逐一落地，不留任何死角：

---

### 修复 1：`Sources/SilkPlayer/PlayerHUDView.swift` —— 彻底打通鼠标穿透，只让真正的按钮接管点击！

1. **在 `topBar(tier:isHUDActive:)` 中**：
   - 左上角的 `specBadgesRow(tier: tier)` 只是只读信息展示胶囊（HDR / 4K / HEVC / METAL），**必须加上 `.allowsHitTesting(false)`**！这样用户在顶栏左侧、中间（标题胶囊已设 `.allowsHitTesting(false)`）、空白处单击拖拽或双击最大化时，100% 穿透到底层 `VideoView`！
   - 全屏时钟 `FullscreenClockView()` 保持 `.allowsHitTesting(false)`。
   - **整个 `topBar` 中，只有右上角的 3 个圆形按钮（置顶、属性、关闭）所在的 `HStack` 允许 `.allowsHitTesting(isHUDActive)`**！
2. **在 `body` 的主 `VStack` 中**：
   - 中间的 `Spacer()` 绝不能拦截任何点击。
   - 当 `!isHUDActive`（HUD 隐藏的沉浸观影态）时，整个 `VStack` 必须设置 `.allowsHitTesting(false)`，确保沉浸态下 100% 的画面没有任何 SwiftUI 透明视图挡在 `VideoView` 前面！

请将 `PlayerHUDView.swift` 的 `body`（第 90~112 行）和 `topBar`（第 153~238 行）精确修改为：

```swift
    public var body: some View {
        GeometryReader { geometry in
            let availableWidth = geometry.size.width
            let tier = layoutTier(for: availableWidth)
            let isHUDActive = isControlsVisible && player.isHUDVisible

            ZStack {
                VStack(spacing: 0) {
                    topBar(tier: tier, isHUDActive: isHUDActive)
                        .padding(.horizontal, 16)
                        .padding(.top, player.isFullscreen ? 16 : 30)
                    Spacer()
                        .allowsHitTesting(false)
                    bottomControls(tier: tier, width: availableWidth)
                        .opacity(isHUDActive ? 1.0 : 0.0)
                        .allowsHitTesting(isHUDActive)
                }
                .allowsHitTesting(isHUDActive)
                .animation(.easeInOut(duration: 0.22), value: isHUDActive)
                .animation(.spring(response: 0.25, dampingFraction: 0.8), value: tier)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
```

以及 `topBar` 方法中：
```swift
            // 1. Base Layer: Leading Spec Badges + Trailing Quick Actions
            HStack(alignment: .center, spacing: 10) {
                specBadgesRow(tier: tier)
                    .padding(.leading, player.isFullscreen ? 0 : (tier == .minimal ? 54 : 70))
                    .opacity(isHUDActive ? 1.0 : 0.0)
                    .allowsHitTesting(false) // 关键修复：只读规格胶囊严禁拦截顶栏拖拽与双击！

                Spacer()
                    .allowsHitTesting(false)
```

---

### 修复 2：`Sources/SilkPlayer/Player/PlayerContainerView.swift` —— 修复右侧拉手透明遮挡

在 `PlayerContainerView.swift` 第 145~156 行，给 `PlaylistDrawerHandleTab` 补上 `.allowsHitTesting` 保护：
```swift
                // Right-Edge Floating Side Triangle Pull Tab (always accessible on right border)
                let isHandleVisible = (player.isHUDVisible || isHoveringRightEdge) && !player.isPlaylistDrawerVisible
                PlaylistDrawerHandleTab(
                    isDrawerVisible: player.isPlaylistDrawerVisible,
                    drawerWidth: drawerWidth
                ) {
                    withAnimation(SilkAnimation.adaptive(reduceMotion: reduceMotion, preferred: .silkSnappy)) {
                        player.togglePlaylistDrawer()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .opacity(isHandleVisible ? 1.0 : 0.0)
                .allowsHitTesting(isHandleVisible)
                .animation(.easeInOut(duration: 0.2), value: isHandleVisible)
                .zIndex(26)
```

---

### 修复 3：`Sources/SilkPlayer/App/PlayerWindowManager.swift` & `PlayerCore.swift` —— 彻底根治“退出全屏变最大且侵入 Dock”与“双击顶栏无法缩小”

#### 3.1 修改 `Sources/SilkPlayer/PlayerCore.swift` 的 `toggleFullscreen()`：
```swift
    public func toggleFullscreen() {
        guard let window = hostWindow ?? NSApp.keyWindow else { return }
        guard !isFullscreenTransitioning else { return }
        if !isFullscreen && !window.styleMask.contains(.fullScreen) {
            isPlaylistDrawerVisible = false
            (window.delegate as? PlayerWindowDelegate)?.capturePreFullScreenFrameIfNeeded(window: window)
        }
        isFullscreenTransitioning = true
        window.toggleFullScreen(nil)
    }
```

#### 3.2 修改 `Sources/SilkPlayer/App/PlayerWindowManager.swift` 的 `PlayerWindowDelegate`：

必须同时解决三个问题：
1. **`isTilingOrSnapSize` 绝不能把全屏尺寸或最大化尺寸当成分屏吸附**！
2. **全屏进出期间（`isFullscreenTransitioning`），`windowWillResize` 100% 放行，`windowDidResize` 100% 禁止调用 `setFrame` 打断动画**；并在 `windowDidExitFullScreen` 结束时精确校验并恢复 `savedPreFullScreenFrame`，确保退出全屏后 100% 回到进入全屏前的普通窗口尺寸，绝不侵入 Dock！
3. **`toggleMaximize` 智能双向切换**：判断当前窗口是否已经处于（或接近）最大尺寸（`curW >= maxContent.width - 16 && curH >= maxContent.height - 16`）。如果已经是最大尺寸，即使 `savedPreZoomFrame` 为 `nil`，也必须缩小回标准居中窗口尺寸（如 `screenFrame.width * 0.55` 的等比尺寸或 `960 × 540`），绝不卡死在最大化状态！

请将 `PlayerWindowDelegate` 完整更新为以下代码：

```swift
@MainActor
public final class PlayerWindowDelegate: NSObject, NSWindowDelegate {
    public weak var session: PlayerWindowSession?
    public weak var player: (any PlayerControllable)?
    public private(set) var isMaximizingOrRestoring: Bool = false
    private var isAdjustingWindowFrame: Bool = false
    private var isFullscreenTransitioning: Bool = false
    private var savedPreZoomFrame: NSRect? = nil
    private var savedPreFullScreenFrame: NSRect? = nil

    public init(session: PlayerWindowSession? = nil, player: (any PlayerControllable)? = nil) {
        self.session = session
        self.player = player
        super.init()
    }

    public func capturePreFullScreenFrameIfNeeded(window: NSWindow) {
        guard !window.styleMask.contains(.fullScreen), !isFullscreenTransitioning else { return }
        let f = window.frame
        guard !f.origin.x.isNaN, !f.origin.y.isNaN, !f.width.isNaN, !f.height.isNaN,
              f.width >= 320, f.height >= 240 else { return }
        if let screen = window.screen ?? NSScreen.main {
            // 严禁把超出可用工作区高度的全屏帧保存为普通窗口帧
            if f.height > screen.visibleFrame.height + 2.0 {
                return
            }
        }
        savedPreFullScreenFrame = f
    }

    /// Checks whether the target frameSize matches macOS native window tiling / split-screen geometry
    /// (e.g. left/right half screen in macOS 15 Sequoia, quarter screen, top/bottom half)
    private func isTilingOrSnapSize(_ size: NSSize, screen: NSScreen?, screenFrame: NSRect) -> Bool {
        // 1. 严禁将物理全屏尺寸（screen.frame.size）误判为分屏！
        if let fullScreenSize = screen?.frame.size {
            if abs(size.width - fullScreenSize.width) <= 8.0 && abs(size.height - fullScreenSize.height) <= 8.0 {
                return false
            }
        }
        // 2. 严禁将整个可用工作区尺寸（最大化）误判为半屏/四分之一分屏！
        let tolerance: CGFloat = 40.0
        if abs(size.width - screenFrame.width) <= tolerance && abs(size.height - screenFrame.height) <= tolerance {
            return false
        }
        // 3. 任何高度超过可用工作区高度的尺寸（例如全屏过渡帧）绝不是分屏！
        if size.height > screenFrame.height + 2.0 || size.width > screenFrame.width + 2.0 {
            return false
        }

        // A. 左右分屏（高度等于可用区高度，宽度在 30% ~ 70% 之间）
        if abs(size.height - screenFrame.height) <= tolerance &&
           size.width >= screenFrame.width * 0.30 &&
           size.width <= screenFrame.width * 0.70 {
            return true
        }
        // B. 上下分屏（宽度等于可用区宽度，高度在 30% ~ 70% 之间）
        if abs(size.width - screenFrame.width) <= tolerance &&
           size.height >= screenFrame.height * 0.30 &&
           size.height <= screenFrame.height * 0.70 {
            return true
        }
        // C. 四分之一分屏（宽高均约为可用区的 50%）
        if abs(size.width - screenFrame.width * 0.5) <= tolerance &&
           abs(size.height - screenFrame.height * 0.5) <= tolerance {
            return true
        }
        return false
    }

    public func windowWillResize(_ window: NSWindow, to frameSize: NSSize) -> NSSize {
        let idleMinW: CGFloat = 640
        let screen = window.screen ?? NSScreen.main
        let screenFrame = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)
        let maxSize = screenFrame.size

        // Sanity guard against NaN or non-positive sizes
        if frameSize.width.isNaN || frameSize.height.isNaN || frameSize.width <= 0 || frameSize.height <= 0 {
            return window.frame.size
        }

        // 在全屏模式、全屏进出过渡期、或等比最大化/还原期间，100% 原样放行！
        if window.styleMask.contains(.fullScreen) ||
           isFullscreenTransitioning ||
           player?.isFullscreen == true ||
           player?.isFullscreenTransitioning == true ||
           isMaximizingOrRestoring {
            return frameSize
        }

        // 如果非用户手动拖拽且传入的是整个物理屏幕尺寸（AppKit 全屏调用首帧），直接放行
        if !window.inLiveResize, let fullSz = screen?.frame.size,
           abs(frameSize.width - fullSz.width) <= 2.0 && abs(frameSize.height - fullSz.height) <= 2.0 {
            return frameSize
        }

        // Allow Shift-key freeform resizing without aspect ratio constraints during interactive dragging
        if window.inLiveResize && NSEvent.modifierFlags.contains(.shift) {
            let minSide: CGFloat = (player?.isAudioOnly == true) ? 380.0 : 360.0
            let minWidth: CGFloat = (player?.isAudioOnly == true) ? 380.0 : idleMinW
            return NSSize(
                width: max(minWidth, min(maxSize.width, frameSize.width)),
                height: max(minSide, min(maxSize.height, frameSize.height))
            )
        }

        // Dedicated pure-audio window resize branch: strictly maintain 1:1 proportional (等比) square resizing
        if player?.isAudioOnly == true {
            let minAudioSize: CGFloat = 380.0
            let maxAudioDimension = min(maxSize.width, maxSize.height)

            let curSize = window.frame.size
            let deltaW = abs(frameSize.width - curSize.width)
            let deltaH = abs(frameSize.height - curSize.height)

            var targetSide: CGFloat
            if deltaH > deltaW && deltaH > 1.0 {
                targetSide = frameSize.height
            } else {
                targetSide = frameSize.width
            }

            targetSide = max(minAudioSize, min(maxAudioDimension, targetSide))
            return NSSize(width: round(targetSide), height: round(targetSide))
        }

        guard let player = self.player, (player.videoWidth > 0 || player.videoHeight > 0) else {
            if !window.inLiveResize && isTilingOrSnapSize(frameSize, screen: screen, screenFrame: screenFrame) {
                return NSSize(
                    width: min(maxSize.width, frameSize.width),
                    height: min(maxSize.height, frameSize.height)
                )
            }
            return NSSize(
                width: max(idleMinW, min(maxSize.width, frameSize.width)),
                height: max(360, min(maxSize.height, frameSize.height))
            )
        }

        let baseAspect = player.effectiveAspectRatio
        let minContentSz = PlayerGeometry.minimumContentSize(for: baseAspect, screenVisibleHeight: screenFrame.height)
        let minW = minContentSz.width
        let minH = minContentSz.height

        // Video-Adaptive Split Screen Tiling ("播放自适应分屏"):
        // Only trigger when NOT in interactive live resize dragging
        if !window.inLiveResize && isTilingOrSnapSize(frameSize, screen: screen, screenFrame: screenFrame) {
            let tolerance: CGFloat = 40.0

            // 1. Full-height vertical split (e.g. Left half, Right half, 1/3, 2/3 column tiles)
            if abs(frameSize.height - screenFrame.height) <= tolerance {
                let targetW = min(maxSize.width, frameSize.width)
                let adaptiveH = round(targetW / max(0.001, baseAspect))
                if adaptiveH <= screenFrame.height {
                    return NSSize(width: round(targetW), height: round(adaptiveH))
                } else {
                    let targetH = screenFrame.height
                    let targetW = min(frameSize.width, round(targetH * baseAspect))
                    return NSSize(width: round(targetW), height: round(targetH))
                }
            }

            // 2. Full-width horizontal split (e.g. Top half, Bottom half)
            if abs(frameSize.width - screenFrame.width) <= tolerance {
                let targetH = min(maxSize.height, frameSize.height)
                let adaptiveW = round(targetH * baseAspect)
                if adaptiveW <= screenFrame.width {
                    return NSSize(width: round(adaptiveW), height: round(targetH))
                } else {
                    let targetW = screenFrame.width
                    let targetH = min(maxSize.height, round(targetW / max(0.001, baseAspect)))
                    return NSSize(width: round(targetW), height: round(targetH))
                }
            }

            // 3. Quarter-screen grid tiling (Half width & Half height)
            let boxW = min(maxSize.width, frameSize.width)
            let boxH = min(maxSize.height, frameSize.height)
            let boxAspect = boxW / max(1.0, boxH)
            if baseAspect >= boxAspect {
                let targetW = boxW
                let targetH = min(boxH, round(targetW / max(0.001, baseAspect)))
                return NSSize(width: round(targetW), height: round(targetH))
            } else {
                let targetH = boxH
                let targetW = min(boxW, round(targetH * baseAspect))
                return NSSize(width: round(targetW), height: round(targetH))
            }
        }

        let curSize = window.frame.size
        let deltaW = abs(frameSize.width - curSize.width)
        let deltaH = abs(frameSize.height - curSize.height)

        var targetW: CGFloat
        var targetH: CGFloat

        if deltaH > deltaW && deltaH > 1.0 {
            targetH = frameSize.height
            targetW = targetH * baseAspect
        } else {
            targetW = frameSize.width
            targetH = targetW / max(0.001, baseAspect)
        }

        if targetW < minW {
            targetW = minW
            targetH = targetW / max(0.001, baseAspect)
        }
        if targetH < minH {
            targetH = minH
            targetW = targetH * baseAspect
        }

        if targetW > maxSize.width {
            targetW = maxSize.width
            targetH = round(targetW / max(0.001, baseAspect))
        }
        if targetH > maxSize.height {
            targetH = maxSize.height
            targetW = round(targetH * baseAspect)
        }
        if targetW > maxSize.width {
            targetW = maxSize.width
            targetH = round(targetW / max(0.001, baseAspect))
        }
        targetW = min(targetW, maxSize.width)
        targetH = min(targetH, maxSize.height)

        if targetW.isNaN || targetH.isNaN || targetW <= 0 || targetH <= 0 {
            return frameSize
        }

        return NSSize(width: round(targetW), height: round(targetH))
    }

    public func windowDidEndLiveResize(_ notification: Notification) {
        guard let window = notification.object as? NSWindow,
              !window.styleMask.contains(.fullScreen),
              !isFullscreenTransitioning,
              let player = self.player else { return }

        // 用户手动拖拽改变了窗口大小：清空最大化记忆并更新全屏前的普通窗口尺寸
        savedPreZoomFrame = nil

        let screen = window.screen ?? NSScreen.main
        let screenFrame = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)
        var curFrame = window.frame
        var adjusted = false

        if curFrame.height > screenFrame.height {
            curFrame.size.height = screenFrame.height
            adjusted = true
        }
        if curFrame.minY < screenFrame.minY {
            curFrame.origin.y = screenFrame.minY
            adjusted = true
        }
        if curFrame.maxY > screenFrame.maxY {
            curFrame.origin.y = max(screenFrame.minY, screenFrame.maxY - curFrame.height)
            adjusted = true
        }
        if curFrame.minX < screenFrame.minX {
            curFrame.origin.x = screenFrame.minX
            adjusted = true
        }
        if curFrame.maxX > screenFrame.maxX {
            curFrame.origin.x = max(screenFrame.minX, screenFrame.maxX - curFrame.width)
            adjusted = true
        }

        if adjusted {
            isAdjustingWindowFrame = true
            window.setFrame(curFrame, display: true, animate: false)
            isAdjustingWindowFrame = false
        }

        capturePreFullScreenFrameIfNeeded(window: window)

        let contentSize = window.contentRect(forFrameRect: window.frame).size
        if player.videoWidth > 0 || player.videoHeight > 0 {
            player.updateRememberedWindowSize(contentSize)
        }
    }

    public func windowDidResize(_ notification: Notification) {
        // 全屏或过渡期间绝对禁止在 windowDidResize 中调用 setFrame 打断动画！
        guard !isFullscreenTransitioning,
              !isMaximizingOrRestoring,
              !isAdjustingWindowFrame,
              player?.isFullscreen != true,
              player?.isFullscreenTransitioning != true else { return }

        guard let window = notification.object as? NSWindow,
              !window.styleMask.contains(.fullScreen) else { return }

        if window.inLiveResize {
            return
        }

        isAdjustingWindowFrame = true
        defer { isAdjustingWindowFrame = false }

        let screen = window.screen ?? NSScreen.main
        let screenFrame = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)
        var curFrame = window.frame
        var adjusted = false

        // 0. 高度防溢出保护：窗口高度绝不能超过可用工作区高度（防止侵入 Dock）
        if curFrame.height > screenFrame.height {
            curFrame.size.height = screenFrame.height
            if let player = self.player, !player.isAudioOnly, player.videoWidth > 0, player.videoHeight > 0 {
                curFrame.size.width = min(screenFrame.width, round(curFrame.size.height * player.effectiveAspectRatio))
            }
            adjusted = true
        }

        // 1. Strict dock invasion defense: bottom of window must never sink below screenFrame.minY
        if curFrame.minY < screenFrame.minY {
            curFrame.origin.y = screenFrame.minY
            adjusted = true
        }

        // 2. Strict menu bar invasion defense: top of window must never exceed screenFrame.maxY
        if curFrame.maxY > screenFrame.maxY {
            curFrame.origin.y = max(screenFrame.minY, screenFrame.maxY - curFrame.height)
            adjusted = true
        }

        // 3. Screen horizontal boundaries clamp
        if curFrame.minX < screenFrame.minX {
            curFrame.origin.x = screenFrame.minX
            adjusted = true
        }
        if curFrame.maxX > screenFrame.maxX {
            curFrame.origin.x = max(screenFrame.minX, screenFrame.maxX - curFrame.width)
            adjusted = true
        }

        if adjusted {
            window.setFrame(curFrame, display: true, animate: false)
        }

        // 4. Video-adaptive vertical centering on half-screen snap
        if let player = self.player, !player.isAudioOnly, player.videoWidth > 0, player.videoHeight > 0 {
            let isLeftDocked = abs(curFrame.minX - screenFrame.minX) <= 10.0
            let isRightDocked = abs(curFrame.maxX - screenFrame.maxX) <= 10.0
            let isHalfWidth = abs(curFrame.width - round(screenFrame.width * 0.5)) <= 40.0

            if (isLeftDocked || isRightDocked) && isHalfWidth && curFrame.height < screenFrame.height - 20.0 {
                let targetY = round(screenFrame.origin.y + (screenFrame.height - curFrame.height) * 0.5)
                if abs(curFrame.origin.y - targetY) > 2.0 {
                    window.setFrameOrigin(NSPoint(x: curFrame.origin.x, y: targetY))
                }
            }
        }
    }

    public func windowWillUseStandardFrame(_ window: NSWindow, defaultFrame: NSRect) -> NSRect {
        guard let player = self.player else { return defaultFrame }

        if player.isAudioOnly {
            let sz: CGFloat = 520
            let cx = round(defaultFrame.minX + (defaultFrame.width - sz) / 2)
            let cy = round(defaultFrame.minY + (defaultFrame.height - sz) / 2)
            return NSRect(x: cx, y: cy, width: sz, height: sz)
        }

        return defaultFrame
    }

    public func toggleMaximize(window: NSWindow) {
        guard !window.styleMask.contains(.fullScreen), !isFullscreenTransitioning else { return }
        let screen = window.screen ?? NSScreen.main
        guard let screenFrame = screen?.visibleFrame else { return }

        isMaximizingOrRestoring = true
        isAdjustingWindowFrame = true
        defer {
            isAdjustingWindowFrame = false
            isMaximizingOrRestoring = false
        }

        // A. 纯音频模式：固定 520x520 居中
        if player?.isAudioOnly == true {
            let sz: CGFloat = 520
            let cx = round(screenFrame.midX - sz / 2)
            let cy = round(screenFrame.midY - sz / 2)
            let targetFrame = NSRect(x: cx, y: cy, width: sz, height: sz)
            window.setFrame(targetFrame, display: true, animate: true)
            return
        }

        // B. 闲置窗口（未加载视频）：在 screenFrame 与 960x540 之间双向切换
        guard let player = self.player, player.videoWidth > 0, player.videoHeight > 0 else {
            let isCurrentlyMax = abs(window.frame.width - screenFrame.width) <= 24.0 &&
                                 abs(window.frame.height - screenFrame.height) <= 24.0
            if isCurrentlyMax {
                let restore = savedPreZoomFrame ?? NSRect(
                    x: round(screenFrame.midX - 480),
                    y: round(screenFrame.midY - 270),
                    width: 960,
                    height: 540
                )
                savedPreZoomFrame = nil
                window.setFrame(restore, display: true, animate: true)
            } else {
                savedPreZoomFrame = window.frame
                window.setFrame(screenFrame, display: true, animate: true)
            }
            return
        }

        // C. 视频播放态：计算当前屏幕可用区内的最大等比安全尺寸
        let aspect = player.effectiveAspectRatio
        let maxContent = PlayerGeometry.maximumSafeContentSize(for: aspect, screenVisibleSize: screenFrame.size)
        let maxW = round(maxContent.width)
        let maxH = round(maxContent.height)

        // 判断当前窗口是否已经处于（或非常接近）等比最大化尺寸
        let isCurrentlyAtMax = abs(window.frame.width - maxW) <= 24.0 &&
                               abs(window.frame.height - maxH) <= 24.0

        if isCurrentlyAtMax {
            // 当前已经是最大尺寸 -> 必须缩小还原！（若 savedPreZoomFrame 存在且比最大尺寸小，则用它；否则缩回 55% 标准居中尺寸）
            let restoreFrame: NSRect
            if let saved = savedPreZoomFrame,
               (abs(saved.width - maxW) > 24.0 || abs(saved.height - maxH) > 24.0) {
                restoreFrame = saved
            } else {
                let stdW: CGFloat
                let stdH: CGFloat
                if player.isEffectiveVertical {
                    stdH = round(screenFrame.height * 0.60)
                    stdW = round(stdH * aspect)
                } else {
                    stdW = round(screenFrame.width * 0.55)
                    stdH = round(stdW / max(0.001, aspect))
                }
                let cx = round(screenFrame.midX - stdW / 2)
                let cy = round(screenFrame.midY - stdH / 2)
                restoreFrame = NSRect(x: cx, y: cy, width: stdW, height: stdH)
            }
            savedPreZoomFrame = nil
            savedPreFullScreenFrame = restoreFrame
            window.setFrame(restoreFrame, display: true, animate: true)
        } else {
            // 当前是普通小窗口 -> 记录当前帧并放大到最大等比居中尺寸
            savedPreZoomFrame = window.frame
            let targetX = round(screenFrame.midX - maxW / 2)
            let targetY = round(screenFrame.midY - maxH / 2)
            let targetFrame = NSRect(x: targetX, y: targetY, width: maxW, height: maxH)
            savedPreFullScreenFrame = targetFrame
            window.setFrame(targetFrame, display: true, animate: true)
        }
    }

    public func windowShouldZoom(_ window: NSWindow, toFrame newFrame: NSRect) -> Bool {
        toggleMaximize(window: window)
        return false
    }

    public func windowWillEnterFullScreen(_ notification: Notification) {
        if let window = notification.object as? NSWindow {
            capturePreFullScreenFrameIfNeeded(window: window)
            window.contentAspectRatio = .zero
            window.aspectRatio = .zero
        }
        isFullscreenTransitioning = true
        player?.isFullscreenTransitioning = true
    }

    public func windowDidEnterFullScreen(_ notification: Notification) {
        isFullscreenTransitioning = false
        player?.isFullscreenTransitioning = false
        player?.setFullscreenState(true)
    }

    public func windowWillExitFullScreen(_ notification: Notification) {
        isFullscreenTransitioning = true
        player?.isFullscreenTransitioning = true
        if let window = notification.object as? NSWindow {
            window.contentAspectRatio = .zero
            window.aspectRatio = .zero
        }
    }

    public func windowDidExitFullScreen(_ notification: Notification) {
        isFullscreenTransitioning = false
        player?.isFullscreenTransitioning = false
        player?.setFullscreenState(false)

        if let window = notification.object as? NSWindow {
            let screen = window.screen ?? NSScreen.main
            let screenFrame = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)

            // 强制校验并恢复进入全屏前的普通窗口尺寸，彻底杜绝退出全屏后变大或侵入 Dock 栏
            if let saved = savedPreFullScreenFrame {
                let clampedW = min(saved.width, screenFrame.width)
                let clampedH = min(saved.height, screenFrame.height)
                let clampedX = max(screenFrame.minX, min(screenFrame.maxX - clampedW, saved.origin.x))
                let clampedY = max(screenFrame.minY, min(screenFrame.maxY - clampedH, saved.origin.y))
                let targetFrame = NSRect(x: clampedX, y: clampedY, width: clampedW, height: clampedH)

                if abs(window.frame.width - targetFrame.width) > 2.0 ||
                   abs(window.frame.height - targetFrame.height) > 2.0 ||
                   abs(window.frame.origin.x - targetFrame.origin.x) > 2.0 ||
                   abs(window.frame.origin.y - targetFrame.origin.y) > 2.0 {
                    isAdjustingWindowFrame = true
                    window.setFrame(targetFrame, display: true, animate: false)
                    isAdjustingWindowFrame = false
                }
            }
        }

        player?.applyContentAspectRatioLock()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            if let player = self?.player, !player.isPlaying {
                player.renderCurrentFrameImmediately()
            }
        }
    }

    public func windowDidFailToEnterFullScreen(_ window: NSWindow) {
        isFullscreenTransitioning = false
        player?.isFullscreenTransitioning = false
    }

    public func windowDidFailToExitFullScreen(_ window: NSWindow) {
        isFullscreenTransitioning = false
        player?.isFullscreenTransitioning = false
    }

    public func windowWillClose(_ notification: Notification) {
        player?.stop()
    }
}
```

---

### 修复 4：`Sources/SilkPlayer/VideoView.swift` —— 修复 `performDrag` 重复触发与双击事件防重入

在 `MetalPlayerContainerView` 中：
1. 保存 `private var currentMouseDownEvent: NSEvent? = nil`。
2. 在 `mouseDragged(with:)` 中，一旦位移超过 3.0pt，立刻置 `canDragWindowFromCurrentMouseDown = false`（防止后续 `mouseDragged` 重复重入调用 `performDrag`），并调用 `window.performDrag(with: currentMouseDownEvent ?? event)`！
3. 双击（`event.clickCount == 2`）触发全屏或最大化时，仅在 `event.clickCount == 2` 时执行（忽略 `clickCount > 2` 的连击洪水），确保不会在双击过快时刚进全屏又立刻触发退全屏！

请将 `VideoView.swift` 中的 `mouseDown`、`mouseDragged`、`mouseUp` 替换为：

```swift
    private var currentMouseDownEvent: NSEvent? = nil

    override public func mouseDown(with event: NSEvent) {
        let loc = self.convert(event.locationInWindow, from: nil)
        let b = bounds
        guard let window = self.window else {
            super.mouseDown(with: event)
            return
        }
        let isFullscreen = window.styleMask.contains(.fullScreen)
        canDragWindowFromCurrentMouseDown = false
        currentMouseDownEvent = event

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

                // 顶栏中间区域双击：最大化/还原或退出全屏（严格匹配 clickCount == 2 防止三连击重入）
                if event.clickCount >= 2 {
                    pendingSingleClickWorkItem?.cancel()
                    pendingSingleClickWorkItem = nil
                    if event.clickCount == 2 {
                        if isFullscreen {
                            player.toggleFullscreen()
                        } else {
                            PlayerWindowManager.shared.toggleMaximize(window: window)
                        }
                    }
                    return
                }

                // 顶栏单击：允许拖拽窗口
                canDragWindowFromCurrentMouseDown = !isFullscreen
                dragInitialMouseScreenLocation = NSEvent.mouseLocation
                dragInitialWindowOrigin = window.frame.origin
                isDraggingWindow = false
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

            if event.clickCount == 2 {
                // 沉浸态下顶部 28pt 仍允许窗口最大化
                if !isFullscreen && !player.isHUDVisible && loc.y >= b.height - 28.0 {
                    PlayerWindowManager.shared.toggleMaximize(window: window)
                    return
                }
                self.handleDoubleClickAction()
            }
            return
        }

        // 单击准备与画布拖拽授权
        canDragWindowFromCurrentMouseDown = !isFullscreen
        dragInitialMouseScreenLocation = NSEvent.mouseLocation
        dragInitialWindowOrigin = window.frame.origin
        isDraggingWindow = false
    }

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
            canDragWindowFromCurrentMouseDown = false
            isDraggingWindow = true
            window.performDrag(with: currentMouseDownEvent ?? event)
            isDraggingWindow = false
        }
    }
```

---

### 修复 5：`Sources/SilkPlayer/Player/EmptyPlaybackView.swift` —— 消除双重边距死区与拖拽重入

在 `EmptyPlaybackView.swift` 中：
1. `WindowDragGestureView` 已经设置了 `.padding(12)`（已经避开了窗口四周边框 12pt 的系统拉伸手柄），因此 `WindowDragCanvasView.mouseDown` 里**严禁再重复加 `margin: 8.0` 拦截**！
2. 同样在 `mouseDragged` 中使用 `canDrag` 锁死单次 `performDrag`：

```swift
public final class WindowDragCanvasView: NSView {
    private var initialMouseLocation: NSPoint = .zero
    private var canDrag: Bool = false
    private var downEvent: NSEvent? = nil

    override public func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override public func mouseDown(with event: NSEvent) {
        guard let window = self.window else { return }
        let loc = self.convert(event.locationInWindow, from: nil)
        let b = bounds

        if event.clickCount >= 2 {
            canDrag = false
            if event.clickCount == 2 {
                if loc.y >= b.height - 52.0 {
                    PlayerWindowManager.shared.toggleMaximize(window: window)
                } else if AppSettings.shared.doubleClickAction == .openFile {
                    PlayerWindowManager.shared.openFilePicker()
                }
            }
            return
        }
        initialMouseLocation = NSEvent.mouseLocation
        downEvent = event
        canDrag = !window.styleMask.contains(.fullScreen)
    }

    override public func mouseDragged(with event: NSEvent) {
        guard canDrag, let window = self.window, !window.styleMask.contains(.fullScreen) else { return }
        let current = NSEvent.mouseLocation
        if hypot(current.x - initialMouseLocation.x, current.y - initialMouseLocation.y) > 3.0 {
            canDrag = false
            window.performDrag(with: downEvent ?? event)
        }
    }
}
```

---

## 三、 验证要求
执行 Agent 完成上述 5 处修改后，运行 `./scripts/run_tests.sh` 确保编译与测试 100% 通过。
