import SwiftUI
import AppKit
import UniformTypeIdentifiers
import SilkCoreKit

/// Dedicated Pure Playlist Sidebar Drawer for SilkPlayer.
/// Focused entirely on playlist duties: drag-and-drop, playback queue management,
/// track switching, and local/SMB file actions.
@MainActor
public struct SilkPlaylistDrawerView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var settings = AppSettings.shared
    @ObservedObject var player: PlayerCore
    var playlist: PlaylistManager
    public var drawerWidth: CGFloat
    public var onSelectPlaylistItem: (PlaylistItem) -> Void
    public var onClose: () -> Void

    @AppStorage(SilkLibraryTheme.userDefaultsKey) private var selectedThemeRaw: String = SilkLibraryTheme.shenghui.rawValue

    private var theme: SilkLibraryTheme {
        SilkLibraryTheme(rawValue: selectedThemeRaw) ?? .shenghui
    }

    private var isLight: Bool {
        theme.isLight
    }

    @State private var hoveredIndex: Int? = nil
    @State private var isFooterClearHovered: Bool = false
    @State private var isDrawerDropTargeted: Bool = false
    @State private var isAwaitingClearConfirm: Bool = false
    @State private var clearConfirmResetTask: Task<Void, Never>? = nil
    @State private var isSearchExpanded: Bool = false
    @State private var searchText: String = ""
    @FocusState private var isSearchFocused: Bool

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
                .opacity(isLight ? 0.35 : 0.18)

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
                if isLight {
                    theme.backgroundBase.opacity(0.96)
                    VisualEffectView(material: .hudWindow, blendingMode: .withinWindow)
                    Rectangle().fill(.ultraThinMaterial)
                } else {
                    Color.black.opacity(0.76)
                    VisualEffectView(material: .hudWindow, blendingMode: .withinWindow)
                    Rectangle().fill(.ultraThinMaterial)
                }
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(
                    isLight
                        ? AnyShapeStyle(theme.borderColor.opacity(0.85))
                        : AnyShapeStyle(LinearGradient(
                            colors: [
                                Color.white.opacity(0.32),
                                Color.white.opacity(0.12),
                                Color.white.opacity(0.06),
                                Color.white.opacity(0.18)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )),
                    lineWidth: 0.8
                )
        )
        .shadow(color: isLight ? Color.black.opacity(0.12) : Color.black.opacity(0.45), radius: 24, x: -6, y: 4)
        .shadow(color: isLight ? Color.black.opacity(0.06) : Color.black.opacity(0.20), radius: 6, x: -2, y: 2)
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            handleDrop(providers: providers)
        }
    }

    // MARK: - Header Bar
    private var headerBar: some View {
        Group {
            if settings.dualPlaylistMode {
                HStack(alignment: .center, spacing: 4) {
                    categoryTab(for: .video, count: playlist.videoCount)
                    categoryTab(for: .audio, count: playlist.audioCount)
                }
            } else {
                HStack(alignment: .center, spacing: 6) {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(isLight ? theme.secondaryText : .white.opacity(0.70))
                    Text(L10n.tr("Playlist", "播放列表"))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(isLight ? theme.primaryText : .white.opacity(0.90))
                    if playlist.count > 0 {
                        Text("\(playlist.count)")
                            .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                            .monospacedDigit()
                            .foregroundColor(isLight ? theme.accentColor : .cyan)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1.5)
                            .background(Capsule().fill(isLight ? theme.accentColor.opacity(0.18) : Color.cyan.opacity(0.18)))
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 28)
            }
        }
        .padding(.horizontal, 10)
        .padding(.top, 10)
        .padding(.bottom, 8)
    }

    private func categoryTab(for category: MediaCategory, count: Int) -> some View {
        let isSelected = playlist.activeCategory == category
        return Button {
            withAnimation(SilkAnimation.adaptive(reduceMotion: reduceMotion, preferred: .silkSnappy)) {
                playlist.switchCategory(category)
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: category.iconName)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                Text(category.title)
                    .font(.system(size: 11.5, weight: isSelected ? .semibold : .medium))
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                        .monospacedDigit()
                        .foregroundColor(isSelected ? (isLight ? theme.accentColor : .cyan) : (isLight ? theme.secondaryText.opacity(0.7) : .white.opacity(0.40)))
                        .padding(.horizontal, 4.5)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(isSelected ? (isLight ? theme.accentColor.opacity(0.18) : Color.cyan.opacity(0.20)) : (isLight ? theme.pillSurface : Color.white.opacity(0.08))))
                }
            }
            .foregroundColor(isSelected ? (isLight ? theme.accentColor : .cyan) : (isLight ? theme.secondaryText : .white.opacity(0.65)))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(isSelected ? (isLight ? theme.pillSurface : Color.white.opacity(0.12)) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusable(false)
    }

    // MARK: - Empty Placeholder
    private var emptyPlaylistPlaceholder: some View {
        VStack(spacing: 10) {
            Spacer(minLength: 8)
            ZStack {
                Circle()
                    .fill(isLight ? theme.pillSurface : Color.white.opacity(0.05))
                    .frame(width: 52, height: 52)
                Image(systemName: settings.dualPlaylistMode ? (playlist.activeCategory == .video ? "film.stack" : "music.note.list") : "list.bullet.rectangle")
                    .font(.system(size: 22))
                    .foregroundColor(isLight ? theme.secondaryText.opacity(0.60) : .white.opacity(0.35))
            }
            Text(settings.dualPlaylistMode ? (playlist.activeCategory == .video ? L10n.tr("Video Playlist Empty", "视频列表为空") : L10n.tr("Music Playlist Empty", "音乐列表为空")) : L10n.tr("Playlist is Empty", "播放列表为空"))
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(isLight ? theme.primaryText : .white.opacity(0.75))
            Text(settings.dualPlaylistMode ? (playlist.activeCategory == .video ? L10n.tr("Drop video files or folders here to add", "拖拽视频文件或文件夹至此处即可添加") : L10n.tr("Drop audio files or folders here to add", "拖拽音频文件或文件夹至此处即可添加")) : L10n.tr("Drop media files or folders here to add", "拖拽媒体文件或文件夹至此处即可添加"))
                .font(.system(size: 11))
                .foregroundColor(isLight ? theme.secondaryText : .white.opacity(0.40))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)

            Spacer(minLength: 8)
        }
        .frame(minHeight: 0)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Filtered Playlist Items & Pinyin Matcher
    private var filteredItems: [(index: Int, item: PlaylistItem)] {
        let enumerated = Array(playlist.items.enumerated().map { ($0.offset, $0.element) })
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard isSearchExpanded, !query.isEmpty else {
            return enumerated
        }
        return enumerated.filter { _, item in
            matchPlaylistItem(item, query: query)
        }
    }

    private func matchPlaylistItem(_ item: PlaylistItem, query: String) -> Bool {
        let titleLower = item.title.lowercased()
        if titleLower.contains(query) { return true }
        let fileNameLower = (item.path as NSString).lastPathComponent.lowercased()
        if fileNameLower.contains(query) { return true }

        let tokens = SilkPinyinMatcher.pinyinTokens(for: item.title)
        if tokens.contains(query) { return true }

        let queryParts = query.split(separator: " ").map(String.init)
        if queryParts.count > 1 {
            let matchesAll = queryParts.allSatisfy { part in
                titleLower.contains(part) || fileNameLower.contains(part) || tokens.contains(part)
            }
            if matchesAll { return true }
        }
        return false
    }

    // MARK: - Playlist Scroll View
    private var playlistScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: true) {
                let itemsToDisplay = filteredItems
                if itemsToDisplay.isEmpty && !searchText.isEmpty {
                    VStack(spacing: 8) {
                        Spacer(minLength: 24)
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 20))
                            .foregroundColor(isLight ? theme.secondaryText.opacity(0.60) : .white.opacity(0.35))
                        Text(L10n.tr("No matching items", "无匹配项目"))
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundColor(isLight ? theme.secondaryText : .white.opacity(0.60))
                        Spacer(minLength: 24)
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    LazyVStack(spacing: 2) {
                        ForEach(itemsToDisplay, id: \.item.id) { index, item in
                            PlaylistItemRowView(
                                index: index,
                                item: item,
                                isCurrent: index == playlist.currentIndex,
                                isPlaying: player.isPlaying,
                                isHovered: hoveredIndex == index,
                                theme: theme,
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
            Divider().opacity(isLight ? 0.30 : 0.15)
            if isSearchExpanded {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundColor(isLight ? theme.secondaryText : .white.opacity(0.60))
                    TextField(L10n.tr("Search playlist or initials...", "搜索片名、拼音简拼…"), text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 11))
                        .foregroundColor(isLight ? theme.primaryText : .white)
                        .focused($isSearchFocused)
                        .onExitCommand {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                if !searchText.isEmpty {
                                    searchText = ""
                                } else {
                                    isSearchExpanded = false
                                    isSearchFocused = false
                                }
                            }
                        }
                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 10.5))
                                .foregroundColor(isLight ? theme.secondaryText : .white.opacity(0.55))
                        }
                        .buttonStyle(.plain)
                    }
                    Button(action: {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            searchText = ""
                            isSearchExpanded = false
                            isSearchFocused = false
                        }
                    }) {
                        Image(systemName: "chevron.right.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(isLight ? theme.secondaryText : .white.opacity(0.65))
                    }
                    .buttonStyle(.plain)
                    .help(L10n.tr("Close search (Esc)", "关闭搜索 (Esc)"))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(RoundedRectangle(cornerRadius: 6).fill(isLight ? theme.pillSurface : Color.white.opacity(0.08)))
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
            } else {
                HStack(spacing: 6) {
                    Button(action: {
                        addMediaViaPicker()
                    }) {
                        HStack(spacing: 3.5) {
                            Image(systemName: "plus")
                                .font(.system(size: 10, weight: .semibold))
                            Text(L10n.tr("Add Media...", "添加媒体…"))
                                .font(.system(size: 10.5, weight: .medium))
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                        }
                        .foregroundColor(isLight ? theme.primaryText : .white.opacity(0.85))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4.5)
                        .background(RoundedRectangle(cornerRadius: 6).fill(isLight ? theme.pillSurface : Color.white.opacity(0.08)))
                    }
                    .buttonStyle(.plain)
                    .focusable(false)
                    .focusEffectDisabled()

                    Spacer(minLength: 4)

                    // PROPOSAL-022: Quick search trigger button with ⌘F
                    Button(action: {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            isSearchExpanded = true
                            isSearchFocused = true
                        }
                    }) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundColor(isLight ? theme.secondaryText : .white.opacity(0.70))
                            .frame(width: 24, height: 24)
                            .background(RoundedRectangle(cornerRadius: 6).fill(isLight ? theme.pillSurface : Color.white.opacity(0.06)))
                    }
                    .buttonStyle(.plain)
                    .focusable(false)
                    .focusEffectDisabled()
                    .keyboardShortcut("f", modifiers: .command)
                    .help(L10n.tr("Search playlist (⌘F)", "搜索播放列表 (⌘F)"))

                    if !playlist.isEmpty {
                        Button(action: {
                            if isAwaitingClearConfirm {
                                clearConfirmResetTask?.cancel()
                                clearConfirmResetTask = nil
                                isAwaitingClearConfirm = false
                                withAnimation(SilkAnimation.adaptive(reduceMotion: reduceMotion, preferred: .silkSnappy)) {
                                    playlist.clear()
                                }
                            } else {
                                isAwaitingClearConfirm = true
                                clearConfirmResetTask?.cancel()
                                clearConfirmResetTask = Task { @MainActor in
                                    try? await Task.sleep(nanoseconds: 3_000_000_000)
                                    guard !Task.isCancelled else { return }
                                    withAnimation(SilkAnimation.adaptive(reduceMotion: reduceMotion, preferred: .silkSnappy)) {
                                        isAwaitingClearConfirm = false
                                    }
                                }
                            }
                        }) {
                            HStack(spacing: 3.5) {
                                Image(systemName: isAwaitingClearConfirm ? "exclamationmark.triangle.fill" : "trash")
                                    .font(.system(size: 9.5))
                                Text(isAwaitingClearConfirm ? L10n.tr("Confirm Clear", "确定清空") : L10n.clearAll)
                                    .font(.system(size: 10.5, weight: .medium))
                                    .lineLimit(1)
                                    .fixedSize(horizontal: true, vertical: false)
                            }
                            .foregroundColor(isAwaitingClearConfirm ? Color(nsColor: .systemRed) : (isFooterClearHovered ? Color(nsColor: .systemRed) : (isLight ? theme.secondaryText : .white.opacity(0.65))))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4.5)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(isAwaitingClearConfirm ? Color.red.opacity(0.24) : (isFooterClearHovered ? Color.red.opacity(0.14) : (isLight ? theme.pillSurface : Color.white.opacity(0.06))))
                            )
                        }
                        .buttonStyle(.plain)
                        .focusable(false)
                        .focusEffectDisabled()
                        .onHover { isFooterClearHovered = $0 }
                        .help(isAwaitingClearConfirm ? L10n.tr("Click again to confirm clearing playlist", "再次点击以确认清空播放列表") : L10n.tr("Clear All (Empty Playlist)", "一键清空播放列表"))
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
            }
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
                if needsAutoPlay {
                    let target = (wasEmpty && playlist.playbackMode == .shuffle)
                        ? (playlist.currentItem ?? newItems.first)
                        : newItems.first
                    if let item = target {
                        onSelectPlaylistItem(item)
                    }
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
            guard !paths.isEmpty else { return }

            Task.detached(priority: .userInitiated) {
                let expanded = PlayerWindowManager.expandFilesAndDirectories(paths)
                guard !expanded.isEmpty else { return }

                var newItems: [PlaylistItem] = []
                for path in expanded {
                    let title = URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
                    let size = (try? FileManager.default.attributesOfItem(atPath: path)[.size] as? Int64) ?? 0
                    let item = MediaItem(path: path, title: title, fileSize: size)
                    newItems.append(PlaylistItem(from: item))
                }

                await MainActor.run {
                    let wasEmpty = self.playlist.isEmpty
                    let needsAutoPlay = wasEmpty || !self.player.isLoaded
                    self.playlist.appendItems(newItems)
                    if needsAutoPlay {
                        let target = (wasEmpty && self.playlist.playbackMode == .shuffle)
                            ? (self.playlist.currentItem ?? newItems.first)
                            : newItems.first
                        if let item = target {
                            self.onSelectPlaylistItem(item)
                        }
                    }
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
    var accentColor: Color = .cyan
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
            .fill(accentColor)
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
    var theme: SilkLibraryTheme = .shenghui
    let onSelect: () -> Void
    let onReveal: () -> Void
    let onDelete: () -> Void
    let onHoverChange: (Bool) -> Void

    private var isLight: Bool {
        theme.isLight
    }

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
                .padding(.trailing, 50)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .focusable(false)
            .focusEffectDisabled()
            .help(rawFileName)

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

    private var rawFileName: String {
        let fn = (item.path as NSString).lastPathComponent
        return fn.isEmpty ? item.title : fn
    }

    private var sanitizedTitle: SanitizedMediaTitle {
        MediaFilenameSanitizer.sanitize(item.title)
    }

    private var leadingIndicator: some View {
        HStack(spacing: 3) {
            if isCurrent {
                if isPlaying {
                    DrawerEqualizerWaveform(isPlaying: true, accentColor: isLight ? theme.accentColor : .cyan)
                } else {
                    Image(systemName: "pause.fill")
                        .font(.system(size: 8.5, weight: .bold))
                        .foregroundColor(isLight ? theme.accentColor : .cyan)
                }
            }

            if let badge = sanitizedTitle.episodeBadge {
                Text(badge)
                    .font(.system(size: 9.5, weight: isCurrent ? .bold : .semibold, design: .monospaced))
                    .monospacedDigit()
                    .foregroundColor(isCurrent ? (isLight ? theme.accentColor : .cyan) : (isLight ? theme.accentColor.opacity(0.92) : .cyan.opacity(0.88)))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            } else if !isCurrent {
                Text(String(format: "%02d", index + 1))
                    .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                    .monospacedDigit()
                    .foregroundColor(isLight ? theme.secondaryText.opacity(0.70) : .white.opacity(0.38))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
        }
        .frame(minWidth: sanitizedTitle.episodeBadge != nil ? (isCurrent ? 58 : 46) : 20, alignment: .leading)
    }

    private var titleAndMeta: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(sanitizedTitle.displayTitle)
                .font(.system(size: 11.5, weight: isCurrent ? .semibold : .regular))
                .foregroundColor(isCurrent ? (isLight ? theme.accentColor : .cyan) : (isLight ? theme.primaryText : .white.opacity(0.90)))
                .lineLimit(1)
                .truncationMode(.tail)

            if item.duration > 0 {
                Text(formatPlaybackTime(item.duration))
                    .font(.system(size: 9.5, design: .monospaced))
                    .foregroundColor(isLight ? theme.secondaryText : .white.opacity(0.40))
            }
        }
    }

    private var hoverActions: some View {
        HStack(spacing: 3) {
            Button(action: onReveal) {
                Image(systemName: "folder")
                    .font(.system(size: 10))
                    .foregroundColor(isLight ? theme.secondaryText : .white.opacity(0.70))
                    .frame(width: 20, height: 20)
                    .background(Circle().fill(isLight ? theme.pillSurface : Color.white.opacity(0.12)))
            }
            .buttonStyle(.plain)
            .help(L10n.showInFinder)

            Button(action: onDelete) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(isLight ? theme.secondaryText : .white.opacity(0.70))
                    .frame(width: 20, height: 20)
                    .background(Circle().fill(isLight ? theme.pillSurface : Color.white.opacity(0.12)))
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
                    ? (isLight ? theme.accentColor.opacity(0.14) : Color.cyan.opacity(0.16))
                    : (isHovered ? (isLight ? theme.pillSurface : Color.white.opacity(0.07)) : (isLight ? Color.clear : Color.white.opacity(0.015)))
            )
    }

    private var rowOverlay: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .strokeBorder(
                isCurrent
                    ? (isLight ? theme.accentColor.opacity(0.45) : Color.cyan.opacity(0.38))
                    : (isHovered ? (isLight ? theme.borderColor.opacity(0.65) : Color.white.opacity(0.12)) : Color.clear),
                lineWidth: 0.75
            )
    }
}

/// Floating Side Triangle Pull Tab Handle for toggling the playlist drawer
@MainActor
/// Three-sided border shape for drawer pull tab: top edge, left rounded edge, bottom edge.
/// Right edge is completely open (0 radius, flush against the window border).
struct DrawerHandleBorderShape: Shape {
    let cornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + cornerRadius, y: rect.minY))
        path.addArc(
            center: CGPoint(x: rect.minX + cornerRadius, y: rect.minY + cornerRadius),
            radius: cornerRadius,
            startAngle: .degrees(-90),
            endAngle: .degrees(180),
            clockwise: true
        )
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - cornerRadius))
        path.addArc(
            center: CGPoint(x: rect.minX + cornerRadius, y: rect.maxY - cornerRadius),
            radius: cornerRadius,
            startAngle: .degrees(180),
            endAngle: .degrees(90),
            clockwise: true
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        return path
    }
}

/// Ultra-slender flattened indicator triangle: exactly 9.5pt height, 2.0pt depth
struct FlattenedIndicatorTriangle: Shape {
    let pointingLeft: Bool

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let h: CGFloat = 9.5
        let w: CGFloat = 2.0
        let cy = rect.midY
        let cx = rect.midX

        if pointingLeft {
            path.move(to: CGPoint(x: cx - w / 2, y: cy))
            path.addLine(to: CGPoint(x: cx + w / 2, y: cy - h / 2))
            path.addLine(to: CGPoint(x: cx + w / 2, y: cy + h / 2))
        } else {
            path.move(to: CGPoint(x: cx + w / 2, y: cy))
            path.addLine(to: CGPoint(x: cx - w / 2, y: cy - h / 2))
            path.addLine(to: CGPoint(x: cx - w / 2, y: cy + h / 2))
        }
        path.closeSubpath()
        return path
    }
}

public struct PlaylistDrawerHandleTab: View {
    public let isDrawerVisible: Bool
    public let drawerWidth: CGFloat
    public var onHoverChange: ((Bool) -> Void)? = nil
    public let action: () -> Void

    @AppStorage(SilkLibraryTheme.userDefaultsKey) private var selectedThemeRaw: String = SilkLibraryTheme.shenghui.rawValue

    private var theme: SilkLibraryTheme {
        SilkLibraryTheme(rawValue: selectedThemeRaw) ?? .shenghui
    }

    public init(
        isDrawerVisible: Bool,
        drawerWidth: CGFloat,
        onHoverChange: ((Bool) -> Void)? = nil,
        action: @escaping () -> Void
    ) {
        self.isDrawerVisible = isDrawerVisible
        self.drawerWidth = drawerWidth
        self.onHoverChange = onHoverChange
        self.action = action
    }

    public var body: some View {
        HStack(spacing: 0) {
            Spacer()
                .allowsHitTesting(false)
            SilkDrawerHandleRepresentable(
                isDrawerVisible: isDrawerVisible,
                customFillColor: theme.isLight ? NSColor(theme.backgroundBase) : nil,
                customStrokeColor: theme.isLight ? NSColor(theme.borderColor) : nil,
                customArrowColor: theme.isLight ? NSColor(theme.accentColor) : nil,
                onHoverChange: onHoverChange,
                action: action
            )
            .frame(width: 28, height: 128)
            .help(L10n.tr("Expand Playlist (P)", "展开播放列表 (P)"))
            .opacity(isDrawerVisible ? 0.0 : 1.0)
            .allowsHitTesting(!isDrawerVisible)
        }
    }
}

public struct SilkDrawerHandleRepresentable: NSViewRepresentable {
    public let isDrawerVisible: Bool
    public var isLeadingEdge: Bool = false
    public var customHandleWidth: CGFloat? = nil
    public var customFillColor: NSColor? = nil
    public var customStrokeColor: NSColor? = nil
    public var customArrowColor: NSColor? = nil
    public var onHoverChange: ((Bool) -> Void)?
    public let action: () -> Void

    public init(
        isDrawerVisible: Bool,
        isLeadingEdge: Bool = false,
        customHandleWidth: CGFloat? = nil,
        customFillColor: NSColor? = nil,
        customStrokeColor: NSColor? = nil,
        customArrowColor: NSColor? = nil,
        onHoverChange: ((Bool) -> Void)? = nil,
        action: @escaping () -> Void
    ) {
        self.isDrawerVisible = isDrawerVisible
        self.isLeadingEdge = isLeadingEdge
        self.customHandleWidth = customHandleWidth
        self.customFillColor = customFillColor
        self.customStrokeColor = customStrokeColor
        self.customArrowColor = customArrowColor
        self.onHoverChange = onHoverChange
        self.action = action
    }

    public func makeNSView(context: Context) -> SilkDrawerHandleNSView {
        let v = SilkDrawerHandleNSView()
        v.isDrawerVisible = isDrawerVisible
        v.isLeadingEdge = isLeadingEdge
        v.customHandleWidth = customHandleWidth
        v.customFillColor = customFillColor
        v.customStrokeColor = customStrokeColor
        v.customArrowColor = customArrowColor
        v.onAction = action
        v.onHoverChange = onHoverChange
        return v
    }

    public func updateNSView(_ nsView: SilkDrawerHandleNSView, context: Context) {
        nsView.isDrawerVisible = isDrawerVisible
        nsView.isLeadingEdge = isLeadingEdge
        nsView.customHandleWidth = customHandleWidth
        nsView.customFillColor = customFillColor
        nsView.customStrokeColor = customStrokeColor
        nsView.customArrowColor = customArrowColor
        nsView.onAction = action
        nsView.onHoverChange = onHoverChange
    }
}

public final class SilkDrawerHandleNSView: NSView {
    public var isDrawerVisible: Bool = false {
        didSet {
            needsDisplay = true
            window?.invalidateCursorRects(for: self)
        }
    }
    public var isLeadingEdge: Bool = false {
        didSet {
            needsDisplay = true
        }
    }
    public var customHandleWidth: CGFloat? {
        didSet { needsDisplay = true }
    }
    public var customFillColor: NSColor? {
        didSet { needsDisplay = true }
    }
    public var customStrokeColor: NSColor? {
        didSet { needsDisplay = true }
    }
    public var customArrowColor: NSColor? {
        didSet { needsDisplay = true }
    }
    public var onAction: (() -> Void)?
    public var onHoverChange: ((Bool) -> Void)?

    private var trackingArea: NSTrackingArea?

    override public init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .cursorUpdate, .mouseMoved, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        self.trackingArea = area
    }

    override public func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.invalidateCursorRects(for: self)
    }

    override public func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        window?.invalidateCursorRects(for: self)
    }

    // Explicit Hit-Test Override:
    // Guarantees this view exclusively captures any click or hover over the handle area,
    // permanently preventing NSThemeFrame from intercepting and starting a window resize.
    override public func hitTest(_ point: NSPoint) -> NSView? {
        guard !isDrawerVisible else { return nil }
        let loc = (superview != nil) ? convert(point, from: superview) : convert(point, from: nil)
        if bounds.contains(loc) {
            return self
        }
        return nil
    }

    // 1. AppKit Native Cursor Rect:
    // Strictly takes priority over NSThemeFrame resize border in AppKit's cursor rect dispatch hierarchy.
    override public func resetCursorRects() {
        super.resetCursorRects()
        if !isDrawerVisible {
            addCursorRect(bounds, cursor: .pointingHand)
        }
    }

    // 2. Cursor Update & Mouse Moved:
    // Absolute enforcement: Whenever the mouse touches even a single pixel of this handle,
    // the cursor is guaranteed to be pointingHand. The horizontal resize arrows can NEVER appear.
    override public func cursorUpdate(with event: NSEvent) {
        if !isDrawerVisible {
            NSCursor.pointingHand.set()
        }
    }

    override public func mouseMoved(with event: NSEvent) {
        if !isDrawerVisible {
            NSCursor.pointingHand.set()
        }
    }

    override public func mouseEntered(with event: NSEvent) {
        if !isDrawerVisible {
            NSCursor.pointingHand.set()
            onHoverChange?(true)
        }
    }

    override public func mouseExited(with event: NSEvent) {
        if !isDrawerVisible {
            NSCursor.arrow.set()
            onHoverChange?(false)
        }
    }

    // 3. Mouse Down & Dragging:
    // 100% consume mouseDown & mouseDragged.
    // NSThemeFrame NEVER receives these events, so window resize dragging is IMPOSSIBLE.
    override public func mouseDown(with event: NSEvent) {
        guard !isDrawerVisible else { return }
        onAction?()
    }

    override public func mouseDragged(with event: NSEvent) {
        // Consumed, prevent window resize
    }

    override public func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }

    // 4. Crisp Native CoreGraphics Drawing:
    // Draw the 1.0pt 3-sided border and 9.5pt flattened indicator triangle with subtle shadow.
    override public func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard !isDrawerVisible else { return }

        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.saveGState()

        let b = bounds
        let handleH: CGFloat = 112.0
        let handleW: CGFloat = customHandleWidth ?? 5.0
        let handleY = (b.height - handleH) * 0.5
        let r: CGFloat = customHandleWidth != nil ? 4.0 : 3.0

        let borderPath = CGMutablePath()
        let triPath = CGMutablePath()
        let triH: CGFloat = 9.5
        let triW: CGFloat = customHandleWidth != nil ? 3.0 : 2.0
        let triY = (b.height - triH) * 0.5

        if isLeadingEdge {
            // 3-sided border path (top, right, bottom, left open)
            borderPath.move(to: CGPoint(x: 0, y: handleY))
            borderPath.addLine(to: CGPoint(x: handleW - r, y: handleY))
            borderPath.addArc(tangent1End: CGPoint(x: handleW, y: handleY), tangent2End: CGPoint(x: handleW, y: handleY + r), radius: r)
            borderPath.addLine(to: CGPoint(x: handleW, y: handleY + handleH - r))
            borderPath.addArc(tangent1End: CGPoint(x: handleW, y: handleY + handleH), tangent2End: CGPoint(x: handleW - r, y: handleY + handleH), radius: r)
            borderPath.addLine(to: CGPoint(x: 0, y: handleY + handleH))

            if customFillColor == nil {
                ctx.setShadow(offset: CGSize(width: 0.5, height: 0), blur: 0.5, color: NSColor.black.withAlphaComponent(0.25).cgColor)
            } else {
                ctx.setShadow(offset: CGSize(width: 0.5, height: 0), blur: 1.5, color: NSColor(calibratedRed: 0.17, green: 0.12, blue: 0.07, alpha: 0.14).cgColor)
            }

            // Flattened indicator triangle pointing right
            let triX: CGFloat = max(1.5, (handleW - triW) * 0.5)
            triPath.move(to: CGPoint(x: triX + triW, y: triY + triH * 0.5)) // Right tip
            triPath.addLine(to: CGPoint(x: triX, y: triY)) // Top left
            triPath.addLine(to: CGPoint(x: triX, y: triY + triH)) // Bottom left
            triPath.closeSubpath()
        } else {
            let handleX = b.width - handleW
            // 3-sided border path (top, left, bottom, right open)
            borderPath.move(to: CGPoint(x: b.width, y: handleY))
            borderPath.addLine(to: CGPoint(x: handleX + r, y: handleY))
            borderPath.addArc(tangent1End: CGPoint(x: handleX, y: handleY), tangent2End: CGPoint(x: handleX, y: handleY + r), radius: r)
            borderPath.addLine(to: CGPoint(x: handleX, y: handleY + handleH - r))
            borderPath.addArc(tangent1End: CGPoint(x: handleX, y: handleY + handleH), tangent2End: CGPoint(x: handleX + r, y: handleY + handleH), radius: r)
            borderPath.addLine(to: CGPoint(x: b.width, y: handleY + handleH))

            ctx.setShadow(offset: CGSize(width: -0.5, height: 0), blur: 0.5, color: NSColor.black.withAlphaComponent(0.25).cgColor)

            // Flattened indicator triangle pointing left (height: 9.5, width: 2.0)
            let triX = b.width - max(1.5, (handleW - triW) * 0.5) - triW
            triPath.move(to: CGPoint(x: triX, y: triY + triH * 0.5)) // Left tip
            triPath.addLine(to: CGPoint(x: triX + triW, y: triY)) // Top right
            triPath.addLine(to: CGPoint(x: triX + triW, y: triY + triH)) // Bottom right
            triPath.closeSubpath()
        }

        if let customFillColor {
            ctx.setFillColor(customFillColor.cgColor)
            ctx.addPath(borderPath)
            ctx.closePath()
            ctx.fillPath()
        }

        // Stroke 3-sided border
        let strokeColor = customStrokeColor ?? NSColor.white.withAlphaComponent(0.75)
        ctx.setStrokeColor(strokeColor.cgColor)
        ctx.setLineWidth(customFillColor != nil ? 1.2 : 1.0)
        ctx.addPath(borderPath)
        ctx.strokePath()

        let arrowColor = customArrowColor ?? NSColor.white.withAlphaComponent(0.85)
        ctx.setFillColor(arrowColor.cgColor)
        ctx.addPath(triPath)
        ctx.fillPath()

        ctx.restoreGState()
    }
}

// MARK: - Lightweight Multimodal Pinyin Matcher
public enum SilkPinyinMatcher {
    public static func pinyinTokens(for input: String) -> String {
        guard !input.isEmpty else { return "" }
        let lowered = input.lowercased()
        if lowered.allSatisfy(\.isASCII) {
            return lowered
        }
        let mutable = NSMutableString(string: input)
        CFStringTransform(mutable, nil, kCFStringTransformToLatin, false)
        CFStringTransform(mutable, nil, kCFStringTransformStripCombiningMarks, false)
        let latin = (mutable as String).lowercased()
        let words = latin.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
        let fullJoined = words.joined()
        let initials = words.compactMap { $0.first.map(String.init) }.joined()
        let spaced = words.joined(separator: " ")
        return "\(lowered) \(spaced) \(fullJoined) \(initials)"
    }
}

