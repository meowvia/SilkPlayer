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
    private var pendingSingleClickWorkItem: DispatchWorkItem?
    private var lastMouseActivityTime: TimeInterval = 0

    override public var acceptsFirstResponder: Bool { true }

    public init(playerCore: PlayerCore) {
        self.playerCore = playerCore
        super.init(frame: .zero)
        self.wantsLayer = true
        self.layer?.backgroundColor = NSColor.black.cgColor

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

        // 0. Window Edge Resize Zone Protection:
        // When in windowed mode, clicks within 8pt of the window outer border belong to AppKit
        // native resize handles. Must never capture or engage performDrag!
        if !isFullscreen {
            let resizeBorderMargin: CGFloat = 8.0
            let isAtResizeBorder = (loc.x <= resizeBorderMargin ||
                                    loc.x >= b.width - resizeBorderMargin ||
                                    loc.y <= resizeBorderMargin ||
                                    loc.y >= b.height - resizeBorderMargin)
            if isAtResizeBorder {
                super.mouseDown(with: event)
                return
            }
        }

        // Dynamic active drawer width calculation
        let activeDrawerWidth: CGFloat
        if playerCore?.isInspectorVisible == true {
            activeDrawerWidth = 348.0
        } else if playerCore?.isPlaylistDrawerVisible == true {
            activeDrawerWidth = PlaylistDrawerDimensions.drawerWidth(for: b.width, isFullscreen: isFullscreen) + 8.0
        } else {
            activeDrawerWidth = 0.0
        }

        // 1. Dismiss drawer on clicking outside without pausing playback or dragging window
        if let player = playerCore {
            if player.isPlaylistDrawerVisible || player.isInspectorVisible {
                let isInsideDrawer = (loc.x >= b.width - activeDrawerWidth) && (loc.y >= 96 && loc.y <= b.height - 64)
                if !isInsideDrawer {
                    player.isPlaylistDrawerVisible = false
                    player.isInspectorVisible = false
                    return
                }
            }

            // 2. Interactive control areas pass-through:
            // Top information bar interactive buttons:
            // Trailing quick action buttons (Close, Pin, Inspector) occupy trailing ~160pt.
            // Leading traffic lights occupy leading 70pt in windowed mode.
            if player.isHUDVisible && loc.y >= b.height - 70 {
                let isTrailingActionArea = loc.x >= b.width - 160.0
                let isLeadingTrafficArea = !isFullscreen && loc.x <= 70.0
                if isTrailingActionArea || isLeadingTrafficArea {
                    super.mouseDown(with: event)
                    return
                }
            }

            // Right-side drawers (playlist or inspector)
            if activeDrawerWidth > 0 && loc.x >= b.width - activeDrawerWidth {
                super.mouseDown(with: event)
                return
            }

            // Right-side vertical volume slider
            if player.isVolumeHUDVisible && loc.x >= b.width - 80 {
                super.mouseDown(with: event)
                return
            }
        }

        if window.firstResponder !== self {
            window.makeFirstResponder(self)
        }

        // 3. Double-Click Handling:
        if event.clickCount >= 2 {
            // Cancel pending single click task immediately - 100% zero playback glitch or stutter!
            pendingSingleClickWorkItem?.cancel()
            pendingSingleClickWorkItem = nil

            if let player = playerCore, player.isHUDVisible {
                let isBottomControlArea = (loc.y <= 112.0)
                let isTopControlArea = (loc.y >= b.height - 70.0)
                if isBottomControlArea || isTopControlArea {
                    return
                }
            }
            self.handleDoubleClickAction()
            return
        }

        // 4. Record mouse-down anchor for potential window dragging
        dragInitialMouseScreenLocation = NSEvent.mouseLocation
        dragInitialWindowOrigin = window.frame.origin
        isDraggingWindow = false
    }

    override public func mouseDragged(with event: NSEvent) {
        guard let window = self.window, !window.styleMask.contains(.fullScreen) else {
            super.mouseDragged(with: event)
            return
        }

        let currentMouseScreen = NSEvent.mouseLocation
        let dx = currentMouseScreen.x - dragInitialMouseScreenLocation.x
        let dy = currentMouseScreen.y - dragInitialMouseScreenLocation.y
        let distance = hypot(dx, dy)

        // Once movement exceeds threshold (3.0pt), engage native macOS window dragging
        if distance > 3.0 {
            // Cancel pending single click if mouse is being dragged
            pendingSingleClickWorkItem?.cancel()
            pendingSingleClickWorkItem = nil

            isDraggingWindow = true
            window.performDrag(with: event)
            isDraggingWindow = false
            return
        }
    }

    override public func mouseUp(with event: NSEvent) {
        // Double-click guard: clickCount >= 2 is handled by mouseDown
        guard event.clickCount == 1 else { return }

        // 1. If user was dragging the window, finish dragging cleanly
        let currentMouseScreen = NSEvent.mouseLocation
        let dx = currentMouseScreen.x - dragInitialMouseScreenLocation.x
        let dy = currentMouseScreen.y - dragInitialMouseScreenLocation.y
        let distance = hypot(dx, dy)

        if isDraggingWindow || distance > 3.0 {
            isDraggingWindow = false
            pendingSingleClickWorkItem?.cancel()
            pendingSingleClickWorkItem = nil
            return
        }

        // 2. If click landed in HUD interactive control bars (bottom controls or top bar) while HUD is visible:
        if let player = playerCore, player.isHUDVisible {
            let loc = self.convert(event.locationInWindow, from: nil)
            let b = bounds
            let isBottomControlArea = (loc.y <= 112.0)
            let isTopControlArea = (loc.y >= b.height - 70.0)
            if isBottomControlArea || isTopControlArea {
                return
            }
        }

        // 3. Stationary in-place click on canvas:
        // Schedule single-click play/pause with standard debounce delay (0.16s).
        // If a second click arrives within this interval, it cancels cleanly without pausing or glitching!
        let hasDoubleClickAction = (AppSettings.shared.doubleClickAction != .none)
        if !hasDoubleClickAction {
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
