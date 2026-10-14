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

        let targetContentW = targetSize.width
        let targetContentH = targetSize.height

        let currentCenter = CGPoint(x: window.frame.midX, y: window.frame.midY)
        let newX = max(screenFrame.minX, min(screenFrame.maxX - targetContentW, currentCenter.x - targetContentW / 2.0))
        let newY = max(screenFrame.minY, min(screenFrame.maxY - targetContentH, currentCenter.y - targetContentH / 2.0))
        let newFrame = NSRect(x: newX, y: newY, width: targetContentW, height: targetContentH)

        window.minSize = NSSize(width: 100, height: 100)
        window.contentMinSize = window.minSize

        window.setFrame(newFrame, display: true, animate: false)

        window.minSize = minContentSz
        window.contentMinSize = minContentSz

        if isVertical {
            lastPortraitContentSize = targetSize
        } else {
            lastLandscapeContentSize = targetSize
        }

        applyContentAspectRatioLock()
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
        window.contentAspectRatio = NSSize(width: 0, height: 0)
        window.aspectRatio = NSSize(width: 0, height: 0)
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
        guard AppSettings.shared.autoResizeWindow,
              self.videoWidth > 0, self.videoHeight > 0,
              let window = self.hostWindow ?? NSApp.keyWindow,
              !isFullscreen,
              !window.styleMask.contains(.fullScreen) else { return }

        let screenFrame = window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)
        let aspect = effectiveAspectRatio
        let isVertical = isEffectiveVertical

        let minSz = PlayerGeometry.minimumContentSize(for: aspect, screenVisibleHeight: screenFrame.height)
        let maxSafeContentSz = PlayerGeometry.maximumSafeContentSize(for: aspect, screenVisibleSize: screenFrame.size)

        var targetContentW: CGFloat
        var targetContentH: CGFloat

        if isVertical {
            let idealH = round(screenFrame.height * 0.60)
            targetContentH = min(max(idealH, minSz.height), maxSafeContentSz.height)
            targetContentW = round(targetContentH * aspect)
            if targetContentW > maxSafeContentSz.width {
                targetContentW = maxSafeContentSz.width
                targetContentH = round(targetContentW / aspect)
            }
            if targetContentW < minSz.width {
                targetContentW = minSz.width
                targetContentH = round(targetContentW / aspect)
            }
        } else {
            let vW = CGFloat(displayVideoWidth > 0 ? displayVideoWidth : videoWidth)
            let idealW = min(vW, screenFrame.width * 0.55)
            targetContentW = max(minSz.width, min(maxSafeContentSz.width, idealW))
            targetContentH = round(targetContentW / aspect)

            if targetContentH > maxSafeContentSz.height {
                targetContentH = maxSafeContentSz.height
                targetContentW = round(targetContentH * aspect)
            }
            if targetContentW < minSz.width {
                targetContentW = minSz.width
                targetContentH = minSz.height
            }
        }

        let frameW = targetContentW
        let frameH = targetContentH

        let currentCenter = CGPoint(x: window.frame.midX, y: window.frame.midY)
        let newX = max(screenFrame.minX, min(screenFrame.maxX - frameW, currentCenter.x - frameW / 2))
        let newY = max(screenFrame.minY, min(screenFrame.maxY - frameH, currentCenter.y - frameH / 2))
        let newFrame = NSRect(x: newX, y: newY, width: frameW, height: frameH)

        window.minSize = NSSize(width: 100, height: 100)
        window.contentMinSize = window.minSize

        window.setFrame(newFrame, display: true, animate: animated)

        window.minSize = minSz
        window.contentMinSize = minSz
        window.maxSize = screenFrame.size
        window.contentMaxSize = screenFrame.size

        let finalContentSize = NSSize(width: targetContentW, height: targetContentH)
        if isVertical {
            lastPortraitContentSize = finalContentSize
        } else {
            lastLandscapeContentSize = finalContentSize
        }

        applyContentAspectRatioLock()
    }
}
