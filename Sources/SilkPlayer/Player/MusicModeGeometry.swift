import Foundation
import AppKit

/// Pure responsive geometry and layout breakpoint calculations for SilkPlayer Music Mode.
/// Keeps width locked per screen resolution while allowing vertical-only resizing.
public enum MusicModeGeometry: Sendable {
    public static let minWidth: CGFloat = 520.0
    public static let maxWidth: CGFloat = 768.0
    public static let minHeight: CGFloat = 500.0
    public static let extendedQueueWidthThreshold: CGFloat = 680.0
    public static let compactBottomHUDWidthThreshold: CGFloat = 640.0
    public static let contentHorizontalPadding: CGFloat = 20.0

    private static let referenceScreenWidth: CGFloat = 3440.0
    private static let referenceLockedWidth: CGFloat = 768.0

    /// Returns the fixed Music Mode window width for a given screen visible width.
    public static func lockedWidth(forScreenWidth visibleWidth: CGFloat) -> CGFloat {
        guard visibleWidth.isFinite, visibleWidth > 0 else { return minWidth }
        let ratio = referenceLockedWidth / referenceScreenWidth
        let scaled = round(visibleWidth * ratio)
        let bounded = max(minWidth, min(maxWidth, scaled))
        return min(bounded, floor(visibleWidth))
    }

    /// Returns the valid minimum height bounded by available screen height.
    public static func effectiveMinHeight(forScreenHeight visibleHeight: CGFloat) -> CGFloat {
        guard visibleHeight.isFinite, visibleHeight > 0 else { return minHeight }
        return min(minHeight, floor(visibleHeight))
    }

    /// Returns the initial or restored window height clamped cleanly inside the visible screen frame.
    public static func resolvedHeight(forScreenHeight visibleHeight: CGFloat, rememberedHeight: CGFloat? = nil) -> CGFloat {
        guard visibleHeight.isFinite, visibleHeight > 0 else { return minHeight }
        let minH = effectiveMinHeight(forScreenHeight: visibleHeight)
        let maxH = floor(visibleHeight)
        if let saved = rememberedHeight, saved.isFinite, saved > 0 {
            return round(max(minH, min(maxH, saved)))
        }
        let defaultH = round(visibleHeight * 0.88)
        return max(minH, min(maxH, defaultH))
    }

    /// Computes a clamped vertical-only Music Mode frame for a target visible screen area.
    public static func clampedFrame(
        around currentFrame: NSRect?,
        targetHeight: CGFloat? = nil,
        rememberedHeight: CGFloat? = nil,
        screenVisibleFrame: NSRect
    ) -> NSRect {
        let lockedW = lockedWidth(forScreenWidth: screenVisibleFrame.width)
        let minH = effectiveMinHeight(forScreenHeight: screenVisibleFrame.height)
        let maxH = max(minH, floor(screenVisibleFrame.height))

        let resolvedH: CGFloat
        if let explicitH = targetHeight, explicitH.isFinite, explicitH > 0 {
            resolvedH = round(max(minH, min(maxH, explicitH)))
        } else {
            resolvedH = resolvedHeight(forScreenHeight: screenVisibleFrame.height, rememberedHeight: rememberedHeight)
        }

        let anchorCenter: CGPoint
        if let cur = currentFrame, !cur.isNull, !cur.isEmpty {
            anchorCenter = CGPoint(x: cur.midX, y: cur.midY)
        } else {
            anchorCenter = CGPoint(x: screenVisibleFrame.midX, y: screenVisibleFrame.midY)
        }

        let maxX = max(screenVisibleFrame.minX, screenVisibleFrame.maxX - lockedW)
        let maxY = max(screenVisibleFrame.minY, screenVisibleFrame.maxY - resolvedH)
        let x = round(max(screenVisibleFrame.minX, min(maxX, anchorCenter.x - lockedW / 2.0)))
        let y = round(max(screenVisibleFrame.minY, min(maxY, anchorCenter.y - resolvedH / 2.0)))

        return NSRect(x: x, y: y, width: lockedW, height: resolvedH)
    }

    /// Clamps interactive resize proposals so horizontal width remains locked and vertical height stays within bounds.
    public static func clampedResizeProposal(_ proposedSize: NSSize, screenVisibleFrame: NSRect) -> NSSize {
        let lockedW = lockedWidth(forScreenWidth: screenVisibleFrame.width)
        let minH = effectiveMinHeight(forScreenHeight: screenVisibleFrame.height)
        let maxH = max(minH, floor(screenVisibleFrame.height))
        let h = proposedSize.height.isFinite ? proposedSize.height : minH
        return NSSize(width: lockedW, height: round(max(minH, min(maxH, h))))
    }

    /// Shows centered-right Album & Format columns when window width is 680 pt or wider.
    public static func showsExtendedQueueColumns(width: CGFloat) -> Bool {
        width >= extendedQueueWidthThreshold
    }

    /// Uses tighter bottom control spacing and a 60 pt volume slider below 640 pt.
    public static func usesCompactBottomControls(width: CGFloat) -> Bool {
        width < compactBottomHUDWidthThreshold
    }

    public static func bottomVolumeTrackWidth(forWindowWidth width: CGFloat) -> CGFloat {
        usesCompactBottomControls(width: width) ? 60.0 : 84.0
    }

    public static func showsVolumePercentage(forWindowWidth width: CGFloat) -> Bool {
        !usesCompactBottomControls(width: width)
    }

    public static func heroArtworkSize(forWindowWidth width: CGFloat) -> CGFloat {
        width >= extendedQueueWidthThreshold ? 78.0 : 68.0
    }
}
