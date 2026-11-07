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
                    let b0 = player.isPlaying ? (player.audioRhythmLevels.first ?? 0.0) : 0.0
                    Image(nsImage: artwork)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: availableW, height: availableH)
                        .blur(radius: 68)
                        .opacity(0.28 + Double(b0) * 0.12)
                        .scaleEffect(1.15)
                        .clipped()
                        .animation(.easeOut(duration: 0.12), value: b0)
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
                        // Discrete Cover Card with Acoustic Bloom
                        let b0 = player.isPlaying ? (player.audioRhythmLevels.first ?? 0.0) : 0.0
                        let b1 = (player.isPlaying && player.audioRhythmLevels.count > 1) ? player.audioRhythmLevels[1] : 0.0
                        let bassEnergy = b0 * 0.65 + b1 * 0.35

                        ZStack {
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .fill(
                                    RadialGradient(
                                        stops: [
                                            .init(color: Color(red: 0.98, green: 0.84, blue: 0.52).opacity(player.isPlaying ? (0.24 + Double(bassEnergy) * 0.26) : 0.04), location: 0.25),
                                            .init(color: Color(red: 0.90, green: 0.70, blue: 0.38).opacity(player.isPlaying ? (0.12 + Double(bassEnergy) * 0.15) : 0.02), location: 0.65),
                                            .init(color: Color.clear, location: 1.0)
                                        ],
                                        center: .center,
                                        startRadius: coverCardSize * 0.20,
                                        endRadius: coverCardSize * 0.75 * (1.0 + CGFloat(bassEnergy) * 0.20)
                                    )
                                )
                                .frame(width: coverCardSize * (1.08 + CGFloat(bassEnergy) * 0.16), height: coverCardSize * (1.08 + CGFloat(bassEnergy) * 0.16))
                                .animation(.easeOut(duration: 0.10), value: bassEnergy)

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
                                .scaleEffect(player.isPlaying ? (1.0 + CGFloat(bassEnergy) * 0.015) : 1.0)
                                .animation(.easeOut(duration: 0.10), value: bassEnergy)
                        }
                        .frame(width: coverCardSize, height: coverCardSize)
                    } else {
                        // Vinyl Disc with Audio Visualizer Halo
                        FloatingVinylDiscView(
                            diameter: vinylDiameter,
                            isPlaying: player.isPlaying,
                            levels: player.audioRhythmLevels
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

// MARK: - Audio Visualizer Halo View (音频声波律动光环)
@MainActor
struct AudioVisualizerHaloView: View {
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
            // Layer 1: Bass glow bloom layer (低频环境柔和光晕，采用平滑边缘渐变消除重度高斯模糊)
            Circle()
                .fill(
                    RadialGradient(
                        stops: [
                            .init(color: Color(red: 0.98, green: 0.84, blue: 0.52).opacity(isPlaying ? (0.22 + Double(bassEnergy) * 0.26) : 0.04), location: 0.32),
                            .init(color: Color(red: 0.90, green: 0.70, blue: 0.38).opacity(isPlaying ? (0.12 + Double(midEnergy) * 0.14) : 0.02), location: 0.68),
                            .init(color: Color(red: 0.90, green: 0.70, blue: 0.38).opacity(isPlaying ? (0.04 + Double(midEnergy) * 0.06) : 0.01), location: 0.86),
                            .init(color: Color.clear, location: 1.0)
                        ],
                        center: .center,
                        startRadius: diameter * 0.28,
                        endRadius: diameter * 0.66 * (1.0 + CGFloat(bassEnergy) * 0.20)
                    )
                )
                .frame(width: diameter * (1.12 + CGFloat(bassEnergy) * 0.28), height: diameter * (1.12 + CGFloat(bassEnergy) * 0.28))

            // Layer 2: Inner visualizer ring (内圈光环)
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [
                            Color(red: 1.00, green: 0.88, blue: 0.60).opacity(isPlaying ? (0.32 + Double(bassEnergy) * 0.32) : 0.06),
                            Color(red: 0.95, green: 0.75, blue: 0.45).opacity(isPlaying ? (0.18 + Double(midEnergy) * 0.25) : 0.03)
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

            // Layer 3: Mid-frequency visualizer ring (中频光环)
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [
                            Color(white: 0.96).opacity(isPlaying ? (0.26 + Double(midEnergy) * 0.28) : 0.05),
                            Color(red: 0.96, green: 0.82, blue: 0.55).opacity(isPlaying ? (0.16 + Double(highEnergy) * 0.20) : 0.03)
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

            // Layer 4: High-frequency accent ring (外圈高频描边微光)
            Circle()
                .stroke(
                    Color(white: 1.00).opacity(isPlaying ? (0.15 + Double(highEnergy) * 0.24) : 0.02),
                    lineWidth: 0.75
                )
                .frame(
                    width: diameter * (1.155 + CGFloat(highEnergy) * 0.18),
                    height: diameter * (1.155 + CGFloat(highEnergy) * 0.18)
                )

            // Layer 5: Ambient Outer Halo (微弱外沿余晕)
            Circle()
                .stroke(
                    Color(red: 0.95, green: 0.82, blue: 0.52).opacity(isPlaying ? (0.08 + Double(bassEnergy) * 0.10) : 0.01),
                    lineWidth: 0.5
                )
                .frame(
                    width: diameter * (1.23 + CGFloat(bassEnergy) * 0.12 + CGFloat(highEnergy) * 0.14),
                    height: diameter * (1.23 + CGFloat(bassEnergy) * 0.12 + CGFloat(highEnergy) * 0.14)
                )
        }
        .animation(.easeOut(duration: 0.10), value: bassEnergy + midEnergy + highEnergy)
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

// MARK: - Vinyl Disc View (黑胶唱片视图)
@MainActor
struct FloatingVinylDiscView: View {
    let diameter: CGFloat
    let isPlaying: Bool
    let levels: [CGFloat]

    var body: some View {
        ZStack {
            // 1. Audio Visualizer Halo (解耦出 TimelineView，仅在律动电平变化时局部刷新)
            AudioVisualizerHaloView(
                diameter: diameter,
                levels: levels,
                isPlaying: isPlaying
            )

            // 2. Natural deep contact soft shadow (平滑羽化径向渐变，零高斯模糊运算)
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

            // 3. Circular Vinyl Disc Asset (TimelineView 仅包裹黑胶资产本身进行匀速旋转)
            TimelineView(.animation(minimumInterval: 1.0 / 24.0, paused: !isPlaying)) { timeline in
                let angle = (timeline.date.timeIntervalSinceReferenceDate * 18.0).truncatingRemainder(dividingBy: 360.0)
                Group {
                    if let vinylImg = TurntableAssets.shared.vinylImage {
                        Image(nsImage: vinylImg)
                            .resizable()
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
        }
        .frame(width: diameter * 1.24, height: diameter * 1.24)
    }
}
