import SwiftUI
import AppKit
import QuartzCore

// MARK: - Native Audio Artwork & Liquid Glass Presentation View
@MainActor
public struct AudioArtworkView: View {
    @ObservedObject var player: PlayerCore
    var playlist: PlaylistManager

    public init(player: PlayerCore, playlist: PlaylistManager) {
        self.player = player
        self.playlist = playlist
    }

    /// Next track title dynamically resolved based on current playback mode
    private var nextTrackPreviewTitle: String? {
        guard let item = playlist.upcomingItem else { return nil }
        if playlist.playbackMode == .singleLoop {
            return "\(item.title) (\(L10n.tr("Single Loop", "单曲循环")))"
        }
        return item.title
    }

    public static func computeCoverCardSize(availableW: CGFloat, availableH: CGFloat) -> CGFloat {
        let topSafeInset: CGFloat = 58.0
        let bottomSafeInset: CGFloat = 108.0
        let safeH = max(180, availableH - topSafeInset - bottomSafeInset)
        return min(360, min(availableW * 0.52, safeH * 0.52))
    }

    public var body: some View {
        GeometryReader { geometry in
            let availableW = geometry.size.width
            let availableH = geometry.size.height
            let topSafeInset: CGFloat = 58.0
            let bottomSafeInset: CGFloat = 108.0
            let safeH = max(180, availableH - topSafeInset - bottomSafeInset)
            let coverCardSize = Self.computeCoverCardSize(availableW: availableW, availableH: availableH)
            let vinylDiameter = max(120, min(320, min(availableW * 0.44, safeH * 0.44)))

            ZStack {
                // 1. Native macOS Liquid Glass frosted backdrop
                VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                    .edgesIgnoringSafeArea(.all)

                // 2. Dark background tint overlay
                Color(red: 0.06, green: 0.07, blue: 0.09).opacity(0.50)
                    .edgesIgnoringSafeArea(.all)

                // 3. Dynamic Backdrop Art (if album art is present)
                if let artwork = player.artworkImage {
                    AudioBackdropArtView(
                        artwork: artwork,
                        isPlaying: player.isPlaying,
                        rhythm: player.audioRhythm,
                        width: availableW,
                        height: availableH
                    )
                }

                // 4. Subtle outer window glass border highlight
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.18), Color.white.opacity(0.04)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.0
                    )
                    .edgesIgnoringSafeArea(.all)
                    .allowsHitTesting(false)

                // 5. Centered Presentation: Vinyl Disc & Audio Visualizer Halo (Safe Inset Viewport)
                VStack(spacing: max(10, min(22, safeH * 0.045))) {
                    if let artwork = player.artworkImage {
                        AudioCoverBloomCardView(
                            artwork: artwork,
                            isPlaying: player.isPlaying,
                            rhythm: player.audioRhythm,
                            coverCardSize: coverCardSize
                        )
                    } else {
                        // Vinyl Disc with Audio Visualizer Halo
                        FloatingVinylDiscView(
                            diameter: vinylDiameter,
                            isPlaying: player.isPlaying,
                            rhythm: player.audioRhythm
                        )
                    }

                    // Track Title & Next Track Preview
                    VStack(spacing: 0) {
                        Text(player.mediaTitle)
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.95))
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .padding(.horizontal, 48)
                            .shadow(color: .black.opacity(0.50), radius: 6, x: 0, y: 2)

                        if let nextTitle = nextTrackPreviewTitle {
                            // 空一行
                            Spacer()
                                .frame(height: max(6, min(14, safeH * 0.04)))

                            // 不对齐正在播放歌名（偏置缩进 18pt），再空两格预告，下一首：
                            HStack(spacing: 0) {
                                Text(L10n.tr("Next:  ", "下一首：  "))
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundColor(Color(red: 0.95, green: 0.82, blue: 0.55).opacity(0.65))

                                Text(nextTitle)
                                    .font(.system(size: 12, weight: .regular, design: .rounded))
                                    .foregroundColor(.white.opacity(0.45))
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                            .offset(x: 18)
                            .padding(.horizontal, 48)
                            .transition(.opacity)
                        }
                    }
                }
                .frame(width: availableW, height: safeH, alignment: .center)
                .padding(.top, topSafeInset)
                .padding(.bottom, bottomSafeInset)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - Decoupled Rhythm Artwork Leaf Views
@MainActor
private struct AudioBackdropArtView: View {
    let artwork: NSImage
    let isPlaying: Bool
    let rhythm: PlayerAudioRhythm
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        let b0 = isPlaying ? (rhythm.levels.first ?? 0.0) : 0.0
        Image(nsImage: artwork)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: width, height: height)
            .blur(radius: 68)
            .opacity(0.28 + Double(b0) * 0.12)
            .scaleEffect(1.15)
            .clipped()
            .animation(.easeOut(duration: 0.07), value: b0)
    }
}

@MainActor
private struct AudioCoverBloomCardView: View {
    let artwork: NSImage
    let isPlaying: Bool
    let rhythm: PlayerAudioRhythm
    let coverCardSize: CGFloat

    var body: some View {
        let levels = rhythm.levels
        let b0 = isPlaying ? (levels.first ?? 0.0) : 0.0
        let b1 = (isPlaying && levels.count > 1) ? levels[1] : 0.0
        let bassEnergy = b0 * 0.65 + b1 * 0.35

        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    RadialGradient(
                        stops: [
                            .init(color: Color(red: 0.98, green: 0.84, blue: 0.52).opacity(0.50), location: 0.25),
                            .init(color: Color(red: 0.90, green: 0.70, blue: 0.38).opacity(0.26), location: 0.65),
                            .init(color: Color.clear, location: 1.0)
                        ],
                        center: .center,
                        startRadius: coverCardSize * 0.20,
                        endRadius: coverCardSize * 0.75
                    )
                )
                .frame(width: coverCardSize * 1.08, height: coverCardSize * 1.08)
                .scaleEffect(1.0 + CGFloat(bassEnergy) * 0.15)
                .opacity(isPlaying ? (0.48 + Double(bassEnergy) * 0.52) : 0.08)
                .animation(.easeOut(duration: 0.07), value: bassEnergy)

            Image(nsImage: artwork)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: coverCardSize, maxHeight: coverCardSize)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1.0)
                )
                .shadow(color: .black.opacity(0.55), radius: 26, x: 0, y: 14)
                .scaleEffect(isPlaying ? (1.0 + CGFloat(bassEnergy) * 0.015) : 1.0)
                .animation(.easeOut(duration: 0.07), value: bassEnergy)
        }
        .frame(width: coverCardSize, height: coverCardSize)
    }
}

// MARK: - Audio Visualizer Halo View
@MainActor
struct AudioVisualizerHaloView: View {
    let diameter: CGFloat
    let rhythm: PlayerAudioRhythm
    let isPlaying: Bool

    var body: some View {
        let levels = rhythm.levels
        let b0 = isPlaying ? (levels.first ?? 0.0) : 0.0
        let b1 = (isPlaying && levels.count > 1) ? levels[1] : 0.0
        let b2 = (isPlaying && levels.count > 3) ? levels[3] : 0.0
        let b3 = (isPlaying && levels.count > 5) ? levels[5] : 0.0

        let bassEnergy = b0 * 0.65 + b1 * 0.35
        let midEnergy = b1 * 0.30 + b2 * 0.70
        let highEnergy = b2 * 0.25 + b3 * 0.75

        ZStack {
            // Layer 1: Bass glow bloom layer (static gradient scaled on GPU to avoid texture rebuilds)
            Circle()
                .fill(
                    RadialGradient(
                        stops: [
                            .init(color: Color(red: 0.98, green: 0.84, blue: 0.52).opacity(0.48), location: 0.32),
                            .init(color: Color(red: 0.90, green: 0.70, blue: 0.38).opacity(0.26), location: 0.68),
                            .init(color: Color(red: 0.90, green: 0.70, blue: 0.38).opacity(0.10), location: 0.86),
                            .init(color: Color.clear, location: 1.0)
                        ],
                        center: .center,
                        startRadius: diameter * 0.28,
                        endRadius: diameter * 0.66
                    )
                )
                .frame(width: diameter * 1.12, height: diameter * 1.12)
                .scaleEffect(1.0 + CGFloat(bassEnergy) * 0.25)
                .opacity(isPlaying ? (0.46 + Double(bassEnergy) * 0.54) : 0.08)

            // Layer 2: Inner visualizer ring
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [
                            Color(red: 1.00, green: 0.88, blue: 0.60).opacity(0.64),
                            Color(red: 0.95, green: 0.75, blue: 0.45).opacity(0.43)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.2
                )
                .frame(width: diameter * 1.025, height: diameter * 1.025)
                .scaleEffect(1.0 + CGFloat(bassEnergy) * 0.095 + CGFloat(midEnergy) * 0.058)
                .opacity(isPlaying ? (0.50 + Double(bassEnergy) * 0.50) : 0.09)

            // Layer 3: Mid-frequency visualizer ring
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [
                            Color(white: 0.96).opacity(0.54),
                            Color(red: 0.96, green: 0.82, blue: 0.55).opacity(0.36)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1.0
                )
                .frame(width: diameter * 1.085, height: diameter * 1.085)
                .scaleEffect(1.0 + CGFloat(midEnergy) * 0.128 + CGFloat(highEnergy) * 0.055)
                .opacity(isPlaying ? (0.48 + Double(midEnergy) * 0.52) : 0.09)

            // Layer 4: High-frequency accent ring
            Circle()
                .stroke(
                    Color(white: 1.00),
                    lineWidth: 0.75
                )
                .frame(width: diameter * 1.155, height: diameter * 1.155)
                .scaleEffect(1.0 + CGFloat(highEnergy) * 0.155)
                .opacity(isPlaying ? (0.15 + Double(highEnergy) * 0.24) : 0.02)

            // Layer 5: Ambient Outer Halo
            Circle()
                .stroke(
                    Color(red: 0.95, green: 0.82, blue: 0.52),
                    lineWidth: 0.5
                )
                .frame(width: diameter * 1.23, height: diameter * 1.23)
                .scaleEffect(1.0 + CGFloat(bassEnergy) * 0.098 + CGFloat(highEnergy) * 0.114)
                .opacity(isPlaying ? (0.08 + Double(bassEnergy) * 0.10) : 0.01)
        }
    }
}

// MARK: - Native Turntable Asset Provider
@MainActor
final class TurntableAssets {
    static let shared = TurntableAssets()

    let vinylImage: NSImage?
    let compactVinylImage: NSImage?

    private init() {
        let base = Self.loadImage(named: "turntable_vinyl")
        self.vinylImage = base
        self.compactVinylImage = base.map { Self.downscale($0, pixelSize: 180) }
    }

    func image(forDiameter diameter: CGFloat) -> NSImage? {
        if diameter <= 90, let compact = compactVinylImage {
            return compact
        }
        return vinylImage
    }

    private static func downscale(_ source: NSImage, pixelSize: CGFloat) -> NSImage {
        let targetSize = NSSize(width: pixelSize, height: pixelSize)
        let scaled = NSImage(size: targetSize)
        scaled.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        source.draw(
            in: NSRect(origin: .zero, size: targetSize),
            from: NSRect(origin: .zero, size: source.size),
            operation: .copy,
            fraction: 1.0
        )
        scaled.unlockFocus()
        return scaled
    }

    private static func loadImage(named: String) -> NSImage? {
        if let url = Bundle.main.url(forResource: named, withExtension: "png", subdirectory: "Turntable") ??
                     Bundle.main.url(forResource: named, withExtension: "png") {
            if let img = NSImage(contentsOf: url) { return img }
        }

        let devPath = "/Volumes/2T/Projects/SilkPlayer/SilkPlayer/Resources/Turntable/\(named).png"
        if FileManager.default.fileExists(atPath: devPath), let img = NSImage(contentsOfFile: devPath) {
            return img
        }

        let relPath = "Resources/Turntable/\(named).png"
        if FileManager.default.fileExists(atPath: relPath), let img = NSImage(contentsOfFile: relPath) {
            return img
        }

        return nil
    }
}

// MARK: - Vinyl Disc View
@MainActor
struct FloatingVinylDiscView: View {
    let diameter: CGFloat
    let isPlaying: Bool
    let rhythm: PlayerAudioRhythm

    var body: some View {
        ZStack {
            // 1. Audio Visualizer Halo
            AudioVisualizerHaloView(
                diameter: diameter,
                rhythm: rhythm,
                isPlaying: isPlaying
            )

            // 2. Natural deep contact soft shadow
            Circle()
                .fill(
                    RadialGradient(
                        stops: [
                            .init(color: Color.black.opacity(0.60), location: 0.35),
                            .init(color: Color.black.opacity(0.20), location: 0.70),
                            .init(color: Color.clear, location: 1.0)
                        ],
                        center: .center,
                        startRadius: diameter * 0.30,
                        endRadius: diameter * 0.52
                    )
                )
                .frame(width: diameter * 1.06, height: diameter * 1.06)
                .offset(y: 8)

            // 3. Circular Vinyl Disc Asset (CoreAnimation render-server driven rotation)
            VinylSpinningLayerView(
                diameter: diameter,
                image: TurntableAssets.shared.image(forDiameter: diameter),
                isPlaying: isPlaying
            )
            .frame(width: diameter, height: diameter)
        }
        .frame(width: diameter * 1.24, height: diameter * 1.24)
    }
}

@MainActor
private struct VinylSpinningLayerView: NSViewRepresentable {
    let diameter: CGFloat
    let image: NSImage?
    let isPlaying: Bool

    func makeNSView(context: Context) -> VinylSpinningHostView {
        let view = VinylSpinningHostView()
        view.update(diameter: diameter, image: image, isPlaying: isPlaying)
        return view
    }

    func updateNSView(_ nsView: VinylSpinningHostView, context: Context) {
        nsView.update(diameter: diameter, image: image, isPlaying: isPlaying)
    }
}

@MainActor
private final class VinylSpinningHostView: NSView {
    private static let rotationAnimationKey = "silk.vinyl.spin"
    private let discLayer = CALayer()
    private var currentImage: NSImage?
    private var currentDiameter: CGFloat = 0
    private var desiredPlaying = false
    private var isSpinActive = false

    override var isFlipped: Bool { false }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layerContentsRedrawPolicy = .duringViewResize
        discLayer.contentsGravity = .resizeAspect
        discLayer.speed = 0.0
        discLayer.timeOffset = 0.0
        layer?.addSublayer(discLayer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        discLayer.bounds = bounds
        discLayer.position = CGPoint(x: bounds.midX, y: bounds.midY)
        if currentImage == nil {
            discLayer.cornerRadius = min(bounds.width, bounds.height) * 0.5
        }
        CATransaction.commit()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard window != nil else { return }
        applyImageContents()
        syncSpinState(force: true)
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        applyImageContents()
    }

    func update(diameter: CGFloat, image: NSImage?, isPlaying: Bool) {
        let imageChanged = currentImage !== image
        let diameterChanged = abs(currentDiameter - diameter) > 0.5
        currentDiameter = diameter
        desiredPlaying = isPlaying

        if imageChanged || (diameterChanged && image == nil) {
            currentImage = image
            applyImageContents()
        }

        if window != nil {
            syncSpinState(force: false)
        }
    }

    private func applyImageContents() {
        let scale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2.0
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        discLayer.contentsScale = scale
        if let image = currentImage {
            discLayer.contents = image.layerContents(forContentsScale: scale)
            discLayer.backgroundColor = nil
            discLayer.cornerRadius = 0
        } else {
            discLayer.contents = nil
            discLayer.backgroundColor = NSColor(white: 0.08, alpha: 1.0).cgColor
            discLayer.cornerRadius = max(currentDiameter, min(bounds.width, bounds.height)) * 0.5
        }
        CATransaction.commit()
    }

    private func ensureRotationAnimation() {
        guard discLayer.animation(forKey: Self.rotationAnimationKey) == nil else { return }
        let rotation = CABasicAnimation(keyPath: "transform.rotation.z")
        rotation.fromValue = 0.0
        rotation.toValue = -Double.pi * 2.0
        rotation.duration = 20.0
        rotation.repeatCount = .infinity
        rotation.isRemovedOnCompletion = false
        discLayer.add(rotation, forKey: Self.rotationAnimationKey)
    }

    private func syncSpinState(force: Bool) {
        ensureRotationAnimation()
        guard force || desiredPlaying != isSpinActive else { return }

        if desiredPlaying {
            if !isSpinActive {
                let pausedTime = discLayer.timeOffset
                discLayer.speed = 1.0
                discLayer.timeOffset = 0.0
                discLayer.beginTime = 0.0
                let timeSincePause = discLayer.convertTime(CACurrentMediaTime(), from: nil) - pausedTime
                discLayer.beginTime = timeSincePause
                isSpinActive = true
            }
        } else {
            if isSpinActive || force {
                if isSpinActive {
                    let pausedTime = discLayer.convertTime(CACurrentMediaTime(), from: nil)
                    discLayer.speed = 0.0
                    discLayer.timeOffset = pausedTime
                } else {
                    discLayer.speed = 0.0
                }
                isSpinActive = false
            }
        }
    }
}
