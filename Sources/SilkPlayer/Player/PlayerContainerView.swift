import SwiftUI
import AppKit
import SilkCoreKit

@MainActor
public struct PlayerContainerView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject var player: PlayerCore
    @ObservedObject private var licenseEngine = SilkProLicenseEngine.shared
    private var settings = AppSettings.shared
    var playlist: PlaylistManager
    @State private var navigationModel = AppNavigationModel.shared

    private var shouldHidePlaylistDrawer: Bool {
        licenseEngine.isProActive && settings.proLibraryHomeEnabled && settings.proHideLegacyPlaylistDrawer
    }
    @State private var isHoveringRightEdge: Bool = false
    @State private var isHoveringHandle: Bool = false
    @State private var drawerDismissTask: Task<Void, Never>? = nil
    var onPlayNext: () -> Void
    var onPlayPrevious: () -> Void
    var onSelectPlaylistItem: (PlaylistItem) -> Void
    var onClosePlayback: () -> Void

    public init(
        player: PlayerCore,
        playlist: PlaylistManager = PlaylistManager.shared,
        onPlayNext: @escaping () -> Void = {},
        onPlayPrevious: @escaping () -> Void = {},
        onSelectPlaylistItem: @escaping (PlaylistItem) -> Void = { _ in },
        onClosePlayback: @escaping () -> Void = {}
    ) {
        self.player = player
        self.playlist = playlist
        self.onPlayNext = onPlayNext
        self.onPlayPrevious = onPlayPrevious
        self.onSelectPlaylistItem = onSelectPlaylistItem
        self.onClosePlayback = onClosePlayback
    }

    public var body: some View {
        GeometryReader { geometry in
            let drawerWidth = PlaylistDrawerDimensions.drawerWidth(for: geometry.size.width, isFullscreen: player.isFullscreen)

            ZStack(alignment: .topLeading) {
                if player.isAudioOnly {
                    MusicModeView(
                        player: player,
                        playlist: playlist,
                        onPlayNext: onPlayNext,
                        onPlayPrevious: onPlayPrevious,
                        onSelectPlaylistItem: onSelectPlaylistItem,
                        onClosePlayback: onClosePlayback
                    )
                    .edgesIgnoringSafeArea(.all)
                } else {
                    // Video Canvas Surface (Right-click context menu is handled natively in MetalPlayerContainerView)
                    VideoView(playerCore: player)
                        .edgesIgnoringSafeArea(.all)

                    // Subtitle Display Layer (Adaptive text & PGS bitmap rendering)
                    SubtitleOverlayView(player: player)
                        .edgesIgnoringSafeArea(.all)
                        .allowsHitTesting(false)
                        .zIndex(15)

                    // Immersive Playback HUD (Embedded Scrubber + Controls + Autohide)
                    PlayerHUDView(
                        player: player,
                        playlist: playlist,
                        onPlayNext: onPlayNext,
                        onPlayPrevious: onPlayPrevious,
                        onSelectPlaylistItem: onSelectPlaylistItem,
                        onClosePlayback: onClosePlayback
                    )
                    .environment(\.colorScheme, .dark)
                    .zIndex(20)
                }

                // Playback Failure Recovery Overlay (prevents silent black screen on dead paths / decode failure)
                if !player.isAudioOnly && player.playbackState == .error {
                    VStack(spacing: 14) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundColor(.orange)
                        Text(L10n.tr("Playback Failed", "无法播放当前媒体"))
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                        Text(player.statusMessage)
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.75))
                            .multilineTextAlignment(.center)
                            .lineLimit(3)
                            .frame(maxWidth: 360)
                        HStack(spacing: 10) {
                            if let failedPath = player.currentFilePath {
                                Button(L10n.tr("Retry", "重试")) {
                                    player.loadMediaWithCrossfade(path: failedPath, startTime: player.currentTime, autoPlay: true)
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.regular)
                            }
                            Button(L10n.tr("Close", "返回")) {
                                onClosePlayback()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.regular)
                        }
                        .padding(.top, 2)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 20)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.black.opacity(0.78))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.white.opacity(0.14), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.45), radius: 18, x: 0, y: 8)
                    .environment(\.colorScheme, .dark)
                    .zIndex(38)
                }

                // Transient On-Screen Display (OSD) HUD (Seek, Play/Pause, Track, Adjustments, Screenshot)
                // Centered at Top with uniform margin across windowed & fullscreen modes (macOS standard)
                if let osd = player.activeOSD {
                    VStack {
                        PlayerOSDView(notification: osd)
                            .padding(.top, player.isAudioOnly ? 58 : (player.isFullscreen ? 76 : 84))
                        Spacer()
                    }
                    .environment(\.colorScheme, .dark)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .allowsHitTesting(false)
                    .zIndex(40)
                }

                // Right-Side Vertical Hidden Volume Bar (Video modes only; Music Mode uses bottom inline bar)
                if !player.isAudioOnly && player.isVolumeHUDVisible {
                    HStack {
                        Spacer()
                        SilkVerticalVolumeBarView(player: player)
                            .padding(.trailing, 20)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .offset(x: 10)),
                        removal: .opacity.combined(with: .offset(x: 14))
                    ))
                    .animation(.silkSnappy, value: player.isVolumeHUDVisible)
                    .zIndex(40)
                }

                if !player.isAudioOnly && !shouldHidePlaylistDrawer {
                    // Right-Edge Invisible Hover Trigger Zone (within 28pt of right edge)
                    // Strictly active in FULLSCREEN mode only; in windowed mode, user must click the side triangle tab.
                    if player.isFullscreen {
                        HStack {
                            Spacer()
                            Color.clear
                                .frame(width: 28)
                                .frame(maxHeight: .infinity)
                                .contentShape(Rectangle())
                                .onHover { isHovering in
                                    isHoveringRightEdge = isHovering
                                    if isHovering {
                                        drawerDismissTask?.cancel()
                                        drawerDismissTask = nil
                                        if !player.isPlaylistDrawerVisible && !player.isInspectorVisible {
                                            withAnimation(SilkAnimation.adaptive(reduceMotion: reduceMotion, preferred: .silkSnappy)) {
                                                player.isPlaylistDrawerVisible = true
                                            }
                                        }
                                    }
                                }
                        }
                        .allowsHitTesting(!player.isPlaylistDrawerVisible)
                        .zIndex(27)
                    }

                    // Right-Edge Floating Side Triangle Pull Tab (always accessible on right border)
                    let isHandleVisible = (player.isHUDVisible || isHoveringRightEdge || isHoveringHandle) && !player.isPlaylistDrawerVisible
                    PlaylistDrawerHandleTab(
                        isDrawerVisible: player.isPlaylistDrawerVisible,
                        drawerWidth: drawerWidth,
                        onHoverChange: { isHovering in
                            isHoveringHandle = isHovering
                            if isHovering {
                                player.reportUserActivity()
                            }
                            if player.isFullscreen && isHovering {
                                drawerDismissTask?.cancel()
                                drawerDismissTask = nil
                                if !player.isPlaylistDrawerVisible && !player.isInspectorVisible {
                                    withAnimation(SilkAnimation.adaptive(reduceMotion: reduceMotion, preferred: .silkSnappy)) {
                                        player.isPlaylistDrawerVisible = true
                                    }
                                }
                            }
                        }
                    ) {
                        withAnimation(SilkAnimation.adaptive(reduceMotion: reduceMotion, preferred: .silkSnappy)) {
                            player.togglePlaylistDrawer()
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.trailing, 0)
                    .opacity(isHandleVisible ? 1.0 : 0.001)
                    .allowsHitTesting(!player.isPlaylistDrawerVisible)
                    .animation(.easeInOut(duration: 0.2), value: isHandleVisible)
                    .zIndex(30)
                }

                // Interactive Backdrop for Drawer Dismissal:
                // Tapping anywhere outside the drawer closes the drawer without pausing playback.
                // Avoids top 60pt region so top bar quick action buttons (Close, Pin, Inspector) are never obstructed.
                if (!player.isAudioOnly && !shouldHidePlaylistDrawer && player.isPlaylistDrawerVisible) || player.isInspectorVisible {
                    Color.black.opacity(0.001)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(SilkAnimation.adaptive(reduceMotion: reduceMotion, preferred: .silkSnappy)) {
                                player.isPlaylistDrawerVisible = false
                                player.isInspectorVisible = false
                            }
                        }
                        .padding(.top, 60)
                        .padding(player.isFullscreen ? 0 : 8)
                        .zIndex(35)
                }

                // Right-Side Slide-In Pure Playlist Drawer
                // Strictly framed within playback area with vertical avoidance (+64pt top, -96pt bottom)
                // to never obstruct top-right Pin / Inspector buttons or bottom scrubber timeline.
                if !player.isAudioOnly && !shouldHidePlaylistDrawer && player.isPlaylistDrawerVisible {
                    HStack(spacing: 0) {
                        Spacer()
                        HStack(spacing: 0) {
                            SilkPlaylistDrawerView(
                                player: player,
                                playlist: playlist,
                                drawerWidth: drawerWidth,
                                onSelectPlaylistItem: { item in
                                    onSelectPlaylistItem(item)
                                },
                                onClose: {
                                    player.isPlaylistDrawerVisible = false
                                }
                            )
                            // Seamless hover bridge covering the 8pt trailing margin to avoid flicker dead-zone
                            Color.clear
                                .frame(width: 8)
                                .frame(maxHeight: .infinity)
                        }
                        .contentShape(Rectangle())
                        .onHover { isInside in
                            if player.isFullscreen {
                                if isInside {
                                    drawerDismissTask?.cancel()
                                    drawerDismissTask = nil
                                } else {
                                    scheduleDrawerAutoDismiss()
                                }
                            }
                        }
                    }
                    .padding(.top, 64)
                    .padding(.bottom, geometry.size.height < 450 ? 64 : 96)
                    .transition(SilkAnimation.transition(reduceMotion: reduceMotion, standard: .move(edge: .trailing)))
                    .zIndex(42)
                }

            // Right-Side Slide-In Media Inspector Drawer (Triggered by 'I')
            // Strictly framed within playback area with vertical avoidance (+64pt top, -96pt bottom)
            if player.isInspectorVisible {
                HStack(spacing: 0) {
                    Spacer()
                    SilkMediaInspectorView(
                        player: player,
                        onClose: {
                            player.isInspectorVisible = false
                        }
                    )
                    .environment(\.colorScheme, .dark)
                    .transition(SilkAnimation.transition(reduceMotion: reduceMotion, standard: .move(edge: .trailing)))
                }
                .padding(.top, 64)
                .padding(.bottom, (player.isAudioOnly ? false : geometry.size.height < 450) ? 64 : 96)
                .padding(.trailing, 8)
                .zIndex(45)
            }

            // Drag & Drop Feedback Overlay
            if player.isDragTargeted {
                ZStack {
                    Color.black.opacity(0.6)
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color.cyan, style: StrokeStyle(lineWidth: 3, dash: [8]))
                        .padding(20)
                    VStack(spacing: 12) {
                        Image(systemName: "arrow.down.doc.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.cyan)
                        Text(L10n.dropToPlay)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .allowsHitTesting(false)
                .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(SilkAnimation.adaptive(reduceMotion: reduceMotion, preferred: .silkSnappy), value: player.isPlaylistDrawerVisible || player.isInspectorVisible)
        .onChange(of: player.isInspectorVisible) { _, isVisible in
            if isVisible {
                if player.isPlaylistDrawerVisible { player.isPlaylistDrawerVisible = false }
                navigationModel.activeInspectorTab = .info
            } else if !player.isPlaylistDrawerVisible {
                navigationModel.activeInspectorTab = .none
            }
        }
        .onChange(of: player.isPlaylistDrawerVisible) { _, isVisible in
            if isVisible {
                if player.isInspectorVisible { player.isInspectorVisible = false }
                navigationModel.activeInspectorTab = .playlist
            } else if !player.isInspectorVisible {
                navigationModel.activeInspectorTab = .none
            }
        }
        }
    }

    private func scheduleDrawerAutoDismiss() {
        guard player.isFullscreen else { return }
        drawerDismissTask?.cancel()
        drawerDismissTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 450_000_000)
            guard !Task.isCancelled, player.isFullscreen else { return }
            withAnimation(SilkAnimation.adaptive(reduceMotion: reduceMotion, preferred: .silkSnappy)) {
                player.isPlaylistDrawerVisible = false
            }
        }
    }
}
