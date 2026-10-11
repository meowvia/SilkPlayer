import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// Dedicated Pure Playlist Sidebar Drawer for SilkPlayer.
/// Focused entirely on playlist duties: drag-and-drop, playback queue management,
/// track switching, and local/SMB file actions.
@MainActor
public struct SilkPlaylistDrawerView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject var player: PlayerCore
    var playlist: PlaylistManager
    public var drawerWidth: CGFloat
    public var onSelectPlaylistItem: (PlaylistItem) -> Void
    public var onClose: () -> Void

    @State private var hoveredIndex: Int? = nil
    @State private var isFooterClearHovered: Bool = false
    @State private var isDrawerDropTargeted: Bool = false

    public init(
        player: PlayerCore,
        playlist: PlaylistManager,
        drawerWidth: CGFloat = 240,
        onSelectPlaylistItem: @escaping (PlaylistItem) -> Void,
        onClose: @escaping () -> Void
    ) {
        self.player = player
        self.playlist = playlist
        self.drawerWidth = drawerWidth
        self.onSelectPlaylistItem = onSelectPlaylistItem
        self.onClose = onClose
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Pure Header Bar: Clean Centered Title + Count Badge
            headerBar

            Divider()
                .opacity(0.18)

            // Playlist Body
            if playlist.isEmpty {
                emptyPlaylistPlaceholder
            } else {
                playlistScrollView
            }

            // Playlist Footer Toolbar
            playlistFooterToolbar
        }
        .frame(width: drawerWidth)
        .frame(maxHeight: .infinity)
        .background(
            ZStack {
                Color.black.opacity(0.76)
                VisualEffectView(material: .hudWindow, blendingMode: .withinWindow)
                Rectangle().fill(.ultraThinMaterial)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.32),
                            Color.white.opacity(0.12),
                            Color.white.opacity(0.06),
                            Color.white.opacity(0.18)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.8
                )
        )
        .shadow(color: Color.black.opacity(0.45), radius: 24, x: -6, y: 4)
        .shadow(color: Color.black.opacity(0.20), radius: 6, x: -2, y: 2)
        .onDrop(of: [.fileURL], isTargeted: $isDrawerDropTargeted) { providers in
            handleDrop(providers: providers)
        }
    }

    // MARK: - Header Bar
    private var headerBar: some View {
        HStack(alignment: .center, spacing: 6) {
            Spacer()

            Text(L10n.playlist)
                .font(.system(size: 13.5, weight: .bold))
                .foregroundColor(.white)

            if playlist.count > 0 {
                Text("\(playlist.count)")
                    .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                    .foregroundColor(.cyan)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1.5)
                    .background(Capsule().fill(Color.cyan.opacity(0.18)))
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 12)
    }

    // MARK: - Empty Placeholder
    private var emptyPlaylistPlaceholder: some View {
        VStack(spacing: 10) {
            Spacer(minLength: 8)
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.05))
                    .frame(width: 52, height: 52)
                Image(systemName: "film.stack")
                    .font(.system(size: 22))
                    .foregroundColor(.white.opacity(0.35))
            }
            Text(L10n.emptyPlaylist)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white.opacity(0.75))
            Text(L10n.tr("Drop video files or folders here to add", "拖拽视频文件或文件夹至此处即可添加"))
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.40))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)

            Spacer(minLength: 8)
        }
        .frame(minHeight: 0)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Playlist Scroll View
    private var playlistScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: true) {
                LazyVStack(spacing: 2) {
                    ForEach(Array(playlist.items.enumerated()), id: \.element.id) { index, item in
                        PlaylistItemRowView(
                            index: index,
                            item: item,
                            isCurrent: index == playlist.currentIndex,
                            isPlaying: player.isPlaying,
                            isHovered: hoveredIndex == index,
                            onSelect: {
                                onSelectPlaylistItem(item)
                            },
                            onReveal: {
                                let url = URL(fileURLWithPath: item.path)
                                NSWorkspace.shared.activateFileViewerSelecting([url])
                            },
                            onDelete: {
                                withAnimation(SilkAnimation.adaptive(reduceMotion: reduceMotion, preferred: .silkSnappy)) {
                                    playlist.removeItem(at: index)
                                }
                            },
                            onHoverChange: { isInside in
                                hoveredIndex = isInside ? index : nil
                            }
                        )
                        .id(item.id)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
            }
            .onAppear {
                if let current = playlist.currentItem {
                    proxy.scrollTo(current.id, anchor: .center)
                }
            }
            .onChange(of: playlist.currentIndex) { _, newIndex in
                if newIndex >= 0 && newIndex < playlist.items.count {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        proxy.scrollTo(playlist.items[newIndex].id, anchor: .center)
                    }
                }
            }
        }
    }

    // MARK: - Footer Toolbar
    private var playlistFooterToolbar: some View {
        VStack(spacing: 0) {
            Divider().opacity(0.15)
            HStack(spacing: 8) {
                Button(action: {
                    addMediaViaPicker()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 10.5, weight: .semibold))
                        Text(L10n.tr("Add Media...", "添加媒体…"))
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(.white.opacity(0.85))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4.5)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.08)))
                }
                .buttonStyle(.plain)
                .focusable(false)
                .focusEffectDisabled()

                Spacer()

                if !playlist.isEmpty {
                    Button(action: {
                        withAnimation(SilkAnimation.adaptive(reduceMotion: reduceMotion, preferred: .silkSnappy)) {
                            playlist.clear()
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "trash")
                                .font(.system(size: 10))
                            Text(L10n.clearAll)
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundColor(isFooterClearHovered ? Color(nsColor: .systemRed) : .white.opacity(0.65))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4.5)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(isFooterClearHovered ? Color.red.opacity(0.14) : Color.white.opacity(0.06))
                        )
                    }
                    .buttonStyle(.plain)
                    .focusable(false)
                    .focusEffectDisabled()
                    .onHover { isFooterClearHovered = $0 }
                    .help(L10n.tr("Clear All (Empty Playlist)", "一键清空播放列表"))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }

    private func addMediaViaPicker() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.message = L10n.chooseVideoDialog
        panel.prompt = L10n.tr("Add", "添加")
        if panel.runModal() == .OK {
            let paths = panel.urls.map(\.path)
            let expanded = PlayerWindowManager.expandFilesAndDirectories(paths)
            if !expanded.isEmpty {
                var newItems: [PlaylistItem] = []
                for path in expanded {
                    let title = URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
                    let size = (try? FileManager.default.attributesOfItem(atPath: path)[.size] as? Int64) ?? 0
                    let item = MediaItem(path: path, title: title, fileSize: size)
                    newItems.append(PlaylistItem(from: item))
                }
                let wasEmpty = playlist.isEmpty
                let needsAutoPlay = wasEmpty || !player.isLoaded
                playlist.appendItems(newItems)
                if needsAutoPlay, let first = newItems.first {
                    onSelectPlaylistItem(first)
                }
            }
        }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard !providers.isEmpty else { return false }
        Task { @MainActor in
            var collectedURLs: [URL] = []
            for provider in providers {
                let url: URL? = await withCheckedContinuation { continuation in
                    _ = provider.loadObject(ofClass: URL.self) { url, _ in
                        continuation.resume(returning: url)
                    }
                }
                if let url = url {
                    collectedURLs.append(url)
                }
            }
            let paths = collectedURLs.map { $0.path }
            let expanded = PlayerWindowManager.expandFilesAndDirectories(paths)
            if !expanded.isEmpty {
                var newItems: [PlaylistItem] = []
                for path in expanded {
                    let title = URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
                    let size = (try? FileManager.default.attributesOfItem(atPath: path)[.size] as? Int64) ?? 0
                    let item = MediaItem(path: path, title: title, fileSize: size)
                    newItems.append(PlaylistItem(from: item))
                }
                let wasEmpty = self.playlist.isEmpty
                let needsAutoPlay = wasEmpty || !self.player.isLoaded
                self.playlist.appendItems(newItems)
                if needsAutoPlay, let first = newItems.first {
                    self.onSelectPlaylistItem(first)
                }
            }
        }
        return true
    }
}

/// Dedicated Pure Media Inspector Sidebar Drawer for SilkPlayer.
/// Triggered via shortcut `I` or the top inspector button.
@MainActor
public struct SilkMediaInspectorView: View {
    @ObservedObject var player: PlayerCore
    public var onClose: () -> Void

    @State private var isCloseHovered: Bool = false
    @State private var isCopied: Bool = false
    @State private var isCopyHovered: Bool = false

    public init(player: PlayerCore, onClose: @escaping () -> Void) {
        self.player = player
        self.onClose = onClose
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.cyan)

                Text(L10n.mediaInspectorTitle)
                    .font(.system(size: 13.5, weight: .bold))
                    .foregroundColor(.white)

                Spacer()

                // One-click Copy Button
                Button(action: copyMediaInfo) {
                    HStack(spacing: 4.5) {
                        Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(isCopied ? .green : .white.opacity(0.85))
                        Text(isCopied ? L10n.copied : L10n.copyInfo)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(isCopied ? .green : .white.opacity(0.85))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3.5)
                    .background(
                        Capsule().fill(isCopied ? Color.green.opacity(0.18) : (isCopyHovered ? Color.white.opacity(0.16) : Color.white.opacity(0.08)))
                    )
                    .overlay(
                        Capsule().strokeBorder(isCopied ? Color.green.opacity(0.35) : Color.white.opacity(0.15), lineWidth: 0.6)
                    )
                }
                .buttonStyle(.plain)
                .onHover { isCopyHovered = $0 }
                .help(L10n.tr("Copy media specifications to clipboard", "一键复制完整影片参数到剪贴板"))

                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10.5, weight: .bold))
                        .foregroundColor(isCloseHovered ? .white : .white.opacity(0.60))
                        .frame(width: 22, height: 22)
                        .background(
                            Circle().fill(isCloseHovered ? Color.white.opacity(0.18) : Color.white.opacity(0.06))
                        )
                }
                .buttonStyle(.plain)
                .onHover { isCloseHovered = $0 }
                .help(L10n.tr("Close Media Properties (Esc / I)", "关闭媒体属性 (Esc / I)"))
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 12)

            Divider().opacity(0.18)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 10) {
                    // Section 1: Video Specs (Strictly aligned with top-left HUD capsule)
                    inspectorCard(
                        title: L10n.videoInformation,
                        icon: "film",
                        tag: SilkMediaFormatHelper.resolutionBadge(width: player.videoWidth, height: player.videoHeight),
                        tagColor: .cyan
                    ) {
                        let resDetail = player.videoWidth > 0
                            ? "\(player.videoWidth) × \(player.videoHeight) (\(SilkMediaFormatHelper.resolutionText(width: player.videoWidth, height: player.videoHeight)))"
                            : "—"
                        inspectorRow(label: L10n.resolution, value: resDetail)
                        inspectorRow(label: L10n.videoCodec, value: player.videoCodec.isEmpty ? "—" : player.videoCodec.uppercased())
                        if player.videoFps > 0 {
                            inspectorRow(label: L10n.tr("Frame Rate", "视频帧率"), value: String(format: "%.2f fps", player.videoFps))
                        }

                        let dynamicRangeValue: String = {
                            if player.isDolbyVision {
                                return player.hdrFormatString.isEmpty ? "Dolby Vision" : player.hdrFormatString
                            } else if player.isHDRContent {
                                return player.hdrFormatString.isEmpty ? "HDR10" : player.hdrFormatString
                            } else {
                                return "SDR (Standard Dynamic Range)"
                            }
                        }()
                        inspectorRow(
                            label: L10n.tr("Dynamic Range", "动态范围"),
                            value: dynamicRangeValue,
                            highlight: (player.isDolbyVision || player.isHDRContent) ? .orange : nil
                        )

                        inspectorRow(
                            label: L10n.tr("Rendering Pipeline", "渲染管线"),
                            value: "Metal Hardware Direct (Zero-Copy)",
                            highlight: .green
                        )

                        if player.videoRotation != 0 {
                            inspectorRow(label: L10n.tr("Rotation", "画面旋转"), value: "\(player.videoRotation)°")
                        }
                        if !player.videoAspectRatio.isEmpty && player.videoAspectRatio != "auto" {
                            inspectorRow(label: L10n.aspectRatio, value: player.videoAspectRatio)
                        }
                        if player.speed != 1.0 {
                            inspectorRow(label: L10n.playbackSpeed, value: String(format: "%.2fx", player.speed))
                        }
                    }

                    // Section 2: Audio & Subtitles
                    inspectorCard(title: L10n.tr("Audio & Subtitles", "声音与字幕"), icon: "waveform") {
                        // Interactive Audio Track Row
                        HStack(alignment: .top, spacing: 8) {
                            Text(L10n.audioTrack)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.white.opacity(0.60))
                                .frame(width: 80, alignment: .leading)

                            Spacer()

                            Menu {
                                ForEach(player.audioTracks) { track in
                                    Button(track.id == player.selectedAudioTrackId ? "✓ \(track.displayName)" : track.displayName) {
                                        player.setAudioTrack(id: track.id)
                                    }
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    let activeName = player.audioTracks.first(where: { $0.id == player.selectedAudioTrackId })?.displayName ?? (player.audioTracks.isEmpty ? L10n.tr("No Audio", "无音频") : "#\(player.selectedAudioTrackId)")
                                    Text("\(activeName) (\(player.audioTracks.count))")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(.cyan.opacity(0.95))
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(.system(size: 9))
                                        .foregroundColor(.white.opacity(0.50))
                                }
                            }
                            .menuStyle(.borderlessButton)
                        }

                        // Selected Audio Codec Info
                        if let selectedAudio = player.audioTracks.first(where: { $0.id == player.selectedAudioTrackId }), !selectedAudio.codec.isEmpty {
                            inspectorRow(label: L10n.tr("Audio Codec", "音频编码"), value: selectedAudio.codec.uppercased())
                        }

                        // Interactive Subtitle Track Row
                        HStack(alignment: .top, spacing: 8) {
                            Text(L10n.subtitles)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.white.opacity(0.60))
                                .frame(width: 80, alignment: .leading)

                            Spacer()

                            Menu {
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
                            } label: {
                                HStack(spacing: 4) {
                                    let activeSub = player.selectedSubtitleTrackId > 0
                                        ? (player.subtitleTracks.first(where: { $0.id == player.selectedSubtitleTrackId })?.displayName ?? "#\(player.selectedSubtitleTrackId)")
                                        : L10n.tr("Disabled", "已关闭")
                                    let countSuffix = player.subtitleTracks.isEmpty ? "" : " (\(player.subtitleTracks.count))"
                                    Text("\(activeSub)\(countSuffix)")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(player.selectedSubtitleTrackId > 0 ? .cyan.opacity(0.95) : .white.opacity(0.70))
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(.system(size: 9))
                                        .foregroundColor(.white.opacity(0.50))
                                }
                            }
                            .menuStyle(.borderlessButton)
                        }

                        inspectorRow(label: L10n.tr("Audio Engine", "音频引擎"), value: "Native CoreAudio (AudioQueue Low-Latency)")
                    }

                    // Section 3: File Source
                    if let path = player.currentFilePath {
                        inspectorCard(title: L10n.tr("Media Source", "媒体文件源"), icon: "internaldrive") {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(URL(fileURLWithPath: path).lastPathComponent)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.92))
                                    .lineLimit(1)
                                    .truncationMode(.middle)

                                Text(path)
                                    .font(.system(size: 9.5, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.48))
                                    .lineLimit(2)
                                    .truncationMode(.middle)
                                    .textSelection(.enabled)

                                HStack {
                                    Spacer()
                                    Button(action: {
                                        let url = URL(fileURLWithPath: path)
                                        NSWorkspace.shared.activateFileViewerSelecting([url])
                                    }) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "folder")
                                            Text(L10n.tr("Finder", "访达"))
                                        }
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(.white.opacity(0.75))
                                        .padding(.horizontal, 7)
                                        .padding(.vertical, 3)
                                        .background(Capsule().fill(Color.white.opacity(0.08)))
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.top, 2)
                            }
                        }
                    }
                }
                .padding(12)
            }
        }
        .frame(width: 340)
        .frame(maxHeight: .infinity)
        .background(
            ZStack {
                Color.black.opacity(0.76)
                VisualEffectView(material: .hudWindow, blendingMode: .withinWindow)
                Rectangle().fill(.ultraThinMaterial)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.32),
                            Color.white.opacity(0.12),
                            Color.white.opacity(0.06),
                            Color.white.opacity(0.18)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.8
                )
        )
        .shadow(color: Color.black.opacity(0.45), radius: 24, x: -6, y: 4)
    }

    private func inspectorCard<Content: View>(
        title: String,
        icon: String,
        tag: String? = nil,
        tagColor: Color = .cyan,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.cyan)

                Text(title)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundColor(.white.opacity(0.85))

                Spacer()

                if let tag = tag {
                    Text(tag)
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(tagColor)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(tagColor.opacity(0.15)))
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                content()
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.white.opacity(0.04)))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
            )
        }
    }

    private func inspectorRow(label: String, value: String, highlight: Color? = nil) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.system(size: 10.5))
                .foregroundColor(.white.opacity(0.45))
            Spacer()
            Text(value)
                .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                .monospacedDigit()
                .foregroundColor(highlight ?? .white.opacity(0.88))
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
        }
        .padding(.vertical, 1)
    }

    private func copyMediaInfo() {
        let text = SilkMediaFormatHelper.formattedMediaInfo(for: player)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        withAnimation(.easeInOut(duration: 0.2)) {
            isCopied = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeInOut(duration: 0.2)) {
                isCopied = false
            }
        }
    }
}

/// Mini 3-bar animated audio equalizer waveform for active playback in drawer.
private struct DrawerEqualizerWaveform: View {
    let isPlaying: Bool
    @State private var animating: Bool = false

    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            bar(minHeight: 4, maxHeight: 11, duration: 0.55)
            bar(minHeight: 8, maxHeight: 15, duration: 0.40)
            bar(minHeight: 5, maxHeight: 12, duration: 0.50)
        }
        .frame(width: 14, height: 16)
        .onAppear {
            if isPlaying { animating = true }
        }
        .onChange(of: isPlaying) { _, playing in
            animating = playing
        }
    }

    private func bar(minHeight: CGFloat, maxHeight: CGFloat, duration: Double) -> some View {
        RoundedRectangle(cornerRadius: 1, style: .continuous)
            .fill(Color.cyan)
            .frame(width: 2.2, height: (isPlaying && animating) ? maxHeight : minHeight)
            .animation(
                isPlaying ? .easeInOut(duration: duration).repeatForever(autoreverses: true) : .easeOut(duration: 0.2),
                value: animating
            )
    }
}

/// Standalone row view for each item in the playlist drawer to optimize SwiftUI type-checking.
private struct PlaylistItemRowView: View {
    let index: Int
    let item: PlaylistItem
    let isCurrent: Bool
    let isPlaying: Bool
    let isHovered: Bool
    let onSelect: () -> Void
    let onReveal: () -> Void
    let onDelete: () -> Void
    let onHoverChange: (Bool) -> Void

    var body: some View {
        ZStack(alignment: .trailing) {
            // Full-width clickable card button covering 100% of the row area
            Button(action: onSelect) {
                HStack(spacing: 8) {
                    leadingIndicator
                    titleAndMeta
                    Spacer(minLength: 0)
                }
                .padding(.leading, 8)
                .padding(.trailing, isHovered ? 52 : 8)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .focusable(false)
            .focusEffectDisabled()

            // Trailing hover quick actions (Show in Finder & Delete)
            if isHovered {
                hoverActions
                    .padding(.trailing, 8)
            }
        }
        .background(rowBackground)
        .overlay(rowOverlay)
        .contentShape(Rectangle())
        .onHover { onHoverChange($0) }
    }

    private var leadingIndicator: some View {
        ZStack {
            if isCurrent {
                if isPlaying {
                    DrawerEqualizerWaveform(isPlaying: true)
                } else {
                    Image(systemName: "pause.fill")
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundColor(.cyan)
                }
            } else {
                Text(String(format: "%02d", index + 1))
                    .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                    .monospacedDigit()
                    .foregroundColor(.white.opacity(0.38))
            }
        }
        .frame(width: 20, alignment: .center)
    }

    private var titleAndMeta: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(item.title)
                .font(.system(size: 11.5, weight: isCurrent ? .semibold : .regular))
                .foregroundColor(isCurrent ? .cyan : .white.opacity(0.90))
                .lineLimit(1)
                .truncationMode(.middle)

            if item.duration > 0 {
                Text(formatPlaybackTime(item.duration))
                    .font(.system(size: 9.5, design: .monospaced))
                    .foregroundColor(.white.opacity(0.40))
            }
        }
    }

    private var hoverActions: some View {
        HStack(spacing: 3) {
            Button(action: onReveal) {
                Image(systemName: "folder")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.70))
                    .frame(width: 20, height: 20)
                    .background(Circle().fill(Color.white.opacity(0.12)))
            }
            .buttonStyle(.plain)
            .help(L10n.showInFinder)

            Button(action: onDelete) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.white.opacity(0.70))
                    .frame(width: 20, height: 20)
                    .background(Circle().fill(Color.white.opacity(0.12)))
            }
            .buttonStyle(.plain)
            .help(L10n.tr("Remove from Playlist", "从列表中移除"))
        }
        .transition(.opacity)
    }

    private var rowBackground: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(
                isCurrent
                    ? Color.cyan.opacity(0.16)
                    : (isHovered ? Color.white.opacity(0.07) : Color.white.opacity(0.015))
            )
    }

    private var rowOverlay: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .strokeBorder(
                isCurrent
                    ? Color.cyan.opacity(0.38)
                    : (isHovered ? Color.white.opacity(0.12) : Color.clear),
                lineWidth: 0.75
            )
    }
}

/// Floating Side Triangle Pull Tab Handle for toggling the playlist drawer
@MainActor
public struct PlaylistDrawerHandleTab: View {
    public let isDrawerVisible: Bool
    public let drawerWidth: CGFloat
    public let action: () -> Void

    public init(isDrawerVisible: Bool, drawerWidth: CGFloat, action: @escaping () -> Void) {
        self.isDrawerVisible = isDrawerVisible
        self.drawerWidth = drawerWidth
        self.action = action
    }

    public var body: some View {
        HStack {
            Spacer()
            Button(action: action) {
                ZStack {
                    UnevenRoundedRectangle(
                        topLeadingRadius: 6,
                        bottomLeadingRadius: 6,
                        bottomTrailingRadius: 0,
                        topTrailingRadius: 0
                    )
                    .fill(.ultraThinMaterial)
                    .overlay(
                        UnevenRoundedRectangle(
                            topLeadingRadius: 6,
                            bottomLeadingRadius: 6,
                            bottomTrailingRadius: 0,
                            topTrailingRadius: 0
                        )
                        .fill(Color.black.opacity(0.32))
                    )
                    .overlay(
                        UnevenRoundedRectangle(
                            topLeadingRadius: 6,
                            bottomLeadingRadius: 6,
                            bottomTrailingRadius: 0,
                            topTrailingRadius: 0
                        )
                        .strokeBorder(Color.white.opacity(0.24), lineWidth: 0.6)
                    )
                    .frame(width: 11, height: 58)

                    Image(systemName: "triangle.fill")
                        .font(.system(size: 5, weight: .semibold))
                        .scaleEffect(x: 0.82, y: 1.0)
                        .foregroundColor(.white.opacity(0.92))
                        .rotationEffect(.degrees(isDrawerVisible ? 90 : -90))
                        .offset(x: -0.5)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .focusable(false)
            .focusEffectDisabled()
            .onHover { hovering in
                if hovering {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
            }
            .help(L10n.tr("Expand Playlist (P)", "展开播放列表 (P)"))
            .opacity(isDrawerVisible ? 0.0 : 1.0)
            .allowsHitTesting(!isDrawerVisible)
        }
    }
}

