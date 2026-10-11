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
            if !isPlaying {
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

            // 2. Center Overlay: Active Media Title (Strictly centered to entire window)
            if !player.mediaTitle.isEmpty {
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
            if tier != .minimal && !player.videoCodec.isEmpty && player.videoCodec != "Unknown" {
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
            PlayerProgressSection(player: player, clock: player.clock, tier: tier)
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
            // 1. 上一集 (expanded, standard 模式直显; minimal 模式下替换快退 5 秒呈现)
            if tier == .expanded || tier == .standard || tier == .minimal {
                HUDTransportButton(
                    icon: "backward.end.fill",
                    size: tier == .minimal ? 12 : 13,
                    weight: .medium,
                    disabled: !playlist.hasPrevious && player.currentTime <= 3.0,
                    helpText: playlist.hasPrevious ? (playlist.previousItem.map { "\($0.title) (Cmd+Left)" } ?? L10n.previousTrack) : (player.currentTime > 3.0 ? "\(L10n.previousTrack) (0:00)" : L10n.noPreviousTrack)
                ) {
                    onPlayPrevious?()
                }
                .accessibilityLabel(L10n.previousTrack)
            }

            // 2. 快退 5 秒 (仅 expanded, standard, compact 模式显示; minimal 模式下被上一集替换)
            if tier == .expanded || tier == .standard || tier == .compact {
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

            // 3. 上一帧 (仅 expanded 模式直显，其他模式收纳进快捷键/更多菜单)
            if tier == .expanded {
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

            // 5. 下一帧 (仅 expanded 模式直显，其他模式收纳进快捷键/更多菜单)
            if tier == .expanded {
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

            // 6. 快进 5 秒 (仅 expanded, standard, compact 模式显示; minimal 模式下被下一集替换)
            if tier == .expanded || tier == .standard || tier == .compact {
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

            // 7. 下一集 (expanded, standard 模式直显; minimal 模式下替换快进 5 秒呈现)
            if tier == .expanded || tier == .standard || tier == .minimal {
                HUDTransportButton(
                    icon: "forward.end.fill",
                    size: tier == .minimal ? 12 : 13,
                    weight: .medium,
                    disabled: !playlist.hasNext,
                    helpText: playlist.hasNext ? (playlist.nextItem.map { "\($0.title) (Cmd+Right)" } ?? L10n.nextTrack) : L10n.noNextTrack
                ) {
                    onPlayNext?()
                }
                .accessibilityLabel(L10n.nextTrack)
            }
        }
        .fixedSize()
        .frame(maxWidth: .infinity, alignment: .center)
    }

    // MARK: - Left Wing Controls (Display, Speed, Screenshot)
    @ViewBuilder
    private func leftWingControls(tier: HUDLayoutTier) -> some View {
        HStack(spacing: 12) {
            // 1. 画面旋转 (仅 expanded 模式直显，其余模式在“更多”菜单中)
            if tier == .expanded {
                HUDTransportButton(
                    icon: "rotate.right",
                    size: 14,
                    weight: .medium,
                    color: player.videoRotation != 0 ? .accentColor : .white.opacity(0.90),
                    helpText: L10n.tr("Video Rotation (Current: \(player.videoRotation)°) [R]", "画面旋转 (当前: \(player.videoRotation)°) [R]")
                ) {
                    player.rotateVideo()
                }
                .accessibilityLabel(L10n.tr("Video Rotation", "画面旋转"))
            }

            // 2. 播放倍速选择菜单 (expanded, standard, compact 模式直显)
            if tier != .minimal {
                HUDSpeedMenuButton(player: player)
            }

            // 3. 截屏 (在 expanded 和 standard 模式直显)
            if tier == .expanded || tier == .standard {
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

@MainActor
struct HUDTransportButton: View {
    let icon: String
    var size: CGFloat = 14
    var weight: Font.Weight = .regular
    var color: Color = .white
    var disabled: Bool = false
    var helpText: String = ""
    var action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size, weight: weight))
                .foregroundColor(color)
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(Color.white.opacity(isHovered ? 0.12 : 0.0))
                )
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.35 : (isHovered ? 1.0 : 0.88))
        .scaleEffect(isHovered && !disabled ? 1.08 : 1.0)
        .animation(.spring(response: 0.20, dampingFraction: 0.75), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
        .help(helpText)
    }
}

@MainActor
struct HUDMenuButton<Content: View>: View {
    let icon: String
    var size: CGFloat = 14
    var weight: Font.Weight = .medium
    var color: Color = .white
    var isActive: Bool = false
    var helpText: String = ""
    @ViewBuilder let content: () -> Content

    @State private var isHovered = false

    var body: some View {
        Menu {
            content()
        } label: {
            Image(systemName: icon)
                .font(.system(size: size, weight: weight))
                .foregroundColor(isActive ? .cyan : color)
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(Color.white.opacity(isHovered ? 0.14 : (isActive ? 0.10 : 0.0)))
                )
                .contentShape(Circle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .frame(width: 28, height: 28)
        .fixedSize()
        .opacity(isHovered || isActive ? 1.0 : 0.88)
        .scaleEffect(isHovered ? 1.08 : 1.0)
        .animation(.spring(response: 0.20, dampingFraction: 0.75), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
        .help(helpText)
    }
}

@MainActor
struct HUDMoreMenuButton<Content: View>: View {
    @ViewBuilder let content: () -> Content
    @State private var isHovered = false

    var body: some View {
        Menu {
            content()
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white.opacity(0.90))
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(Color.white.opacity(isHovered ? 0.14 : 0.0))
                )
                .contentShape(Circle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .frame(width: 28, height: 28)
        .fixedSize()
        .opacity(isHovered ? 1.0 : 0.88)
        .scaleEffect(isHovered ? 1.08 : 1.0)
        .animation(.spring(response: 0.20, dampingFraction: 0.75), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
        .help("更多控制")
    }
}

@MainActor
struct HUDSpeedMenuButton: View {
    @ObservedObject var player: PlayerCore
    @State private var isHovered = false

    var body: some View {
        Menu {
            ForEach([0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 2.0], id: \.self) { rate in
                Button(abs(player.speed - rate) < 0.04 ? "✓ \(String(format: "%.2fx", rate))\(rate == 1.0 ? " (" + L10n.speedNormal + ")" : "")" : "\(String(format: "%.2fx", rate))\(rate == 1.0 ? " (" + L10n.speedNormal + ")" : "")") {
                    player.setSpeed(rate)
                }
            }
        } label: {
            Text(speedPillText)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundColor(player.speed != 1.0 ? .cyan : .white.opacity(0.88))
                .frame(minWidth: 32)
                .frame(height: 26)
                .padding(.horizontal, 4)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(isHovered ? 0.14 : (player.speed != 1.0 ? 0.12 : 0.06)))
                )
                .overlay(
                    Capsule()
                        .strokeBorder(player.speed != 1.0 ? Color.cyan.opacity(0.4) : Color.white.opacity(0.15), lineWidth: 0.6)
                )
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .scaleEffect(isHovered ? 1.06 : 1.0)
        .animation(.spring(response: 0.20, dampingFraction: 0.75), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
        .help(L10n.tr("Playback Speed: \(String(format: "%.2fx", player.speed)) (Click to choose)", "倍速播放: \(String(format: "%.2fx", player.speed)) (点击选择常规倍速)"))
    }

    private var speedPillText: String {
        if player.speed == 1.0 {
            return "1.0x"
        } else if player.speed.truncatingRemainder(dividingBy: 0.1) < 0.01 {
            return String(format: "%.1fx", player.speed)
        } else {
            return String(format: "%.2fx", player.speed)
        }
    }
}

@MainActor
struct HUDCircleButton: View {
    let icon: String
    var isActive: Bool = false
    var helpText: String = ""
    var action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(isActive ? .cyan : .white.opacity(0.92))
                .frame(width: 30, height: 30)
                .background(
                    ZStack {
                        Circle()
                            .fill(.ultraThinMaterial)
                        if isActive {
                            Circle()
                                .fill(Color.cyan.opacity(0.25))
                        } else {
                            Circle()
                                .fill(Color.black.opacity(0.20))
                        }
                    }
                )
                .overlay(
                    Circle()
                        .strokeBorder(
                            isActive
                                ? Color.cyan.opacity(0.65)
                                : Color.white.opacity(isHovered ? 0.35 : 0.18),
                            lineWidth: 0.75
                        )
                )
                .shadow(color: Color.black.opacity(0.25), radius: 6, x: 0, y: 2)
                .scaleEffect(isHovered ? 1.06 : 1.0)
                .animation(.spring(response: 0.22, dampingFraction: 0.75), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
        .help(helpText)
    }
}

@MainActor
struct HUDVolumeSlider: View {
    @ObservedObject var player: PlayerCore
    @State private var isHovered = false
    @State private var isDragging = false

    var body: some View {
        HStack(spacing: 6) {
            Button(action: { player.toggleMute() }) {
                Image(systemName: volumeIconName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(player.isMuted ? Color(nsColor: .systemRed) : .white.opacity(0.92))
                    .frame(width: 24, height: 24)
                    .background(
                        Circle()
                            .fill(Color.white.opacity(isHovered ? 0.12 : 0.0))
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(player.isMuted ? L10n.unmuteAudio : L10n.muteAudio)
            .help("\(player.isMuted ? L10n.unmuteAudio : L10n.muteAudio) (M)")

            GeometryReader { geo in
                let maxLimit = AppSettings.shared.maxVolumeLimit
                let currentVol = player.isMuted ? 0.0 : player.volume
                let fraction = CGFloat(max(0.0, min(maxLimit, currentVol)) / maxLimit)
                let isExpanded = isHovered || isDragging
                let height: CGFloat = isExpanded ? 6.0 : 4.0
                let knobSize: CGFloat = isExpanded ? 11.0 : 8.0

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.black.opacity(0.35))
                        .frame(height: height)

                    Capsule()
                        .fill(Color.white.opacity(0.25))
                        .frame(height: height)

                    Capsule()
                        .fill(
                            player.isMuted
                                ? LinearGradient(colors: [Color.red.opacity(0.85), Color.red.opacity(0.65)], startPoint: .leading, endPoint: .trailing)
                                : LinearGradient(colors: [Color.white, Color.cyan.opacity(0.85)], startPoint: .leading, endPoint: .trailing)
                        )
                        .frame(width: max(0, min(geo.size.width, geo.size.width * fraction)), height: height)

                    if isExpanded {
                        Circle()
                            .fill(Color.white)
                            .shadow(color: Color.black.opacity(0.35), radius: 2, x: 0, y: 1)
                            .frame(width: knobSize, height: knobSize)
                            .offset(x: max(0, min(geo.size.width - knobSize, geo.size.width * fraction - (knobSize / 2.0))))
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .frame(maxHeight: .infinity, alignment: .center)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            isDragging = true
                            if player.isMuted {
                                player.toggleMute()
                            }
                            let newFraction = max(0.0, min(1.0, value.location.x / geo.size.width))
                            player.setVolume(Double(newFraction * maxLimit), maxLimit: maxLimit)
                        }
                        .onEnded { _ in
                            isDragging = false
                        }
                )
            }
            .frame(width: 72, height: 18)
            .animation(.spring(response: 0.22, dampingFraction: 0.75), value: isHovered)
            .animation(.spring(response: 0.22, dampingFraction: 0.75), value: isDragging)
        }
        .onHover { hovering in
            isHovered = hovering
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(L10n.volumeSlider)
        .accessibilityValue("\(Int(player.isMuted ? 0 : player.volume))%")
    }

    private var volumeIconName: String {
        if player.isMuted || player.volume <= 0 {
            return "speaker.slash.fill"
        } else if player.volume < 40 {
            return "speaker.wave.1.fill"
        } else {
            return "speaker.wave.2.fill"
        }
    }
}

// MARK: - Isolated Progress Section with Millisecond Magnetic Snap
@MainActor
public struct PlayerProgressSection: View {
    @ObservedObject var player: PlayerCore
    var clock: PlayerClock
    var tier: HUDLayoutTier = .expanded
    @State private var showRemainingTime: Bool = false

    public init(player: PlayerCore, clock: PlayerClock, tier: HUDLayoutTier = .expanded) {
        self.player = player
        self.clock = clock
        self.tier = tier
    }

    public var body: some View {
        HStack(spacing: tier == .minimal ? 8 : 10) {
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
                        // 在倍速播放模式下，进度球飞速前移，高亮条脱离与狂奔进度球动态跨度绑定，改为平滑聚光焦点指示，根除高频翻转与剧烈抽搐
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
            .contentShape(Rectangle()) // 32px invisible hit area captures every touch
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
                                // 首次落点 0ms 零延迟分发：彻底消除 35ms 人为等待，瞬间截取画面
                                thumbnailEngine.requestThumbnail(for: player.currentFilePath, at: rawTargetTime)
                            } else {
                                hoverDebounceTask = Task { @MainActor in
                                    try? await Task.sleep(nanoseconds: 35_000_000) // 仅在后续持续滑动时 35ms 节流
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
            // Continuous High-Precision Scrubbing & Click-to-Seek (Knob-center physics)
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
                                    try? await Task.sleep(nanoseconds: 35_000_000) // 35ms light throttle window (~30fps)
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
            // 1. I-Frame Thumbnail Canvas (Dynamic Aspect based on transform)
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

            // 2. High-precision Timecode + Chapter Info
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

