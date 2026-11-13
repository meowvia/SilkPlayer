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
    private var localMouseDownMonitor: Any?
    private var lastCanvasMouseDownTime: TimeInterval = 0
    private var lastCanvasMouseDownLocation: NSPoint = .zero
    private var lastHandledDoubleClickTime: TimeInterval = 0

    isolated deinit {
        if let monitor = localMouseDownMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    override public var acceptsFirstResponder: Bool { true }

    public init(playerCore: PlayerCore) {
        self.playerCore = playerCore
        super.init(frame: .zero)
        self.wantsLayer = true
        self.layer?.backgroundColor = playerCore.isAudioOnly ? NSColor.clear.cgColor : NSColor.black.cgColor
        self.layer?.masksToBounds = true

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
        if window != nil {
            setupWindowDoubleClickMonitorIfNeeded()
        } else if let monitor = localMouseDownMonitor {
            NSEvent.removeMonitor(monitor)
            localMouseDownMonitor = nil
        }
        applyRenderViewLayout()
    }

    private func setupWindowDoubleClickMonitorIfNeeded() {
        guard localMouseDownMonitor == nil else { return }
        localMouseDownMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown]) { [weak self] event in
            guard let self = self,
                  let window = self.window,
                  event.window === window,
                  let player = self.playerCore,
                  player.isLoaded else {
                return event
            }

            let loc = self.convert(event.locationInWindow, from: nil)
            let b = self.bounds
            guard b.width > 0, b.height > 0, b.contains(loc) else { return event }

            let isFullscreen = window.styleMask.contains(.fullScreen)

            // 1. 四周 8pt 原生缩放边框绝对放行（特别排除右侧播放列表拉手胶囊区域，禁止触发拉伸）
            if !isFullscreen {
                let margin: CGFloat = 8.0
                let isOverHandle = (player.isPlaylistDrawerVisible == false) &&
                    (loc.x >= b.width - 32.0) &&
                    (abs(loc.y - b.height * 0.5) <= 72.0)
                if !isOverHandle && (loc.x <= margin || loc.x >= b.width - margin || loc.y <= margin || loc.y >= b.height - margin) {
                    return event
                }
            }

            // 2. 若点击落在实际原生控件（如 NSPopUpButton）或右侧展开的抽屉内，原样放行
            if let hitView = window.contentView?.hitTest(event.locationInWindow), hitView is NSControl {
                return event
            }
            let activeDrawerWidth: CGFloat = player.isInspectorVisible ? 348.0 :
                (player.isPlaylistDrawerVisible ? (PlaylistDrawerDimensions.drawerWidth(for: b.width, isFullscreen: isFullscreen) + 8.0) : 0.0)
            if activeDrawerWidth > 0 && loc.x >= b.width - activeDrawerWidth && loc.y >= 64 && loc.y <= b.height - 60 {
                return event
            }

            // 3. HUD 激活时，排除右上角快捷按钮热区、左上角红绿灯热区、右侧抽屉拉手热区、以及底部实际控制按钮与进度条热区
            if player.isHUDVisible {
                let topButtonsMinY = b.height - (isFullscreen ? 56.0 : 68.0)
                if loc.y >= topButtonsMinY && (loc.x >= b.width - 148.0 || (!isFullscreen && loc.x <= 78.0)) {
                    return event
                }
                if !player.isPlaylistDrawerVisible && loc.x >= b.width - 32.0 && abs(loc.y - b.height * 0.5) <= 72.0 {
                    return event
                }
                if loc.y <= 86.0 {
                    return event
                }
            }

            // 4. 判定画布双击（兼容系统 clickCount >= 2 以及被 NSHostingView 拆散的快速连击）
            let now = event.timestamp
            let dt = now - self.lastCanvasMouseDownTime
            let dist = hypot(loc.x - self.lastCanvasMouseDownLocation.x, loc.y - self.lastCanvasMouseDownLocation.y)
            let isDoubleClick = (event.clickCount >= 2) || (dt > 0.01 && dt <= min(0.35, NSEvent.doubleClickInterval) && dist <= 12.0)

            self.lastCanvasMouseDownTime = now
            self.lastCanvasMouseDownLocation = loc

            guard isDoubleClick else { return event }
            guard now - self.lastHandledDoubleClickTime > 0.20 else { return nil }
            self.lastHandledDoubleClickTime = now

            self.pendingSingleClickWorkItem?.cancel()
            self.pendingSingleClickWorkItem = nil
            self.canDragWindowFromCurrentMouseDown = false

            let isMaximized: Bool
            if let delegate = window.delegate as? PlayerWindowDelegate {
                isMaximized = (delegate.currentInteractiveMode == .maximized)
            } else {
                isMaximized = false
            }

            let topBarHeight: CGFloat = isFullscreen ? 56.0 : (isMaximized ? 88.0 : 32.0)
            if loc.y >= b.height - topBarHeight {
                if isFullscreen {
                    player.toggleFullscreen()
                } else {
                    PlayerWindowManager.shared.toggleMaximize(window: window)
                }
            } else {
                if isFullscreen {
                    player.toggleFullscreen()
                } else {
                    self.handleDoubleClickAction()
                }
            }
            return nil
        }
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
        let isFullscreen = playerCore?.isFullscreen == true
        if let p = playerCore, p.isAudioOnly {
            self.layer?.backgroundColor = NSColor.clear.cgColor
            metalRenderView?.isHidden = true
            return
        } else {
            self.layer?.backgroundColor = NSColor.black.cgColor
            metalRenderView?.isHidden = false
        }
        self.layer?.cornerRadius = isFullscreen ? 0.0 : 10.0
        self.layer?.masksToBounds = true

        guard let view = playerCore?.playerLayer?.player.view else { return }
        let b = bounds
        guard b.width > 0, b.height > 0 else { return }

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }

        view.wantsLayer = true
        view.layer?.cornerRadius = isFullscreen ? 0.0 : 9.0
        view.layer?.masksToBounds = true
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
        // 窗口模式下施加 1pt 安全内缩，确保四周完整露出系统 1pt 黑色边框底衬，彻底消除边缘溢出断层
        let inset: CGFloat = isFullscreen ? 0.0 : 1.0
        let safeBounds = NSRect(
            x: inset,
            y: inset,
            width: max(1.0, b.width - inset * 2.0),
            height: max(1.0, b.height - inset * 2.0)
        )

        var videoFrame = safeBounds
        if let p = playerCore, p.videoWidth > 0, p.videoHeight > 0 {
            let aspect = p.transform.displayAspectRatio(
                rawWidth: p.displayVideoWidth > 0 ? p.displayVideoWidth : p.videoWidth,
                rawHeight: p.displayVideoHeight > 0 ? p.displayVideoHeight : p.videoHeight,
                ratioSetting: p.videoAspectRatio
            )
            let safeAspect = max(0.001, aspect)
            let containerAspect = safeBounds.width / max(1.0, safeBounds.height)

            if abs(containerAspect - safeAspect) > 0.002 {
                if containerAspect > safeAspect {
                    // 容器更宽（如拉宽窗口产生立柱黑边）：高度撑满安全区，宽度等比居中
                    let vH = safeBounds.height
                    let vW = round(vH * safeAspect)
                    let vX = round(safeBounds.minX + (safeBounds.width - vW) / 2.0)
                    videoFrame = NSRect(x: vX, y: safeBounds.minY, width: vW, height: vH)
                } else {
                    // 容器更高（如拉高窗口产生信箱黑边）：宽度撑满安全区，高度等比居中
                    let vW = safeBounds.width
                    let vH = round(vW / safeAspect)
                    let vY = round(safeBounds.minY + (safeBounds.height - vH) / 2.0)
                    videoFrame = NSRect(x: safeBounds.minX, y: vY, width: vW, height: vH)
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
        return buildContextMenu(for: player)
    }

    /// Constructs the video canvas context menu (exposed for unit verification of fullscreen gating and presets).
    public func buildContextMenu(for player: PlayerCore) -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false

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

        menu.addItem(.separator())

        let isFullscreenWindow = player.isFullscreen || (window?.styleMask.contains(.fullScreen) == true)
        let canScaleWindow = !isFullscreenWindow && !player.isAudioOnly && player.videoWidth > 0 && player.videoHeight > 0

        let scaleSubmenu = NSMenu()
        scaleSubmenu.autoenablesItems = false
        let scalePresets: [(title: String, fraction: Double)] = [
            ("50%", 0.5),
            ("75%", 0.75),
            ("100%", 1.0)
        ]

        let activeWindow = player.hostWindow ?? window ?? NSApp.keyWindow
        let screenVisibleSize = (activeWindow?.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)).size
        let currentSize = activeWindow?.frame.size ?? .zero
        let aspect = player.effectiveAspectRatio
        let minSz = PlayerGeometry.minimumContentSize(for: aspect, screenVisibleHeight: screenVisibleSize.height)
        let maxSz = PlayerGeometry.maximizedContentSize(for: aspect, screenVisibleSize: screenVisibleSize)

        for preset in scalePresets {
            let item = NSMenuItem(
                title: preset.title,
                action: #selector(handleFitWindowScale(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = preset.fraction
            if canScaleWindow {
                let targetSize = PlayerGeometry.windowPresetContentSize(
                    fraction: CGFloat(preset.fraction),
                    aspect: aspect,
                    screenVisibleSize: screenVisibleSize
                )
                let state = PlayerGeometry.windowPresetMenuState(
                    targetSize: targetSize,
                    currentSize: currentSize,
                    minSize: minSz,
                    maxSize: maxSz
                )
                item.isEnabled = state.isEnabled
                item.state = state.isCurrent ? .on : .off
            } else {
                item.isEnabled = false
                item.state = .off
            }
            scaleSubmenu.addItem(item)
        }

        scaleSubmenu.addItem(.separator())

        let resetSizeItem = NSMenuItem(
            title: L10n.windowSizeReset,
            action: #selector(handleResetWindowSize(_:)),
            keyEquivalent: ""
        )
        resetSizeItem.target = self
        if canScaleWindow {
            let rawW = CGFloat(player.displayVideoWidth > 0 ? player.displayVideoWidth : player.videoWidth)
            let rawH = CGFloat(player.displayVideoHeight > 0 ? player.displayVideoHeight : player.videoHeight)
            let baseW = player.transform.isPerpendicular ? rawH : rawW
            let adaptiveSize = PlayerGeometry.adaptiveVideoContentSize(
                for: aspect,
                isVertical: player.isEffectiveVertical,
                rawVideoWidth: baseW,
                screenVisibleSize: screenVisibleSize
            )
            let resetState = PlayerGeometry.windowPresetMenuState(
                targetSize: adaptiveSize,
                currentSize: currentSize,
                minSize: minSz,
                maxSize: maxSz
            )
            resetSizeItem.isEnabled = resetState.isEnabled
            resetSizeItem.state = resetState.isCurrent ? .on : .off
        } else {
            resetSizeItem.isEnabled = false
            resetSizeItem.state = .off
        }
        scaleSubmenu.addItem(resetSizeItem)

        let windowSizeItem = NSMenuItem(title: L10n.windowSizeMenu, action: nil, keyEquivalent: "")
        windowSizeItem.submenu = scaleSubmenu
        windowSizeItem.isEnabled = canScaleWindow
        menu.addItem(windowSizeItem)

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

    @objc private func handleFitWindowScale(_ sender: NSMenuItem) {
        guard let scale = sender.representedObject as? Double else { return }
        playerCore?.fitWindow(scale: scale)
    }

    @objc private func handleResetWindowSize(_ sender: Any?) {
        playerCore?.resetWindowSize()
    }

    override public func hitTest(_ point: NSPoint) -> NSView? {
        guard let window = self.window, !window.styleMask.contains(.fullScreen) else {
            return super.hitTest(point)
        }
        let loc = (superview != nil) ? self.convert(point, from: superview) : self.convert(point, from: nil)
        let b = bounds
        let margin: CGFloat = 8.0
        // 四周边框与四角（8pt）绝对放行：返回 nil，直通 AppKit 系统 NSThemeFrame，激活原生八向缩放手柄与原生拖拽循环
        // 关键防护：在右侧拉手胶囊区域（宽 28pt，高 128pt，垂直居中），禁止返回 nil，确保在拉手区域只允许展开播放列表，严禁触发窗口拉伸动作
        let isOverHandle = (playerCore?.isPlaylistDrawerVisible == false) &&
            (loc.x >= b.width - 32.0) &&
            (abs(loc.y - b.height * 0.5) <= 72.0)
        if !isOverHandle && (loc.x <= margin || loc.x >= b.width - margin || loc.y <= margin || loc.y >= b.height - margin) {
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
        if playerCore?.hostWindow !== window {
            playerCore?.hostWindow = window
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

        // 顶栏高度：铺满最大化时为 88pt（确保大屏幕上极其容易双击顶栏还原），普通窗口为 32pt（匹配标准原生标题栏），全屏模式为 56pt
        let topBarHeight: CGFloat = isFullscreen ? 56.0 : (isMaximized ? 88.0 : 32.0)
        let isTopBarArea = (loc.y >= b.height - topBarHeight)
        let isBottomControlArea = (loc.y <= 112.0)

        // 2. 顶栏区域全局判定（无论是 HUD 激活态还是沉浸观影态）
        if isTopBarArea {
            // A. 顶栏双击：窗口模式下 100% 触发铺满最大化 / 还原切换，绝不进入全屏；全屏模式下双击顶栏退出全屏
            if event.clickCount >= 2 {
                pendingSingleClickWorkItem?.cancel()
                pendingSingleClickWorkItem = nil
                guard event.timestamp - lastHandledDoubleClickTime > 0.20 else { return }
                lastHandledDoubleClickTime = event.timestamp
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

        // 3. 画面视口区域双击事件优先路由：双击动作始终具有最高响应特权，绝不在底栏盲区被静默丢弃
        if window.firstResponder !== self {
            window.makeFirstResponder(self)
        }

        if event.clickCount >= 2 {
            pendingSingleClickWorkItem?.cancel()
            pendingSingleClickWorkItem = nil
            guard event.timestamp - lastHandledDoubleClickTime > 0.20 else { return }
            lastHandledDoubleClickTime = event.timestamp
            if isFullscreen {
                player.toggleFullscreen()
            } else {
                self.handleDoubleClickAction()
            }
            return
        }

        // 4. 底部控制栏区域：HUD 激活时保护控制面板，禁止单次点击穿透暂停或发起窗口拖拽
        if isBottomControlArea && player.isHUDVisible {
            canDragWindowFromCurrentMouseDown = false
            return
        }

        // 5. 画面区域（已排除四周 8pt 边框）单次点击按下：允许拖拽移动窗口（超过 8pt 调用 window.performDrag）或松开触发播放/暂停
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

        // 防双击手势与微距拖拽冲突：若检测到连击手势，严禁启动窗口拖拽截获事件流
        guard event.clickCount < 2 else {
            return
        }

        let current = NSEvent.mouseLocation
        let dx = current.x - dragInitialMouseScreenLocation.x
        let dy = current.y - dragInitialMouseScreenLocation.y
        let distance = hypot(dx, dy)
        // 防抖微位移阈值放宽至 8.0pt（避免快速连击双击时的手指微位移误触 window.performDrag）
        if distance > 8.0 {
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
        if distance > 8.0 {
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

        // 画面空白处防抖单击（对齐系统级双击间隔，给予用户充足连击窗口）
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
            let delay = min(0.22, NSEvent.doubleClickInterval)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: task)
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
