import SwiftUI
import AppKit

@MainActor
public struct PlayerContainerView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject var player: PlayerCore
    var playlist: PlaylistManager
    @State private var navigationModel = AppNavigationModel.shared
    @State private var isHoveringRightEdge: Bool = false
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
                // Video Canvas Surface
                VideoView(playerCore: player)
                    .edgesIgnoringSafeArea(.all)
                    .contextMenu {
                        let flipH = player.transform.flipH
                        let flipV = player.transform.flipV

                        Button(L10n.tr("Rotate 90° Clockwise", "顺时针旋转 90°")) {
                            player.rotateVideo(clockwise: true)
                        }
                        Button(L10n.tr("Rotate 90° Counterclockwise", "逆时针旋转 90°")) {
                            player.rotateVideo(clockwise: false)
                        }
                        Button(L10n.tr("Reset Orientation", "复位")) {
                            player.resetVideoRotation()
                        }
                        Divider()
                        Button(L10n.tr("Flip Horizontal", "水平翻转") + (flipH ? " ✓" : "")) {
                            player.toggleFlipHorizontal()
                        }
                        Button(L10n.tr("Flip Vertical", "垂直翻转") + (flipV ? " ✓" : "")) {
                            player.toggleFlipVertical()
                        }
                    }

                // Native Audio Artwork & Minimalist Presentation Layer (for pure audio)
                if player.isAudioOnly {
                    AudioArtworkView(player: player, playlist: playlist)
                        .edgesIgnoringSafeArea(.all)
                        .allowsHitTesting(false)
                }

                // Immersive Playback HUD (Embedded Scrubber + Controls + Autohide)
                PlayerHUDView(
                    player: player,
                    playlist: playlist,
                    onPlayNext: onPlayNext,
                    onPlayPrevious: onPlayPrevious,
                    onClosePlayback: onClosePlayback
                )
                .environment(\.colorScheme, .dark)
                .zIndex(20)

                // Subtitle Display Layer (Adaptive text & PGS bitmap rendering)
                // Positioned above HUD layer to guarantee 100% zero occlusion
                SubtitleOverlayView(player: player)
                    .edgesIgnoringSafeArea(.all)

                // Transient On-Screen Display (OSD) HUD (Seek, Play/Pause, Track, Adjustments, Screenshot)
                // Centered at Top with uniform margin across windowed & fullscreen modes (macOS standard)
                if let osd = player.activeOSD {
                    VStack {
                        PlayerOSDView(notification: osd)
                            .padding(.top, player.isFullscreen ? 76 : 84)
                        Spacer()
                    }
                    .environment(\.colorScheme, .dark)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .allowsHitTesting(false)
                }

                // Right-Side Vertical Hidden Volume Bar (Instant feedback, auto-hiding)
                if player.isVolumeHUDVisible {
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
                }

                // Right-Edge Invisible Hover Trigger Zone (within 24pt of right edge)
                // Strictly active in FULLSCREEN mode only; in windowed mode, user must click the side triangle tab.
                if player.isFullscreen {
                    HStack {
                        Spacer()
                        Color.clear
                            .frame(width: 24)
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
                }

                // Right-Edge Floating Side Triangle Pull Tab (always accessible on right border)
                PlaylistDrawerHandleTab(
                    isDrawerVisible: player.isPlaylistDrawerVisible,
                    drawerWidth: drawerWidth
                ) {
                    withAnimation(SilkAnimation.adaptive(reduceMotion: reduceMotion, preferred: .silkSnappy)) {
                        player.togglePlaylistDrawer()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .opacity(player.isHUDVisible || isHoveringRightEdge || player.isPlaylistDrawerVisible ? 1.0 : 0.0)
                .animation(.easeInOut(duration: 0.2), value: player.isHUDVisible || isHoveringRightEdge || player.isPlaylistDrawerVisible)
                .zIndex(26)

                // Interactive Backdrop for Drawer Dismissal:
                // Tapping anywhere outside the drawer closes the drawer without pausing playback.
                // Avoids top 60pt region so top bar quick action buttons (Close, Pin, Inspector) are never obstructed.
                if player.isPlaylistDrawerVisible || player.isInspectorVisible {
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
                        .zIndex(10)
                }

                // Right-Side Slide-In Pure Playlist Drawer
                // Strictly framed within playback area with vertical avoidance (+64pt top, -96pt bottom)
                // to never obstruct top-right Pin / Inspector buttons or bottom scrubber timeline.
                if player.isPlaylistDrawerVisible {
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
                    .zIndex(25)
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
                .padding(.bottom, geometry.size.height < 450 ? 64 : 96)
                .padding(.trailing, 8)
                .zIndex(25)
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
            try? await Task.sleep(nanoseconds: 600_000_000)
            guard !Task.isCancelled, player.isFullscreen else { return }
            withAnimation(SilkAnimation.adaptive(reduceMotion: reduceMotion, preferred: .silkSnappy)) {
                player.isPlaylistDrawerVisible = false
            }
        }
    }
}
