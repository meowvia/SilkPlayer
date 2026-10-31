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

        view.wantsLayer = true

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

        view.autoresizingMask = [.width, .height]
        view.layer?.setAffineTransform(.identity)
        view.frame = b
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

        if event.hasPreciseScrollingDeltas {
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
                    let step = deltaY * 0.15
                    player.adjustVolume(by: step)
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
                if event.momentumPhase.contains(.began) || event.momentumPhase.contains(.changed) {
                    let stepSign = event.scrollingDeltaY > 0 ? 1.0 : (event.scrollingDeltaY < 0 ? -1.0 : 0.0)
                    if stepSign != 0 {
                        if AppSettings.shared.scrollWheelAction == .seek {
                            player.step(seconds: stepSign * AppSettings.shared.shortSeekStep)
                        } else {
                            player.handleScrollWheelVolume(deltaY: stepSign)
                        }
                        player.reportUserActivity()
                    }
                }
            }
        } else {
            let stepSign = event.deltaY > 0 ? 1.0 : (event.deltaY < 0 ? -1.0 : 0.0)
            if stepSign != 0 {
                if AppSettings.shared.scrollWheelAction == .seek {
                    player.step(seconds: stepSign * AppSettings.shared.shortSeekStep)
                } else {
                    player.handleScrollWheelVolume(deltaY: stepSign)
                }
                player.reportUserActivity()
            }
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
            isDraggingWindow = true
            window.performDrag(with: event)
            isDraggingWindow = false
        }
    }

    override public func mouseUp(with event: NSEvent) {
        guard event.clickCount == 1 else { return }

        let current = NSEvent.mouseLocation
        let distance = hypot(current.x - dragInitialMouseScreenLocation.x, current.y - dragInitialMouseScreenLocation.y)
        if distance > 3.0 || isDraggingWindow {
            isDraggingWindow = false
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
