import Foundation
import AppKit
import QuartzCore
import SilkCoreKit

extension PlayerCore {
    public func updateRememberedWindowSize(_ contentSize: NSSize) {
        guard let window = hostWindow ?? NSApp.keyWindow,
              !window.styleMask.contains(.fullScreen),
              !window.isZoomed else { return }

        if isEffectiveVertical {
            lastPortraitContentSize = contentSize
        } else {
            lastLandscapeContentSize = contentSize
        }
    }

    public func applyRotationWindowAdaptation(isOrientationChange: Bool) {
        guard let window = hostWindow ?? NSApp.keyWindow else { return }

        // 全屏模式下：窗口 frame 绝对不动，仅画面居中做黑边适配
        if window.styleMask.contains(.fullScreen) || window.isZoomed {
            return
        }

        // 0° ↔ 180°: 窗口尺寸、位置都不变，只旋转画面
        if !isOrientationChange {
            return
        }

        let screenFrame = window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)
        let newAspect = effectiveAspectRatio
        let isVertical = isEffectiveVertical
        let minContentSz = PlayerGeometry.minimumContentSize(for: newAspect, screenVisibleHeight: screenFrame.height)

        let curContentRect = window.contentRect(forFrameRect: window.frame)
        let remembered = isVertical ? lastPortraitContentSize : lastLandscapeContentSize
        let targetSize = PlayerGeometry.calculateRotationTargetSize(
            currentContentSize: curContentRect.size,
            targetAspect: newAspect,
            isTargetVertical: isVertical,
            rememberedSize: remembered,
            screenVisibleSize: screenFrame.size
        )

        applyVideoWindowContentSize(
            targetSize,
            on: window,
            screenFrame: screenFrame,
            minContentSize: minContentSz,
            animated: false
        )
    }

    public func setAspectRatio(_ ratio: String) {
        videoAspectRatio = ratio
        applyContentAspectRatioLock()
        applyAdaptiveWindowGeometry(animated: true)
        showOSD(.pictureAdjustment(name: L10n.aspectRatio, value: ratio))
        renderContainer?.applyRenderViewLayout()
    }

    public func applyContentAspectRatioLock() {
        guard let window = hostWindow ?? NSApp.keyWindow else { return }
        window.contentAspectRatio = .zero
        window.aspectRatio = .zero
        window.resizeIncrements = NSSize(width: 1, height: 1)
        window.contentResizeIncrements = NSSize(width: 1, height: 1)
    }

    public func configureMusicModeChrome(on window: NSWindow) {
        if !window.styleMask.contains(.fullScreen) {
            var behavior = window.collectionBehavior
            behavior.remove([.fullScreenPrimary, .fullScreenAllowsTiling, .fullScreenAuxiliary])
            behavior.insert(.fullScreenNone)
            if #available(macOS 15.0, *) {
                behavior.insert(.fullScreenDisallowsTiling)
            }
            window.collectionBehavior = behavior
        }
        window.standardWindowButton(.zoomButton)?.isEnabled = false
        window.standardWindowButton(.zoomButton)?.alphaValue = 1.0
    }

    public func restoreStandardWindowChrome(on window: NSWindow) {
        if !window.styleMask.contains(.fullScreen) {
            var behavior = window.collectionBehavior
            behavior.remove([.fullScreenAuxiliary, .fullScreenNone])
            if #available(macOS 15.0, *) {
                behavior.remove(.fullScreenDisallowsTiling)
            }
            behavior.insert([.fullScreenPrimary, .fullScreenAllowsTiling])
            window.collectionBehavior = behavior
        }
        window.standardWindowButton(.zoomButton)?.isEnabled = true
    }

    public func applyAudioWindowGeometry(animated: Bool = false) {
        guard let window = self.hostWindow ?? NSApp?.keyWindow else { return }

        if isFullscreen || window.styleMask.contains(.fullScreen) {
            if !pendingAudioGeometryAfterExitFullScreen && !isFullscreenTransitioning && !PlayerWindowManager.isRunningTests {
                pendingAudioGeometryAfterExitFullScreen = true
                window.toggleFullScreen(nil)
            }
            return
        }

        pendingAudioGeometryAfterExitFullScreen = false
        applyContentAspectRatioLock()
        configureMusicModeChrome(on: window)

        let screenFrame = window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)
        let lockedW = MusicModeGeometry.lockedWidth(forScreenWidth: screenFrame.width)
        let expandedMinH = MusicModeGeometry.effectiveMinHeight(forScreenHeight: screenFrame.height)
        let collapsedH = MusicModeGeometry.collapsedHeight(forWindowWidth: lockedW, screenVisibleHeight: screenFrame.height)
        let maxH = max(expandedMinH, floor(screenFrame.height))

        let minAudioSize = NSSize(width: lockedW, height: min(collapsedH, expandedMinH))
        let maxAudioSize = NSSize(width: lockedW, height: maxH)

        let isCollapsed = AppSettings.shared.isMusicQueueCollapsed
        let storedHeight = UserDefaults.standard.object(forKey: PlayerCore.musicModeHeightDefaultsKey) as? Double
        let rememberedHeight = storedHeight.map { CGFloat($0) }

        let currentFrame = window.frame
        let newFrame: NSRect
        if isCollapsed {
            if abs(currentFrame.width - lockedW) <= 1.0 && !currentFrame.isEmpty {
                newFrame = MusicModeGeometry.toggledCollapseFrame(
                    around: currentFrame,
                    targetCollapsed: true,
                    rememberedExpandedHeight: rememberedHeight,
                    screenVisibleFrame: screenFrame
                )
            } else {
                newFrame = MusicModeGeometry.clampedFrame(
                    around: currentFrame,
                    targetHeight: collapsedH,
                    rememberedHeight: rememberedHeight,
                    clampToExpandedMin: false,
                    screenVisibleFrame: screenFrame
                )
            }
        } else {
            let isAlreadyMusicWidth = abs(currentFrame.width - lockedW) <= 1.0 &&
                currentFrame.height >= expandedMinH && currentFrame.height <= maxH
            let targetHeight: CGFloat? = isAlreadyMusicWidth ? currentFrame.height : nil

            newFrame = MusicModeGeometry.clampedFrame(
                around: currentFrame,
                targetHeight: targetHeight,
                rememberedHeight: rememberedHeight,
                screenVisibleFrame: screenFrame
            )
        }

        // Release constraints temporarily so AppKit accepts both shrink and expand smoothly
        window.minSize = NSSize(width: 100, height: 100)
        window.contentMinSize = NSSize(width: 100, height: 100)
        window.maxSize = NSSize(width: max(lockedW, currentFrame.width), height: max(maxH, currentFrame.height))
        window.contentMaxSize = window.maxSize

        if abs(currentFrame.width - newFrame.width) > 0.5 ||
           abs(currentFrame.height - newFrame.height) > 0.5 ||
           abs(currentFrame.origin.x - newFrame.origin.x) > 0.5 ||
           abs(currentFrame.origin.y - newFrame.origin.y) > 0.5 {
            isApplyingAudioWindowGeometry = true
            defer { isApplyingAudioWindowGeometry = false }
            window.setFrame(newFrame, display: true, animate: animated)
        }

        window.minSize = minAudioSize
        window.contentMinSize = minAudioSize
        window.maxSize = maxAudioSize
        window.contentMaxSize = maxAudioSize
        configureMusicModeChrome(on: window)
    }

    public func setMusicQueueCollapsed(_ collapsed: Bool, animated: Bool = true) {
        guard isAudioOnly else {
            AppSettings.shared.isMusicQueueCollapsed = collapsed
            return
        }

        guard let window = self.hostWindow ?? NSApp?.keyWindow else {
            AppSettings.shared.isMusicQueueCollapsed = collapsed
            return
        }

        let screenFrame = window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)
        let lockedW = MusicModeGeometry.lockedWidth(forScreenWidth: screenFrame.width)
        let expandedMinH = MusicModeGeometry.effectiveMinHeight(forScreenHeight: screenFrame.height)
        let collapsedH = MusicModeGeometry.collapsedHeight(forWindowWidth: lockedW, screenVisibleHeight: screenFrame.height)
        let maxH = max(expandedMinH, floor(screenFrame.height))

        let wasCollapsed = AppSettings.shared.isMusicQueueCollapsed
        if collapsed && !wasCollapsed && window.frame.height >= expandedMinH - 1.0 {
            UserDefaults.standard.set(Double(window.frame.height), forKey: PlayerCore.musicModeHeightDefaultsKey)
        }

        let storedHeight = UserDefaults.standard.object(forKey: PlayerCore.musicModeHeightDefaultsKey) as? Double
        let targetFrame = MusicModeGeometry.toggledCollapseFrame(
            around: window.frame,
            targetCollapsed: collapsed,
            rememberedExpandedHeight: storedHeight.map { CGFloat($0) },
            screenVisibleFrame: screenFrame
        )

        isApplyingAudioWindowGeometry = true
        defer { isApplyingAudioWindowGeometry = false }

        AppSettings.shared.isMusicQueueCollapsed = collapsed
        let minAudioSize = NSSize(width: lockedW, height: min(collapsedH, expandedMinH))
        let maxAudioSize = NSSize(width: lockedW, height: maxH)
        window.minSize = NSSize(width: 100, height: 100)
        window.contentMinSize = NSSize(width: 100, height: 100)
        window.maxSize = NSSize(width: max(lockedW, window.frame.width), height: max(maxH, window.frame.height))
        window.contentMaxSize = window.maxSize

        // Collapsing synchronously without AppKit's nested resize loop eliminates blank Spacer frames
        // and prevents external events from interrupting mid-transition at expandedMinHeight.
        let shouldAnimate = animated && !collapsed
        if PlayerWindowManager.isRunningTests {
            window.setFrame(targetFrame, display: false, animate: false)
        } else {
            window.setFrame(targetFrame, display: true, animate: shouldAnimate)
        }

        window.minSize = minAudioSize
        window.contentMinSize = minAudioSize
        window.maxSize = maxAudioSize
        window.contentMaxSize = maxAudioSize
    }

    public func toggleMusicQueueCollapsed() {
        setMusicQueueCollapsed(!AppSettings.shared.isMusicQueueCollapsed, animated: true)
    }

    public func applyAdaptiveWindowGeometry(animated: Bool = true) {
        applyAdaptiveWindowGeometry(animated: animated, force: false)
    }

    public func resetWindowSize() {
        guard let targetSize = applyAdaptiveWindowGeometry(animated: true, force: true) else { return }
        showOSD(.pictureAdjustment(
            name: L10n.windowSizeMenu,
            value: "\(L10n.windowSizeDefaultShort) (\(Int(targetSize.width)) × \(Int(targetSize.height)))"
        ))
    }

    public func fitWindow(scale: Double) {
        guard !isAudioOnly,
              let window = hostWindow ?? NSApp.keyWindow,
              !isFullscreen,
              !window.styleMask.contains(.fullScreen),
              videoWidth > 0, videoHeight > 0,
              scale > 0 else { return }

        let screenFrame = window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)
        let aspect = effectiveAspectRatio
        let clampedFraction = min(1.0, max(0.1, scale))

        let targetSize = PlayerGeometry.windowPresetContentSize(
            fraction: CGFloat(clampedFraction),
            aspect: aspect,
            screenVisibleSize: screenFrame.size
        )
        let minSz = PlayerGeometry.minimumContentSize(for: aspect, screenVisibleHeight: screenFrame.height)

        applyVideoWindowContentSize(
            targetSize,
            on: window,
            screenFrame: screenFrame,
            minContentSize: minSz,
            animated: true
        )

        let scaleLabel = Self.formattedWindowPercentageLabel(clampedFraction)
        showOSD(.pictureAdjustment(
            name: L10n.windowSizeMenu,
            value: "\(scaleLabel) (\(Int(targetSize.width)) × \(Int(targetSize.height)))"
        ))
    }

    @discardableResult
    private func applyAdaptiveWindowGeometry(animated: Bool, force: Bool) -> NSSize? {
        guard !isAudioOnly,
              let window = self.hostWindow ?? NSApp.keyWindow,
              !isFullscreen,
              !window.styleMask.contains(.fullScreen) else { return nil }

        restoreStandardWindowChrome(on: window)

        let screenFrame = window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)
        window.maxSize = screenFrame.size
        window.contentMaxSize = screenFrame.size

        guard (force || AppSettings.shared.autoResizeWindow),
              self.videoWidth > 0, self.videoHeight > 0 else { return nil }

        let aspect = effectiveAspectRatio
        let minSz = PlayerGeometry.minimumContentSize(for: aspect, screenVisibleHeight: screenFrame.height)
        let rawW = CGFloat(displayVideoWidth > 0 ? displayVideoWidth : videoWidth)
        let rawH = CGFloat(displayVideoHeight > 0 ? displayVideoHeight : videoHeight)
        let baseW = transform.isPerpendicular ? rawH : rawW
        let targetSize = PlayerGeometry.adaptiveVideoContentSize(
            for: aspect,
            isVertical: isEffectiveVertical,
            rawVideoWidth: baseW,
            screenVisibleSize: screenFrame.size
        )

        applyVideoWindowContentSize(
            targetSize,
            on: window,
            screenFrame: screenFrame,
            minContentSize: minSz,
            animated: animated
        )
        return targetSize
    }

    /// Temporarily releases `minSize`, exits any maximized tracking state, applies a centered frame
    /// inside `screenFrame`, restores `[minContentSize, screenFrame.size]` bounds, and re-locks aspect rules.
    private func applyVideoWindowContentSize(
        _ targetSize: NSSize,
        on window: NSWindow,
        screenFrame: NSRect,
        minContentSize: NSSize,
        animated: Bool
    ) {
        (window.delegate as? PlayerWindowDelegate)?.resetInteractiveModeToNormal()

        let frameW = min(screenFrame.width, targetSize.width)
        let frameH = min(screenFrame.height, targetSize.height)
        let currentCenter = CGPoint(x: window.frame.midX, y: window.frame.midY)
        let newX = max(screenFrame.minX, min(screenFrame.maxX - frameW, round(currentCenter.x - frameW / 2.0)))
        let newY = max(screenFrame.minY, min(screenFrame.maxY - frameH, round(currentCenter.y - frameH / 2.0)))
        let newFrame = NSRect(x: newX, y: newY, width: frameW, height: frameH)

        window.minSize = NSSize(width: 100, height: 100)
        window.contentMinSize = window.minSize

        let shouldAnimate = animated && !PlayerWindowManager.isRunningTests
        window.setFrame(newFrame, display: true, animate: shouldAnimate)

        window.minSize = minContentSize
        window.contentMinSize = minContentSize
        window.maxSize = screenFrame.size
        window.contentMaxSize = screenFrame.size

        let finalContentSize = NSSize(width: frameW, height: frameH)
        if isEffectiveVertical {
            lastPortraitContentSize = finalContentSize
        } else {
            lastLandscapeContentSize = finalContentSize
        }

        applyContentAspectRatioLock()
    }

    private static func formattedWindowPercentageLabel(_ fraction: Double) -> String {
        let percent = Int((min(1.0, max(0.1, fraction)) * 100.0).rounded())
        return "\(percent)%"
    }
}

/// Coordinates local `.eventTracking` window dragging in Music Mode so dragging never triggers
/// macOS `WindowManager` desktop/edge tiling (`performDrag`) while maintaining raw cursor tracking
/// with coalescing disabled and no artificial 4-edge screen clamping.
@MainActor
public final class MusicWindowDragCoordinator {
    public static let shared = MusicWindowDragCoordinator()

    public private(set) var isDragging: Bool = false

    public static func translatedOrigin(
        initialOrigin: NSPoint,
        initialMouseLocation: NSPoint,
        currentMouseLocation: NSPoint
    ) -> NSPoint {
        NSPoint(
            x: initialOrigin.x + (currentMouseLocation.x - initialMouseLocation.x),
            y: initialOrigin.y + (currentMouseLocation.y - initialMouseLocation.y)
        )
    }

    public static func screenGrabLocation(
        for event: NSEvent,
        on window: NSWindow
    ) -> NSPoint {
        if event.window === window {
            return window.convertPoint(toScreen: event.locationInWindow)
        }
        return NSEvent.mouseLocation
    }

    @discardableResult
    public static func applyOriginIfMoved(
        _ targetOrigin: NSPoint,
        to window: NSWindow,
        minimumDelta: CGFloat = 0.25
    ) -> Bool {
        let currentOrigin = window.frame.origin
        guard abs(targetOrigin.x - currentOrigin.x) >= minimumDelta ||
              abs(targetOrigin.y - currentOrigin.y) >= minimumDelta else {
            return false
        }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        window.setFrameOrigin(targetOrigin)
        CATransaction.commit()
        return true
    }

    public func beginDrag(on window: NSWindow, with event: NSEvent) {
        guard !window.styleMask.contains(.fullScreen),
              !isDragging,
              !PlayerWindowManager.isRunningTests,
              (NSEvent.pressedMouseButtons & 1) != 0 else {
            return
        }

        let initialOrigin = window.frame.origin
        let initialMouseLocation = Self.screenGrabLocation(for: event, on: window)
        let startScreenID = window.screen.map(ObjectIdentifier.init)

        isDragging = true
        let previousCoalescing = NSEvent.isMouseCoalescingEnabled
        NSEvent.isMouseCoalescingEnabled = false
        defer {
            NSEvent.isMouseCoalescingEnabled = previousCoalescing
            isDragging = false
            if let currentScreen = window.screen,
               let startScreenID,
               ObjectIdentifier(currentScreen) != startScreenID,
               let session = PlayerWindowManager.shared.sessions.first(where: { $0.window === window }),
               session.player?.isAudioOnly == true {
                (session.player as? PlayerCore)?.applyAudioWindowGeometry(animated: false)
            }
        }

        window.trackEvents(
            matching: [.leftMouseDragged, .leftMouseUp],
            timeout: NSEvent.foreverDuration,
            mode: .eventTracking
        ) { [weak window] trackedEvent, stop in
            guard let trackedEvent, let window else {
                stop.pointee = true
                return
            }

            var latestEvent = trackedEvent
            while let queued = window.nextEvent(
                matching: [.leftMouseDragged, .leftMouseUp],
                until: .distantPast,
                inMode: .eventTracking,
                dequeue: true
            ) {
                latestEvent = queued
                if queued.type == .leftMouseUp {
                    break
                }
            }

            if !window.isVisible || window.styleMask.contains(.fullScreen) {
                stop.pointee = true
                return
            }

            let targetOrigin = Self.translatedOrigin(
                initialOrigin: initialOrigin,
                initialMouseLocation: initialMouseLocation,
                currentMouseLocation: NSEvent.mouseLocation
            )
            _ = Self.applyOriginIfMoved(targetOrigin, to: window)

            if latestEvent.type == .leftMouseUp || (NSEvent.pressedMouseButtons & 1) == 0 {
                stop.pointee = true
            }
        }
    }
}
