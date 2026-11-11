import SwiftUI
import AppKit
import QuartzCore
import UniformTypeIdentifiers
import Observation

/// Unified three-tier Music Mode interface rendered inside PlayerContainerView when playing audio.
@MainActor
public struct MusicModeView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var settings = AppSettings.shared
    private var metadataService = AudioTrackMetadataService.shared

    @ObservedObject var player: PlayerCore
    var playlist: PlaylistManager
    public var onPlayNext: () -> Void
    public var onPlayPrevious: () -> Void
    public var onSelectPlaylistItem: (PlaylistItem) -> Void
    public var onClosePlayback: () -> Void

    @State private var browsingCategory: MediaCategory = .audio
    @State private var searchQuery: String = ""
    @State private var isDropTargeted: Bool = false
    @State private var isAddHovered: Bool = false
    @State private var isClearHovered: Bool = false
    @State private var isSortHovered: Bool = false
    @State private var isModeHovered: Bool = false
    @State private var isUpNextHovered: Bool = false
    @State private var isHeroTitleHovered: Bool = false
    @State private var locatePlayingTrigger: Int = 0
    @State private var suppressedAutoScrollID: UUID? = nil
    @State private var suppressedAutoScrollDeadline: Date = .distantPast
    @State private var highlightedTrackID: UUID? = nil
    @State private var locateHighlightTask: Task<Void, Never>? = nil
    @State private var wheelController = MusicWheelController()

    public init(
        player: PlayerCore,
        playlist: PlaylistManager,
        onPlayNext: @escaping () -> Void,
        onPlayPrevious: @escaping () -> Void,
        onSelectPlaylistItem: @escaping (PlaylistItem) -> Void,
        onClosePlayback: @escaping () -> Void
    ) {
        self.player = player
        self.playlist = playlist
        self.onPlayNext = onPlayNext
        self.onPlayPrevious = onPlayPrevious
        self.onSelectPlaylistItem = onSelectPlaylistItem
        self.onClosePlayback = onClosePlayback
    }

    private var effectiveBrowsingCategory: MediaCategory {
        settings.dualPlaylistMode ? browsingCategory : playlist.activeCategory
    }

    private var sourceQueueItems: [PlaylistItem] {
        if !settings.dualPlaylistMode {
            return playlist.unifiedItems
        }
        return effectiveBrowsingCategory == .video ? playlist.videoItems : playlist.audioItems
    }

    private var activePlayingAudioItem: PlaylistItem? {
        if let path = player.currentFilePath {
            if playlist.audioCurrentIndex >= 0,
               playlist.audioCurrentIndex < playlist.audioItems.count {
                let indexed = playlist.audioItems[playlist.audioCurrentIndex]
                if indexed.path == path {
                    return indexed
                }
            }
            if let match = playlist.audioItems.first(where: { $0.path == path }) {
                return match
            }
            if let match = playlist.items.first(where: { $0.path == path }) {
                return match
            }
            return PlaylistItem(path: path, title: player.mediaTitle, duration: player.duration)
        }
        return playlist.currentItem
    }

    private var activePlayingAudioIndex: Int? {
        if let path = player.currentFilePath {
            if playlist.audioCurrentIndex >= 0,
               playlist.audioCurrentIndex < playlist.audioItems.count,
               playlist.audioItems[playlist.audioCurrentIndex].path == path {
                return playlist.audioCurrentIndex
            }
            if let idx = playlist.audioItems.firstIndex(where: { $0.path == path }) {
                return idx
            }
        }
        if playlist.activeCategory == .audio, playlist.audioCurrentIndex >= 0, playlist.audioCurrentIndex < playlist.audioItems.count {
            return playlist.audioCurrentIndex
        }
        return nil
    }

    private var filteredEntries: [(index: Int, item: PlaylistItem, metadata: AudioTrackMetadata)] {
        let trimmed = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if trimmed.isEmpty {
            return sourceQueueItems.enumerated().map { idx, item in
                (index: idx, item: item, metadata: metadataService.metadata(for: item))
            }
        }
        return sourceQueueItems.enumerated().compactMap { idx, item in
            let meta = metadataService.metadata(for: item)
            if item.title.localizedStandardContains(trimmed) ||
               meta.title.localizedStandardContains(trimmed) ||
               meta.artist.localizedStandardContains(trimmed) ||
               meta.album.localizedStandardContains(trimmed) ||
               meta.formatLabel.localizedStandardContains(trimmed) {
                return (index: idx, item: item, metadata: meta)
            }
            return nil
        }
    }

    public var body: some View {
        GeometryReader { geometry in
            let windowWidth = geometry.size.width
            let sidePadding = MusicModeGeometry.contentHorizontalPadding
            let isCollapsed = settings.isMusicQueueCollapsed

            ZStack {
                // Background Smoked Glass Canvas
                musicBackgroundLayer

                VStack(spacing: 0) {
                    // Top Chrome Titlebar
                    topChromeBar(windowWidth: windowWidth)
                        .padding(.horizontal, sidePadding)
                        .padding(.top, isCollapsed ? 8 : 10)
                        .padding(.bottom, isCollapsed ? 8 : 10)

                    // Tier 1: Compact Hero Card
                    heroCard(windowWidth: windowWidth, isDropHighlighted: isCollapsed && isDropTargeted)
                        .padding(.horizontal, sidePadding)

                    // Centered Collapse/Expand Triangle Toggle
                    QueueCollapseToggleStrip(isCollapsed: isCollapsed) {
                        player.toggleMusicQueueCollapsed()
                    }
                    .padding(.horizontal, sidePadding)
                    .padding(.top, 3)
                    .padding(.bottom, isCollapsed ? 3 : 5)

                    // Tier 2: Single-Row Toolbar + Headerless Queue
                    if !isCollapsed {
                        queueSectionCard(windowWidth: windowWidth)
                            .padding(.horizontal, sidePadding)
                            .frame(maxHeight: .infinity)
                            .padding(.bottom, 10)
                            .transition(.opacity)
                    } else {
                        Spacer(minLength: 0)
                    }

                    // Tier 3: Unified Bottom Playback HUD
                    bottomControlSection(windowWidth: windowWidth)
                        .padding(.horizontal, sidePadding)
                        .padding(.bottom, isCollapsed ? 12 : 14)
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
                    handleDrop(providers: providers)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            browsingCategory = .audio
            metadataService.ensureLoaded(for: playlist.audioItems, priorityPath: player.currentFilePath)
            installMusicScrollWheelMonitor()
        }
        .onDisappear {
            removeMusicScrollWheelMonitor()
            locateHighlightTask?.cancel()
            locateHighlightTask = nil
            wheelController.cancelRevealTimer()
        }
        .onChange(of: playlist.audioItems) { _, items in
            metadataService.ensureLoaded(for: items, priorityPath: player.currentFilePath)
        }
        .onChange(of: player.volume) { _, _ in
            wheelController.revealVolumePercentage()
        }
        .onChange(of: player.isMuted) { _, _ in
            wheelController.revealVolumePercentage()
        }
        .onChange(of: player.currentFilePath) { _, newPath in
            if let newPath = newPath {
                if let match = playlist.audioItems.first(where: { $0.path == newPath }) {
                    metadataService.ensureLoaded(for: [match], priorityPath: newPath)
                } else {
                    metadataService.ensureLoaded(
                        for: [PlaylistItem(path: newPath, title: player.mediaTitle, duration: player.duration)],
                        priorityPath: newPath
                    )
                }
            }
        }
    }

    // MARK: - Background Canvas

    private var musicBackgroundLayer: some View {
        ZStack {
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                .edgesIgnoringSafeArea(.all)

            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.08, blue: 0.10).opacity(0.92),
                    Color(red: 0.05, green: 0.05, blue: 0.07).opacity(0.96)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .edgesIgnoringSafeArea(.all)

            if let artwork = player.artworkImage {
                GeometryReader { geo in
                    Image(nsImage: artwork)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .blur(radius: 75)
                        .saturation(1.25)
                        .opacity(0.22)
                        .clipped()
                }
                .edgesIgnoringSafeArea(.all)
            } else {
                RadialGradient(
                    colors: [
                        Color(red: 0.25, green: 0.20, blue: 0.12).opacity(0.16),
                        Color.clear
                    ],
                    center: .top,
                    startRadius: 20,
                    endRadius: 420
                )
                .edgesIgnoringSafeArea(.all)
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: - Top Titlebar

    private func topChromeBar(windowWidth: CGFloat) -> some View {
        ZStack {
            MusicWindowDragStrip()
                .frame(maxWidth: .infinity)
                .frame(height: 36)

            HStack(spacing: 8) {
                // Reserve space for native macOS traffic lights (Close / Minimize / Disabled Zoom)
                Spacer()
                    .frame(width: 58)
                    .allowsHitTesting(false)

                Spacer(minLength: 4)

                // Trailing quick actions: Pin, Inspector, Close
                HStack(spacing: 8) {
                    HUDCircleButton(
                        icon: settings.keepWindowOnTop ? "pin.fill" : "pin",
                        isActive: settings.keepWindowOnTop,
                        helpText: settings.keepWindowOnTop
                            ? L10n.tr("Unpin Window", "取消窗口置顶")
                            : L10n.tr("Keep Window on Top", "保持窗口置顶")
                    ) {
                        PlayerWindowManager.shared.toggleAlwaysOnTop()
                        let next = PlayerWindowManager.shared.isAlwaysOnTop
                        player.showOSD(.pictureAdjustment(
                            name: L10n.tr("Always on Top", "窗口置顶"),
                            value: next ? L10n.tr("On", "开启") : L10n.tr("Off", "关闭")
                        ))
                    }

                    HUDCircleButton(
                        icon: player.isInspectorVisible ? "info.circle.fill" : "info.circle",
                        isActive: player.isInspectorVisible,
                        helpText: L10n.tr("Media Properties (I)", "媒体属性 (I)")
                    ) {
                        player.toggleInspector()
                    }

                    HUDCircleButton(
                        icon: "xmark",
                        isActive: false,
                        helpText: L10n.tr("Close Playback / Return Home (Esc / Cmd+W)", "退出播放 / 返回主页 (Esc / Cmd+W)"),
                        tooltipHorizontalAlignment: .trailing
                    ) {
                        player.isPlaylistDrawerVisible = false
                        player.isInspectorVisible = false
                        onClosePlayback()
                    }
                }
            }

            // Centered Dual-Track Switcher Pill
            if settings.dualPlaylistMode {
                HStack(spacing: 2) {
                    titlebarCategoryTab(category: .video, count: playlist.videoCount)
                    titlebarCategoryTab(category: .audio, count: playlist.audioCount)
                }
                .padding(3)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.08))
                )
                .overlay(
                    Capsule()
                        .strokeBorder(Color.white.opacity(0.14), lineWidth: 0.6)
                )
                .frame(maxWidth: max(180, windowWidth - 230))
            } else {
                Text("\(L10n.tr("Queue", "播放列表")) · \(playlist.audioCount)")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundColor(.white.opacity(0.85))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color.white.opacity(0.08)))
                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.14), lineWidth: 0.6))
                    .allowsHitTesting(false)
            }
        }
        .frame(height: 36)
    }

    private func titlebarCategoryTab(category: MediaCategory, count: Int) -> some View {
        let isSelected = browsingCategory == category
        return Button {
            if settings.isMusicQueueCollapsed {
                player.setMusicQueueCollapsed(false, animated: true)
            }
            withAnimation(SilkAnimation.adaptive(reduceMotion: reduceMotion, preferred: .silkSnappy)) {
                browsingCategory = category
                searchQuery = ""
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: category.iconName)
                    .font(.system(size: 10.5, weight: isSelected ? .semibold : .regular))
                Text(category.title)
                    .font(.system(size: 11.5, weight: isSelected ? .semibold : .medium))
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                        .monospacedDigit()
                        .foregroundColor(isSelected ? .cyan : .white.opacity(0.45))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(
                            Capsule()
                                .fill(isSelected ? Color.cyan.opacity(0.18) : Color.white.opacity(0.08))
                        )
                }
            }
            .foregroundColor(isSelected ? .white : .white.opacity(0.62))
            .padding(.horizontal, 10)
            .padding(.vertical, 4.5)
            .background(
                Capsule()
                    .fill(isSelected ? Color.white.opacity(0.14) : Color.clear)
            )
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .focusable(false)
        .focusEffectDisabled()
    }

    // MARK: - Tier 1: Hero Card

    private func heroCard(windowWidth: CGFloat, isDropHighlighted: Bool = false) -> some View {
        let artSize = MusicModeGeometry.heroArtworkSize(forWindowWidth: windowWidth)
        let currentItem = activePlayingAudioItem
        let meta = currentItem.map { metadataService.metadata(for: $0) }
        let titleText: String = {
            if let m = meta, !m.title.isEmpty { return m.title }
            let repaired = AudioTrackMetadataService.repairMojibakeIfNeeded(player.mediaTitle)
            let sanitized = MediaFilenameSanitizer.sanitize(repaired).cleanTitle
            return sanitized.isEmpty ? L10n.tr("Unknown Track", "未知曲目") : sanitized
        }()
        let subtitleText: String = {
            guard let m = meta else { return "" }
            let a = m.artist.trimmingCharacters(in: .whitespacesAndNewlines)
            let al = m.album.trimmingCharacters(in: .whitespacesAndNewlines)
            if !a.isEmpty && !al.isEmpty {
                return "\(a) · \(al)"
            } else if !a.isEmpty {
                return a
            } else if !al.isEmpty {
                return al
            }
            return L10n.tr("Local Audio", "本地音频")
        }()
        let specText: String = {
            let text = meta?.heroSpecText ?? ""
            if !text.isEmpty { return text }
            if let codec = player.audioTracks.first(where: { $0.id == player.selectedAudioTrackId })?.codec, !codec.isEmpty {
                return codec.uppercased()
            }
            return "AUDIO"
        }()
        let isLossless = ["FLAC", "ALAC", "WAV", "AIFF", "DSD", "APE", "PCM"].contains(meta?.formatLabel.uppercased() ?? "")
        let indexLabel: String = {
            let total = playlist.audioCount
            if let idx = activePlayingAudioIndex, total > 0 {
                return "\(idx + 1) / \(total)"
            }
            return total > 0 ? "— / \(total)" : "0 / 0"
        }()

        return HStack(alignment: .center, spacing: 14) {
            // Leading Vinyl / Album Artwork
            Group {
                if let artwork = player.artworkImage {
                    ZStack {
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .fill(Color.black.opacity(0.35))
                        Image(nsImage: artwork)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: artSize, height: artSize)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .frame(width: artSize, height: artSize)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.20), lineWidth: 0.7)
                    )
                    .shadow(color: Color.black.opacity(0.38), radius: 8, x: 0, y: 3)
                } else {
                    FloatingVinylDiscView(
                        diameter: artSize * 0.82,
                        isPlaying: player.isPlaying,
                        rhythm: player.audioRhythm
                    )
                    .frame(width: artSize, height: artSize)
                }
            }

            // Middle: Clickable Now Playing Title + Artist/Album -> locates active song in queue
            Button(action: locatePlayingTrack) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(player.isPlaying ? Color.cyan : Color.white.opacity(0.35))
                            .frame(width: 6, height: 6)
                        Text(player.isPlaying ? L10n.tr("NOW PLAYING", "正在播放") : L10n.tr("PAUSED", "已暂停"))
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(player.isPlaying ? .cyan.opacity(0.92) : .white.opacity(0.55))
                            .tracking(0.6)
                        if isHeroTitleHovered && activePlayingAudioItem != nil {
                            Image(systemName: "scope")
                                .font(.system(size: 9.5, weight: .semibold))
                                .foregroundColor(.cyan.opacity(0.88))
                                .transition(.opacity)
                        }
                    }

                    Text(titleText)
                        .font(.system(size: 15.5, weight: .semibold, design: .rounded))
                        .foregroundColor(isHeroTitleHovered && activePlayingAudioItem != nil ? .cyan : .white)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    Text(subtitleText)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.62))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .padding(.vertical, 2)
                .padding(.horizontal, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isHeroTitleHovered && activePlayingAudioItem != nil ? Color.white.opacity(0.06) : Color.clear)
                )
                .contentShape(Rectangle())
                .overlay(
                    MusicPointingHandOverlay(enabled: activePlayingAudioItem != nil)
                )
            }
            .buttonStyle(.plain)
            .focusable(false)
            .focusEffectDisabled()
            .onHover { hovering in
                withAnimation(.easeOut(duration: 0.14)) {
                    isHeroTitleHovered = hovering
                }
            }
            .help(L10n.tr("Locate playing song in playlist", "点击在播放列表中定位当前歌曲"))
            .frame(minWidth: 110, maxWidth: .infinity, alignment: .leading)

            // Trailing: Centered Audio Spec Pill + Symmetrical Spectrum Bars & Counter
            VStack(alignment: .center, spacing: 11) {
                Text(specText)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(
                        isLossless
                            ? Color(red: 0.98, green: 0.80, blue: 0.45)
                            : .cyan.opacity(0.92)
                    )
                    .lineLimit(1)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3.5)
                    .background(
                        Capsule()
                            .fill(
                                isLossless
                                    ? Color(red: 0.98, green: 0.78, blue: 0.35).opacity(0.14)
                                    : Color.cyan.opacity(0.12)
                            )
                    )
                    .overlay(
                        Capsule()
                            .strokeBorder(
                                isLossless
                                    ? Color(red: 0.98, green: 0.78, blue: 0.35).opacity(0.32)
                                    : Color.cyan.opacity(0.28),
                                lineWidth: 0.6
                            )
                    )
                    .fixedSize(horizontal: true, vertical: false)

                Button(action: locatePlayingTrack) {
                    HStack(spacing: 8) {
                        MusicSpectrumMiniMeter(
                            rhythm: player.audioRhythm,
                            isPlaying: player.isPlaying
                        )
                        Text(indexLabel)
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .monospacedDigit()
                            .foregroundColor(.white.opacity(0.68))
                            .fixedSize(horizontal: true, vertical: false)
                    }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .contentShape(Rectangle())
                    .overlay(
                        MusicPointingHandOverlay(enabled: activePlayingAudioItem != nil)
                    )
                }
                .buttonStyle(.plain)
                .focusable(false)
                .focusEffectDisabled()
                .help(L10n.tr("Locate playing song in playlist", "点击在播放列表中定位当前歌曲"))
            }
            .padding(.top, 2)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.055))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(
                    isDropHighlighted ? Color.cyan.opacity(0.65) : Color.white.opacity(0.11),
                    lineWidth: isDropHighlighted ? 1.5 : 0.75
                )
        )
    }

    // MARK: - Tier 2: Single-Row Toolbar & Headerless Queue

    private func queueSectionCard(windowWidth: CGFloat) -> some View {
        let entries = filteredEntries
        let showExtendedColumns = MusicModeGeometry.showsExtendedQueueColumns(width: windowWidth)
        let activePlayingID = activePlayingAudioItem?.id

        return VStack(spacing: 0) {
            // Single-row Toolbar: + Add, Clear, Search, Custom Sort
            HStack(spacing: 7) {
                Button(action: addMediaViaPicker) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 10.5, weight: .bold))
                        Text(L10n.tr("Add", "添加"))
                            .font(.system(size: 11, weight: .semibold))
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                    .foregroundColor(.white.opacity(0.92))
                    .padding(.horizontal, 10)
                    .frame(height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.white.opacity(isAddHovered ? 0.16 : 0.10))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.14), lineWidth: 0.6)
                    )
                }
                .buttonStyle(.plain)
                .focusable(false)
                .focusEffectDisabled()
                .onHover { isAddHovered = $0 }
                .help(L10n.tr("Add Music, Videos, or Folders", "添加音乐、视频或文件夹"))

                Button {
                    withAnimation(SilkAnimation.adaptive(reduceMotion: reduceMotion, preferred: .silkSnappy)) {
                        if settings.dualPlaylistMode {
                            playlist.clearCategory(browsingCategory)
                        } else {
                            playlist.clear()
                        }
                    }
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(
                            sourceQueueItems.isEmpty
                                ? .white.opacity(0.25)
                                : (isClearHovered ? Color(nsColor: .systemRed) : .white.opacity(0.68))
                        )
                        .frame(width: 28, height: 28)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(isClearHovered && !sourceQueueItems.isEmpty ? Color.red.opacity(0.14) : Color.white.opacity(0.06))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.10), lineWidth: 0.6)
                        )
                }
                .buttonStyle(.plain)
                .disabled(sourceQueueItems.isEmpty)
                .focusable(false)
                .focusEffectDisabled()
                .onHover { isClearHovered = $0 }
                .help(L10n.tr("Clear Current Queue", "清空当前列表"))

                // Search Capsule
                HStack(spacing: 5) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.42))

                    TextField(
                        L10n.tr("Search songs / artists...", "搜索歌曲 / 歌手..."),
                        text: $searchQuery
                    )
                    .textFieldStyle(.plain)
                    .font(.system(size: 11.5))
                    .foregroundColor(.white.opacity(0.92))

                    if !searchQuery.isEmpty {
                        Button {
                            searchQuery = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.45))
                        }
                        .buttonStyle(.plain)
                        .focusable(false)
                    }
                }
                .padding(.horizontal, 9)
                .frame(height: 28)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.black.opacity(0.24))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.10), lineWidth: 0.6)
                )

                // Custom Sort Menu (enabled when viewing Audio queue)
                if effectiveBrowsingCategory == .audio {
                    sortMenuButton
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)

            Divider()
                .opacity(0.14)

            // Queue List (Headerless)
            if entries.isEmpty {
                emptyQueuePlaceholder(isFilteredEmpty: !searchQuery.isEmpty && !sourceQueueItems.isEmpty)
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: true) {
                        LazyVStack(spacing: 1.5) {
                            ForEach(entries, id: \.item.id) { entry in
                                let isCurrent = (entry.item.id == activePlayingID)
                                MusicQueueRowView(
                                    displayIndex: entry.index + 1,
                                    item: entry.item,
                                    metadata: entry.metadata,
                                    category: effectiveBrowsingCategory,
                                    isCurrent: isCurrent,
                                    isPlaying: isCurrent && player.isPlaying,
                                    isPulseHighlighted: highlightedTrackID == entry.item.id,
                                    showExtendedColumns: showExtendedColumns,
                                    windowWidth: windowWidth,
                                    onSelect: {
                                        handleSelectQueueItem(entry.item, in: effectiveBrowsingCategory)
                                    },
                                    onRemove: {
                                        withAnimation(SilkAnimation.adaptive(reduceMotion: reduceMotion, preferred: .silkSnappy)) {
                                            if settings.dualPlaylistMode {
                                                playlist.removeItem(id: entry.item.id, inCategory: effectiveBrowsingCategory)
                                            } else {
                                                playlist.removeItem(id: entry.item.id)
                                            }
                                        }
                                    }
                                )
                                .equatable()
                                .id(entry.item.id)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4.5)
                    }
                    .onAppear {
                        if let active = activePlayingAudioItem {
                            Task { @MainActor in
                                await Task.yield()
                                proxy.scrollTo(active.id, anchor: .center)
                            }
                        }
                    }
                    .onChange(of: player.currentFilePath) { _, _ in
                        if let active = activePlayingAudioItem, searchQuery.isEmpty, effectiveBrowsingCategory == .audio {
                            if Self.shouldSuppressAutoScroll(
                                suppressedID: suppressedAutoScrollID,
                                deadline: suppressedAutoScrollDeadline,
                                selectedID: playlist.currentItem?.id
                            ) {
                                return
                            }
                            suppressedAutoScrollID = nil
                            withAnimation(.easeInOut(duration: 0.25)) {
                                proxy.scrollTo(active.id, anchor: .center)
                            }
                        }
                    }
                    .onChange(of: playlist.audioCurrentIndex) { _, _ in
                        if let active = activePlayingAudioItem, searchQuery.isEmpty, effectiveBrowsingCategory == .audio {
                            if Self.shouldSuppressAutoScroll(
                                suppressedID: suppressedAutoScrollID,
                                deadline: suppressedAutoScrollDeadline,
                                selectedID: playlist.currentItem?.id
                            ) {
                                return
                            }
                            suppressedAutoScrollID = nil
                            withAnimation(.easeInOut(duration: 0.25)) {
                                proxy.scrollTo(active.id, anchor: .center)
                            }
                        }
                    }
                    .onChange(of: locatePlayingTrigger) { _, _ in
                        guard let active = activePlayingAudioItem else { return }
                        Task { @MainActor in
                            await Task.yield()
                            withAnimation(.easeInOut(duration: 0.28)) {
                                proxy.scrollTo(active.id, anchor: .center)
                            }
                            try? await Task.sleep(nanoseconds: 35_000_000)
                            withAnimation(.easeInOut(duration: 0.20)) {
                                proxy.scrollTo(active.id, anchor: .center)
                            }
                        }
                    }
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(
                    isDropTargeted ? Color.cyan.opacity(0.65) : Color.white.opacity(0.10),
                    lineWidth: isDropTargeted ? 1.5 : 0.75
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var sortMenuButton: some View {
        let activeOrder = playlist.audioSortOrder
        let directionArrow = playlist.audioSortDirection == .ascending ? "↑" : "↓"
        let buttonTitle: String = activeOrder == .manual
            ? activeOrder.title
            : "\(activeOrder.title) \(directionArrow)"

        return Menu {
            ForEach(PlaylistSortOrder.allCases, id: \.self) { order in
                Button {
                    if order == .manual {
                        playlist.sortAudioItems(by: .manual, metadataProvider: { metadataService.metadata(for: $0) })
                    } else if playlist.audioSortOrder == order {
                        let nextDir = playlist.audioSortDirection.toggled
                        playlist.sortAudioItems(by: order, direction: nextDir, metadataProvider: { metadataService.metadata(for: $0) })
                    } else {
                        playlist.sortAudioItems(by: order, direction: .ascending, metadataProvider: { metadataService.metadata(for: $0) })
                    }
                } label: {
                    let isSelected = playlist.audioSortOrder == order
                    let prefix = isSelected ? "✓ " : ""
                    let suffix = (isSelected && order != .manual) ? " \(directionArrow)" : ""
                    Text("\(prefix)\(order.title)\(suffix)")
                }
            }

            if playlist.audioSortOrder != .manual {
                Divider()
                Button(L10n.tr("Toggle Ascending / Descending", "切换升序 / 降序")) {
                    playlist.sortAudioItems(
                        by: playlist.audioSortOrder,
                        direction: playlist.audioSortDirection.toggled,
                        metadataProvider: { metadataService.metadata(for: $0) }
                    )
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.system(size: 10, weight: .semibold))
                Text(buttonTitle)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
            }
            .foregroundColor(activeOrder == .manual ? .white.opacity(0.80) : .cyan)
            .padding(.horizontal, 9)
            .frame(height: 28)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(activeOrder == .manual ? Color.white.opacity(isSortHovered ? 0.14 : 0.07) : Color.cyan.opacity(0.14))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(activeOrder == .manual ? Color.white.opacity(0.11) : Color.cyan.opacity(0.32), lineWidth: 0.6)
            )
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .onHover { isSortHovered = $0 }
        .help(L10n.tr("Sort Audio Queue", "排序音乐播放列表"))
    }

    private func emptyQueuePlaceholder(isFilteredEmpty: Bool) -> some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: isFilteredEmpty ? "magnifyingglass" : (effectiveBrowsingCategory == .video ? "film.stack" : "music.note.list"))
                .font(.system(size: 26, weight: .light))
                .foregroundColor(.white.opacity(0.28))

            Text(
                isFilteredEmpty
                    ? L10n.tr("No matching songs", "未找到匹配的曲目")
                    : (effectiveBrowsingCategory == .video
                        ? L10n.tr("No videos in queue", "暂无视频文件")
                        : L10n.tr("Drop music files or folders here", "拖拽音乐文件或文件夹到此处"))
            )
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(.white.opacity(0.45))

            if isFilteredEmpty {
                Button(L10n.tr("Clear Search", "清除搜索")) {
                    searchQuery = ""
                }
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.cyan)
                .padding(.top, 2)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Tier 3: Unified Bottom Playback HUD

    private func bottomControlSection(windowWidth: CGFloat) -> some View {
        let scrubberTier = HUDLayoutTier.determine(width: windowWidth, isFullscreen: false)
        let compact = MusicModeGeometry.usesCompactBottomControls(width: windowWidth)
        let volWidth = MusicModeGeometry.bottomVolumeTrackWidth(forWindowWidth: windowWidth)
        let showVolPercent = MusicModeGeometry.showsVolumePercentage(forWindowWidth: windowWidth)
        let isSingleLoop = playlist.playbackMode == .singleLoop
        let upcomingTrack = isSingleLoop ? activePlayingAudioItem : playlist.upcomingItem

        return VStack(spacing: compact ? 6 : 8) {
            // 1. Subtle Up Next Strip directly above progress bar
            if let upcomingTrack {
                upNextPreviewStrip(
                    item: upcomingTrack,
                    isRepeatOne: isSingleLoop,
                    compact: compact
                )
            }

            // 2. Native Scrubber (also accepts mouse-wheel vertical scroll to adjust volume)
            PlayerProgressSection(player: player, clock: player.clock, playlist: playlist, tier: scrubberTier)
                .contentShape(Rectangle())
                .onHover { wheelController.isHoveringProgressSection = $0 }

            // 3. Centered Transport + Wings
            ZStack(alignment: .center) {
                // Center Group: Prev, Play/Pause, Next
                HStack(spacing: compact ? 12 : 16) {
                    HUDTransportButton(
                        icon: "backward.end.fill",
                        size: compact ? 12.5 : 13.5,
                        weight: .medium,
                        disabled: !playlist.hasPrevious && !player.canRewindToStart,
                        helpText: playlist.hasPrevious
                            ? (playlist.previousItem.map { "\($0.title) (Cmd+Left)" } ?? L10n.previousTrack)
                            : (player.canRewindToStart ? "\(L10n.previousTrack) (0:00)" : L10n.noPreviousTrack)
                    ) {
                        suppressedAutoScrollID = nil
                        onPlayPrevious()
                    }
                    .accessibilityLabel(L10n.previousTrack)

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
                    .hudTooltip("\(player.isPlaying ? L10n.pause : L10n.play) (Space)", edge: .top)
                    .help("\(player.isPlaying ? L10n.pause : L10n.play) (Space)")

                    HUDTransportButton(
                        icon: "forward.end.fill",
                        size: compact ? 12.5 : 13.5,
                        weight: .medium,
                        disabled: !playlist.hasNext,
                        helpText: playlist.hasNext
                            ? (playlist.nextItem.map { "\($0.title) (Cmd+Right)" } ?? L10n.nextTrack)
                            : L10n.noNextTrack
                    ) {
                        suppressedAutoScrollID = nil
                        onPlayNext()
                    }
                    .accessibilityLabel(L10n.nextTrack)
                }

                // Wings
                HStack(alignment: .center, spacing: 0) {
                    // Left Wing: Playback Mode + Speed
                    HStack(spacing: compact ? 6 : 8) {
                        let mode = playlist.playbackMode
                        let isHighlighted = mode != .sequential
                        Button {
                            playlist.togglePlaybackMode()
                            player.showOSD(.pictureAdjustment(
                                name: L10n.tr("Playback Mode", "播放模式"),
                                value: playlist.playbackMode.title
                            ))
                        } label: {
                            Image(systemName: mode.iconName)
                                .font(.system(size: 13.5, weight: .medium))
                                .foregroundColor(isHighlighted ? .cyan : .white.opacity(0.88))
                                .frame(width: 28, height: 28)
                                .background(
                                    Circle()
                                        .fill(Color.white.opacity(isModeHovered ? 0.14 : (isHighlighted ? 0.10 : 0.0)))
                                )
                                .contentShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .onHover { isModeHovered = $0 }
                        .hudTooltip(
                            "\(mode.title) (\(L10n.tr("Click to switch", "点击切换模式")))",
                            edge: .top,
                            horizontalAlignment: .leading
                        )
                        .help(mode.title)

                        HUDSpeedMenuButton(player: player)
                    }

                    Spacer(minLength: 8)

                    // Right Wing: Compact Inline Volume Slider + Settings (NO Fullscreen Button)
                    HStack(spacing: compact ? 6 : 10) {
                        MusicInlineVolumeSlider(
                            player: player,
                            trackWidth: volWidth,
                            showPercentage: showVolPercent,
                            recentVolumeChangeReveal: wheelController.isVolumePercentageRevealed,
                            onHoverChanged: { wheelController.isHoveringVolumeSection = $0 }
                        )

                        HUDTransportButton(
                            icon: "gearshape",
                            size: 14,
                            weight: .medium,
                            color: .white.opacity(0.90),
                            helpText: L10n.tr("Preferences (Cmd+,)", "偏好设置 (Cmd+,)"),
                            tooltipHorizontalAlignment: .trailing
                        ) {
                            PlayerWindowManager.shared.openSettings()
                        }
                        .accessibilityLabel(L10n.settings)
                    }
                }
            }
        }
        .padding(.top, 2)
    }

    @ViewBuilder
    private func upNextPreviewStrip(item: PlaylistItem, isRepeatOne: Bool, compact: Bool) -> some View {
        let meta = metadataService.metadata(for: item)
        let displayTitle: String = {
            if !meta.queueDisplayTitle.isEmpty { return meta.queueDisplayTitle }
            let cleaned = MediaFilenameSanitizer.sanitize(item.title).cleanTitle
            return cleaned.isEmpty ? item.title : cleaned
        }()
        let durationSec = item.duration > 0 ? item.duration : (meta.duration ?? 0)
        let modeLabel = isRepeatOne
            ? L10n.tr("Repeat One", "单曲循环")
            : L10n.tr("Up Next", "下一首")

        Button {
            suppressedAutoScrollID = nil
            if isRepeatOne {
                player.seek(to: 0)
            } else {
                onPlayNext()
            }
        } label: {
            HStack(spacing: 7) {
                HStack(spacing: 3.5) {
                    if isRepeatOne {
                        Image(systemName: "repeat.1")
                            .font(.system(size: 9, weight: .bold))
                    }
                    Text(modeLabel)
                        .font(.system(size: compact ? 9.5 : 10, weight: .bold))
                }
                .foregroundColor(Color(red: 1.0, green: 0.78, blue: 0.35))
                .padding(.horizontal, 6.5)
                .padding(.vertical, 2)
                .background(
                    Capsule()
                        .fill(Color.orange.opacity(0.18))
                )
                .overlay(
                    Capsule()
                        .strokeBorder(Color.orange.opacity(0.36), lineWidth: 0.5)
                )
                .fixedSize(horizontal: true, vertical: false)

                Text(displayTitle)
                    .font(.system(size: compact ? 10.5 : 11, weight: .medium))
                    .foregroundColor(.white.opacity(isUpNextHovered ? 0.96 : 0.84))
                    .lineLimit(1)
                    .truncationMode(.tail)

                if durationSec > 0 {
                    Text(formatPlaybackTime(durationSec))
                        .font(.system(size: 10.5, weight: .regular, design: .monospaced))
                        .monospacedDigit()
                        .foregroundColor(.white.opacity(0.48))
                        .fixedSize(horizontal: true, vertical: false)
                }
            }
            .padding(.leading, 4)
            .padding(.trailing, 10)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(Color.orange.opacity(isUpNextHovered ? 0.12 : 0.05))
            )
            .overlay(
                Capsule()
                    .strokeBorder(Color.orange.opacity(isUpNextHovered ? 0.32 : 0.16), lineWidth: 0.5)
            )
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .onHover { isUpNextHovered = $0 }
        .frame(maxWidth: .infinity, alignment: .center)
        .help(
            isRepeatOne
                ? L10n.tr("Click to restart track", "点击重新播放当前曲目")
                : "\(L10n.tr("Play Next", "立即播放下一首")): \(displayTitle)"
        )
    }

    // MARK: - Actions

    private func locatePlayingTrack() {
        guard let active = activePlayingAudioItem else { return }
        suppressedAutoScrollID = nil
        if settings.isMusicQueueCollapsed {
            player.setMusicQueueCollapsed(false, animated: true)
        }
        if effectiveBrowsingCategory != .audio {
            browsingCategory = .audio
        }
        if !searchQuery.isEmpty {
            searchQuery = ""
        }
        triggerLocatePulse(for: active.id)
        locatePlayingTrigger &+= 1
    }

    private func triggerLocatePulse(for trackID: UUID) {
        locateHighlightTask?.cancel()
        withAnimation(.easeOut(duration: 0.16)) {
            highlightedTrackID = trackID
        }
        locateHighlightTask = Task { @MainActor [trackID] in
            try? await Task.sleep(nanoseconds: 1_050_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.35)) {
                if highlightedTrackID == trackID {
                    highlightedTrackID = nil
                }
            }
        }
    }

    private func installMusicScrollWheelMonitor() {
        wheelController.installMonitor(player: player, settings: settings)
    }

    private func removeMusicScrollWheelMonitor() {
        wheelController.removeMonitor()
    }

    static func shouldSuppressAutoScroll(
        suppressedID: UUID?,
        deadline: Date,
        selectedID: UUID?,
        now: Date = Date()
    ) -> Bool {
        guard let suppressedID, now < deadline else { return false }
        if let selectedID {
            return selectedID == suppressedID
        }
        return true
    }

    private func handleSelectQueueItem(_ item: PlaylistItem, in category: MediaCategory) {
        if category == .audio {
            suppressedAutoScrollID = item.id
            suppressedAutoScrollDeadline = Date().addingTimeInterval(3.5)
        } else {
            suppressedAutoScrollID = nil
        }
        if settings.dualPlaylistMode && playlist.activeCategory != category {
            playlist.switchCategory(category)
        }
        onSelectPlaylistItem(item)
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
            importPaths(paths)
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
            let paths = collectedURLs.map(\.path)
            if !paths.isEmpty {
                importPaths(paths)
            }
        }
        return true
    }

    private func importPaths(_ paths: [String]) {
        DispatchQueue.global(qos: .userInitiated).async {
            let expanded = PlayerWindowManager.expandFilesAndDirectories(paths)
            guard !expanded.isEmpty else { return }

            var newItems: [PlaylistItem] = []
            for p in expanded {
                let title = URL(fileURLWithPath: p).deletingPathExtension().lastPathComponent
                let size = (try? FileManager.default.attributesOfItem(atPath: p)[.size] as? Int64) ?? 0
                let item = MediaItem(path: p, title: title, fileSize: size)
                newItems.append(PlaylistItem(from: item))
            }

            Task { @MainActor in
                let wasEmpty = playlist.isEmpty
                let needsAutoPlay = wasEmpty || !player.isLoaded
                playlist.appendItems(newItems)
                metadataService.ensureLoaded(for: newItems)
                if needsAutoPlay, let target = newItems.first {
                    handleSelectQueueItem(target, in: PlaylistManager.category(for: target.url))
                }
            }
        }
    }
}

// MARK: - Helper Subviews

@MainActor
private struct QueueCollapseToggleStrip: View {
    let isCollapsed: Bool
    let action: () -> Void

    @State private var isHovered: Bool = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Color.clear
                    .frame(maxWidth: .infinity)
                    .frame(height: 18)
                    .contentShape(Rectangle())

                HStack(spacing: 0) {
                    Image(systemName: isCollapsed ? "arrowtriangle.down.fill" : "arrowtriangle.up.fill")
                        .font(.system(size: 8.5, weight: .bold))
                        .foregroundColor(.white.opacity(isHovered ? 0.92 : 0.56))
                }
                .frame(width: 52, height: 16)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(isHovered ? 0.14 : 0.055))
                )
                .overlay(
                    Capsule()
                        .strokeBorder(Color.white.opacity(isHovered ? 0.24 : 0.10), lineWidth: 0.6)
                )
            }
            .overlay(
                MusicPointingHandOverlay(enabled: true)
            )
        }
        .buttonStyle(.plain)
        .focusable(false)
        .focusEffectDisabled()
        .onHover { isHovered = $0 }
        .accessibilityLabel(
            isCollapsed
                ? L10n.tr("Expand Playlist Queue", "展开播放列表")
                : L10n.tr("Collapse Playlist Queue", "收起播放列表")
        )
        .help(
            isCollapsed
                ? L10n.tr("Expand Playlist Queue (Cmd+L)", "展开播放列表 (Cmd+L)")
                : L10n.tr("Collapse Playlist Queue (Cmd+L)", "收起播放列表 (Cmd+L)")
        )
    }
}

@MainActor
private struct MusicQueueRowView: View, @preconcurrency Equatable {
    let displayIndex: Int
    let item: PlaylistItem
    let metadata: AudioTrackMetadata
    let category: MediaCategory
    let isCurrent: Bool
    let isPlaying: Bool
    let isPulseHighlighted: Bool
    let showExtendedColumns: Bool
    let windowWidth: CGFloat
    let onSelect: () -> Void
    let onRemove: () -> Void

    static func == (lhs: MusicQueueRowView, rhs: MusicQueueRowView) -> Bool {
        lhs.displayIndex == rhs.displayIndex &&
        lhs.item == rhs.item &&
        lhs.metadata == rhs.metadata &&
        lhs.category == rhs.category &&
        lhs.isCurrent == rhs.isCurrent &&
        lhs.isPlaying == rhs.isPlaying &&
        lhs.isPulseHighlighted == rhs.isPulseHighlighted &&
        lhs.showExtendedColumns == rhs.showExtendedColumns &&
        lhs.windowWidth == rhs.windowWidth
    }

    @State private var isHovered: Bool = false

    private var rowTitleText: String {
        if category == .video {
            let cleaned = MediaFilenameSanitizer.sanitize(item.title).cleanTitle
            return cleaned.isEmpty ? item.title : cleaned
        }
        let combined = metadata.queueDisplayTitle
        if !combined.isEmpty { return combined }
        let cleaned = MediaFilenameSanitizer.sanitize(item.title).cleanTitle
        return cleaned.isEmpty ? item.title : cleaned
    }

    private var resolvedDuration: Double {
        if item.duration > 0 { return item.duration }
        if let metaDur = metadata.duration, metaDur > 0 { return metaDur }
        return 0
    }

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 8) {
                // Leading Track Index / Playing Bars
                Group {
                    if isCurrent {
                        MusicMiniPlayingBars(isPlaying: isPlaying)
                    } else {
                        Text("\(displayIndex)")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .monospacedDigit()
                            .foregroundColor(isHovered ? .white.opacity(0.75) : .white.opacity(0.40))
                    }
                }
                .frame(width: 26, alignment: .trailing)

                // Song / Video Title
                HStack(spacing: 6) {
                    Text(rowTitleText)
                        .font(.system(size: 12.5, weight: isCurrent ? .semibold : .medium))
                        .foregroundColor(isCurrent ? .cyan : .white.opacity(isHovered ? 0.96 : 0.88))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Extended Columns on Large Screens (>= 680 pt): Left-Aligned Album + Format
                if showExtendedColumns {
                    if category == .audio {
                        Text(metadata.album.isEmpty ? "—" : metadata.album)
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(metadata.album.isEmpty ? .white.opacity(0.22) : .white.opacity(0.48))
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .frame(width: min(156, max(110, windowWidth * 0.21)), alignment: .leading)
                    }

                    Text(metadata.formatLabel)
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.46))
                        .lineLimit(1)
                        .frame(width: 44, alignment: .leading)
                }

                // Trailing Duration (hidden while hover remove button is visible)
                Text(resolvedDuration > 0 ? formatPlaybackTime(resolvedDuration) : "--:--")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .monospacedDigit()
                    .foregroundColor(.white.opacity(0.48))
                    .opacity(isHovered ? 0.0 : 1.0)
                    .frame(width: 44, alignment: .trailing)
            }
            .frame(maxWidth: .infinity, minHeight: 31, alignment: .leading)
            .padding(.horizontal, 8)
            .padding(.vertical, 4.5)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(
                        isPulseHighlighted
                            ? Color.cyan.opacity(0.24)
                            : (isCurrent
                                ? Color.cyan.opacity(0.14)
                                : (isHovered ? Color.white.opacity(0.08) : Color.clear))
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(
                        isPulseHighlighted
                            ? Color.cyan.opacity(0.85)
                            : (isCurrent ? Color.cyan.opacity(0.30) : Color.clear),
                        lineWidth: isPulseHighlighted ? 1.2 : 0.6
                    )
            )
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .overlay(alignment: .trailing) {
            if isHovered {
                Button(action: onRemove) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundColor(.white.opacity(0.65))
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(Color.white.opacity(0.12)))
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .padding(.trailing, 8)
                .help(L10n.tr("Remove from Playlist", "从列表移除"))
            }
        }
        .onHover { isHovered = $0 }
        .contextMenu {
            Button(L10n.play) {
                onSelect()
            }
            if item.path.range(of: "://", options: .literal) == nil {
                Button(L10n.tr("Show in Finder", "在访达中显示")) {
                    NSWorkspace.shared.activateFileViewerSelecting([item.url])
                }
            }
            Divider()
            Button(L10n.tr("Remove from Playlist", "从列表移除"), role: .destructive) {
                onRemove()
            }
        }
    }
}

@MainActor
private struct MusicMiniPlayingBars: View {
    let isPlaying: Bool

    var body: some View {
        MiniPlayingBarsLayerView(isPlaying: isPlaying)
            .frame(width: 12, height: 12)
    }
}

@MainActor
private struct MiniPlayingBarsLayerView: NSViewRepresentable {
    let isPlaying: Bool

    func makeNSView(context: Context) -> MiniPlayingBarsHostView {
        let view = MiniPlayingBarsHostView()
        view.update(isPlaying: isPlaying)
        return view
    }

    func updateNSView(_ nsView: MiniPlayingBarsHostView, context: Context) {
        nsView.update(isPlaying: isPlaying)
    }
}

@MainActor
private final class MiniPlayingBarsHostView: NSView {
    private static let animationKey = "silk.mini.bars.scaleY"
    private let barLayers: [CALayer] = (0..<3).map { _ in CALayer() }
    private var desiredPlaying = false
    private var isAnimating = false

    override var isFlipped: Bool { false }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        let barColor = NSColor(Color.cyan).cgColor
        for bar in barLayers {
            bar.backgroundColor = barColor
            bar.cornerRadius = 1.0
            bar.anchorPoint = CGPoint(x: 0.5, y: 0.0)
            bar.bounds = CGRect(x: 0, y: 0, width: 2.4, height: 11.0)
            bar.transform = CATransform3DMakeScale(1.0, 0.35, 1.0)
            layer?.addSublayer(bar)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let barWidth: CGFloat = 2.4
        let spacing: CGFloat = 2.0
        let totalWidth = barWidth * 3.0 + spacing * 2.0
        let startX = (bounds.width - totalWidth) * 0.5
        for (idx, bar) in barLayers.enumerated() {
            if bar.superlayer !== layer {
                layer?.addSublayer(bar)
            }
            bar.position = CGPoint(
                x: startX + CGFloat(idx) * (barWidth + spacing) + barWidth * 0.5,
                y: 0.5
            )
        }
        CATransaction.commit()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        syncAnimationState(force: true)
    }

    func update(isPlaying: Bool) {
        desiredPlaying = isPlaying
        syncAnimationState(force: false)
    }

    private func syncAnimationState(force: Bool) {
        guard window != nil else {
            if isAnimating {
                for bar in barLayers {
                    bar.removeAnimation(forKey: Self.animationKey)
                }
                isAnimating = false
            }
            return
        }
        guard force || desiredPlaying != isAnimating else { return }

        if desiredPlaying {
            let fromValues: [Double] = [0.32, 0.92, 0.42]
            let toValues: [Double] = [0.95, 0.30, 0.88]
            let durations: [CFTimeInterval] = [0.42, 0.54, 0.46]
            for (idx, bar) in barLayers.enumerated() {
                if bar.animation(forKey: Self.animationKey) == nil {
                    let anim = CABasicAnimation(keyPath: "transform.scale.y")
                    anim.fromValue = fromValues[idx]
                    anim.toValue = toValues[idx]
                    anim.duration = durations[idx]
                    anim.autoreverses = true
                    anim.repeatCount = .infinity
                    anim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                    anim.isRemovedOnCompletion = false
                    bar.add(anim, forKey: Self.animationKey)
                }
            }
            isAnimating = true
        } else {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            for bar in barLayers {
                bar.removeAnimation(forKey: Self.animationKey)
                bar.transform = CATransform3DMakeScale(1.0, 0.35, 1.0)
            }
            CATransaction.commit()
            isAnimating = false
        }
    }
}

@MainActor
private struct MusicSpectrumMiniMeter: View {
    let rhythm: PlayerAudioRhythm
    let isPlaying: Bool

    private static let bandIndices: [Int] = [4, 2, 0, 1, 0, 2, 3, 5]
    private static let archWeights: [CGFloat] = [0.58, 0.78, 0.94, 1.0, 1.0, 0.94, 0.78, 0.58]
    private static let activeGradient = Gradient(colors: [
        Color(red: 0.25, green: 0.92, blue: 1.0),
        Color(red: 0.18, green: 0.58, blue: 1.0)
    ])

    var body: some View {
        let levels = rhythm.levels
        Canvas(opaque: false, rendersAsynchronously: false) { graphics, size in
            let barWidth: CGFloat = 2.6
            let spacing: CGFloat = 3.0
            let totalWidth = barWidth * 8.0 + spacing * 7.0
            let startX = (size.width - totalWidth) * 0.5

            for idx in 0..<8 {
                let bandIdx = Self.bandIndices[idx]
                let weight = Self.archWeights[idx]
                let raw: CGFloat = (isPlaying && bandIdx < levels.count) ? levels[bandIdx] : 0.14
                let normalized = min(1.0, max(0.0, (0.20 + 0.80 * raw) * weight))
                let height = isPlaying
                    ? max(4.5, min(18.5, 4.5 + normalized * 14.0))
                    : max(4.0, 4.0 + weight * 3.5)

                let rect = CGRect(
                    x: startX + CGFloat(idx) * (barWidth + spacing),
                    y: (size.height - height) * 0.5,
                    width: barWidth,
                    height: height
                )
                let path = Path(roundedRect: rect, cornerRadius: barWidth * 0.5)

                if isPlaying {
                    graphics.fill(
                        path,
                        with: .linearGradient(
                            Self.activeGradient,
                            startPoint: CGPoint(x: rect.midX, y: rect.minY),
                            endPoint: CGPoint(x: rect.midX, y: rect.maxY)
                        )
                    )
                } else {
                    graphics.fill(path, with: .color(Color.white.opacity(0.28)))
                }
            }
        }
        .frame(width: 42, height: 19)
    }
}

@MainActor
private struct MusicInlineVolumeSlider: View {
    @ObservedObject var player: PlayerCore
    let trackWidth: CGFloat
    let showPercentage: Bool
    var recentVolumeChangeReveal: Bool = false
    var onHoverChanged: (Bool) -> Void = { _ in }

    @State private var isDragging: Bool = false
    @State private var isHovered: Bool = false

    private var iconName: String {
        if player.isMuted || player.volume <= 0 {
            return "speaker.slash.fill"
        } else if player.volume < 33 {
            return "speaker.wave.1.fill"
        } else if player.volume < 66 {
            return "speaker.wave.2.fill"
        } else {
            return "speaker.wave.3.fill"
        }
    }

    private var shouldRevealPercentage: Bool {
        showPercentage || isHovered || isDragging || recentVolumeChangeReveal
    }

    var body: some View {
        let maxLimit = max(100.0, AppSettings.shared.maxVolumeLimit)
        let currentVol = player.isMuted ? 0.0 : player.volume
        let fraction = CGFloat(max(0.0, min(1.0, currentVol / maxLimit)))

        HStack(spacing: 6) {
            Button(action: { player.toggleMute() }) {
                Image(systemName: iconName)
                    .font(.system(size: 13.5, weight: .medium))
                    .foregroundColor(player.isMuted ? .white.opacity(0.45) : (player.volume > 100 ? .orange : .white.opacity(0.88)))
                    .frame(width: 26, height: 26)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .help("\(player.isMuted ? L10n.unmuteAudio : L10n.muteAudio) (M)")

            GeometryReader { geo in
                let trackH: CGFloat = isDragging ? 5.0 : 4.0
                let knobSize: CGFloat = isDragging ? 11.0 : 9.0
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.20))
                        .frame(height: trackH)

                    Capsule()
                        .fill(player.volume > 100 && !player.isMuted ? Color.orange : Color.cyan)
                        .frame(width: max(0, min(geo.size.width, geo.size.width * fraction)), height: trackH)

                    Circle()
                        .fill(Color.white)
                        .shadow(color: Color.black.opacity(0.35), radius: 2, x: 0, y: 1)
                        .frame(width: knobSize, height: knobSize)
                        .offset(x: max(0, min(geo.size.width - knobSize, geo.size.width * fraction - knobSize / 2.0)))
                }
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            isDragging = true
                            if player.isMuted {
                                player.toggleMute()
                            }
                            let newFrac = max(0.0, min(1.0, value.location.x / max(1.0, geo.size.width)))
                            player.setVolume(Double(newFrac) * maxLimit, maxLimit: maxLimit, showOSD: false)
                        }
                        .onEnded { _ in
                            isDragging = false
                        }
                )
            }
            .frame(width: trackWidth, height: 18)

            if shouldRevealPercentage {
                Text("\(Int(round(currentVol)))%")
                    .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                    .monospacedDigit()
                    .foregroundColor(.white.opacity(0.62))
                    .frame(width: 34, alignment: .trailing)
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
            }
        }
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
            onHoverChanged(hovering)
        }
        .animation(.easeOut(duration: 0.16), value: shouldRevealPercentage)
    }
}

/// Coordinates scoped mouse-wheel volume control over Music Mode bottom playback/volume controls
/// and temporary volume percentage reveal on narrow windows without blocking queue scrolling.
@MainActor
@Observable
private final class MusicWheelController {
    var isHoveringProgressSection: Bool = false
    var isHoveringVolumeSection: Bool = false
    var isVolumePercentageRevealed: Bool = false

    @ObservationIgnored
    private var monitor: Any? = nil
    @ObservationIgnored
    private var revealTask: Task<Void, Never>? = nil

    func revealVolumePercentage() {
        isVolumePercentageRevealed = true
        revealTask?.cancel()
        revealTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 1_400_000_000)
            guard !Task.isCancelled, let self else { return }
            self.isVolumePercentageRevealed = false
        }
    }

    func cancelRevealTimer() {
        revealTask?.cancel()
        revealTask = nil
    }

    func installMonitor(player: PlayerCore, settings: AppSettings) {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self, weak player] event in
            guard let self, let player, player.isAudioOnly else { return event }
            if let settingsWin = PlayerWindowManager.shared.settingsWindow, event.window === settingsWin {
                return event
            }
            if let hostWin = player.hostWindow, let evWin = event.window, evWin !== hostWin {
                return event
            }
            guard self.isHoveringProgressSection || self.isHoveringVolumeSection else {
                return event
            }

            let rawDeltaY = event.hasPreciseScrollingDeltas ? event.scrollingDeltaY : event.deltaY
            // Preserve horizontal trackpad swipes untouched
            guard abs(rawDeltaY) >= abs(event.scrollingDeltaX), abs(rawDeltaY) > 0.001 else {
                return event
            }

            let maxLimit = max(100.0, settings.maxVolumeLimit)
            let step: Double
            if event.hasPreciseScrollingDeltas {
                step = max(-6.0, min(6.0, Double(rawDeltaY) * 0.22))
            } else {
                step = (rawDeltaY > 0 ? 1.0 : -1.0) * 3.0
            }

            if player.isMuted && step > 0 {
                player.toggleMute()
            }
            let baseVol = player.isMuted ? 0.0 : player.volume
            let nextVol = max(0.0, min(maxLimit, baseVol + step))
            player.setVolume(nextVol, maxLimit: maxLimit, showOSD: false)
            self.revealVolumePercentage()
            return nil
        }
    }

    func removeMonitor() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }
}

/// Adds a non-blocking pointing-hand cursor rect without intercepting SwiftUI clicks or hover events.
@MainActor
private struct MusicPointingHandOverlay: NSViewRepresentable {
    let enabled: Bool

    func makeNSView(context: Context) -> MusicPointingHandNSView {
        let view = MusicPointingHandNSView()
        view.isCursorEnabled = enabled
        return view
    }

    func updateNSView(_ nsView: MusicPointingHandNSView, context: Context) {
        if nsView.isCursorEnabled != enabled {
            nsView.isCursorEnabled = enabled
            nsView.window?.invalidateCursorRects(for: nsView)
        }
    }

    final class MusicPointingHandNSView: NSView {
        var isCursorEnabled: Bool = true

        override func hitTest(_ point: NSPoint) -> NSView? {
            nil
        }

        override func resetCursorRects() {
            guard isCursorEnabled else { return }
            addCursorRect(bounds, cursor: .pointingHand)
        }
    }
}

/// Transparent AppKit drag surface behind the top titlebar supporting drag & double-click vertical maximize.
@MainActor
private struct MusicWindowDragStrip: NSViewRepresentable {
    func makeNSView(context: Context) -> MusicDragStripNSView {
        MusicDragStripNSView()
    }

    func updateNSView(_ nsView: MusicDragStripNSView, context: Context) {}

    final class MusicDragStripNSView: NSView {
        override var mouseDownCanMoveWindow: Bool { true }

        override func mouseDown(with event: NSEvent) {
            guard let window = self.window else { return }
            window.performDrag(with: event)
        }
    }
}
