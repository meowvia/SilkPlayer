import SwiftUI
import AppKit
import QuartzCore
import SilkCoreKit

// MARK: - Metal Native Player Container View
public final class MetalPlayerContainerView: NSView {
    public weak var playerCore: PlayerCore?
    private var trackingArea: NSTrackingArea?
    private var dragInitialMouseScreenLocation: NSPoint = .zero
    private var dragInitialWindowOrigin: NSPoint = .zero
    private var isDraggingWindow: Bool = false
    private var canDragWindowFromCurrentMouseDown: Bool = false
    private var pendingSingleClickWorkItem: DispatchWorkItem?
    private var lastMouseActivityTime: TimeInterval = 0

    override public var acceptsFirstResponder: Bool { true }

    public init(playerCore: PlayerCore) {
        self.playerCore = playerCore
        super.init(frame: .zero)
        self.wantsLayer = true
        self.layer?.backgroundColor = playerCore.isAudioOnly ? NSColor.clear.cgColor : NSColor.black.cgColor

        // Register for file drag & drop
        registerForDraggedTypes([.fileURL])

        // Attach player core's hardware render view
        playerCore.attachRenderContainer(self)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        applyRenderViewLayout()
    }

    override public func layout() {
        super.layout()
        applyRenderViewLayout()
    }

    override public func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        applyRenderViewLayout()
    }

    public var metalRenderView: SilkMetalRenderView? {
        playerCore?.playerLayer?.player.view as? SilkMetalRenderView
    }

    override public func viewWillStartLiveResize() {
        super.viewWillStartLiveResize()
    }

    override public func viewDidEndLiveResize() {
        super.viewDidEndLiveResize()
        applyRenderViewLayout()
        if let p = playerCore, !p.isPlaying {
            p.renderCurrentFrameImmediately()
        }
    }

    public func applyRenderViewLayout() {
        if let p = playerCore, p.isAudioOnly {
            self.layer?.backgroundColor = NSColor.clear.cgColor
            metalRenderView?.isHidden = true
            return
        } else {
            self.layer?.backgroundColor = NSColor.black.cgColor
            metalRenderView?.isHidden = false
        }
        guard let view = playerCore?.playerLayer?.player.view else { return }
        let b = bounds
        guard b.width > 0, b.height > 0 else { return }

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }

        view.wantsLayer = true
        view.layer?.contentsGravity = .resizeAspect

        if let metalView = view as? SilkMetalRenderView, let p = playerCore {
            metalView.transformUniforms = MetalTransformUniforms(
                rotation: Int32(p.transform.effectiveRotation),
                flipH: p.transform.flipH ? 1 : 0,
                flipV: p.transform.flipV ? 1 : 0
            )
            metalView.targetAspect = p.transform.displayAspectRatio(
                rawWidth: p.displayVideoWidth > 0 ? p.displayVideoWidth : p.videoWidth,
                rawHeight: p.displayVideoHeight > 0 ? p.displayVideoHeight : p.videoHeight,
                ratioSetting: p.videoAspectRatio
            )
            if !p.isPlaying {
                metalView.updateMetalGeometryAndRedraw()
            }
        }

        // 精准计算保持视频原始比例的画面视口帧，居中悬浮于黑色底座之上：
        // 彻底杜绝全屏与窗口拉伸期间的画面撕裂与人物变形
        var videoFrame = b
        if let p = playerCore, p.videoWidth > 0, p.videoHeight > 0 {
            let aspect = p.transform.displayAspectRatio(
                rawWidth: p.displayVideoWidth > 0 ? p.displayVideoWidth : p.videoWidth,
                rawHeight: p.displayVideoHeight > 0 ? p.displayVideoHeight : p.videoHeight,
                ratioSetting: p.videoAspectRatio
            )
            let safeAspect = max(0.001, aspect)
            let containerAspect = b.width / max(1.0, b.height)

            if abs(containerAspect - safeAspect) > 0.002 {
                if containerAspect > safeAspect {
                    // 容器更宽（如 21:9 全屏播放 16:9 视频）：高度撑满，宽度等比居中
                    let vH = b.height
                    let vW = round(vH * safeAspect)
                    let vX = round((b.width - vW) / 2.0)
                    videoFrame = NSRect(x: vX, y: 0, width: vW, height: vH)
                } else {
                    // 容器更高（如宽屏播放竖屏视频）：宽度撑满，高度等比居中
                    let vW = b.width
                    let vH = round(vW / safeAspect)
                    let vY = round((b.height - vH) / 2.0)
                    videoFrame = NSRect(x: 0, y: vY, width: vW, height: vH)
                }
            }
        }

        view.autoresizingMask = []
        view.layer?.setAffineTransform(.identity)
        view.frame = videoFrame
    }

    // MARK: - Drag and Drop Destination
    override public func draggingEntered(_ sender: any NSDraggingInfo) -> NSDragOperation {
        let pboard = sender.draggingPasteboard
        if let urls = pboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL], !urls.isEmpty {
            DispatchQueue.main.async { [weak self] in
                self?.playerCore?.isDragTargeted = true
            }
            return .copy
        }
        return []
    }

    override public func draggingUpdated(_ sender: any NSDraggingInfo) -> NSDragOperation {
        return .copy
    }

    override public func draggingExited(_ sender: (any NSDraggingInfo)?) {
        DispatchQueue.main.async { [weak self] in
            self?.playerCore?.isDragTargeted = false
        }
    }

    override public func prepareForDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        return true
    }

    override public func performDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        DispatchQueue.main.async { [weak self] in
            self?.playerCore?.isDragTargeted = false
        }
        let pboard = sender.draggingPasteboard
        if let urls = pboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL], !urls.isEmpty {
            DispatchQueue.main.async { [weak self] in
                self?.playerCore?.handleDroppedURLs(urls)
            }
            return true
        }
        return false
    }

    // MARK: - Trackpad & Scroll Gesture Handling (Volume & Scrubbing)
    private enum ScrollGestureAxis {
        case undefined
        case horizontal // Seeking
        case vertical   // Volume
    }
    private var currentGestureAxis: ScrollGestureAxis = .undefined
    private var accumulatedScrubDelta: CGFloat = 0.0
    private var scrubInitialTime: Double = 0.0

    override public func scrollWheel(with event: NSEvent) {
        guard let player = playerCore else {
            super.scrollWheel(with: event)
            return
        }

        // 1. 触控板连续平滑手势（双指滑动，有手势阶段 began / changed / ended / cancelled）
        if !event.phase.isEmpty {
            switch event.phase {
            case .began:
                currentGestureAxis = .undefined
                accumulatedScrubDelta = 0.0
                scrubInitialTime = player.currentTime

            case .changed:
                if currentGestureAxis == .undefined {
                    let dx = abs(event.scrollingDeltaX)
                    let dy = abs(event.scrollingDeltaY)
                    if dx > 1.2 || dy > 1.2 {
                        currentGestureAxis = (dy >= dx) ? .vertical : .horizontal
                        if currentGestureAxis == .horizontal {
                            player.startScrubbing()
                        }
                    }
                }

                if currentGestureAxis == .vertical {
                    let deltaY = Double(event.scrollingDeltaY)
                    if AppSettings.shared.scrollWheelAction == .seek {
                        let stepSign = deltaY > 0 ? 1.0 : (deltaY < 0 ? -1.0 : 0.0)
                        player.step(seconds: stepSign * AppSettings.shared.shortSeekStep)
                    } else {
                        let step = deltaY * 0.15
                        player.adjustVolume(by: step)
                    }
                    player.reportUserActivity()
                } else if currentGestureAxis == .horizontal {
                    accumulatedScrubDelta += event.scrollingDeltaX
                    let duration = player.duration > 0 ? player.duration : 100.0
                    let scrubSpeedFactor = max(10.0, duration * 0.035)
                    let scrubOffset = Double(accumulatedScrubDelta / 300.0) * scrubSpeedFactor
                    let targetTime = max(0.0, min(duration, scrubInitialTime + scrubOffset))
                    player.updateScrubbing(to: targetTime)
                    player.showSeekOSD(targetTime: targetTime, offset: scrubOffset, duration: duration)
                    player.reportUserActivity()
                }

            case .ended, .cancelled:
                if currentGestureAxis == .horizontal {
                    let duration = player.duration > 0 ? player.duration : 100.0
                    let scrubSpeedFactor = max(10.0, duration * 0.035)
                    let scrubOffset = Double(accumulatedScrubDelta / 300.0) * scrubSpeedFactor
                    let targetTime = max(0.0, min(duration, scrubInitialTime + scrubOffset))
                    player.finishScrubbing(to: targetTime)
                }
                currentGestureAxis = .undefined
                accumulatedScrubDelta = 0.0

            default:
                break
            }
            return
        }

        // 2. 传统机械滚轮鼠标 / 外接鼠标驱动 / 惯性滚轮（phase 为空）
        let rawDeltaY = event.hasPreciseScrollingDeltas ? event.scrollingDeltaY : event.deltaY
        guard abs(rawDeltaY) > 0.001 else { return }

        player.reportUserActivity()

        if AppSettings.shared.scrollWheelAction == .seek {
            let stepSign = rawDeltaY > 0 ? 1.0 : -1.0
            player.step(seconds: stepSign * AppSettings.shared.shortSeekStep)
        } else {
            // 音量调节：精确滚轮按增量微调，机械单步滚轮每格调节 3%
            let step: Double
            if event.hasPreciseScrollingDeltas {
                step = Double(rawDeltaY) * 0.20
            } else {
                step = (rawDeltaY > 0 ? 1.0 : -1.0) * 3.0
            }
            player.adjustVolume(by: step)
        }
    }

    // MARK: - Mouse Tracking & Double-Click
    override public func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }

    override public func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseMoved, .mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        self.trackingArea = area
    }

    override public func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        let now = CACurrentMediaTime()
        guard now - lastMouseActivityTime >= 0.05 else { return }
        lastMouseActivityTime = now
        DispatchQueue.main.async { [weak self] in
            self?.playerCore?.reportUserActivity()
        }
    }

    override public func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        DispatchQueue.main.async { [weak self] in
            self?.playerCore?.reportUserActivity()
        }
    }

    override public func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
    }

    override public func menu(for event: NSEvent) -> NSMenu? {
        guard let player = playerCore, !player.isAudioOnly else { return nil }
        let menu = NSMenu()

        let rotateCW = NSMenuItem(
            title: L10n.tr("Rotate 90° Clockwise", "顺时针旋转 90°"),
            action: #selector(handleRotateCW(_:)),
            keyEquivalent: ""
        )
        rotateCW.target = self
        menu.addItem(rotateCW)

        let rotateCCW = NSMenuItem(
            title: L10n.tr("Rotate 90° Counterclockwise", "逆时针旋转 90°"),
            action: #selector(handleRotateCCW(_:)),
            keyEquivalent: ""
        )
        rotateCCW.target = self
        menu.addItem(rotateCCW)

        let resetRot = NSMenuItem(
            title: L10n.tr("Reset Orientation", "复位"),
            action: #selector(handleResetRotation(_:)),
            keyEquivalent: ""
        )
        resetRot.target = self
        menu.addItem(resetRot)

        menu.addItem(.separator())

        let flipH = NSMenuItem(
            title: L10n.tr("Flip Horizontal", "水平翻转"),
            action: #selector(handleFlipH(_:)),
            keyEquivalent: ""
        )
        flipH.target = self
        flipH.state = player.transform.flipH ? .on : .off
        menu.addItem(flipH)

        let flipV = NSMenuItem(
            title: L10n.tr("Flip Vertical", "垂直翻转"),
            action: #selector(handleFlipV(_:)),
            keyEquivalent: ""
        )
        flipV.target = self
        flipV.state = player.transform.flipV ? .on : .off
        menu.addItem(flipV)

        return menu
    }

    @objc private func handleRotateCW(_ sender: Any?) {
        playerCore?.rotateVideo(clockwise: true)
    }

    @objc private func handleRotateCCW(_ sender: Any?) {
        playerCore?.rotateVideo(clockwise: false)
    }

    @objc private func handleResetRotation(_ sender: Any?) {
        playerCore?.resetVideoRotation()
    }

    @objc private func handleFlipH(_ sender: Any?) {
        playerCore?.toggleFlipHorizontal()
    }

    @objc private func handleFlipV(_ sender: Any?) {
        playerCore?.toggleFlipVertical()
    }

    override public func hitTest(_ point: NSPoint) -> NSView? {
        guard let window = self.window, !window.styleMask.contains(.fullScreen) else {
            return super.hitTest(point)
        }
        let loc = (superview != nil) ? self.convert(point, from: superview) : self.convert(point, from: nil)
        let b = bounds
        let margin: CGFloat = 8.0
        // 四周边框与四角（8pt）绝对放行：返回 nil，直通 AppKit 系统 NSThemeFrame，激活原生八向缩放手柄与原生拖拽循环
        if loc.x <= margin || loc.x >= b.width - margin || loc.y <= margin || loc.y >= b.height - margin {
            return nil
        }
        return super.hitTest(point)
    }

    override public func mouseDown(with event: NSEvent) {
        let loc = self.convert(event.locationInWindow, from: nil)
        let b = bounds
        guard let window = self.window else {
            super.mouseDown(with: event)
            return
        }
        let isFullscreen = window.styleMask.contains(.fullScreen)
        canDragWindowFromCurrentMouseDown = false

        // 1. 边缘 8pt 预留给 AppKit 原生 NSThemeFrame 八向拉伸，绝不在此拦截
        if !isFullscreen {
            let margin: CGFloat = 8.0
            if loc.x <= margin || loc.x >= b.width - margin || loc.y <= margin || loc.y >= b.height - margin {
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

        let isMaximized: Bool
        if let delegate = window.delegate as? PlayerWindowDelegate {
            isMaximized = (delegate.currentInteractiveMode == .maximized)
        } else if let screen = window.screen ?? NSScreen.main {
            let sf = screen.visibleFrame
            isMaximized = (abs(window.frame.width - sf.width) <= 16.0 && abs(window.frame.height - sf.height) <= 16.0)
        } else {
            isMaximized = false
        }

        // 顶栏高度：铺满最大化时为 88pt（确保大屏幕上极其容易双击顶栏还原），普通窗口为 78pt，全屏模式为 56pt
        let topBarHeight: CGFloat = isFullscreen ? 56.0 : (isMaximized ? 88.0 : 78.0)
        let isTopBarArea = (loc.y >= b.height - topBarHeight)
        let isBottomControlArea = (loc.y <= 112.0)

        // 2. 顶栏区域全局判定（无论是 HUD 激活态还是沉浸观影态）
        if isTopBarArea {
            // A. 顶栏双击：窗口模式下 100% 触发铺满最大化 / 还原切换，绝不进入全屏；全屏模式下双击顶栏退出全屏
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

            // B. 顶栏红绿灯与右侧操作按钮：HUD 激活时放行给子视图按钮响应
            let isLeadingTrafficArea = !isFullscreen && loc.x <= 72.0
            let isTrailingActionArea = loc.x >= b.width - 160.0
            if (isLeadingTrafficArea || isTrailingActionArea) && player.isHUDVisible {
                super.mouseDown(with: event)
                return
            }

            // C. 顶栏空白处/标题胶囊处单击：允许拖拽移动窗口（非最大化时）
            canDragWindowFromCurrentMouseDown = !isFullscreen && !isMaximized
            dragInitialMouseScreenLocation = NSEvent.mouseLocation
            dragInitialWindowOrigin = window.frame.origin
            isDraggingWindow = false
            return
        }

        // 3. 底部控制栏区域：禁止任何画布暂停与窗口拖拽
        if isBottomControlArea && player.isHUDVisible {
            canDragWindowFromCurrentMouseDown = false
            return
        }

        // 4. 中间视频画面核心视口区域
        if window.firstResponder !== self {
            window.makeFirstResponder(self)
        }

        if event.clickCount >= 2 {
            pendingSingleClickWorkItem?.cancel()
            pendingSingleClickWorkItem = nil
            if isFullscreen {
                player.toggleFullscreen()
            } else {
                self.handleDoubleClickAction()
            }
            return
        }

        // 画面区域（已排除四周 8pt 边框）单击：允许拖拽移动窗口（超过 3pt 调用 window.performDrag）或松开触发播放/暂停
        canDragWindowFromCurrentMouseDown = !isFullscreen && !isMaximized
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
        let dx = current.x - dragInitialMouseScreenLocation.x
        let dy = current.y - dragInitialMouseScreenLocation.y
        let distance = hypot(dx, dy)
        if distance > 3.0 {
            pendingSingleClickWorkItem?.cancel()
            pendingSingleClickWorkItem = nil
            canDragWindowFromCurrentMouseDown = false
            window.performDrag(with: event)
        }
    }

    override public func mouseUp(with event: NSEvent) {
        canDragWindowFromCurrentMouseDown = false

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

    private func handleDoubleClickAction() {
        guard let player = playerCore else { return }
        switch AppSettings.shared.doubleClickAction {
        case .toggleFullscreen:
            player.toggleFullscreen()
        case .playPause:
            player.togglePlayPause()
        case .openFile:
            PlayerWindowManager.shared.openFilePicker()
        case .none:
            break
        }
    }
}

// MARK: - SwiftUI Representable
public struct VideoView: NSViewRepresentable {
    public let playerCore: PlayerCore

    public init(playerCore: PlayerCore) {
        self.playerCore = playerCore
    }

    public func makeNSView(context: Context) -> MetalPlayerContainerView {
        return MetalPlayerContainerView(playerCore: playerCore)
    }

    public func updateNSView(_ nsView: MetalPlayerContainerView, context: Context) {
        playerCore.attachRenderContainer(nsView)
    }
}
