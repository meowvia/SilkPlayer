import Foundation
import AppKit

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

    public func applyAudioWindowGeometry(animated: Bool = false) {
        guard let window = self.hostWindow ?? NSApp.keyWindow,
              !isFullscreen,
              !window.styleMask.contains(.fullScreen) else { return }

        applyContentAspectRatioLock()

        let screenFrame = window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)
        let minAudioSize = NSSize(width: 380, height: 380)
        let maxSquare = min(screenFrame.width, screenFrame.height)
        let maxAudioSize = NSSize(width: maxSquare, height: maxSquare)

        window.minSize = minAudioSize
        window.contentMinSize = minAudioSize
        window.maxSize = maxAudioSize
        window.contentMaxSize = maxAudioSize

        let currentFrame = window.frame
        let isAlreadySquareAudio = abs(currentFrame.width - currentFrame.height) <= 4.0 && currentFrame.width >= 360

        if isAlreadySquareAudio {
            // Already an active square audio window, preserve user's size
            return
        }

        let targetW: CGFloat = 520
        let targetH: CGFloat = 520

        let currentCenter = CGPoint(x: window.frame.midX, y: window.frame.midY)
        let newX = max(screenFrame.minX, min(screenFrame.maxX - targetW, currentCenter.x - targetW / 2))
        let newY = max(screenFrame.minY, min(screenFrame.maxY - targetH, currentCenter.y - targetH / 2))
        let newFrame = NSRect(x: newX, y: newY, width: targetW, height: targetH)

        window.setFrame(newFrame, display: true, animate: false)
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
