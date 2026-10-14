import SwiftUI
import AppKit

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

    public var body: some View {
        GeometryReader { geometry in
            let availableW = geometry.size.width
            let availableH = geometry.size.height
            let coverCardSize = max(180, min(480, min(availableW * 0.52, availableH * 0.48)))
            let vinylDiameter = max(240, min(540, min(availableW * 0.65, (availableH - 160) * 0.68)))

            ZStack {
                // 1. Native macOS Liquid Glass frosted backdrop
                VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                    .edgesIgnoringSafeArea(.all)

                // 2. Translucent dark obsidian cinema tint
                Color(red: 0.06, green: 0.07, blue: 0.09).opacity(0.50)
                    .edgesIgnoringSafeArea(.all)

                // 3. Dynamic Backdrop Art (if album art is present)
                if let artwork = player.artworkImage {
                    let b0 = player.isPlaying ? (player.audioRhythmLevels.first ?? 0.0) : 0.0
                    Image(nsImage: artwork)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: availableW, height: availableH)
                        .blur(radius: 68)
                        .opacity(0.28 + Double(b0) * 0.12)
                        .scaleEffect(1.15)
                        .clipped()
                        .animation(.easeOut(duration: 0.08), value: b0)
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

                // 5. Centered Presentation: Pure Floating Vinyl Disc & Acoustic Resonance Corona
                VStack(spacing: 28) {
                    if let artwork = player.artworkImage {
                        // Discrete Cover Card with Acoustic Bloom
                        let b0 = player.isPlaying ? (player.audioRhythmLevels.first ?? 0.0) : 0.0
                        let b1 = (player.isPlaying && player.audioRhythmLevels.count > 1) ? player.audioRhythmLevels[1] : 0.0
                        let bassEnergy = b0 * 0.65 + b1 * 0.35

                        ZStack {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(
                                    RadialGradient(
                                        colors: [
                                            Color(red: 0.98, green: 0.84, blue: 0.52).opacity(player.isPlaying ? (0.22 + Double(bassEnergy) * 0.26) : 0.04),
                                            Color(red: 0.90, green: 0.70, blue: 0.38).opacity(player.isPlaying ? (0.10 + Double(bassEnergy) * 0.15) : 0.02),
                                            Color.clear
                                        ],
                                        center: .center,
                                        startRadius: coverCardSize * 0.25,
                                        endRadius: coverCardSize * 0.75 * (1.0 + CGFloat(bassEnergy) * 0.20)
                                    )
                                )
                                .frame(width: coverCardSize * (1.08 + CGFloat(bassEnergy) * 0.16), height: coverCardSize * (1.08 + CGFloat(bassEnergy) * 0.16))
                                .blur(radius: 28)
                                .animation(.easeOut(duration: 0.08), value: bassEnergy)

                            Image(nsImage: artwork)
                                .resizable()
                                .interpolation(.high)
                                .aspectRatio(contentMode: .fit)
                                .frame(maxWidth: coverCardSize, maxHeight: coverCardSize)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(Color.white.opacity(0.15), lineWidth: 1.0)
                                )
                                .shadow(color: .black.opacity(0.55), radius: 26, x: 0, y: 14)
                                .scaleEffect(player.isPlaying ? (1.0 + CGFloat(bassEnergy) * 0.015) : 1.0)
                                .animation(.easeOut(duration: 0.08), value: bassEnergy)
                        }
                        .frame(width: coverCardSize, height: coverCardSize)
                    } else {
                        // Pure Floating Vinyl Disc with Acoustic Resonance Corona
                        FloatingVinylDiscView(
                            diameter: vinylDiameter,
                            isPlaying: player.isPlaying,
                            levels: player.audioRhythmLevels
                        )
                    }

                    // Track Title & Next Track Preview (空一行 不对齐正在播放歌名，再空两格预告，下一首：)
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
                                .frame(height: 14)

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
                .offset(y: -8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - Audiophile Acoustic Resonance Corona (高保真黑胶声学环形共振光冕)
@MainActor
struct AcousticResonanceCoronaView: View {
    let diameter: CGFloat
    let levels: [CGFloat]
    let isPlaying: Bool

    var body: some View {
        let b0 = isPlaying ? (levels.first ?? 0.0) : 0.0
        let b1 = (isPlaying && levels.count > 1) ? levels[1] : 0.0
        let b2 = (isPlaying && levels.count > 3) ? levels[3] : 0.0
        let b3 = (isPlaying && levels.count > 5) ? levels[5] : 0.0

        let bassEnergy = b0 * 0.65 + b1 * 0.35
        let midEnergy = b1 * 0.30 + b2 * 0.70
        let highEnergy = b2 * 0.25 + b3 * 0.75

        ZStack {
            // Layer 1: Deep Core Resonance Bloom (深层低频弥散气场)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.98, green: 0.84, blue: 0.52).opacity(isPlaying ? (0.18 + Double(bassEnergy) * 0.25) : 0.04),
                            Color(red: 0.90, green: 0.70, blue: 0.38).opacity(isPlaying ? (0.09 + Double(midEnergy) * 0.12) : 0.02),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: diameter * 0.35,
                        endRadius: diameter * 0.65 * (1.0 + CGFloat(bassEnergy) * 0.20)
                    )
                )
                .frame(width: diameter * (1.10 + CGFloat(bassEnergy) * 0.28), height: diameter * (1.10 + CGFloat(bassEnergy) * 0.28))
                .blur(radius: 32)

            // Layer 2: Inner Harmonic Resonance Ring (内圈声学谐波光环 - 偏暖金)
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [
                            Color(red: 1.00, green: 0.88, blue: 0.60).opacity(isPlaying ? (0.28 + Double(bassEnergy) * 0.32) : 0.06),
                            Color(red: 0.95, green: 0.75, blue: 0.45).opacity(isPlaying ? (0.15 + Double(midEnergy) * 0.25) : 0.03)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.2
                )
                .frame(
                    width: diameter * (1.025 + CGFloat(bassEnergy) * 0.10 + CGFloat(midEnergy) * 0.06),
                    height: diameter * (1.025 + CGFloat(bassEnergy) * 0.10 + CGFloat(midEnergy) * 0.06)
                )
                .shadow(color: Color(red: 1.00, green: 0.85, blue: 0.50).opacity(isPlaying ? (Double(bassEnergy) * 0.35) : 0.0), radius: 6)

            // Layer 3: Mid Harmonic Corona Ring (中频光冕环 - 水银白金)
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [
                            Color(white: 0.96).opacity(isPlaying ? (0.24 + Double(midEnergy) * 0.28) : 0.05),
                            Color(red: 0.96, green: 0.82, blue: 0.55).opacity(isPlaying ? (0.14 + Double(highEnergy) * 0.20) : 0.03)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1.0
                )
                .frame(
                    width: diameter * (1.085 + CGFloat(midEnergy) * 0.14 + CGFloat(highEnergy) * 0.06),
                    height: diameter * (1.085 + CGFloat(midEnergy) * 0.14 + CGFloat(highEnergy) * 0.06)
                )
                .shadow(color: Color.white.opacity(isPlaying ? (Double(midEnergy) * 0.25) : 0.0), radius: 4)

            // Layer 4: High-Frequency Shimmer Corona (外圈高频轻灵微光环 - 极细)
            Circle()
                .stroke(
                    Color(white: 1.00).opacity(isPlaying ? (0.12 + Double(highEnergy) * 0.24) : 0.02),
                    lineWidth: 0.75
                )
                .frame(
                    width: diameter * (1.155 + CGFloat(highEnergy) * 0.18),
                    height: diameter * (1.155 + CGFloat(highEnergy) * 0.18)
                )
                .shadow(color: Color(red: 0.98, green: 0.88, blue: 0.65).opacity(isPlaying ? (Double(highEnergy) * 0.30) : 0.0), radius: 5)

            // Layer 5: Ambient Outer Halo (微弱外沿余晕)
            Circle()
                .stroke(
                    Color(red: 0.95, green: 0.82, blue: 0.52).opacity(isPlaying ? (0.06 + Double(bassEnergy) * 0.10) : 0.01),
                    lineWidth: 0.5
                )
                .frame(
                    width: diameter * (1.23 + CGFloat(bassEnergy) * 0.12 + CGFloat(highEnergy) * 0.14),
                    height: diameter * (1.23 + CGFloat(bassEnergy) * 0.12 + CGFloat(highEnergy) * 0.14)
                )
        }
        .animation(.easeOut(duration: 0.08), value: bassEnergy + midEnergy + highEnergy)
    }
}

// MARK: - Native Turntable Asset Provider
@MainActor
final class TurntableAssets {
    static let shared = TurntableAssets()

    let vinylImage: NSImage?

    private init() {
        self.vinylImage = Self.loadImage(named: "turntable_vinyl")
    }

    private static func loadImage(named: String) -> NSImage? {
        if let url = Bundle.main.url(forResource: named, withExtension: "png", subdirectory: "Turntable") ??
                     Bundle.main.url(forResource: named, withExtension: "png") {
            if let img = NSImage(contentsOf: url) { return img }
        }

        let devPath = "/Volumes/2T/SilkPlayer/Resources/Turntable/\(named).png"
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

// MARK: - Pure Floating Audiophile Vinyl Disc (纯净高保真悬浮黑胶 · 丝滑慢速旋转)
@MainActor
struct FloatingVinylDiscView: View {
    let diameter: CGFloat
    let isPlaying: Bool
    let levels: [CGFloat]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !isPlaying)) { timeline in
            let angle = (timeline.date.timeIntervalSinceReferenceDate * 18.0).truncatingRemainder(dividingBy: 360.0)
            ZStack {
                // 1. Acoustic Resonance Corona (Multi-layer harmonic bloom and rings)
                AcousticResonanceCoronaView(
                    diameter: diameter,
                    levels: levels,
                    isPlaying: isPlaying
                )

                // 2. Natural deep contact soft shadow
                Circle()
                    .fill(Color.black.opacity(0.60))
                    .frame(width: diameter * 0.96, height: diameter * 0.96)
                    .blur(radius: 26)
                    .offset(y: 12)

                // 3. High-Precision Circular Vinyl Disc with Concentric Champagne Gold Label
                Group {
                    if let vinylImg = TurntableAssets.shared.vinylImage {
                        Image(nsImage: vinylImg)
                            .resizable()
                            .interpolation(.high)
                            .aspectRatio(contentMode: .fit)
                            .frame(width: diameter, height: diameter)
                            .rotationEffect(.degrees(angle))
                    } else {
                        Circle()
                            .fill(Color(white: 0.08))
                            .frame(width: diameter, height: diameter)
                            .rotationEffect(.degrees(angle))
                    }
                }
            }
            .frame(width: diameter, height: diameter)
        }
    }
}
