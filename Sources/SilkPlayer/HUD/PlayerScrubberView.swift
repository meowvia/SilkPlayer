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
    @State private var showRemainingTime: Bool = false

    public init(player: PlayerCore, clock: PlayerClock, playlist: PlaylistManager = PlaylistManager.shared, tier: HUDLayoutTier = .expanded) {
        self.player = player
        self.clock = clock
        self.playlist = playlist
        self.tier = tier
    }

    public var body: some View {
        HStack(spacing: tier == .minimal ? 6 : 8) {
            // Elapsed Time
            Text(formatPlaybackTime(player.isScrubbing ? player.scrubTime : clock.currentTime))
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .monospacedDigit()
                .foregroundColor(.white.opacity(0.88))
                .shadow(color: .black.opacity(0.35), radius: 2, x: 0, y: 1)
                .frame(minWidth: tier == .minimal ? 38 : 46, alignment: .trailing)

            // Progress Bar Scrubber
            PlayerScrubberView(player: player, clock: clock)

            // Clickable Duration / Remaining Time Toggle
            Button(action: { showRemainingTime.toggle() }) {
                Text(formattedRightTime)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .monospacedDigit()
                    .foregroundColor(showRemainingTime ? .cyan.opacity(0.95) : .white.opacity(0.85))
                    .shadow(color: .black.opacity(0.35), radius: 2, x: 0, y: 1)
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
    @ObservedObject private var thumbnailEngine = SilkThumbnailEngine.shared

    @State private var isHovered: Bool = false
    @State private var hoverLocationX: CGFloat? = nil
    @State private var lastHoverRequestedTime: Double = -1.0
    @State private var hoverDebounceTask: Task<Void, Never>? = nil

    public init(player: PlayerCore, clock: PlayerClock) {
        self.player = player
        self.clock = clock
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

            ZStack(alignment: .leading) {
                // 1. Base Track (Pure glass cinema transparency)
                Capsule()
                    .fill(Color.black.opacity(0.20))
                    .frame(height: trackHeight)

                Capsule()
                    .fill(Color.white.opacity(0.12))
                    .frame(height: trackHeight)

                // 2. Buffer Progress Track
                if clock.duration > 0 && player.cachedDuration > 2.0 {
                    let current = player.isScrubbing ? player.scrubTime : clock.currentTime
                    let bufferedEnd = min(clock.duration, current + player.cachedDuration)
                    let bufferFraction = CGFloat(max(0.0, min(1.0, bufferedEnd / clock.duration)))
                    let bufferWidth = currentKnobRadius + bufferFraction * currentTravelSpan
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.22),
                                    Color.cyan.opacity(0.16)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(0, min(totalWidth, bufferWidth)), height: trackHeight)
                }

                // 3. Hover Preview Track (Anchored precisely to knob center & hover point)
                if let hoverX = hoverLocationX, !player.isScrubbing, clock.duration > 0 {
                    let clampedHoverX = max(currentKnobRadius, min(totalWidth - currentKnobRadius, hoverX))
                    let isSpeedAltered = (player.speed != 1.0 || player.isFastForwarding2x)
                    if isSpeedAltered {
                        Capsule()
                            .fill(Color.white.opacity(0.32))
                            .frame(width: max(10, currentKnobRadius * 2.2), height: trackHeight)
                            .position(x: clampedHoverX, y: geometry.size.height / 2.0)
                    } else {
                        let spanStart = min(currentKnobX, clampedHoverX)
                        let spanWidth = max(0, abs(clampedHoverX - currentKnobX))

                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.26),
                                        Color.white.opacity(0.14)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: spanWidth, height: trackHeight)
                            .offset(x: spanStart)
                    }
                }

                // 4. Chapter Markers (Magnetic ticks accurately aligned with knob center kinematics)
                if clock.duration > 0 && !player.chapters.isEmpty {
                    ForEach(player.chapters) { chapter in
                        let fraction = CGFloat(max(0.0, min(1.0, chapter.time / clock.duration)))
                        let markX = currentKnobRadius + fraction * currentTravelSpan
                        if fraction > 0.01 && fraction < 0.99 {
                            Rectangle()
                                .fill(Color.white.opacity(0.60))
                                .frame(width: 1.5, height: trackHeight + 2.0)
                                .shadow(color: Color.black.opacity(0.5), radius: 1, x: 0, y: 0)
                                .position(x: markX, y: geometry.size.height / 2.0)
                        }
                    }
                }

                // 5. Played Fill Track (Luminous cinema cyan-blue glass ending exactly at knob center)
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.cyan.opacity(0.95),
                                Color.blue.opacity(0.80)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(0, min(totalWidth, currentKnobX)), height: trackHeight)

                // 6. Scrub Knob (Strictly centered at knobCenterX with sub-pixel precision)
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
                let activeAnchorX = player.isScrubbing ? currentKnobX : (hoverLocationX != nil ? max(currentKnobRadius, min(totalWidth - currentKnobRadius, hoverLocationX!)) : currentKnobX)
                if clock.duration > 0, (isHovered || player.isScrubbing) {
                    let activeFraction = fraction(for: activeAnchorX, totalWidth: totalWidth, isExpanded: isExpanded)
                    let rawTime = player.isScrubbing ? player.scrubTime : (activeFraction * clock.duration)
                    let activeChapter = player.chapters.last(where: { $0.time <= rawTime })
                    let chapterTitle = activeChapter?.title

                    let cardHalfWidth: CGFloat = player.transform.isPerpendicular ? 42 : 85
                    let clampedCenterX = max(cardHalfWidth + 10, min(totalWidth - cardHalfWidth - 10, activeAnchorX))

                    ScrubberHoverCardView(
                        thumbnail: thumbnailEngine.activeThumbnail,
                        isLoading: thumbnailEngine.isLoading,
                        time: rawTime,
                        chapterTitle: chapterTitle,
                        transform: player.transform
                    )
                    .position(x: clampedCenterX, y: player.transform.isPerpendicular ? -82 : -68)
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
                    if clock.duration > 0 {
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
                    if !player.isScrubbing {
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
                        player.updateScrubbing(to: rawTime)
                        if abs(rawTime - lastHoverRequestedTime) >= 0.05 {
                            let isInitialScrub = (lastHoverRequestedTime < 0)
                            lastHoverRequestedTime = rawTime
                            hoverDebounceTask?.cancel()
                            if isInitialScrub {
                                thumbnailEngine.requestThumbnail(for: player.currentFilePath, at: rawTime)
                            } else {
                                hoverDebounceTask = Task { @MainActor in
                                    try? await Task.sleep(nanoseconds: 35_000_000)
                                    guard !Task.isCancelled else { return }
                                    thumbnailEngine.requestThumbnail(for: player.currentFilePath, at: rawTime)
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
                        player.finishScrubbing(to: rawTime)
                        if !isHovered {
                            thumbnailEngine.clearCurrent()
                        }
                    }
            )
            .animation(.spring(response: 0.22, dampingFraction: 0.75), value: isExpanded)
        }
        .frame(height: 32)
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
}

// MARK: - Scrubber Hover Preview Card View
@MainActor
public struct ScrubberHoverCardView: View {
    let thumbnail: NSImage?
    let isLoading: Bool
    let time: Double
    let chapterTitle: String?
    var transform: VideoTransform

    public init(
        thumbnail: NSImage?,
        isLoading: Bool,
        time: Double,
        chapterTitle: String?,
        transform: VideoTransform = VideoTransform()
    ) {
        self.thumbnail = thumbnail
        self.isLoading = isLoading
        self.time = time
        self.chapterTitle = chapterTitle
        self.transform = transform
    }

    public var body: some View {
        VStack(spacing: 5) {
            let isVert = transform.isPerpendicular
            let cardW: CGFloat = isVert ? 64 : 156
            let cardH: CGFloat = isVert ? 114 : 88

            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.black.opacity(0.85))
                    .frame(width: cardW, height: cardH)

                if let img = thumbnail {
                    Image(nsImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .rotationEffect(.degrees(Double(transform.effectiveRotation)))
                        .scaleEffect(x: transform.flipH ? -1.0 : 1.0, y: transform.flipV ? -1.0 : 1.0)
                        .frame(width: cardW, height: cardH)
                        .clipped()
                        .cornerRadius(6)
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
                    .frame(width: 156, height: 88)
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
