//
//  WindowGeometryCoordinator.swift
//  SilkPlayer
//
//  Created for SilkPlayer - Unified Single Window Geometry State Machine.
//  Coordinates window sizing, aspect ratio constraints, safe area clamping,
//  and seamless transitions between video (16:9, vertical 9:16) and audio (1:1 vinyl) modes.
//

import AppKit
import Foundation

@MainActor
public final class WindowGeometryCoordinator {
    public static let shared = WindowGeometryCoordinator()
    private init() {}

    public enum WindowMode: Equatable {
        case idle
        case video(aspectRatio: CGFloat, isVertical: Bool)
        case audio
        case fullscreen
    }

    public private(set) var currentMode: WindowMode = .idle
    private var isAdjusting: Bool = false

    /// Transitions window frame and constraints to target presentation mode cleanly.
    public func transition(
        window: NSWindow,
        to mode: WindowMode,
        videoWidth: Int = 0,
        videoHeight: Int = 0,
        animated: Bool = false
    ) {
        guard !window.styleMask.contains(.fullScreen) else {
            currentMode = .fullscreen
            return
        }

        guard !isAdjusting else { return }
        isAdjusting = true
        defer { isAdjusting = false }

        self.currentMode = mode
        let screen = window.screen ?? NSScreen.main
        let screenFrame = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)

        // Reset aspect locks prior to constraint changes to prevent AppKit animation conflict
        window.contentAspectRatio = .zero
        window.aspectRatio = .zero

        switch mode {
        case .idle:
            let minSz = NSSize(width: 640, height: 360)
            window.minSize = minSz
            window.contentMinSize = minSz
            window.maxSize = screenFrame.size
            window.contentMaxSize = screenFrame.size

        case .audio:
            let minAudioSize = NSSize(width: 380, height: 380)
            let maxSquare = min(screenFrame.width, screenFrame.height)
            let maxAudioSize = NSSize(width: maxSquare, height: maxSquare)

            window.minSize = minAudioSize
            window.contentMinSize = minAudioSize
            window.maxSize = maxAudioSize
            window.contentMaxSize = maxAudioSize

            let currentFrame = window.frame
            let isAlreadySquareAudio = abs(currentFrame.width - currentFrame.height) <= 4.0 && currentFrame.width >= 360
            if !isAlreadySquareAudio {
                let targetSize: CGFloat = 520
                let currentCenter = CGPoint(x: window.frame.midX, y: window.frame.midY)
                let newX = max(screenFrame.minX, min(screenFrame.maxX - targetSize, currentCenter.x - targetSize / 2))
                let newY = max(screenFrame.minY, min(screenFrame.maxY - targetSize, currentCenter.y - targetSize / 2))
                let newFrame = NSRect(x: newX, y: newY, width: targetSize, height: targetSize)
                window.setFrame(newFrame, display: true, animate: animated)
            }

        case .video(let aspect, let isVertical):
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
                    targetContentH = round(targetContentW / max(0.001, aspect))
                }
                if targetContentW < minSz.width {
                    targetContentW = minSz.width
                    targetContentH = round(targetContentW / max(0.001, aspect))
                }
            } else {
                let vW = CGFloat(videoWidth > 0 ? videoWidth : 1280)
                let idealW = min(vW, screenFrame.width * 0.55)
                targetContentW = max(minSz.width, min(maxSafeContentSz.width, idealW))
                targetContentH = round(targetContentW / max(0.001, aspect))

                if targetContentH > maxSafeContentSz.height {
                    targetContentH = maxSafeContentSz.height
                    targetContentW = round(targetContentH * aspect)
                }
                if targetContentW < minSz.width {
                    targetContentW = minSz.width
                    targetContentH = minSz.height
                }
            }

            let currentCenter = CGPoint(x: window.frame.midX, y: window.frame.midY)
            let newX = max(screenFrame.minX, min(screenFrame.maxX - targetContentW, currentCenter.x - targetContentW / 2))
            let newY = max(screenFrame.minY, min(screenFrame.maxY - targetContentH, currentCenter.y - targetContentH / 2))
            let newFrame = NSRect(x: newX, y: newY, width: targetContentW, height: targetContentH)

            window.minSize = NSSize(width: 100, height: 100)
            window.contentMinSize = window.minSize

            window.setFrame(newFrame, display: true, animate: animated)

            window.minSize = minSz
            window.contentMinSize = minSz
            window.maxSize = screenFrame.size
            window.contentMaxSize = screenFrame.size

        case .fullscreen:
            break
        }
    }
}
