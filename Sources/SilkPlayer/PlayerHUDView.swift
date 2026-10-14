import SwiftUI
import AppKit
import SilkCoreKit

/// Responsive HUD layout density tiers based on available canvas width and presentation mode.
@MainActor
public enum HUDLayoutTier: Equatable {
    case expanded      // >= 860: Fullscreen or large desktop window (all 15 controls fully visible)
    case standard      // 660 ..< 860: Standard window (frame steps hidden, more menu active)
    case compact       // 480 ..< 660: Compact window (e.g. 720p 4:3, secondary controls in more menu)
    case minimal       // < 480: Vertical video / ultra-compact window (essential controls only)
}

@MainActor
public struct PlayerHUDView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var settings = AppSettings.shared
    @ObservedObject var player: PlayerCore
    var playlist: PlaylistManager
    public var onPlayNext: (() -> Void)?
    public var onPlayPrevious: (() -> Void)?
    public var onClosePlayback: (() -> Void)?

    @State private var isControlsVisible: Bool = true
    @State private var idleTask: Task<Void, Never>? = nil
    @State private var mouseMonitor: Any?
    @State private var isCursorHidden: Bool = false

    public init(
        player: PlayerCore,
        playlist: PlaylistManager = PlaylistManager.shared,
        onPlayNext: (() -> Void)? = nil,
        onPlayPrevious: (() -> Void)? = nil,
        onClosePlayback: (() -> Void)? = nil
    ) {
        self.player = player
        self.playlist = playlist
        self.onPlayNext = onPlayNext
        self.onPlayPrevious = onPlayPrevious
        self.onClosePlayback = onClosePlayback
    }

    public var body: some View {
        GeometryReader { geometry in
            let availableWidth = geometry.size.width
            let tier = layoutTier(for: availableWidth)

            ZStack {
                VStack(spacing: 0) {
                    topBar(tier: tier)
                        .padding(.horizontal, 16)
                        .padding(.top, player.isFullscreen ? 16 : 30)
                    Spacer()
                    bottomControls(tier: tier, width: availableWidth)
                }
                .opacity(isControlsVisible && player.isHUDVisible ? 1.0 : 0.0)
                .allowsHitTesting(isControlsVisible && player.isHUDVisible)
                .animation(.easeInOut(duration: 0.22), value: isControlsVisible && player.isHUDVisible)
                .animation(.spring(response: 0.25, dampingFraction: 0.8), value: tier)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            setupMouseMonitor()
            registerUserActivity()
        }
        .onDisappear {
            teardownMouseMonitor()
        }
        .onChange(of: player.isPlaying) { _, isPlaying in
            if !isPlaying || player.isAudioOnly {
                showCursor()
                player.setTrafficLightsHidden(false)
                if !isControlsVisible {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isControlsVisible = true
                    }
                }
            } else {
                registerUserActivity()
            }
        }
        .onChange(of: player.isAudioOnly) { _, isAudio in
            if isAudio {
                showCursor()
                player.setTrafficLightsHidden(false)
                if !isControlsVisible {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isControlsVisible = true
                    }
                }
                player.isHUDVisible = true
            }
        }
    }

    private func layoutTier(for width: CGFloat) -> HUDLayoutTier {
        if player.isFullscreen || width >= 860 {
            return .expanded
        } else if width >= 660 {
            return .standard
        } else if width >= 480 {
            return .compact
        } else {
            return .minimal
        }
    }

    // MARK: - Top Information Bar
    private func topBar(tier: HUDLayoutTier) -> some View {
        ZStack(alignment: .center) {
            // 1. Base Layer: Leading Spec Badges + Trailing Quick Actions
            HStack(alignment: .center, spacing: 10) {
                specBadgesRow(tier: tier)
                    .padding(.leading, player.isFullscreen ? 0 : (tier == .minimal ? 54 : 70)) // Avoid traffic lights in windowed mode

                Spacer()

                // Trailing Quick Action Buttons: Pin, Inspector, Close
                HStack(spacing: 8) {
                    // Window Pin / Always on Top Button
                    HUDCircleButton(
                        icon: settings.keepWindowOnTop ? "pin.fill" : "pin",
                        isActive: settings.keepWindowOnTop,
                        helpText: settings.keepWindowOnTop ? L10n.tr("Unpin Window", "取消窗口置顶") : L10n.tr("Keep Window on Top", "保持窗口置顶")
                    ) {
                        let next = !settings.keepWindowOnTop
                        settings.keepWindowOnTop = next
                        player.showOSD(.pictureAdjustment(name: L10n.tr("Always on Top", "窗口置顶"), value: next ? L10n.tr("On", "开启") : L10n.tr("Off", "关闭")))
                    }

                    // Media Inspector Button
                    if tier != .minimal {
                        HUDCircleButton(
                            icon: player.isInspectorVisible ? "info.circle.fill" : "info.circle",
                            isActive: player.isInspectorVisible,
                            helpText: L10n.tr("Media Properties (I)", "媒体属性 (I)")
                        ) {
                            player.toggleInspector()
                        }
                    }

                    // Close Current Media / Return to Empty Canvas
                    HUDCircleButton(
                        icon: "xmark",
                        isActive: false,
                        helpText: L10n.tr("Close Playback / Return Home (Esc / Cmd+W)", "退出播放 / 返回主页 (Esc / Cmd+W)")
                    ) {
                        player.isPlaylistDrawerVisible = false
                        player.isInspectorVisible = false
                        onClosePlayback?()
                    }
                }
            }

            // 2. Center Overlay: Active Media Title (Strictly centered to entire window, hidden in audio mode)
            if !player.mediaTitle.isEmpty && !player.isAudioOnly {
                Text(player.mediaTitle)
                    .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.90))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        ZStack {
                            Capsule().fill(.ultraThinMaterial)
                            Capsule().fill(Color.black.opacity(0.28))
                        }
                    )
                    .overlay(
                        Capsule().strokeBorder(Color.white.opacity(0.18), lineWidth: 0.6)
                    )
                    .shadow(color: Color.black.opacity(0.30), radius: 6, x: 0, y: 2)
                    .frame(maxWidth: max(160, tier == .expanded ? 460 : 280))
            }
        }
    }

    // MARK: - Real-time Media Spec Badges (HDR / 4K / Codec / Audio)
    private func specBadgesRow(tier: HUDLayoutTier) -> some View {
        HStack(spacing: 6) {
            // 1. Dynamic HDR / Dolby Vision Spec Badge (Read-only media specification indicator)
            if player.isHDRContent || player.isDolbyVision {
                HStack(spacing: 4.5) {
                    Image(systemName: player.isDolbyVision ? "sparkles.tv" : "sun.max.fill")
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundColor(.orange)

                    Text(player.hdrFormatString.isEmpty ? (player.isDolbyVision ? "Dolby Vision" : "HDR") : player.hdrFormatString)
                        .font(.system(size: 10.5, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4.5)
                .background(
                    ZStack {
                        Capsule().fill(.ultraThinMaterial)
                        Capsule().fill(Color.black.opacity(0.28))
                    }
                )
                .overlay(
                    Capsule().strokeBorder(Color.white.opacity(0.22), lineWidth: 0.6)
                )
                .help(player.isDolbyVision ? "Dolby Vision" : "High Dynamic Range (HDR)")
            }

            // 2. Resolution Badge (e.g. 4K UHD, 1080p HD, 8K)
            if player.videoWidth > 0 && player.videoHeight > 0 {
                Text(resolutionText)
                    .font(.system(size: 10.5, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.92))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4.5)
                    .background(
                        ZStack {
                            Capsule().fill(.ultraThinMaterial)
                            Capsule().fill(Color.black.opacity(0.28))
                        }
                    )
                    .overlay(
                        Capsule().strokeBorder(Color.white.opacity(0.20), lineWidth: 0.6)
                    )
            }

            // 3. Codec Badge (e.g. HEVC, H.264, AV1, ProRes)
            if !player.isAudioOnly && tier != .minimal && !player.videoCodec.isEmpty && player.videoCodec != "Unknown" {
                Text(cleanCodecText)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.cyan.opacity(0.95))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4.5)
                    .background(
                        ZStack {
                            Capsule().fill(.ultraThinMaterial)
                            Capsule().fill(Color.cyan.opacity(0.12))
                        }
                    )
                    .overlay(
                        Capsule().strokeBorder(Color.cyan.opacity(0.30), lineWidth: 0.6)
                    )
            }

            // 4. Hardware Direct Zero-Copy Badge
            if tier == .expanded {
                HStack(spacing: 3.5) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 5.5, height: 5.5)
                        .shadow(color: Color.green.opacity(0.8), radius: 3)
                    Text("METAL")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(.green.opacity(0.95))
                }
                .padding(.horizontal, 6.5)
                .padding(.vertical, 4.5)
                .background(
                    ZStack {
                        Capsule().fill(.ultraThinMaterial)
                        Capsule().fill(Color.black.opacity(0.28))
                    }
                )
                .overlay(
                    Capsule().strokeBorder(Color.green.opacity(0.30), lineWidth: 0.6)
                )
            }
        }
        .shadow(color: Color.black.opacity(0.25), radius: 6, x: 0, y: 2)
    }

    private var resolutionText: String {
        SilkMediaFormatHelper.resolutionText(width: player.videoWidth, height: player.videoHeight)
    }

    private var cleanCodecText: String {
        let c = player.videoCodec.uppercased()
        if c.contains("HEVC") || c.contains("H265") || c.contains("H.265") {
            return "HEVC"
        } else if c.contains("H264") || c.contains("AVC") || c.contains("H.264") {
            return "H.264"
        } else if c.contains("AV1") {
            return "AV1"
        } else if c.contains("PRORES") {
            return "ProRes"
        } else if c.contains("VP9") {
            return "VP9"
        }
        return c.components(separatedBy: " ").first ?? c
    }

    // MARK: - Bottom Cinema-Embedded HUD Controls (No Clunky Physical Bar Box)
    @ViewBuilder
    private func bottomControls(tier: HUDLayoutTier, width: CGFloat) -> some View {
        VStack(spacing: tier == .minimal ? 6 : 8) {
            // 1. Sleek Scrubber Progress Section (Directly embedded on video canvas)
            PlayerProgressSection(player: player, clock: player.clock, playlist: playlist, tier: tier)
                .padding(.horizontal, 16)

            // 2. Cohesive Transport and Functional Controls
            ZStack(alignment: .center) {
                // Layer 1: Center Group (绝对 100% 物理居中，完美对称几何中轴)
                centerControls(tier: tier, width: width)

                // Layer 2: Left Wing & Right Wing (两翼自然贴靠，中间完全透明留空)
                HStack(alignment: .center, spacing: 0) {
                    leftWingControls(tier: tier)
                    Spacer()
                    rightWingControls(tier: tier)
                }
                .padding(.horizontal, 16)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 24)
        .padding(.bottom, 14)
        .background(
            LinearGradient(
                colors: [
                    Color.clear,
                    Color.black.opacity(0.10),
                    Color.black.opacity(0.40)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)
        )
    }

    // MARK: - Center Transport Group (Symmetrical & Physically Centered)
    @ViewBuilder
    private func centerControls(tier: HUDLayoutTier, width: CGFloat) -> some View {
        let spacing: CGFloat = tier == .minimal ? 10 : 14
        HStack(spacing: spacing) {
            // 1. 上一集 (常驻全部模式，最小/紧凑窗口首选保留)
            HUDTransportButton(
                icon: "backward.end.fill",
                size: (tier == .minimal || tier == .compact) ? 12 : 13,
                weight: .medium,
                disabled: !playlist.hasPrevious && player.currentTime <= 3.0,
                helpText: playlist.hasPrevious ? (playlist.previousItem.map { "\($0.title) (Cmd+Left)" } ?? L10n.previousTrack) : (player.currentTime > 3.0 ? "\(L10n.previousTrack) (0:00)" : L10n.noPreviousTrack)
            ) {
                onPlayPrevious?()
            }
            .accessibilityLabel(L10n.previousTrack)

            // 2. 快退 5 秒 (仅 expanded, standard 宽松模式直显，音频模式下隐藏)
            if !player.isAudioOnly && (tier == .expanded || tier == .standard) {
                let backStep = Int(settings.shortSeekStep)
                let backIcon = backStep == 5 ? "gobackward.5" : (backStep == 10 ? "gobackward.10" : "gobackward")
                HUDTransportButton(
                    icon: backIcon,
                    size: 13.5,
                    weight: .medium,
                    helpText: L10n.tr("Step backward \(backStep)s (Left)", "快退 \(backStep) 秒 (Left)")
                ) {
                    player.step(seconds: -Double(backStep))
                }
                .accessibilityLabel(L10n.tr("Step backward \(backStep)s", "快退 \(backStep) 秒"))
            }

            // 3. 上一帧 (仅 expanded 模式直显，音频模式下隐藏)
            if !player.isAudioOnly && tier == .expanded {
                HUDTransportButton(
                    icon: "backward.frame",
                    size: 13.5,
                    weight: .medium,
                    helpText: L10n.tr("Previous Frame ( [ )", "上一帧 / 逐帧微调取帧 ( [ )")
                ) {
                    player.stepFrame(forward: false)
                }
                .accessibilityLabel(L10n.tr("Previous Frame", "上一帧"))
            }

            // 4. 播放 / 暂停 (核心大圆形播放键 - 任何模式永远常驻绝对中轴)
            Button(action: { player.togglePlayPause() }) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.24),
                                    Color.white.opacity(0.12)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 38, height: 38)
                        .overlay(
                            Circle()
                                .strokeBorder(Color.white.opacity(0.30), lineWidth: 0.8)
                        )
                        .shadow(color: Color.black.opacity(0.28), radius: 5, x: 0, y: 2)

                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 15.5, weight: .bold))
                        .foregroundColor(.white)
                        .offset(x: player.isPlaying ? 0 : 1.0)
                }
                .contentShape(Circle())
            }
            .buttonStyle(HUDInteractiveButtonStyle(hoverScale: 1.08))
            .accessibilityLabel(player.isPlaying ? L10n.pause : L10n.play)
            .help("\(player.isPlaying ? L10n.pause : L10n.play) (Space)")

            // 5. 下一帧 (仅 expanded 模式直显，音频模式下隐藏)
            if !player.isAudioOnly && tier == .expanded {
                HUDTransportButton(
                    icon: "forward.frame",
                    size: 13.5,
                    weight: .medium,
                    helpText: L10n.tr("Next Frame ( ] )", "下一帧 / 逐帧微调取帧 ( ] )")
                ) {
                    player.stepFrame(forward: true)
                }
                .accessibilityLabel(L10n.tr("Next Frame", "下一帧"))
            }

            // 6. 快进 5 秒 (仅 expanded, standard 宽松模式直显，音频模式下隐藏)
            if !player.isAudioOnly && (tier == .expanded || tier == .standard) {
                let forwardStep = Int(settings.shortSeekStep)
                let forwardIcon = forwardStep == 5 ? "goforward.5" : (forwardStep == 10 ? "goforward.10" : "goforward")
                HUDTransportButton(
                    icon: forwardIcon,
                    size: 13.5,
                    weight: .medium,
                    helpText: L10n.tr("Step forward \(forwardStep)s (Right)", "快进 \(forwardStep) 秒 (Right)")
                ) {
                    player.step(seconds: Double(forwardStep))
                }
                .accessibilityLabel(L10n.tr("Step forward \(forwardStep)s", "快进 \(forwardStep) 秒"))
            }

            // 7. 下一集 (常驻全部模式，最小/紧凑窗口首选保留)
            HUDTransportButton(
                icon: "forward.end.fill",
                size: (tier == .minimal || tier == .compact) ? 12 : 13,
                weight: .medium,
                disabled: !playlist.hasNext,
                helpText: playlist.hasNext ? (playlist.nextItem.map { "\($0.title) (Cmd+Right)" } ?? L10n.nextTrack) : L10n.noNextTrack
            ) {
                onPlayNext?()
            }
            .accessibilityLabel(L10n.nextTrack)
        }
        .fixedSize()
        .frame(maxWidth: .infinity, alignment: .center)
    }

    // MARK: - Left Wing Controls (Playback Mode, Speed, Screenshot)
    @ViewBuilder
    private func leftWingControls(tier: HUDLayoutTier) -> some View {
        HStack(spacing: 12) {
            // 0. 播放模式 (顺序播放 / 列表循环 / 单曲循环 / 随机播放)
            PlaybackModeButton(playlist: playlist)

            // 1. 播放倍速选择菜单 (expanded, standard, compact 模式直显)
            if tier != .minimal {
                HUDSpeedMenuButton(player: player)
            }

            // 2. 截屏 (仅在视频播放时于 expanded 和 standard 模式直显，纯音频回放自动隐藏)
            if !player.isAudioOnly && (tier == .expanded || tier == .standard) {
                HUDTransportButton(
                    icon: "camera",
                    size: 14,
                    weight: .medium,
                    color: .white.opacity(0.90),
                    helpText: L10n.tr("Capture Screenshot (Cmd+S)", "截取画面 (Cmd+S)")
                ) {
                    triggerScreenshot()
                }
                .accessibilityLabel(L10n.tr("Capture Screenshot", "截取画面"))
            }
        }
    }

    // MARK: - Right Wing Controls (Playlist, Tracks, Subtitles, More, Settings, Fullscreen)
    @ViewBuilder
    private func rightWingControls(tier: HUDLayoutTier) -> some View {
        HStack(spacing: tier == .minimal ? 10 : 12) {
            // 1. 音轨选择原生菜单 (expanded 和 standard 模式直显，compact/minimal 收纳进更多)
            if tier == .expanded || tier == .standard {
                HUDMenuButton(
                    icon: "waveform",
                    size: 14,
                    weight: .medium,
                    helpText: L10n.audioTrackSelection
                ) {
                    audioTracksMenuContent
                }
            }

            // 3. 字幕选择原生菜单 (expanded, standard, compact 模式直显，minimal 收纳进更多)
            if tier != .minimal {
                HUDMenuButton(
                    icon: "captions.bubble",
                    size: 14,
                    weight: .medium,
                    isActive: player.selectedSubtitleTrackId > 0,
                    helpText: L10n.subtitleTrackSelection
                ) {
                    subtitleTracksMenuContent
                }
            }

            // 4. 更多控制菜单 (当处于 standard, compact, minimal 模式时动态出现，收纳次级功能)
            if tier != .expanded {
                HUDMoreMenuButton {
                    moreMenuContent(tier: tier)
                }
            }

            // 5. 偏好设置 (仅 expanded 模式直显，其余模式在“更多”菜单中)
            if tier == .expanded {
                HUDTransportButton(
                    icon: "gearshape",
                    size: 14,
                    weight: .medium,
                    color: .white.opacity(0.90),
                    helpText: L10n.tr("Preferences (Cmd+,)", "偏好设置 (Cmd+,)")
                ) {
                    PlayerWindowManager.shared.openSettings()
                }
                .accessibilityLabel(L10n.settings)
            }

            // 6. 全屏切换 (永远常驻最右侧，符合 macOS 原生操作直觉与肌肉记忆)
            HUDTransportButton(
                icon: player.isFullscreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right",
                size: 13.5,
                weight: .medium,
                color: .white.opacity(0.90),
                helpText: L10n.toggleFullscreenHelp
            ) {
                player.toggleFullscreen()
            }
            .accessibilityLabel(player.isFullscreen ? L10n.exitFullscreen : L10n.enterFullscreen)
        }
    }

    // MARK: - Reusable Menu Contents for Audio, Subtitles & More
    @ViewBuilder
    private var audioTracksMenuContent: some View {
        if player.audioTracks.isEmpty {
            Text(L10n.noAudioTracks)
        } else {
            ForEach(player.audioTracks) { track in
                Button(track.id == player.selectedAudioTrackId ? "✓ \(track.displayName)" : track.displayName) {
                    player.setAudioTrack(id: track.id, notifyOSD: true)
                }
            }
        }
    }

    @ViewBuilder
    private var subtitleTracksMenuContent: some View {
        if !player.subtitleTracks.isEmpty {
            Text("\(L10n.subtitles) (\(player.subtitleTracks.count))")
                .font(.system(size: 11, weight: .semibold))
            Divider()
        }
        Button("＋ " + L10n.loadExternalSubtitle) {
            player.openSubtitleDialog()
        }
        Divider()
        Button(player.selectedSubtitleTrackId <= 0 ? "✓ " + L10n.disableSubtitles : L10n.disableSubtitles) {
            player.setSubtitleTrack(id: 0, notifyOSD: true)
        }
        Divider()
        if player.subtitleTracks.isEmpty {
            Text(L10n.noSubtitles)
        } else {
            ForEach(player.subtitleTracks) { track in
                Button(track.id == player.selectedSubtitleTrackId ? "✓ \(track.displayName)" : track.displayName) {
                    player.setSubtitleTrack(id: track.id, notifyOSD: true)
                }
            }
        }
    }

    @ViewBuilder
    private func moreMenuContent(tier: HUDLayoutTier) -> some View {
        // 1. 如果在 minimal 模式下，包含倍速选择
        if tier == .minimal {
            Menu(L10n.playbackSpeed + " (\(String(format: "%.2fx", player.speed)))") {
                ForEach([0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 2.0], id: \.self) { rate in
                    Button(abs(player.speed - rate) < 0.04 ? "✓ \(String(format: "%.2fx", rate))\(rate == 1.0 ? " (" + L10n.speedNormal + ")" : "")" : "\(String(format: "%.2fx", rate))\(rate == 1.0 ? " (" + L10n.speedNormal + ")" : "")") {
                        player.setSpeed(rate)
                    }
                }
            }
        }

        // 2. 如果在 compact 或 minimal 模式下，包含音轨
        if tier == .compact || tier == .minimal {
            let audioCount = player.audioTracks.count
            Menu(audioCount > 0 ? "\(L10n.audioTrackSelection) (\(audioCount))" : L10n.audioTrackSelection) {
                audioTracksMenuContent
            }
        }

        // 3. 如果在 compact 或 minimal 模式下，包含字幕
        if tier == .compact || tier == .minimal {
            let subCount = player.subtitleTracks.count
            Menu(subCount > 0 ? "\(L10n.subtitleTrackSelection) (\(subCount))" : L10n.subtitleTrackSelection) {
                subtitleTracksMenuContent
            }
        }

        // 4. 剧集切换 (在 compact / minimal 模式)
        if tier == .compact || tier == .minimal {
            Divider()
            Button(L10n.previousTrack + " (Cmd+Left)") {
                onPlayPrevious?()
            }
            .disabled(!playlist.hasPrevious)

            Button(L10n.nextTrack + " (Cmd+Right)") {
                onPlayNext?()
            }
            .disabled(!playlist.hasNext)
        }

        Divider()

        // 5. 逐帧微调 (在 standard, compact, minimal 模式)
        Menu(L10n.frameStep) {
            Button(L10n.tr("Previous Frame ( [ )", "上一帧 ( [ )")) {
                player.stepFrame(forward: false)
            }
            Button(L10n.tr("Next Frame ( ] )", "下一帧 ( ] )")) {
                player.stepFrame(forward: true)
            }
        }

        // 6. 画面旋转 (在 standard, compact, minimal 模式)
        Button(L10n.tr("Rotate Video", "画面旋转") + " (\(player.videoRotation)°) [R]") {
            player.rotateVideo()
        }

        // 7. 截屏 (在 compact, minimal 模式)
        if tier == .compact || tier == .minimal {
            Button(L10n.tr("Capture Screenshot (Cmd+S)", "截取画面 (Cmd+S)")) {
                triggerScreenshot()
            }
        }

        Divider()

        // 8. 媒体检查器与偏好设置
        Button(L10n.mediaInspectorTitle + " (I)") {
            player.toggleInspector()
        }

        Button(L10n.settings + "... (Cmd+,)") {
            PlayerWindowManager.shared.openSettings()
        }
    }

    public func cycleSpeed() {
        let speeds: [Double] = [1.0, 1.25, 1.5, 2.0, 0.25, 0.5, 0.75]
        let current = player.speed
        if let idx = speeds.firstIndex(where: { abs($0 - current) < 0.05 }) {
            let nextIdx = (idx + 1) % speeds.count
            player.setSpeed(speeds[nextIdx])
        } else {
            player.setSpeed(1.0)
        }
    }



    private func setupMouseMonitor() {
        if mouseMonitor == nil {
            var lastActivityTime: TimeInterval = 0
            mouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDown, .rightMouseDown, .leftMouseDragged, .scrollWheel]) { [weak player] event in
                // Strictly ignore events occurring inside auxiliary windows like Settings
                if let settingsWin = PlayerWindowManager.shared.settingsWindow, event.window === settingsWin {
                    return event
                }
                guard let p = player else { return event }
                if let hostWin = p.hostWindow, let evWin = event.window, evWin !== hostWin {
                    return event
                }

                if event.type == .scrollWheel, let hostWin = p.hostWindow {
                    // Allow playlist and inspector drawers to handle internal scroll
                    if p.isPlaylistDrawerVisible && event.locationInWindow.x > (hostWin.frame.width - 340) {
                        return event
                    }
                    if p.isInspectorVisible && event.locationInWindow.x > (hostWin.frame.width - 340) {
                        return event
                    }

                    MainActor.assumeIsolated {
                        self.handleScrollWheelEvent(event: event, player: p)
                        self.registerUserActivity()
                    }
                    return nil
                }

                if event.type == .mouseMoved {
                    let now = CACurrentMediaTime()
                    if now - lastActivityTime < 0.04 { // 40ms (~25Hz) hardware gate eliminates cursor stickiness
                        return event
                    }
                    lastActivityTime = now
                }

                Task { @MainActor in
                    self.registerUserActivity()
                }
                return event
            }
        }
    }

    @MainActor
    private func handleScrollWheelEvent(event: NSEvent, player: PlayerCore) {
        switch AppSettings.shared.scrollWheelAction {
        case .volume:
            if event.hasPreciseScrollingDeltas {
                let delta = Double(event.scrollingDeltaY)
                if abs(delta) > 0.08 {
                    let step = delta * 0.18
                    player.adjustVolume(by: step)
                }
            } else {
                let stepSign = event.deltaY > 0 ? 1.0 : (event.deltaY < 0 ? -1.0 : 0.0)
                if stepSign != 0 {
                    player.handleScrollWheelVolume(deltaY: stepSign)
                }
            }
        case .seek:
            if event.hasPreciseScrollingDeltas {
                let delta = Double(event.scrollingDeltaY) * 0.12
                if abs(delta) > 0.05 {
                    player.step(seconds: delta)
                }
            } else {
                let stepSign = event.deltaY > 0 ? 1.0 : (event.deltaY < 0 ? -1.0 : 0.0)
                if stepSign != 0 {
                    player.step(seconds: stepSign * AppSettings.shared.shortSeekStep)
                }
            }
        }
    }

    private func hideCursor() {
        guard !isCursorHidden else { return }
        guard let hostWin = player.hostWindow, hostWin.isKeyWindow else { return }
        guard NSApp.modalWindow == nil else { return }
        if PlayerWindowManager.shared.settingsWindow != nil { return }
        NSCursor.setHiddenUntilMouseMoves(true)
        isCursorHidden = true
    }

    private func showCursor() {
        guard isCursorHidden else { return }
        NSCursor.unhide()
        isCursorHidden = false
    }

    private func teardownMouseMonitor() {
        if let monitor = mouseMonitor {
            NSEvent.removeMonitor(monitor)
            mouseMonitor = nil
        }
        idleTask?.cancel()
        showCursor()
        player.setTrafficLightsHidden(false)
    }

    private func registerUserActivity() {
        showCursor()
        player.setTrafficLightsHidden(false)
        player.reportUserActivity()
        if !isControlsVisible {
            withAnimation(.easeInOut(duration: 0.2)) {
                isControlsVisible = true
            }
        }
        idleTask?.cancel()
        guard !player.isScrubbing else { return } // Never auto-hide while scrubbing
        if player.isAudioOnly {
            // Audio mode: progress bar and bottom controls stay permanently visible for quick track switching
            return
        }
        idleTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_800_000_000) // 1.8 seconds idle timeout
            guard !Task.isCancelled else { return }
            guard !player.isScrubbing else { return } // Guard against delayed execution while scrubbing
            // Do not auto-hide HUD or hide cursor if settings window is open, modal dialog is active, or player window is not key
            guard let hostWin = player.hostWindow, hostWin.isKeyWindow else { return }
            guard NSApp.modalWindow == nil else { return }
            if PlayerWindowManager.shared.settingsWindow != nil {
                return
            }
            if player.isPlaying {
                withAnimation(.easeInOut(duration: 0.25)) {
                    isControlsVisible = false
                }
                player.setTrafficLightsHidden(true)
                hideCursor()
            }
        }
    }

    private func triggerScreenshot() {
        player.takeScreenshot()
    }
}

// MARK: - Reusable HUD Controls & Components

@MainActor
struct HUDInteractiveButtonStyle: ButtonStyle {
    var hoverScale: CGFloat = 1.05

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

