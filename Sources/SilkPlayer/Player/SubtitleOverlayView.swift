import SwiftUI
import AppKit
import SilkCoreKit

/// Native Cinema Subtitle Overlay View for SilkPlayer.
/// Conforms to macOS Human Interface Guidelines & Professional Video Standards:
/// 1. PGS / SUP Blu-ray bitmap subtitles scale proportionally to exact video coordinates,
///    never stretched, never cut off, maintaining pixel-perfect Blu-ray master layout.
/// 2. Text subtitles (SRT, ASS, VTT) render in authentic cinema style:
///    - Dynamic font scaling proportional to video height (never miniature on 4K, never huge on small windows)
///    - Pure white typography with multi-directional high-contrast drop shadow (no machine-translation dark box)
///    - Adaptive bottom clearance that clears the HUD progress bar smoothly.
@MainActor
public struct SubtitleOverlayView: View {
    @ObservedObject var player: PlayerCore
    @ObservedObject var subtitleModel: SubtitleModel

    public init(player: PlayerCore) {
        self.player = player
        self.subtitleModel = player.subtitleModel
    }

    public var body: some View {
        GeometryReader { geometry in
            let viewW = max(1.0, geometry.size.width)
            let viewH = max(1.0, geometry.size.height)

            // Compute exact aspect-fitted video display rectangle within view using transform
            let rawVideoW = CGFloat(player.displayVideoWidth > 0 ? player.displayVideoWidth : (player.videoWidth > 0 ? player.videoWidth : 1920))
            let rawVideoH = CGFloat(player.displayVideoHeight > 0 ? player.displayVideoHeight : (player.videoHeight > 0 ? player.videoHeight : 1080))
            let videoRect = player.transform.renderedVideoRect(
                in: CGSize(width: viewW, height: viewH),
                rawWidth: Int(rawVideoW),
                rawHeight: Int(rawVideoH),
                ratioSetting: player.videoAspectRatio
            )
            let renderedW = videoRect.width
            let renderedH = videoRect.height
            let originX = videoRect.minX
            let originY = videoRect.minY

            ZStack {
                ForEach(subtitleModel.parts) { part in
                    if let image = part.image {
                        renderBitmapSubtitle(
                            image: image,
                            origin: part.origin,
                            videoW: rawVideoW,
                            videoH: rawVideoH,
                            renderedW: renderedW,
                            renderedH: renderedH,
                            originX: originX,
                            originY: originY,
                            viewW: viewW,
                            viewH: viewH
                        )
                    } else if let attrText = part.text {
                        renderTextSubtitle(
                            attrText: attrText,
                            textPosition: part.textPosition,
                            renderedW: renderedW,
                            renderedH: renderedH,
                            originY: originY,
                            viewW: viewW,
                            viewH: viewH
                        )
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .allowsHitTesting(false)
        .animation(.easeInOut(duration: 0.18), value: player.isHUDVisible)
    }

    // MARK: - PGS / Bitmap Subtitle Rendering (e.g. Red Sparrow, Blu-ray Remux)
    @ViewBuilder
    private func renderBitmapSubtitle(
        image: NSImage,
        origin: CGPoint,
        videoW: CGFloat,
        videoH: CGFloat,
        renderedW: CGFloat,
        renderedH: CGFloat,
        originX: CGFloat,
        originY: CGFloat,
        viewW: CGFloat,
        viewH: CGFloat
    ) -> some View {
        let imgW = image.size.width
        let imgH = image.size.height

        let scale = player.subtitleScale

        // Case 1: Full-frame PGS composite (spans majority of Blu-ray 1080p / 2160p canvas)
        if (imgW >= videoW * 0.75 || imgW >= 1440.0) && imgH >= 360.0 {
            let pgsAspect = imgW / max(1.0, imgH)
            let fitW = renderedW * scale
            let fitH = fitW / pgsAspect
            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .frame(width: fitW, height: fitH)
                .position(x: viewW / 2.0, y: originY + (renderedH / 2.0))
        }
        // Case 2: Sub-rectangle with explicit video-relative origin
        else if origin != .zero {
            // Blu-ray BD-ROM HDMV PGS specification standardizes subtitle authoring
            // on a 1920x1080 canvas (even for 4K UHD Blu-ray releases like 300).
            let standard169Height = videoW * 9.0 / 16.0
            let isCropped = videoH < standard169Height * 0.90
            let pgsCanvasW: CGFloat = 1920.0
            let pgsCanvasH: CGFloat = isCropped ? (pgsCanvasW / (videoW / max(1.0, videoH))) : 1080.0
            let topLetterboxOffset = isCropped ? ((1080.0 - pgsCanvasH) / 2.0) : 0.0
            let adjustedOriginY = max(0.0, origin.y - topLetterboxOffset)

            let normX = origin.x / pgsCanvasW
            let normY = adjustedOriginY / pgsCanvasH
            let normW = imgW / pgsCanvasW
            let normH = imgH / pgsCanvasH

            let subW = normW * renderedW * scale
            let subH = normH * renderedH * scale
            let subCenterX = originX + (normX * renderedW) + (subW / 2.0)

            let computedCenterY = originY + (normY * renderedH) + (subH / 2.0)
            let minTopCenterY = max(originY + 12.0, player.isFullscreen ? 16.0 : 44.0) + (subH / 2.0)
            let maxBottomCenterY = originY + renderedH - (subH / 2.0) - (player.isHUDVisible ? 90.0 : 20.0)
            let subCenterY = min(maxBottomCenterY, max(minTopCenterY, computedCenterY))

            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
                .frame(width: subW, height: subH)
                .position(x: subCenterX, y: subCenterY)
        }
        // Case 3: Cropped bitmap subtitle without origin (render proportionally at bottom-center of video)
        else {
            let scale = min(renderedW / max(1.0, imgW), renderedH / max(1.0, imgH))
            let subW = min(renderedW * 0.85, imgW * scale)
            let subH = max(1.0, subW * (imgH / max(1.0, imgW)))
            let bottomPad: CGFloat = player.isHUDVisible ? 110.0 : 38.0
            let targetCenterY = originY + renderedH - (subH / 2.0) - bottomPad

            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
                .frame(width: subW, height: subH)
                .position(x: viewW / 2.0, y: targetCenterY)
        }
    }

    // MARK: - Text Subtitle Rendering (e.g. Spider-Man, Red Sparrow, SRT, ASS, VTT)
    @ViewBuilder
    private func renderTextSubtitle(
        attrText: NSAttributedString,
        textPosition: TextPosition?,
        renderedW: CGFloat,
        renderedH: CGFloat,
        originY: CGFloat,
        viewW: CGFloat,
        viewH: CGFloat
    ) -> some View {
        let textStr = attrText.string.trimmingCharacters(in: .whitespacesAndNewlines)
        if !textStr.isEmpty {
            // Dynamic cinema font size: ~5.0% of visible video height, scaled by user preference
            let baseFontSize = max(26.0, min(68.0, renderedH * 0.050))
            let finalFontSize = baseFontSize * player.subtitleScale
            let maxContentWidth = max(200.0, min(renderedW * 0.88, 1200.0))

            if let subtitleImage = generateCinemaSubtitleImage(
                attrText: attrText,
                fontSize: finalFontSize,
                maxWidth: maxContentWidth
            ) {
                let subW = subtitleImage.size.width
                let subH = subtitleImage.size.height
                let isTop = textPosition?.verticalAlign == .top

                let targetCenterY: CGFloat = {
                    if isTop {
                        let minSafeTop = max(originY + 16.0, player.isFullscreen ? 24.0 : 48.0)
                        return minSafeTop + (subH / 2.0)
                    } else {
                        // Bottom-anchored layout:
                        // Multi-line subtitles expand UPWARDS so bottom descenders never clip or sink into the HUD.
                        let bottomClearance: CGFloat = player.isHUDVisible ? 126.0 : 42.0
                        let videoBottom = originY + renderedH
                        // Anchor to the higher of video bottom margin or window HUD avoidance
                        let targetBottom = min(videoBottom - bottomClearance, viewH - (player.isHUDVisible ? 126.0 : 20.0))
                        let computedCenterY = targetBottom - (subH / 2.0)
                        let minTopCenterY = originY + 20.0 + (subH / 2.0)
                        return max(minTopCenterY, computedCenterY)
                    }
                }()

                Image(nsImage: subtitleImage)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: subW, height: subH)
                    .position(
                        x: viewW / 2.0,
                        y: targetCenterY
                    )
            }
        }
    }

    /// Renders cinema-grade typography with 8-directional solid fill dilation,
    /// soft ambient drop shadow, and generous descender padding to guarantee zero Lego wireframe artifacts.
    private func generateCinemaSubtitleImage(
        attrText: NSAttributedString,
        fontSize: CGFloat,
        maxWidth: CGFloat
    ) -> NSImage? {
        let textStr = attrText.string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !textStr.isEmpty else { return nil }

        let cacheKey = SubtitleCacheKey(text: textStr, fontSize: Int(fontSize), maxWidth: Int(maxWidth))
        if let cached = SubtitleImageCache.shared.image(for: cacheKey) {
            return cached
        }

        return autoreleasepool {
            let baseFont = NSFont.systemFont(ofSize: fontSize, weight: .bold)
            // Dilation distance: solid outline thickness (8-way expansion)
            let d: CGFloat = max(1.5, fontSize * 0.035)
            // Generous vertical and horizontal padding for dilation, descenders (g, j, p, q, y) and ambient shadow
            let strokeMargin: CGFloat = ceil(d) + ceil(abs(baseFont.descender)) + 10.0

            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .center
            paragraphStyle.lineBreakMode = .byWordWrapping
            paragraphStyle.lineSpacing = max(2.0, fontSize * 0.10)

            let blackAttrText = NSMutableAttributedString(attributedString: attrText)
            let whiteAttrText = NSMutableAttributedString(attributedString: attrText)
            let fullRange = NSRange(location: 0, length: attrText.length)

            // Normalize font while preserving existing style traits (e.g. italics from ASS / VTT)
            blackAttrText.enumerateAttribute(.font, in: fullRange, options: []) { value, range, _ in
                var targetFont = baseFont
                if let existingFont = value as? NSFont {
                    let traits = existingFont.fontDescriptor.symbolicTraits
                    var newDescriptor = baseFont.fontDescriptor
                    if traits.contains(.italic) { newDescriptor = newDescriptor.withSymbolicTraits(.italic) }
                    if traits.contains(.bold) { newDescriptor = newDescriptor.withSymbolicTraits(.bold) }
                    targetFont = NSFont(descriptor: newDescriptor, size: fontSize) ?? baseFont
                }
                blackAttrText.removeAttribute(.font, range: range)
                blackAttrText.addAttribute(.font, value: targetFont, range: range)

                whiteAttrText.removeAttribute(.font, range: range)
                whiteAttrText.addAttribute(.font, value: targetFont, range: range)
            }

            // CRITICAL FIX: Strictly ZERO .strokeWidth!
            // CJK characters in Apple CoreText must use pure solid fill to avoid composite glyph outline cross-stitching.
            blackAttrText.removeAttribute(.strokeWidth, range: fullRange)
            blackAttrText.removeAttribute(.strokeColor, range: fullRange)
            blackAttrText.addAttribute(.paragraphStyle, value: paragraphStyle, range: fullRange)
            blackAttrText.addAttribute(.foregroundColor, value: NSColor.black, range: fullRange)

            whiteAttrText.removeAttribute(.strokeWidth, range: fullRange)
            whiteAttrText.removeAttribute(.strokeColor, range: fullRange)
            whiteAttrText.addAttribute(.paragraphStyle, value: paragraphStyle, range: fullRange)
            whiteAttrText.addAttribute(.foregroundColor, value: NSColor.white, range: fullRange)

            let constraintWidth = max(100.0, maxWidth - (strokeMargin * 2.0))
            let textBounds = whiteAttrText.boundingRect(
                with: NSSize(width: constraintWidth, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading]
            )

            let contentW = ceil(textBounds.width)
            let contentH = ceil(textBounds.height)
            let totalW = contentW + (strokeMargin * 2.0)
            let totalH = contentH + (strokeMargin * 2.0)
            let totalSize = NSSize(width: totalW, height: totalH)

            // Support full 2.0x / 3.0x Retina backing resolution
            let backingScale = NSScreen.main?.backingScaleFactor ?? 2.0
            let pixelW = max(1, Int(ceil(totalW * backingScale)))
            let pixelH = max(1, Int(ceil(totalH * backingScale)))

            guard let rep = NSBitmapImageRep(
                bitmapDataPlanes: nil,
                pixelsWide: pixelW,
                pixelsHigh: pixelH,
                bitsPerSample: 8,
                samplesPerPixel: 4,
                hasAlpha: true,
                isPlanar: false,
                colorSpaceName: .deviceRGB,
                bytesPerRow: 0,
                bitsPerPixel: 0
            ) else { return nil }

            rep.size = totalSize
            let image = NSImage(size: totalSize)
            image.addRepresentation(rep)

            image.lockFocus()
            guard let ctx = NSGraphicsContext.current?.cgContext else {
                image.unlockFocus()
                return nil
            }

            let drawRect = NSRect(x: strokeMargin, y: strokeMargin, width: contentW, height: contentH)

            // Phase 1: High-contrast ambient shadow for bright HDR/SDR scenes
            ctx.saveGState()
            let shadowColor = NSColor.black.withAlphaComponent(0.80).cgColor
            ctx.setShadow(offset: CGSize(width: 0, height: -1.5), blur: 3.0, color: shadowColor)
            blackAttrText.draw(in: drawRect.offsetBy(dx: 0, dy: -d))
            ctx.restoreGState()

            // Phase 2: 8-Directional Solid Fill Dilation (Pure Fill, Zero Stroke)
            // Eliminates all inner glyph wireframes while producing a solid, uniform outer border
            let offsets: [(CGFloat, CGFloat)] = [
                (-d, 0), (d, 0), (0, -d), (0, d),
                (-d, -d), (-d, d), (d, -d), (d, d)
            ]
            for (dx, dy) in offsets {
                blackAttrText.draw(in: drawRect.offsetBy(dx: dx, dy: dy))
            }

            // Phase 3: Pure white core text fill at center
            whiteAttrText.draw(in: drawRect)

            image.unlockFocus()

            SubtitleImageCache.shared.set(image, for: cacheKey)
            return image
        }
    }
}

// MARK: - Subtitle Memory Optimization: Zero-Allocation Image Cache
struct SubtitleCacheKey: Hashable, Sendable {
    let text: String
    let fontSize: Int
    let maxWidth: Int
}

final class SubtitleImageCache: @unchecked Sendable {
    static let shared = SubtitleImageCache()
    private let lock = NSLock()
    private var cache: [SubtitleCacheKey: NSImage] = [:]
    private var keysOrder: [SubtitleCacheKey] = []
    private let maxEntries = 8

    func image(for key: SubtitleCacheKey) -> NSImage? {
        lock.lock()
        defer { lock.unlock() }
        return cache[key]
    }

    func set(_ image: NSImage, for key: SubtitleCacheKey) {
        lock.lock()
        defer { lock.unlock() }
        if cache[key] == nil {
            if keysOrder.count >= maxEntries {
                let oldest = keysOrder.removeFirst()
                cache.removeValue(forKey: oldest)
            }
            keysOrder.append(key)
        }
        cache[key] = image
    }

    func clear() {
        lock.lock()
        defer { lock.unlock() }
        cache.removeAll()
        keysOrder.removeAll()
    }
}
