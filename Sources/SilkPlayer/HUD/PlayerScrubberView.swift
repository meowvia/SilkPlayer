import SwiftUI
import AppKit
import SilkCoreKit

// MARK: - Playback Mode Toggle Button
@MainActor
public struct PlaybackModeButton: View {
    var playlist: PlaylistManager
    @State private var isHovered: Bool = false

    public init(playlist: PlaylistManager = PlaylistManager.shared) {
        self.playlist = playlist
    }

    public var body: some View {
        Button(action: {
            playlist.togglePlaybackMode()
        }) {
            Image(systemName: playlist.playbackMode.iconName)
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundColor(playlist.playbackMode == .sequential ? .white.opacity(0.48) : .cyan.opacity(0.95))
                .frame(width: 24, height: 24)
                .background(
                    Circle()
                        .fill(Color.white.opacity(isHovered ? 0.12 : (playlist.playbackMode == .sequential ? 0.0 : 0.08)))
                )
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .scaleEffect(isHovered ? 1.08 : 1.0)
        .animation(.spring(response: 0.20, dampingFraction: 0.75), value: isHovered)
        .onHover { isHovered = $0 }
        .hudTooltip(L10n.tr("Playback Mode: \(playlist.playbackMode.title) (Click to switch)", "播放模式: \(playlist.playbackMode.title) (点击切换)"), edge: .top)
        .help(playlist.playbackMode.title)
    }
}

// MARK: - Isolated Progress Section with Millisecond Magnetic Snap
@MainActor
public struct PlayerProgressSection: View {
    @ObservedObject var player: PlayerCore
    var clock: PlayerClock
    var playlist: PlaylistManager
    var tier: HUDLayoutTier = .expanded
    var showsHoverPreview: Bool = true
    var compactScrubberHeight: CGFloat? = nil
    @State private var showRemainingTime: Bool = false

    public init(
        player: PlayerCore,
        clock: PlayerClock,
        playlist: PlaylistManager = PlaylistManager.shared,
        tier: HUDLayoutTier = .expanded,
        showsHoverPreview: Bool = true,
        compactScrubberHeight: CGFloat? = nil
    ) {
        self.player = player
        self.clock = clock
        self.playlist = playlist
        self.tier = tier
        self.showsHoverPreview = showsHoverPreview
        self.compactScrubberHeight = compactScrubberHeight
    }

    public var body: some View {
        HStack(spacing: tier == .minimal ? 6 : 8) {
            // Elapsed Time
            Text(formatPlaybackTime(player.isScrubbing ? player.scrubTime : clock.currentTime))
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .monospacedDigit()
                .foregroundColor(.white.opacity(0.88))
                .shadow(color: .black.opacity(0.60), radius: 2, x: 0, y: 1)
                .frame(minWidth: tier == .minimal ? 38 : 46, alignment: .trailing)

            // Progress Bar Scrubber
            PlayerScrubberView(
                player: player,
                clock: clock,
                showsHoverPreview: showsHoverPreview,
                compactHeight: compactScrubberHeight
            )

            // Clickable Duration / Remaining Time Toggle
            Button(action: { showRemainingTime.toggle() }) {
                Text(formattedRightTime)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .monospacedDigit()
                    .foregroundColor(showRemainingTime ? .cyan.opacity(0.95) : .white.opacity(0.85))
                    .shadow(color: .black.opacity(0.60), radius: 2, x: 0, y: 1)
                    .frame(minWidth: tier == .minimal ? 38 : 46, alignment: .leading)
            }
            .buttonStyle(.plain)
            .help(showRemainingTime ? L10n.tr("Click to show total duration", "点击显示总时长") : L10n.tr("Click to show remaining countdown", "点击显示剩余倒计时"))
        }
    }

    private var formattedRightTime: String {
        if showRemainingTime {
            let current = player.isScrubbing ? player.scrubTime : clock.currentTime
            let remaining = max(0, clock.duration - current)
            return "-\(formatPlaybackTime(remaining))"
        } else {
            return formatPlaybackTime(clock.duration)
        }
    }
}

// MARK: - Interactive Progress Bar Scrubber (Continuous Precision)
@MainActor
public struct PlayerScrubberView: View {
    @ObservedObject var player: PlayerCore
    var clock: PlayerClock
    var showsHoverPreview: Bool = true
    var compactHeight: CGFloat? = nil
    @ObservedObject private var thumbnailEngine = SilkThumbnailEngine.shared

    @State private var isHovered: Bool = false
    @State private var hoverLocationX: CGFloat? = nil
    @State private var lastHoverRequestedTime: Double = -1.0
    @State private var hoverDebounceTask: Task<Void, Never>? = nil

    private static let bufferGradient = Gradient(colors: [
        Color.white.opacity(0.22),
        Color.cyan.opacity(0.16)
    ])
    private static let hoverGradient = Gradient(colors: [
        Color.white.opacity(0.26),
        Color.white.opacity(0.14)
    ])
    private static let playedGradient = Gradient(colors: [
        Color.cyan.opacity(0.95),
        Color.blue.opacity(0.80)
    ])

    public init(
        player: PlayerCore,
        clock: PlayerClock,
        showsHoverPreview: Bool = true,
        compactHeight: CGFloat? = nil
    ) {
        self.player = player
        self.clock = clock
        self.showsHoverPreview = showsHoverPreview
        self.compactHeight = compactHeight
    }

    public var body: some View {
        GeometryReader { geometry in
            let totalWidth = geometry.size.width
            let progress = currentProgress(totalWidth: totalWidth)
            let isExpanded = isHovered || player.isScrubbing
            let trackHeight: CGFloat = isExpanded ? 7.5 : 4.5
            let currentKnobSize = knobSize(isExpanded: isExpanded)
            let currentKnobRadius = knobRadius(isExpanded: isExpanded)
            let currentTravelSpan = travelSpan(totalWidth: totalWidth, isExpanded: isExpanded)
            let currentKnobX = knobCenterX(progress: progress, totalWidth: totalWidth, isExpanded: isExpanded)

            let bufferWidth: CGFloat = {
                guard clock.duration > 0, player.cachedDuration > 2.0 else { return 0 }
                let current = player.isScrubbing ? player.scrubTime : clock.currentTime
                let bufferedEnd = min(clock.duration, current + player.cachedDuration)
                let bufferFraction = CGFloat(max(0.0, min(1.0, bufferedEnd / clock.duration)))
                return max(0, min(totalWidth, currentKnobRadius + bufferFraction * currentTravelSpan))
            }()
            let hoverX = (!player.isScrubbing && clock.duration > 0) ? hoverLocationX : nil
            let isSpeedAltered = (player.speed != 1.0 || player.isFastForwarding2x)
            let chapterPositions: [CGFloat] = {
                guard clock.duration > 0, !player.chapters.isEmpty else { return [] }
                return player.chapters.compactMap { chapter in
                    let fraction = CGFloat(max(0.0, min(1.0, chapter.time / clock.duration)))
                    guard fraction > 0.01 && fraction < 0.99 else { return nil }
                    return currentKnobRadius + fraction * currentTravelSpan
                }
            }()
            let playedWidth = max(0, min(totalWidth, currentKnobX))

            ZStack(alignment: .leading) {
                // 1-5. Track background, buffer, hover span, chapter markers, and played fill in one Canvas
                Canvas(opaque: false, rendersAsynchronously: false) { graphics, size in
                    let trackY = (size.height - trackHeight) * 0.5
                    let baseRect = CGRect(x: 0, y: trackY, width: size.width, height: trackHeight)
                    let basePath = Path(roundedRect: baseRect, cornerRadius: trackHeight * 0.5)
                    graphics.fill(basePath, with: .color(Color.black.opacity(0.35)))
                    graphics.fill(basePath, with: .color(Color.white.opacity(0.12)))

                    if bufferWidth > 0 {
                        let rect = CGRect(x: 0, y: trackY, width: bufferWidth, height: trackHeight)
                        graphics.fill(
                            Path(roundedRect: rect, cornerRadius: min(trackHeight, bufferWidth) * 0.5),
                            with: .linearGradient(
                                Self.bufferGradient,
                                startPoint: CGPoint(x: rect.minX, y: rect.midY),
                                endPoint: CGPoint(x: rect.maxX, y: rect.midY)
                            )
                        )
                    }

                    if let rawHoverX = hoverX {
                        let clampedHoverX = max(currentKnobRadius, min(size.width - currentKnobRadius, rawHoverX))
                        if isSpeedAltered {
                            let pillWidth = max(10, currentKnobRadius * 2.2)
                            let rect = CGRect(
                                x: clampedHoverX - pillWidth * 0.5,
                                y: trackY,
                                width: pillWidth,
                                height: trackHeight
                            )
                            graphics.fill(
                                Path(roundedRect: rect, cornerRadius: trackHeight * 0.5),
                                with: .color(Color.white.opacity(0.32))
                            )
                        } else {
                            let spanStart = min(currentKnobX, clampedHoverX)
                            let spanWidth = max(0, abs(clampedHoverX - currentKnobX))
                            if spanWidth > 0 {
                                let rect = CGRect(x: spanStart, y: trackY, width: spanWidth, height: trackHeight)
                                graphics.fill(
                                    Path(roundedRect: rect, cornerRadius: min(trackHeight, spanWidth) * 0.5),
                                    with: .linearGradient(
                                        Self.hoverGradient,
                                        startPoint: CGPoint(x: rect.minX, y: rect.midY),
                                        endPoint: CGPoint(x: rect.maxX, y: rect.midY)
                                    )
                                )
                            }
                        }
                    }

                    if !chapterPositions.isEmpty {
                        let markerHeight = trackHeight + 2.0
                        let markerY = (size.height - markerHeight) * 0.5
                        for markX in chapterPositions {
                            graphics.fill(
                                Path(CGRect(x: markX - 1.25, y: markerY, width: 2.5, height: markerHeight)),
                                with: .color(Color.black.opacity(0.35))
                            )
                            graphics.fill(
                                Path(CGRect(x: markX - 0.75, y: markerY, width: 1.5, height: markerHeight)),
                                with: .color(Color.white.opacity(0.60))
                            )
                        }
                    }

                    if playedWidth > 0 {
                        let rect = CGRect(x: 0, y: trackY, width: playedWidth, height: trackHeight)
                        graphics.fill(
                            Path(roundedRect: rect, cornerRadius: min(trackHeight, playedWidth) * 0.5),
                            with: .linearGradient(
                                Self.playedGradient,
                                startPoint: CGPoint(x: rect.minX, y: rect.midY),
                                endPoint: CGPoint(x: rect.maxX, y: rect.midY)
                            )
                        )
                    }
                }
                .frame(width: totalWidth, height: geometry.size.height)

                // 6. Scrub Knob (Centered at knobCenterX)
                Circle()
                    .fill(Color.white)
                    .overlay(
                        Circle()
                            .strokeBorder(Color.cyan.opacity(0.85), lineWidth: isExpanded ? 1.0 : 0.5)
                    )
                    .shadow(color: Color.black.opacity(0.35), radius: isExpanded ? 4 : 2, x: 0, y: 1)
                    .frame(width: currentKnobSize, height: currentKnobSize)
                    .position(x: currentKnobX, y: geometry.size.height / 2.0)

                // 7. Hover / Scrub Floating Preview Card with I-Frame Thumbnail & High-Precision Timestamp
                if showsHoverPreview, clock.duration > 0, (isHovered || player.isScrubbing) {
                    let activeAnchorX = player.isScrubbing ? currentKnobX : (hoverLocationX != nil ? max(currentKnobRadius, min(totalWidth - currentKnobRadius, hoverLocationX!)) : currentKnobX)
                    let activeFraction = fraction(for: activeAnchorX, totalWidth: totalWidth, isExpanded: isExpanded)
                    let rawTime = player.isScrubbing ? player.scrubTime : (activeFraction * clock.duration)
                    let activeChapter = player.chapters.last(where: { $0.time <= rawTime })
                    let chapterTitle = activeChapter?.title

                    let isVertical = player.isEffectiveVertical
                    let cardHalfWidth: CGFloat = (isVertical || player.transform.isPerpendicular) ? 42 : 85
                    let clampedCenterX = max(cardHalfWidth + 10, min(totalWidth - cardHalfWidth - 10, activeAnchorX))

                    ScrubberHoverCardView(
                        thumbnail: thumbnailEngine.activeThumbnail,
                        isLoading: thumbnailEngine.isLoading,
                        time: rawTime,
                        chapterTitle: chapterTitle,
                        transform: player.transform,
                        isVertical: isVertical
                    )
                    .position(x: clampedCenterX, y: (isVertical || player.transform.isPerpendicular) ? -82 : -68)
                    .transition(.opacity.combined(with: .scale(scale: 0.94)))
                }
            }
            .frame(maxHeight: .infinity, alignment: .center)
            .contentShape(Rectangle())
            .onContinuousHover { phase in
                switch phase {
                case .active(let location):
                    withAnimation(.spring(response: 0.18, dampingFraction: 0.75)) {
                        isHovered = true
                        hoverLocationX = location.x
                    }
                    if showsHoverPreview, clock.duration > 0 {
                        let activeFraction = fraction(for: location.x, totalWidth: geometry.size.width, isExpanded: true)
                        let rawTargetTime = max(0.0, min(clock.duration, activeFraction * clock.duration))
                        if abs(rawTargetTime - lastHoverRequestedTime) >= 0.05 {
                            let isInitialLanding = (lastHoverRequestedTime < 0)
                            lastHoverRequestedTime = rawTargetTime
                            hoverDebounceTask?.cancel()
                            if isInitialLanding {
                                thumbnailEngine.requestThumbnail(for: player.currentFilePath, at: rawTargetTime)
                            } else {
                                hoverDebounceTask = Task { @MainActor in
                                    try? await Task.sleep(nanoseconds: 35_000_000)
                                    guard !Task.isCancelled else { return }
                                    thumbnailEngine.requestThumbnail(for: player.currentFilePath, at: rawTargetTime)
                                }
                            }
                        }
                    }
                case .ended:
                    hoverDebounceTask?.cancel()
                    hoverDebounceTask = nil
                    lastHoverRequestedTime = -1.0
                    withAnimation(.spring(response: 0.18, dampingFraction: 0.75)) {
                        isHovered = false
                        hoverLocationX = nil
                    }
                    if showsHoverPreview, !player.isScrubbing {
                        thumbnailEngine.clearCurrent()
                    }
                }
            }
            .highPriorityGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if !player.isScrubbing {
                            player.startScrubbing()
                        }
                        let dragFraction = fraction(for: value.location.x, totalWidth: geometry.size.width, isExpanded: true)
                        let rawTime = max(0.0, min(clock.duration, dragFraction * clock.duration))
                        let targetTime = Self.snapTime(rawTime, duration: clock.duration, chapters: player.chapters)
                        player.updateScrubbing(to: targetTime)
                        if showsHoverPreview, abs(targetTime - lastHoverRequestedTime) >= 0.05 {
                            let isInitialScrub = (lastHoverRequestedTime < 0)
                            lastHoverRequestedTime = targetTime
                            hoverDebounceTask?.cancel()
                            if isInitialScrub {
                                thumbnailEngine.requestThumbnail(for: player.currentFilePath, at: targetTime)
                            } else {
                                hoverDebounceTask = Task { @MainActor in
                                    try? await Task.sleep(nanoseconds: 35_000_000)
                                    guard !Task.isCancelled else { return }
                                    thumbnailEngine.requestThumbnail(for: player.currentFilePath, at: targetTime)
                                }
                            }
                        }
                    }
                    .onEnded { value in
                        hoverDebounceTask?.cancel()
                        hoverDebounceTask = nil
                        lastHoverRequestedTime = -1.0
                        let dragFraction = fraction(for: value.location.x, totalWidth: geometry.size.width, isExpanded: true)
                        let rawTime = max(0.0, min(clock.duration, dragFraction * clock.duration))
                        let targetTime = Self.snapTime(rawTime, duration: clock.duration, chapters: player.chapters)
                        player.finishScrubbing(to: targetTime)
                        if showsHoverPreview, !isHovered {
                            thumbnailEngine.clearCurrent()
                        }
                    }
            )
            .animation(.spring(response: 0.22, dampingFraction: 0.75), value: isExpanded)
        }
        .frame(height: compactHeight ?? 32)
    }

    // MARK: - Knob Geometry and Physical Center Kinematics
    private func knobSize(isExpanded: Bool) -> CGFloat {
        isExpanded ? 15.0 : 9.5
    }

    private func knobRadius(isExpanded: Bool) -> CGFloat {
        knobSize(isExpanded: isExpanded) / 2.0
    }

    private func travelSpan(totalWidth: CGFloat, isExpanded: Bool) -> CGFloat {
        max(1.0, totalWidth - knobSize(isExpanded: isExpanded))
    }

    private func knobCenterX(progress: CGFloat, totalWidth: CGFloat, isExpanded: Bool) -> CGFloat {
        let r = knobRadius(isExpanded: isExpanded)
        return r + progress * travelSpan(totalWidth: totalWidth, isExpanded: isExpanded)
    }

    private func fraction(for locationX: CGFloat, totalWidth: CGFloat, isExpanded: Bool) -> CGFloat {
        let r = knobRadius(isExpanded: isExpanded)
        let span = travelSpan(totalWidth: totalWidth, isExpanded: isExpanded)
        let clampedX = max(r, min(totalWidth - r, locationX))
        return max(0.0, min(1.0, (clampedX - r) / span))
    }

    private func currentProgress(totalWidth: CGFloat) -> CGFloat {
        guard clock.duration > 0 else { return 0 }
        let time = player.isScrubbing ? player.scrubTime : clock.currentTime
        return CGFloat(max(0, min(1, time / clock.duration)))
    }

    // MARK: - Chapter Snapping Kinematics
    /// Evaluates magnetic chapter snapping with an adaptive threshold: max(2.0, duration * 0.012).
    public static func snapTime(_ rawTime: Double, duration: Double, chapters: [ChapterItem]) -> Double {
        guard duration > 0, !chapters.isEmpty else { return rawTime }
        let threshold = max(2.0, duration * 0.012)
        for chapter in chapters {
            if abs(rawTime - chapter.time) <= threshold {
                return chapter.time
            }
        }
        return rawTime
    }
}

// MARK: - Scrubber Hover Preview Card View
@MainActor
public struct ScrubberHoverCardView: View {
    let thumbnail: NSImage?
    let isLoading: Bool
    let time: Double
    let chapterTitle: String?
    var transform: VideoTransform
    var isVertical: Bool

    public init(
        thumbnail: NSImage?,
        isLoading: Bool,
        time: Double,
        chapterTitle: String?,
        transform: VideoTransform = VideoTransform(),
        isVertical: Bool = false
    ) {
        self.thumbnail = thumbnail
        self.isLoading = isLoading
        self.time = time
        self.chapterTitle = chapterTitle
        self.transform = transform
        self.isVertical = isVertical
    }

    public var body: some View {
        VStack(spacing: 5) {
            let isVert = isVertical || transform.isPerpendicular
            let cardW: CGFloat = isVert ? 64 : 156
            let cardH: CGFloat = isVert ? 114 : 88

            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.black.opacity(0.85))
                    .frame(width: cardW, height: cardH)

                if let img = thumbnail {
                    if transform.isPerpendicular {
                        Image(nsImage: img)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: cardH, height: cardW)
                            .rotationEffect(.degrees(Double(transform.effectiveRotation)))
                            .scaleEffect(x: transform.flipH ? -1.0 : 1.0, y: transform.flipV ? -1.0 : 1.0)
                            .frame(width: cardW, height: cardH)
                            .clipped()
                            .cornerRadius(6)
                    } else {
                        Image(nsImage: img)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .rotationEffect(.degrees(Double(transform.effectiveRotation)))
                            .scaleEffect(x: transform.flipH ? -1.0 : 1.0, y: transform.flipV ? -1.0 : 1.0)
                            .frame(width: cardW, height: cardH)
                            .clipped()
                            .cornerRadius(6)
                    }
                } else {
                    ZStack {
                        if isLoading {
                            ProgressView()
                                .controlSize(.small)
                                .tint(.white.opacity(0.85))
                        } else {
                            Image(systemName: "film")
                                .font(.system(size: 22))
                                .foregroundColor(.white.opacity(0.30))
                        }
                    }
                    .frame(width: cardW, height: cardH)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.25), lineWidth: 0.8)
            )

            VStack(spacing: 1.5) {
                if let title = chapterTitle, !title.isEmpty {
                    Text(title)
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundColor(.cyan.opacity(0.95))
                        .lineLimit(1)
                        .frame(maxWidth: 150)
                }
                Text(formatMillisecondsTime(time))
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .monospacedDigit()
                    .foregroundColor(.white)
            }
            .padding(.bottom, 2)
        }
        .padding(6)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.black.opacity(0.60))
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [Color.white.opacity(0.45), Color.white.opacity(0.15)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 0.8
                )
        )
        .shadow(color: Color.black.opacity(0.50), radius: 10, x: 0, y: 4)
    }
}

/// High-precision time formatter displaying hundredths of a second (millisecond level)
public func formatMillisecondsTime(_ seconds: Double) -> String {
    guard !seconds.isNaN, !seconds.isInfinite, seconds >= 0 else { return "00:00.00" }
    let totalCentiseconds = Int(round(seconds * 100.0))
    let totalSeconds = totalCentiseconds / 100
    let centiseconds = totalCentiseconds % 100
    let hours = totalSeconds / 3600
    let minutes = (totalSeconds % 3600) / 60
    let secs = totalSeconds % 60
    if hours > 0 {
        return String(format: "%02d:%02d:%02d.%02d", hours, minutes, secs, centiseconds)
    } else {
        return String(format: "%02d:%02d.%02d", minutes, secs, centiseconds)
    }
}
