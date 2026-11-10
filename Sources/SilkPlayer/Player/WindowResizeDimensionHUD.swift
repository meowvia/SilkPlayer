import SwiftUI
import AppKit

/// Formatter that calculates live dimensions and human-readable aspect ratio.
public struct WindowDimensionFormatter: Sendable {
    public static func format(
        size: CGSize,
        videoWidth: Int = 0,
        videoHeight: Int = 0,
        isAudioOnly: Bool = false
    ) -> (dimensions: String, ratio: String) {
        let w = Int(round(size.width))
        let h = Int(round(size.height))
        let dimStr = "\(w) × \(h)"

        if isAudioOnly {
            return (dimStr, "1:1")
        }

        guard w > 0 && h > 0 else {
            return (dimStr, "")
        }

        let r = Double(w) / Double(h)
        var ratioLabel: String

        // Precision matching against common cinematographic and display aspect ratios:
        if abs(r - (16.0 / 9.0)) <= 0.045 {
            ratioLabel = "16:9"
        } else if abs(r - (16.0 / 10.0)) <= 0.035 {
            ratioLabel = "16:10"
        } else if abs(r - (4.0 / 3.0)) <= 0.035 {
            ratioLabel = "4:3"
        } else if abs(r - 2.39) <= 0.05 || abs(r - 2.35) <= 0.05 {
            ratioLabel = "2.39:1"
        } else if abs(r - (21.0 / 9.0)) <= 0.05 {
            ratioLabel = "21:9"
        } else if abs(r - 1.0) <= 0.03 {
            ratioLabel = "1:1"
        } else if abs(r - (9.0 / 16.0)) <= 0.035 {
            ratioLabel = "9:16"
        } else {
            ratioLabel = String(format: "%.2f:1", r)
        }

        // 100% Native Resolution Pixel-to-Pixel Alignment:
        if videoWidth > 0 && videoHeight > 0 && abs(w - videoWidth) <= 1 && abs(h - videoHeight) <= 1 {
            ratioLabel += " · 100%"
        }

        return (dimStr, ratioLabel)
    }
}

/// Floating HUD badge showing current window dimensions and aspect ratio during manual drag resize.
/// Follows cursor dynamically with safe viewport padding.
public struct WindowResizeDimensionHUD: View {
    public let size: CGSize
    public let cursorLocation: CGPoint?
    public let windowSize: CGSize
    public let videoWidth: Int
    public let videoHeight: Int
    public let isAudioOnly: Bool

    public init(
        size: CGSize,
        cursorLocation: CGPoint? = nil,
        windowSize: CGSize,
        videoWidth: Int = 0,
        videoHeight: Int = 0,
        isAudioOnly: Bool = false
    ) {
        self.size = size
        self.cursorLocation = cursorLocation
        self.windowSize = windowSize
        self.videoWidth = videoWidth
        self.videoHeight = videoHeight
        self.isAudioOnly = isAudioOnly
    }

    private var formatted: (dimensions: String, ratio: String) {
        WindowDimensionFormatter.format(
            size: size,
            videoWidth: videoWidth,
            videoHeight: videoHeight,
            isAudioOnly: isAudioOnly
        )
    }

    private var targetPosition: CGPoint {
        let pillW: CGFloat = 175
        let pillH: CGFloat = 34

        guard let cursor = cursorLocation, cursor.x > 0 || cursor.y > 0 else {
            // Default center if cursor location is unknown
            return CGPoint(x: windowSize.width / 2, y: windowSize.height / 2)
        }

        // Convert AppKit (bottom-left) to SwiftUI (top-left)
        let cursorSwiftUI = CGPoint(x: cursor.x, y: windowSize.height - cursor.y)

        var posX = cursorSwiftUI.x
        var posY = cursorSwiftUI.y

        // Offset intelligently toward interior of window so pill stays visible
        if posX > windowSize.width - 140 {
            posX -= (pillW / 2 + 20)
        } else if posX < 140 {
            posX += (pillW / 2 + 20)
        }

        if posY > windowSize.height - 70 {
            posY -= (pillH / 2 + 22)
        } else if posY < 70 {
            posY += (pillH / 2 + 22)
        }

        // Clamp securely inside safe margins
        let minX = pillW / 2 + 16
        let maxX = max(minX, windowSize.width - pillW / 2 - 16)
        let minY = pillH / 2 + 16
        let maxY = max(minY, windowSize.height - pillH / 2 - 16)

        return CGPoint(
            x: min(max(minX, posX), maxX),
            y: min(max(minY, posY), maxY)
        )
    }

    public var body: some View {
        let (dimensions, ratio) = formatted
        HStack(spacing: 6) {
            Image(systemName: "aspectratio")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white.opacity(0.85))

            Text(dimensions)
                .font(.system(size: 12.5, weight: .bold, design: .monospaced))
                .foregroundColor(.white)

            if !ratio.isEmpty {
                Text("·")
                    .foregroundColor(.white.opacity(0.45))
                    .font(.system(size: 12, weight: .medium))

                Text(ratio)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundColor(Color(nsColor: .systemTeal).opacity(0.95))
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.black.opacity(0.78))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 0.8)
        )
        .shadow(color: Color.black.opacity(0.40), radius: 6, x: 0, y: 3)
        .position(targetPosition)
        .allowsHitTesting(false)
    }
}
