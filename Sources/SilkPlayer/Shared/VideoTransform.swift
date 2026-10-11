//
//  VideoTransform.swift
//  SilkPlayer
//
//  Created for SilkPlayer - Mathematical Video Transform Model.
//  Single Source of Truth for Rotation, Mirroring, and Coordinate Mapping.
//

import Foundation
import CoreGraphics

/// Immutable, thread-safe mathematical transform model representing video orientation, mirroring, and spatial mapping.
public struct VideoTransform: Sendable, Equatable {
    /// File intrinsic rotation from container metadata / DisplayMatrix (0, 90, 180, 270)
    public var intrinsicRotation: Int
    /// User manual rotation in 90-degree steps (0, 90, 180, 270)
    public var userRotation: Int
    /// Screen-space horizontal mirror
    public var flipH: Bool
    /// Screen-space vertical mirror
    public var flipV: Bool
    /// Digital zoom factor (reserved for P1/P2)
    public var zoom: Double
    /// Pan offset in screen points (reserved for P1/P2)
    public var pan: CGPoint

    public init(
        intrinsicRotation: Int = 0,
        userRotation: Int = 0,
        flipH: Bool = false,
        flipV: Bool = false,
        zoom: Double = 1.0,
        pan: CGPoint = .zero
    ) {
        self.intrinsicRotation = ((intrinsicRotation % 360) + 360) % 360
        self.userRotation = ((userRotation % 360) + 360) % 360
        self.flipH = flipH
        self.flipV = flipV
        self.zoom = zoom
        self.pan = pan
    }

    /// Effective composite rotation angle: 0, 90, 180, or 270 degrees
    public var effectiveRotation: Int {
        ((intrinsicRotation + userRotation) % 360 + 360) % 360
    }

    /// Whether the effective orientation is perpendicular to raw video layout (90° or 270°)
    public var isPerpendicular: Bool {
        let r = effectiveRotation
        return r == 90 || r == 270
    }

    /// Checks if the presented video is vertical (aspect ratio < 1.0)
    public func isEffectiveVertical(
        rawWidth: Int,
        rawHeight: Int,
        sar: (num: Int, den: Int)? = nil,
        ratioSetting: String = "auto"
    ) -> Bool {
        displayAspectRatio(rawWidth: rawWidth, rawHeight: rawHeight, sar: sar, ratioSetting: ratioSetting) < 1.0
    }

    /// Primary display aspect ratio (width / height) taking SAR/DAR and rotation into account
    public func displayAspectRatio(
        rawWidth: Int,
        rawHeight: Int,
        sar: (num: Int, den: Int)? = nil,
        ratioSetting: String = "auto"
    ) -> CGFloat {
        let baseAspect: CGFloat
        switch ratioSetting {
        case "16:9":
            baseAspect = 16.0 / 9.0
        case "4:3":
            baseAspect = 4.0 / 3.0
        case "2.35:1":
            baseAspect = 2.35
        default:
            var w = CGFloat(rawWidth > 0 ? rawWidth : 1920)
            let h = CGFloat(rawHeight > 0 ? rawHeight : 1080)
            if let sar = sar, sar.num > 0, sar.den > 0, sar.num != sar.den {
                w = round(w * CGFloat(sar.num) / CGFloat(sar.den))
            }
            baseAspect = w / max(1.0, h)
        }

        return isPerpendicular ? (1.0 / max(0.001, baseAspect)) : baseAspect
    }

    /// Calculates the letterboxed/pillarboxed active video rectangle inside a view size
    public func renderedVideoRect(
        in viewSize: CGSize,
        rawWidth: Int,
        rawHeight: Int,
        sar: (num: Int, den: Int)? = nil,
        ratioSetting: String = "auto"
    ) -> CGRect {
        guard viewSize.width > 0, viewSize.height > 0 else { return .zero }
        let aspect = displayAspectRatio(rawWidth: rawWidth, rawHeight: rawHeight, sar: sar, ratioSetting: ratioSetting)
        let viewAspect = viewSize.width / viewSize.height

        var w: CGFloat
        var h: CGFloat
        if viewAspect > aspect {
            h = viewSize.height
            w = h * aspect
        } else {
            w = viewSize.width
            h = w / aspect
        }
        let x = (viewSize.width - w) / 2.0
        let y = (viewSize.height - h) / 2.0
        return CGRect(x: x, y: y, width: w, height: h)
    }

    /// Maps a point from view coordinates to raw video pixel coordinates
    public func viewToVideo(
        point: CGPoint,
        in viewSize: CGSize,
        rawWidth: Int,
        rawHeight: Int,
        sar: (num: Int, den: Int)? = nil,
        ratioSetting: String = "auto"
    ) -> CGPoint? {
        let videoRect = renderedVideoRect(in: viewSize, rawWidth: rawWidth, rawHeight: rawHeight, sar: sar, ratioSetting: ratioSetting)
        guard videoRect.contains(point), videoRect.width > 0, videoRect.height > 0 else { return nil }

        // Normalize to [0, 1] presented viewport coordinates
        var normX = (point.x - videoRect.minX) / videoRect.width
        var normY = (point.y - videoRect.minY) / videoRect.height

        if flipH { normX = 1.0 - normX }
        if flipV { normY = 1.0 - normY }

        let rw = CGFloat(rawWidth > 0 ? rawWidth : 1920)
        let rh = CGFloat(rawHeight > 0 ? rawHeight : 1080)

        let origX: CGFloat
        let origY: CGFloat
        switch effectiveRotation {
        case 90:
            origX = (1.0 - normY) * rw
            origY = normX * rh
        case 180:
            origX = (1.0 - normX) * rw
            origY = (1.0 - normY) * rh
        case 270:
            origX = normY * rw
            origY = (1.0 - normX) * rh
        default:
            origX = normX * rw
            origY = normY * rh
        }

        return CGPoint(x: origX, y: origY)
    }

    /// Maps a point from raw video pixel coordinates to view coordinates
    public func videoToView(
        point: CGPoint,
        in viewSize: CGSize,
        rawWidth: Int,
        rawHeight: Int,
        sar: (num: Int, den: Int)? = nil,
        ratioSetting: String = "auto"
    ) -> CGPoint {
        let rw = CGFloat(rawWidth > 0 ? rawWidth : 1920)
        let rh = CGFloat(rawHeight > 0 ? rawHeight : 1080)
        let videoRect = renderedVideoRect(in: viewSize, rawWidth: rawWidth, rawHeight: rawHeight, sar: sar, ratioSetting: ratioSetting)

        let normOrigX = max(0.0, min(1.0, point.x / rw))
        let normOrigY = max(0.0, min(1.0, point.y / rh))

        var normX: CGFloat
        var normY: CGFloat
        switch effectiveRotation {
        case 90:
            normX = normOrigY
            normY = 1.0 - normOrigX
        case 180:
            normX = 1.0 - normOrigX
            normY = 1.0 - normOrigY
        case 270:
            normX = 1.0 - normOrigY
            normY = normOrigX
        default:
            normX = normOrigX
            normY = normOrigY
        }

        if flipH { normX = 1.0 - normX }
        if flipV { normY = 1.0 - normY }

        return CGPoint(
            x: videoRect.minX + normX * videoRect.width,
            y: videoRect.minY + normY * videoRect.height
        )
    }

    /// Steps clockwise by 90 degrees
    public mutating func rotateClockwise() {
        userRotation = (userRotation + 90) % 360
    }

    /// Steps counterclockwise by 90 degrees
    public mutating func rotateCounterclockwise() {
        userRotation = (userRotation + 270) % 360
    }

    /// Toggles horizontal mirroring
    public mutating func toggleFlipH() {
        flipH.toggle()
    }

    /// Toggles vertical mirroring
    public mutating func toggleFlipV() {
        flipV.toggle()
    }

    /// Resets rotation to the file's natural orientation (userRotation = 0)
    public mutating func resetToNatural() {
        userRotation = 0
        flipH = false
        flipV = false
        zoom = 1.0
        pan = .zero
    }
}
