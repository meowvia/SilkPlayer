import SwiftUI
import AppKit
import ImageIO
import SilkCoreKit
import UniformTypeIdentifiers

// MARK: - Domain & Filter Types

public enum SilkLibraryDomain: String, CaseIterable, Identifiable, Sendable {
    case video
    case audio

    public var id: String { rawValue }
}

private enum SilkVideoLayoutMode: String, CaseIterable, Identifiable {
    case grid
    case list

    var id: String { rawValue }
}

private enum SilkVideoFilter: String, CaseIterable, Identifiable {
    case all
    case movies
    case series
    case continueWatching
    case ultraHD
    case unwatched

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return L10n.tr("All", "全部")
        case .movies: return L10n.tr("Movies", "电影")
        case .series: return L10n.tr("TV Series", "电视剧")
        case .continueWatching: return L10n.tr("Continue", "继续观看")
        case .ultraHD: return L10n.tr("4K / HDR", "4K / HDR")
        case .unwatched: return L10n.tr("Unwatched", "未看过")
        }
    }
}

private struct SilkSeriesGroup: Identifiable {
    let id: String
    let seriesName: String
    let episodes: [SilkMediaLibraryRecord]
    let seasonsCount: Int
    let latestResumeEpisode: SilkMediaLibraryRecord
    let posterPath: String?
}

private struct SilkAudioDirectoryEntry: Identifiable {
    let id: String
    let name: String
    let fullPath: String
    let trackCount: Int
    let totalBytes: Int64
    let sourceLabel: String?
}

// MARK: - Main Single-Window Pro Media Library View

@MainActor
public struct SilkProLibraryView: View {
    @ObservedObject var library = SilkMediaLibraryEngine.shared
    @Bindable var settings = AppSettings.shared

    /// Launches a selected library item together with its ordered playback context queue (e.g. series episodes or folder audio tracks).
    public var onPlayItem: (_ target: SilkMediaLibraryRecord, _ queue: [SilkMediaLibraryRecord], _ forceFromBeginning: Bool) -> Void
    /// Fallback open-file panel action.
    public var onOpenFile: () -> Void
    /// Fallback drag-and-drop file handler.
    public var onFilesDropped: ([URL]) -> Void

    @State private var domain: SilkLibraryDomain = .video
    @State private var videoLayoutMode: SilkVideoLayoutMode = .grid
    @State private var videoFilter: SilkVideoFilter = .all
    @State private var selectedSourceId: String = "all"
    @State private var searchText: String = ""
    @State private var expandedSeriesIds: Set<String> = []
    @State private var focusedGridSeriesId: String? = nil
    @State private var currentAudioFolderPath: String? = nil

    @State private var showSMBSheet: Bool = false
    @State private var showSourcesSheet: Bool = false
    @State private var isDropTargeted: Bool = false
    @FocusState private var isSearchFocused: Bool

    public init(
        onPlayItem: @escaping (_ target: SilkMediaLibraryRecord, _ queue: [SilkMediaLibraryRecord], _ forceFromBeginning: Bool) -> Void,
        onOpenFile: @escaping () -> Void,
        onFilesDropped: @escaping ([URL]) -> Void
    ) {
        self.onPlayItem = onPlayItem
        self.onOpenFile = onOpenFile
        self.onFilesDropped = onFilesDropped
    }

    public var body: some View {
        ZStack {
            VisualEffectView(material: .sidebar, blendingMode: .behindWindow)
                .edgesIgnoringSafeArea(.all)
                .allowsHitTesting(false)

            Color(nsColor: .windowBackgroundColor)
                .opacity(0.32)
                .edgesIgnoringSafeArea(.all)
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                topToolbar
                Divider().opacity(0.18)

                if !library.sources.isEmpty {
                    filterStripBar
                    Divider().opacity(0.12)
                }

                contentBody
            }
            .padding(.top, 2)

            if isDropTargeted {
                dropOverlay
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: selectedSourceId) { _, _ in
            currentAudioFolderPath = nil
        }
        .sheet(isPresented: $showSMBSheet) {
            SilkSMBMountSheet()
        }
        .sheet(isPresented: $showSourcesSheet) {
            SilkSourcesManagerSheet(onAddSMB: {
                showSourcesSheet = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    showSMBSheet = true
                }
            })
        }
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            guard !providers.isEmpty else { return false }
            Task { @MainActor in
                var urls: [URL] = []
                for provider in providers {
                    let url: URL? = await withCheckedContinuation { cont in
                        _ = provider.loadObject(ofClass: URL.self) { item, _ in
                            cont.resume(returning: item)
                        }
                    }
                    if let url { urls.append(url) }
                }
                if !urls.isEmpty {
                    onFilesDropped(urls)
                }
            }
            return true
        }
    }

    // MARK: - Row 1: Unified Header Toolbar

    private var topToolbar: some View {
        ZStack {
            WindowDragGestureView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            HStack(spacing: 10) {
                // Reserve left margin for macOS traffic lights (close/min/zoom)
                Spacer().frame(width: 68)

                // Domain Switcher (Video Library vs Audio Folder Library)
                Picker("", selection: $domain) {
                    Label(L10n.tr("Video", "影视片库"), systemImage: "film.stack")
                        .tag(SilkLibraryDomain.video)
                    Label(L10n.tr("Audio", "音频库"), systemImage: "music.note.list")
                        .tag(SilkLibraryDomain.audio)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 180)

                // Instant Search Field
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11.5))
                        .foregroundColor(.secondary)

                    TextField(
                        domain == .video
                            ? L10n.tr("Search title, pinyin, codec...", "搜索片名、拼音简拼或编码…")
                            : L10n.tr("Search folder, track, format...", "搜索音频目录、曲目或格式…"),
                        text: $searchText
                    )
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .focused($isSearchFocused)

                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 11.5))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .frame(maxWidth: 320)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color.primary.opacity(0.06))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .stroke(Color.primary.opacity(isSearchFocused ? 0.25 : 0.08), lineWidth: 0.75)
                )

                // Invisible Cmd+F focus shortcut trigger
                Button("") {
                    isSearchFocused = true
                }
                .keyboardShortcut("f", modifiers: .command)
                .frame(width: 0, height: 0)
                .opacity(0)

                Spacer(minLength: 4)

                // Video Layout Switcher (Grid / List)
                if domain == .video {
                    Picker("", selection: $videoLayoutMode) {
                        Image(systemName: "square.grid.2x2")
                            .tag(SilkVideoLayoutMode.grid)
                            .help(L10n.tr("Grid View", "宫格排列"))
                        Image(systemName: "list.bullet")
                            .tag(SilkVideoLayoutMode.list)
                            .help(L10n.tr("List View", "列表排列"))
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 64)
                }

                // Source Filter Picker
                if !library.sources.isEmpty {
                    Menu {
                        Button {
                            selectedSourceId = "all"
                        } label: {
                            if selectedSourceId == "all" {
                                Label(L10n.tr("All Sources", "全部媒体源"), systemImage: "checkmark")
                            } else {
                                Text(L10n.tr("All Sources", "全部媒体源"))
                            }
                        }
                        Divider()
                        ForEach(library.sources) { src in
                            Button {
                                selectedSourceId = src.id
                            } label: {
                                let label = "\(src.displayName) (\(src.itemCount))"
                                if selectedSourceId == src.id {
                                    Label(label, systemImage: "checkmark")
                                } else {
                                    Text(label)
                                }
                            }
                        }
                        Divider()
                        Button(L10n.tr("Manage Media Sources...", "管理媒体源…")) {
                            showSourcesSheet = true
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "externaldrive.connected.to.line.below")
                                .font(.system(size: 11))
                            Text(activeSourceLabel)
                                .font(.system(size: 11.5, weight: .medium))
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4.5)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.primary.opacity(0.06))
                        )
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                }

                // Manual Rescan Button
                Button {
                    Task {
                        await library.rescanAll()
                    }
                } label: {
                    Group {
                        if library.isScanning {
                            ProgressView()
                                .controlSize(.small)
                                .scaleEffect(0.65)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 12, weight: .medium))
                        }
                    }
                    .frame(width: 26, height: 26)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.primary.opacity(0.05))
                    )
                }
                .buttonStyle(.plain)
                .disabled(library.sources.isEmpty || library.isScanning)
                .help(L10n.tr("Incremental Rescan All Sources", "增量重扫所有媒体源"))

                // Settings Button (Opens Tab 2 LAN Settings)
                Button {
                    PlayerWindowManager.shared.openSettings(initialTab: 2)
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 12.5, weight: .medium))
                        .frame(width: 26, height: 26)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.primary.opacity(0.05))
                        )
                }
                .buttonStyle(.plain)
                .help(L10n.tr("LAN Settings (⌘,)", "局域网设置 (⌘,)"))
            }
            .padding(.trailing, 14)
        }
        .frame(height: 50)
    }

    // MARK: - Row 2: Filter Pills & Status

    private var filterStripBar: some View {
        HStack(spacing: 6) {
            if domain == .video {
                ForEach(SilkVideoFilter.allCases) { f in
                    filterPill(title: f.title, isSelected: videoFilter == f) {
                        videoFilter = f
                    }
                }
            } else {
                audioFolderBreadcrumbBar
            }

            Spacer()

            if library.isScanning {
                HStack(spacing: 5) {
                    ProgressView()
                        .controlSize(.small)
                        .scaleEffect(0.6)
                    let countSuffix = library.scanningDiscoveredCount > 0 ? " (\(library.scanningDiscoveredCount))" : ""
                    Text(L10n.tr(
                        "Indexing \(library.scanningSourceName ?? "")\(countSuffix)...",
                        "正在索引 \(library.scanningSourceName ?? "")\(countSuffix)…"
                    ))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                }
            } else if let scanErr = library.lastScanError, !scanErr.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10.5))
                        .foregroundColor(.orange)
                    Text(scanErr)
                        .font(.system(size: 11))
                        .foregroundColor(.orange)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .frame(maxWidth: 300, alignment: .trailing)
            } else {
                Text(summaryCounterText)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private func filterPill(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11.5, weight: isSelected ? .semibold : .medium))
                .foregroundColor(isSelected ? .primary : .secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(isSelected ? Color.accentColor.opacity(0.18) : Color.primary.opacity(0.045))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(isSelected ? Color.accentColor.opacity(0.42) : Color.clear, lineWidth: 0.8)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Content Body

    @ViewBuilder
    private var contentBody: some View {
        if library.sources.isEmpty {
            onboardingZeroState
        } else if domain == .video {
            videoLibraryList
        } else {
            audioLibraryList
        }
    }

    private var onboardingZeroState: some View {
        VStack(spacing: 18) {
            Spacer()

            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.accentColor.opacity(0.10))
                    .frame(width: 68, height: 68)
                Image(systemName: "film.stack")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundColor(.accentColor)
            }

            VStack(spacing: 6) {
                Text(L10n.tr("Connect LAN or Local Media Folders", "添加局域网或本机媒体源"))
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.primary)

                Text(L10n.tr(
                    "Connect SMB 2/3, NFS, or local directories from the left sidebar or buttons below.",
                    "支持通过左侧栏或下方入口挂载 SMB 2/3、NFS 共享或添加本机文件夹，分别索引电影、电视剧与音频目录。"
                ))
                .font(.system(size: 12.5))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 460)
            }

            HStack(spacing: 12) {
                Button {
                    showSMBSheet = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "network")
                        Text(L10n.tr("Mount SMB 2/3 / NFS", "挂载 SMB 2/3 / NFS"))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    pickLocalFolderAndAdd()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "folder.badge.plus")
                        Text(L10n.tr("Add Local Folder", "添加本机目录"))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                }
                .buttonStyle(.bordered)

                Button {
                    onOpenFile()
                } label: {
                    Text(L10n.tr("Open File", "打开单个文件"))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
            }
            .padding(.top, 4)

            Spacer()
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Video Domain View (Separated Movies & TV Series, Grid / List)

    private var videoGridColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 230, maximum: 290), spacing: 10)]
    }

    @ViewBuilder
    private var videoLibraryList: some View {
        let filteredVideos = computeFilteredVideos()
        let resumeItems = filteredVideos
            .filter { $0.watchState == .inProgress }
            .sorted { ($0.lastPlayedAt ?? 0) > ($1.lastPlayedAt ?? 0) }
        let movies = filteredVideos.filter { $0.kind == .movie }
        let seriesGroups = groupSeries(from: filteredVideos.filter { $0.kind == .seriesEpisode })

        if filteredVideos.isEmpty {
            emptyFilterResultState
        } else {
            ScrollView(.vertical, showsIndicators: true) {
                LazyVStack(alignment: .leading, spacing: 16) {
                    // Compact Continue Watching Strip
                    if videoFilter == .all && searchText.isEmpty && !resumeItems.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(L10n.tr("Continue Watching", "继续观看"))
                                .font(.system(size: 11.5, weight: .semibold))
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 4)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(resumeItems.prefix(6)) { item in
                                        continueWatchingPill(item: item, allVideos: filteredVideos)
                                    }
                                }
                                .padding(.horizontal, 2)
                            }
                        }
                    }

                    // Movies Section
                    if videoFilter != .series && !movies.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            mediaSectionHeader(
                                title: L10n.tr("Movies", "电影"),
                                count: movies.count,
                                icon: "film"
                            )

                            if videoLayoutMode == .grid {
                                LazyVGrid(columns: videoGridColumns, spacing: 10) {
                                    ForEach(movies) { movie in
                                        movieGridCard(item: movie, queue: movies)
                                    }
                                }
                            } else {
                                LazyVStack(spacing: 4) {
                                    ForEach(movies) { movie in
                                        mediaRow(item: movie, queue: movies)
                                    }
                                }
                            }
                        }
                    }

                    // TV Series Section
                    if videoFilter != .movies && !seriesGroups.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            mediaSectionHeader(
                                title: L10n.tr("TV Series", "电视剧"),
                                count: seriesGroups.count,
                                icon: "tv"
                            )

                            if videoLayoutMode == .grid {
                                LazyVGrid(columns: videoGridColumns, spacing: 10) {
                                    ForEach(seriesGroups) { group in
                                        seriesGridCard(group: group)
                                    }
                                }

                                if let focusedId = focusedGridSeriesId,
                                   let focusedGroup = seriesGroups.first(where: { $0.id == focusedId }) {
                                    gridSeriesEpisodeDrawer(group: focusedGroup)
                                }
                            } else {
                                LazyVStack(spacing: 6) {
                                    ForEach(seriesGroups) { group in
                                        seriesRowCard(group: group)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
    }

    private func mediaSectionHeader(title: String, count: Int, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
            Text("\(title) (\(count))")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)
            Spacer()
            Divider()
                .opacity(0.08)
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 4)
        .padding(.top, 2)
    }

    private func movieGridCard(item: SilkMediaLibraryRecord, queue: [SilkMediaLibraryRecord]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.primary.opacity(0.06))
                        .frame(width: 34, height: 34)
                    Image(systemName: "film")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.accentColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    if let source = library.sources.first(where: { $0.id == item.sourceId }) {
                        Text("\(sourceProtocolPrefix(source))\(source.displayName)")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary.opacity(0.85))
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
            }

            HStack(spacing: 4) {
                if !item.resolutionTag.isEmpty {
                    specChip(item.resolutionTag, tint: item.resolutionTag == "4K" ? .purple : .blue)
                }
                if item.isDolbyVision {
                    specChip("DV", tint: .orange)
                } else if item.isHDR {
                    specChip("HDR", tint: .orange)
                }
                if !item.videoCodecTag.isEmpty {
                    specChip(item.videoCodecTag, tint: .secondary)
                }
                Spacer()
                Text(formatBytes(item.fileSizeBytes))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
            }

            HStack {
                watchStateIndicator(item)
                Spacer()
                Button {
                    onPlayItem(item, queue, false)
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 9))
                        Text(item.watchState == .inProgress ? L10n.tr("Resume", "续播") : L10n.tr("Play", "播放"))
                            .font(.system(size: 10.5, weight: .medium))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3.5)
                    .background(RoundedRectangle(cornerRadius: 5, style: .continuous).fill(Color.accentColor.opacity(0.15)))
                    .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(11)
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.045))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 0.75)
        )
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            onPlayItem(item, queue, false)
        }
        .contextMenu {
            videoContextMenu(item: item, queue: queue)
        }
    }

    private func seriesGridCard(group: SilkSeriesGroup) -> some View {
        let isFocused = focusedGridSeriesId == group.id
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.primary.opacity(0.06))
                        .frame(width: 34, height: 34)
                    Image(systemName: "tv")
                        .font(.system(size: 13.5, weight: .medium))
                        .foregroundColor(.accentColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(group.seriesName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    Text(L10n.tr(
                        "\(group.seasonsCount) Season(s) · \(group.episodes.count) Episodes",
                        "\(group.seasonsCount) 季 · \(group.episodes.count) 集"
                    ))
                    .font(.system(size: 10.5))
                    .foregroundColor(.secondary)
                }
                Spacer(minLength: 0)
            }

            HStack(spacing: 4) {
                if !group.latestResumeEpisode.resolutionTag.isEmpty {
                    specChip(group.latestResumeEpisode.resolutionTag, tint: .blue)
                }
                if !group.latestResumeEpisode.videoCodecTag.isEmpty {
                    specChip(group.latestResumeEpisode.videoCodecTag, tint: .secondary)
                }
                Spacer()
            }

            HStack {
                Button {
                    withAnimation(.easeInOut(duration: 0.16)) {
                        focusedGridSeriesId = isFocused ? nil : group.id
                    }
                } label: {
                    HStack(spacing: 3) {
                        Text(isFocused ? L10n.tr("Hide Episodes", "收起选集") : L10n.tr("Episodes", "选集列表"))
                            .font(.system(size: 10.5, weight: .medium))
                        Image(systemName: isFocused ? "chevron.up" : "chevron.down")
                            .font(.system(size: 9))
                    }
                    .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)

                Spacer()

                Button {
                    onPlayItem(group.latestResumeEpisode, group.episodes, false)
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 9))
                        Text(seriesActionLabel(group.latestResumeEpisode))
                            .font(.system(size: 10.5, weight: .medium))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3.5)
                    .background(RoundedRectangle(cornerRadius: 5, style: .continuous).fill(Color.accentColor.opacity(0.15)))
                    .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(11)
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isFocused ? Color.accentColor.opacity(0.08) : Color.primary.opacity(0.045))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(isFocused ? Color.accentColor.opacity(0.45) : Color.primary.opacity(0.08), lineWidth: 0.85)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.16)) {
                focusedGridSeriesId = isFocused ? nil : group.id
            }
        }
    }

    private func gridSeriesEpisodeDrawer(group: SilkSeriesGroup) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(group.seriesName)
                    .font(.system(size: 13, weight: .semibold))
                Text(L10n.tr("(\(group.episodes.count) Episodes)", "（共 \(group.episodes.count) 集）"))
                    .font(.system(size: 11.5))
                    .foregroundColor(.secondary)
                Spacer()
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        focusedGridSeriesId = nil
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundColor(.secondary)
                        .padding(4)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 6)

            LazyVStack(spacing: 2) {
                ForEach(group.episodes) { ep in
                    mediaRow(item: ep, queue: group.episodes)
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 0.8)
        )
    }

    private func continueWatchingPill(item: SilkMediaLibraryRecord, allVideos: [SilkMediaLibraryRecord]) -> some View {
        Button {
            let queue = queueForVideoItem(item, from: allVideos)
            onPlayItem(item, queue, false)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: item.kind == .seriesEpisode ? "tv" : "film")
                    .font(.system(size: 12))
                    .foregroundColor(.accentColor)
                    .frame(width: 24, height: 24)
                    .background(RoundedRectangle(cornerRadius: 5, style: .continuous).fill(Color.primary.opacity(0.06)))

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        ProgressView(value: max(0.04, item.progressFraction))
                            .progressViewStyle(.linear)
                            .frame(width: 68)
                        Text(remainingTimeLabel(item))
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 7)
            .frame(width: 220, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.primary.opacity(0.055))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 0.7)
            )
        }
        .buttonStyle(.plain)
    }

    private func seriesRowCard(group: SilkSeriesGroup) -> some View {
        let isExpanded = expandedSeriesIds.contains(group.id)
        return VStack(spacing: 0) {
            HStack(spacing: 10) {
                Button {
                    withAnimation(.easeInOut(duration: 0.16)) {
                        if isExpanded {
                            expandedSeriesIds.remove(group.id)
                        } else {
                            expandedSeriesIds.insert(group.id)
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundColor(.secondary)
                            .frame(width: 12)

                        Image(systemName: "tv")
                            .font(.system(size: 12.5))
                            .foregroundColor(.accentColor)
                            .frame(width: 24, height: 24)
                            .background(RoundedRectangle(cornerRadius: 5, style: .continuous).fill(Color.primary.opacity(0.06)))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(group.seriesName)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.primary)
                                .lineLimit(1)

                            HStack(spacing: 6) {
                                Text(L10n.tr(
                                    "\(group.seasonsCount) Season(s) · \(group.episodes.count) Episodes",
                                    "共 \(group.seasonsCount) 季 · \(group.episodes.count) 集"
                                ))
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)

                                if !group.latestResumeEpisode.resolutionTag.isEmpty {
                                    specChip(group.latestResumeEpisode.resolutionTag, tint: .blue)
                                }
                            }
                        }

                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                // Direct Resume Series Episode Button
                Button {
                    onPlayItem(group.latestResumeEpisode, group.episodes, false)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 9.5))
                        Text(seriesActionLabel(group.latestResumeEpisode))
                            .font(.system(size: 11, weight: .medium))
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.accentColor.opacity(0.16))
                    )
                    .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.primary.opacity(isExpanded ? 0.06 : 0.035))
            )

            if isExpanded {
                VStack(spacing: 2) {
                    ForEach(group.episodes) { ep in
                        mediaRow(item: ep, queue: group.episodes, indent: 22)
                    }
                }
                .padding(.top, 3)
                .padding(.bottom, 4)
            }
        }
    }

    private func mediaRow(item: SilkMediaLibraryRecord, queue: [SilkMediaLibraryRecord], indent: CGFloat = 0) -> some View {
        HStack(spacing: 10) {
            if indent > 0 {
                Spacer().frame(width: indent)
            }

            if item.kind == .movie {
                Image(systemName: "film")
                    .font(.system(size: 12))
                    .foregroundColor(.accentColor)
                    .frame(width: 24, height: 24)
                    .background(RoundedRectangle(cornerRadius: 5, style: .continuous).fill(Color.primary.opacity(0.06)))
            } else if item.kind == .seriesEpisode {
                Text(String(format: "S%02dE%02d", item.seasonNumber ?? 1, item.episodeNumber ?? 1))
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(.secondary)
                    .frame(width: 54, alignment: .leading)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)

                HStack(spacing: 5) {
                    if !item.resolutionTag.isEmpty {
                        specChip(item.resolutionTag, tint: item.resolutionTag == "4K" ? .purple : .blue)
                    }
                    if item.isDolbyVision {
                        specChip("Dolby Vision", tint: .orange)
                    } else if item.isHDR {
                        specChip("HDR", tint: .orange)
                    }
                    if !item.videoCodecTag.isEmpty {
                        specChip(item.videoCodecTag, tint: .secondary)
                    }
                    if !item.audioSpecTag.isEmpty {
                        specChip(item.audioSpecTag, tint: .teal)
                    }
                    if let source = library.sources.first(where: { $0.id == item.sourceId }) {
                        Text("\(sourceProtocolPrefix(source))\(source.displayName)")
                            .font(.system(size: 10.5))
                            .foregroundColor(.secondary.opacity(0.8))
                            .lineLimit(1)
                    }
                }
            }

            Spacer(minLength: 8)

            // File size
            Text(formatBytes(item.fileSizeBytes))
                .font(.system(size: 10.5, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 58, alignment: .trailing)

            // Watch State Pill
            watchStateIndicator(item)
                .frame(width: 96, alignment: .trailing)

            Button {
                onPlayItem(item, queue, false)
            } label: {
                Image(systemName: "play.fill")
                    .font(.system(size: 10.5))
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(Color.primary.opacity(0.08)))
            }
            .buttonStyle(.plain)
            .help(L10n.tr("Play Now", "立即播放"))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Color.primary.opacity(0.025))
        )
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            onPlayItem(item, queue, false)
        }
        .contextMenu {
            videoContextMenu(item: item, queue: queue)
        }
    }

    @ViewBuilder
    private func videoContextMenu(item: SilkMediaLibraryRecord, queue: [SilkMediaLibraryRecord]) -> some View {
        Button(L10n.tr("Play / Resume", "播放 / 继续观看")) {
            onPlayItem(item, queue, false)
        }
        Button(L10n.tr("Play from Beginning", "从头播放")) {
            onPlayItem(item, queue, true)
        }
        Divider()
        Button(L10n.tr("Mark as Watched", "标记为已看完")) {
            Task { await library.setWatchState(path: item.path, state: .watched) }
        }
        Button(L10n.tr("Mark as Unwatched (Reset Progress)", "重置为未观看")) {
            Task { await library.setWatchState(path: item.path, state: .unwatched) }
        }
        Divider()
        Button(L10n.tr("Show in Finder", "在访达中显示")) {
            NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: item.path)])
        }
    }

    // MARK: - Audio Domain View (Hierarchical Folder Drilldown)

    @ViewBuilder
    private var audioFolderBreadcrumbBar: some View {
        HStack(spacing: 6) {
            Button {
                currentAudioFolderPath = nil
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 10.5))
                    Text(L10n.tr("Audio Roots", "音频根目录"))
                        .font(.system(size: 11.5, weight: currentAudioFolderPath == nil ? .semibold : .medium))
                }
                .foregroundColor(currentAudioFolderPath == nil ? .primary : .secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(currentAudioFolderPath == nil ? Color.accentColor.opacity(0.16) : Color.primary.opacity(0.045))
                )
            }
            .buttonStyle(.plain)

            if let currentPath = currentAudioFolderPath {
                Button {
                    navigateUpAudioFolder(from: currentPath)
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 10, weight: .semibold))
                        Text(L10n.tr("Up", "上级"))
                            .font(.system(size: 11, weight: .medium))
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.primary.opacity(0.06))
                    )
                }
                .buttonStyle(.plain)

                Text(audioBreadcrumbDisplayPath(currentPath))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.head)
            }
        }
    }

    @ViewBuilder
    private var audioLibraryList: some View {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let audioItems = library.items.filter { item in
            guard item.kind == .audio else { return false }
            if selectedSourceId != "all" && item.sourceId != selectedSourceId { return false }
            return true
        }

        if audioItems.isEmpty {
            emptyFilterResultState
        } else if !q.isEmpty {
            let matched = audioItems
                .filter { matchesQuery($0, query: q) }
                .sorted { ($0.trackNumber ?? 9999, $0.title) < ($1.trackNumber ?? 9999, $1.title) }
            if matched.isEmpty {
                emptyFilterResultState
            } else {
                ScrollView(.vertical, showsIndicators: true) {
                    LazyVStack(alignment: .leading, spacing: 3) {
                        ForEach(matched) { track in
                            audioTrackRow(track: track, queue: matched, showAlbumColumn: true)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
        } else {
            let contents = computeAudioDirectoryContents(from: audioItems)
            if contents.folders.isEmpty && contents.tracks.isEmpty {
                emptyFilterResultState
            } else {
                ScrollView(.vertical, showsIndicators: true) {
                    LazyVStack(alignment: .leading, spacing: 6) {
                        if !contents.folders.isEmpty {
                            Text(L10n.tr("Folders (\(contents.folders.count))", "目录 (\(contents.folders.count))"))
                                .font(.system(size: 11.5, weight: .semibold))
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 4)

                            ForEach(contents.folders) { folder in
                                audioDirectoryRow(folder)
                            }
                        }

                        if !contents.tracks.isEmpty {
                            HStack {
                                Text(L10n.tr("Audio Files (\(contents.tracks.count))", "音频文件 (\(contents.tracks.count))"))
                                    .font(.system(size: 11.5, weight: .semibold))
                                    .foregroundColor(.secondary)
                                Spacer()
                                Button {
                                    if let first = contents.tracks.first {
                                        onPlayItem(first, contents.tracks, true)
                                    }
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "play.fill")
                                            .font(.system(size: 9.5))
                                        Text(L10n.tr("Play Folder", "播放当前目录"))
                                            .font(.system(size: 11, weight: .medium))
                                    }
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 4)
                                    .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Color.accentColor.opacity(0.15)))
                                    .foregroundColor(.accentColor)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 4)
                            .padding(.top, contents.folders.isEmpty ? 0 : 6)

                            ForEach(contents.tracks) { track in
                                audioTrackRow(track: track, queue: contents.tracks, showAlbumColumn: false)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
        }
    }

    private func audioDirectoryRow(_ entry: SilkAudioDirectoryEntry) -> some View {
        Button {
            currentAudioFolderPath = entry.fullPath
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "folder.fill")
                    .font(.system(size: 15))
                    .foregroundColor(.accentColor)
                    .frame(width: 28, height: 28)
                    .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Color.primary.opacity(0.06)))

                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        if let label = entry.sourceLabel, !label.isEmpty {
                            Text(label)
                                .font(.system(size: 10.5))
                                .foregroundColor(.secondary)
                            Text("·")
                                .foregroundColor(.secondary)
                        }
                        Text(L10n.tr("\(entry.trackCount) tracks", "\(entry.trackCount) 首"))
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                Text(formatBytes(entry.totalBytes))
                    .font(.system(size: 10.5, design: .monospaced))
                    .foregroundColor(.secondary)

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.primary.opacity(0.035))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func audioTrackRow(
        track: SilkMediaLibraryRecord,
        queue: [SilkMediaLibraryRecord],
        showAlbumColumn: Bool,
        indent: CGFloat = 0
    ) -> some View {
        HStack(spacing: 10) {
            if indent > 0 {
                Spacer().frame(width: indent)
            }

            if let tNum = track.trackNumber {
                Text(String(format: "%02d", tNum))
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(.secondary)
                    .frame(width: 26, alignment: .trailing)
            } else {
                Image(systemName: "waveform")
                    .font(.system(size: 10.5))
                    .foregroundColor(.secondary)
                    .frame(width: 26, alignment: .center)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(track.title)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    if let artist = track.artistName, !artist.isEmpty {
                        Text(artist)
                            .font(.system(size: 10.5))
                            .foregroundColor(.secondary)
                    }
                    if showAlbumColumn, let album = track.albumName, !album.isEmpty {
                        Text("· \(album)")
                            .font(.system(size: 10.5))
                            .foregroundColor(.secondary.opacity(0.85))
                            .lineLimit(1)
                    }
                }
            }

            Spacer(minLength: 8)

            if !track.audioSpecTag.isEmpty {
                specChip(track.audioSpecTag, tint: .teal)
            }

            Text(formatBytes(track.fileSizeBytes))
                .font(.system(size: 10.5, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 58, alignment: .trailing)

            Button {
                onPlayItem(track, queue, true)
            } label: {
                Image(systemName: "play.fill")
                    .font(.system(size: 10))
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(Color.primary.opacity(0.08)))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5.5)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.primary.opacity(0.025))
        )
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            onPlayItem(track, queue, true)
        }
        .contextMenu {
            Button(L10n.tr("Play in Music Mode", "在音乐模式播放")) {
                onPlayItem(track, queue, true)
            }
            Divider()
            Button(L10n.tr("Show in Finder", "在访达中显示")) {
                NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: track.path)])
            }
        }
    }

    private var emptyFilterResultState: some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: searchText.isEmpty ? "tray" : "magnifyingglass")
                .font(.system(size: 26))
                .foregroundColor(.secondary.opacity(0.7))
            Text(searchText.isEmpty
                 ? L10n.tr("No matching media items in this category.", "当前分类下暂无匹配媒体条目。")
                 : L10n.tr("No results match \"\(searchText)\".", "未找到与“\(searchText)”匹配的片源。"))
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            if !searchText.isEmpty || videoFilter != .all || selectedSourceId != "all" {
                Button(L10n.tr("Reset Filters", "重置筛选条件")) {
                    searchText = ""
                    videoFilter = .all
                    currentAudioFolderPath = nil
                    selectedSourceId = "all"
                }
                .controlSize(.small)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var dropOverlay: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 2, dash: [8, 5]))
            .background(Color.accentColor.opacity(0.08))
            .overlay(
                VStack(spacing: 6) {
                    Image(systemName: "play.square.stack")
                        .font(.system(size: 30))
                    Text(L10n.tr("Drop Files to Play Immediately", "松手立即单窗口播放所选文件"))
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(.accentColor)
            )
            .padding(14)
            .allowsHitTesting(false)
    }

    // MARK: - Filtering & Grouping Logic

    private func computeFilteredVideos() -> [SilkMediaLibraryRecord] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return library.items.filter { item in
            if item.kind == .audio { return false }
            if selectedSourceId != "all" && item.sourceId != selectedSourceId { return false }
            if !q.isEmpty && !matchesQuery(item, query: q) { return false }

            switch videoFilter {
            case .all: return true
            case .continueWatching: return item.watchState == .inProgress
            case .movies: return item.kind == .movie
            case .series: return item.kind == .seriesEpisode
            case .ultraHD: return item.resolutionTag == "4K" || item.isHDR || item.isDolbyVision
            case .unwatched: return item.watchState == .unwatched
            }
        }
    }

    private func normalizeDirPath(_ path: String) -> String {
        var trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        while trimmed.count > 1 && trimmed.hasSuffix("/") {
            trimmed.removeLast()
        }
        return trimmed
    }

    private func activeAudioRootEntries(from audioItems: [SilkMediaLibraryRecord]) -> [SilkAudioDirectoryEntry] {
        let activeSources = library.sources.filter { selectedSourceId == "all" || $0.id == selectedSourceId }
        var seenPaths: Set<String> = []
        var roots: [SilkAudioDirectoryEntry] = []

        for source in activeSources {
            let sourceTracks = audioItems.filter { $0.sourceId == source.id }
            guard !sourceTracks.isEmpty else { continue }

            let basePath = normalizeDirPath(source.path)
            let protoLabel = sourceProtocolPrefix(source).trimmingCharacters(in: CharacterSet(charactersIn: " ·"))
            let sourceTag = protoLabel.isEmpty ? source.displayName : "\(protoLabel) · \(source.displayName)"

            let rootCandidates: [(path: String, name: String)]
            if source.includedRelativePaths.isEmpty {
                rootCandidates = [(basePath, source.displayName)]
            } else {
                rootCandidates = source.includedRelativePaths.map { rel in
                    let cleanRel = rel.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                    if cleanRel.isEmpty {
                        return (basePath, source.displayName)
                    }
                    let full = normalizeDirPath((basePath as NSString).appendingPathComponent(cleanRel))
                    return (full, (full as NSString).lastPathComponent)
                }
            }

            for candidate in rootCandidates {
                guard seenPaths.insert(candidate.path).inserted else { continue }
                let matching = sourceTracks.filter {
                    $0.path == candidate.path || $0.path.hasPrefix(candidate.path + "/")
                }
                guard !matching.isEmpty else { continue }
                let bytes = matching.reduce(Int64(0)) { $0 + $1.fileSizeBytes }
                roots.append(SilkAudioDirectoryEntry(
                    id: candidate.path,
                    name: candidate.name,
                    fullPath: candidate.path,
                    trackCount: matching.count,
                    totalBytes: bytes,
                    sourceLabel: sourceTag
                ))
            }
        }

        return roots.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private func computeAudioDirectoryContents(from audioItems: [SilkMediaLibraryRecord]) -> (folders: [SilkAudioDirectoryEntry], tracks: [SilkMediaLibraryRecord]) {
        guard let rawCurrent = currentAudioFolderPath else {
            return (activeAudioRootEntries(from: audioItems), [])
        }
        let currentDir = normalizeDirPath(rawCurrent)
        let prefix = currentDir == "/" ? "/" : (currentDir + "/")

        var childAggregates: [String: (count: Int, bytes: Int64)] = [:]
        var directTracks: [SilkMediaLibraryRecord] = []

        for track in audioItems where track.path.hasPrefix(prefix) {
            let rel = String(track.path.dropFirst(prefix.count))
            guard !rel.isEmpty else { continue }
            if let slashIdx = rel.firstIndex(of: "/") {
                let folderName = String(rel[..<slashIdx])
                guard !folderName.isEmpty else { continue }
                let prev = childAggregates[folderName] ?? (0, 0)
                childAggregates[folderName] = (prev.count + 1, prev.bytes + track.fileSizeBytes)
            } else {
                directTracks.append(track)
            }
        }

        let folders = childAggregates.map { (name, info) in
            let full = normalizeDirPath((currentDir as NSString).appendingPathComponent(name))
            return SilkAudioDirectoryEntry(
                id: full,
                name: name,
                fullPath: full,
                trackCount: info.count,
                totalBytes: info.bytes,
                sourceLabel: nil
            )
        }
        .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }

        let sortedTracks = directTracks.sorted { lhs, rhs in
            let tA = lhs.trackNumber ?? 9999
            let tB = rhs.trackNumber ?? 9999
            if tA != tB { return tA < tB }
            return lhs.fileName.localizedStandardCompare(rhs.fileName) == .orderedAscending
        }

        return (folders, sortedTracks)
    }

    private func navigateUpAudioFolder(from currentPath: String) {
        let norm = normalizeDirPath(currentPath)
        let allAudio = library.items.filter { $0.kind == .audio && (selectedSourceId == "all" || $0.sourceId == selectedSourceId) }
        let rootPaths = Set(activeAudioRootEntries(from: allAudio).map(\.fullPath))
        if rootPaths.contains(norm) {
            currentAudioFolderPath = nil
            return
        }
        let parent = normalizeDirPath((norm as NSString).deletingLastPathComponent)
        if parent.isEmpty || parent == "/" || !rootPaths.contains(where: { parent == $0 || parent.hasPrefix($0 + "/") }) {
            currentAudioFolderPath = nil
        } else {
            currentAudioFolderPath = parent
        }
    }

    private func audioBreadcrumbDisplayPath(_ currentPath: String) -> String {
        let norm = normalizeDirPath(currentPath)
        let allAudio = library.items.filter { $0.kind == .audio && (selectedSourceId == "all" || $0.sourceId == selectedSourceId) }
        for root in activeAudioRootEntries(from: allAudio) {
            if norm == root.fullPath {
                return root.name
            }
            if norm.hasPrefix(root.fullPath + "/") {
                let rel = String(norm.dropFirst(root.fullPath.count + 1))
                return "\(root.name) / \(rel.replacingOccurrences(of: "/", with: " / "))"
            }
        }
        return (norm as NSString).lastPathComponent
    }

    private func sourceProtocolPrefix(for source: SilkLibrarySource) -> String {
        sourceProtocolPrefix(source)
    }

    private func sourceProtocolPrefix(_ source: SilkLibrarySource) -> String {
        switch source.kind {
        case .smb: return "SMB · "
        case .nfs: return "NFS · "
        case .local: return ""
        @unknown default: return ""
        }
    }

    private func matchesQuery(_ item: SilkMediaLibraryRecord, query: String) -> Bool {
        if item.title.lowercased().contains(query) { return true }
        if item.fileName.lowercased().contains(query) { return true }
        if item.pinyinTokens.contains(query) { return true }
        if item.seriesName?.lowercased().contains(query) == true { return true }
        if item.albumName?.lowercased().contains(query) == true { return true }
        if item.artistName?.lowercased().contains(query) == true { return true }
        if item.resolutionTag.lowercased().contains(query) { return true }
        if item.videoCodecTag.lowercased().contains(query) { return true }
        if item.audioSpecTag.lowercased().contains(query) { return true }
        return false
    }

    private func groupSeries(from episodes: [SilkMediaLibraryRecord]) -> [SilkSeriesGroup] {
        let dict = Dictionary(grouping: episodes) { item in
            item.seriesName?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? "Other Series"
        }
        return dict.map { (name, eps) in
            let sorted = eps.sorted { a, b in
                let sa = a.seasonNumber ?? 1
                let sb = b.seasonNumber ?? 1
                if sa != sb { return sa < sb }
                let ea = a.episodeNumber ?? 0
                let eb = b.episodeNumber ?? 0
                if ea != eb { return ea < eb }
                return a.title.localizedStandardCompare(b.title) == .orderedAscending
            }
            let seasons = Set(sorted.compactMap { $0.seasonNumber ?? 1 }).count
            let resumeCandidate = sorted
                .filter { $0.watchState == .inProgress }
                .sorted { ($0.lastPlayedAt ?? 0) > ($1.lastPlayedAt ?? 0) }
                .first
                ?? sorted.first(where: { $0.watchState == .unwatched })
                ?? sorted[0]
            let poster = sorted.compactMap(\.posterPath).first
            return SilkSeriesGroup(
                id: name.lowercased(),
                seriesName: name,
                episodes: sorted,
                seasonsCount: max(1, seasons),
                latestResumeEpisode: resumeCandidate,
                posterPath: poster
            )
        }
        .sorted { a, b in
            let la = a.latestResumeEpisode.lastPlayedAt ?? 0
            let lb = b.latestResumeEpisode.lastPlayedAt ?? 0
            if la != lb { return la > lb }
            return a.seriesName.localizedStandardCompare(b.seriesName) == .orderedAscending
        }
    }

    private func queueForVideoItem(_ item: SilkMediaLibraryRecord, from allVideos: [SilkMediaLibraryRecord]) -> [SilkMediaLibraryRecord] {
        if item.kind == .seriesEpisode, let series = item.seriesName {
            return groupSeries(from: allVideos.filter { $0.kind == .seriesEpisode && $0.seriesName == series })
                .first?.episodes ?? [item]
        }
        return allVideos.filter { $0.kind == .movie }
    }

    // MARK: - Formatting & Small UI Elements

    private var activeSourceLabel: String {
        if selectedSourceId == "all" {
            return L10n.tr("All Sources", "全部媒体源")
        }
        return library.sources.first(where: { $0.id == selectedSourceId })?.displayName ?? L10n.tr("Source", "媒体源")
    }

    private var summaryCounterText: String {
        if domain == .video {
            let count = computeFilteredVideos().count
            return L10n.tr("\(count) videos", "\(count) 项影视")
        } else {
            let count = library.items.filter { $0.kind == .audio && (selectedSourceId == "all" || $0.sourceId == selectedSourceId) }.count
            return L10n.tr("\(count) tracks", "\(count) 首曲目")
        }
    }

    private func specChip(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(.system(size: 9.5, weight: .semibold, design: .rounded))
            .foregroundColor(tint == .secondary ? .secondary : tint)
            .padding(.horizontal, 5)
            .padding(.vertical, 1.5)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(tint.opacity(0.13))
            )
    }

    @ViewBuilder
    private func watchStateIndicator(_ item: SilkMediaLibraryRecord) -> some View {
        switch item.watchState {
        case .watched:
            Label(L10n.tr("Watched", "已看完"), systemImage: "checkmark.circle.fill")
                .font(.system(size: 10.5))
                .foregroundColor(.green)
        case .inProgress:
            HStack(spacing: 4) {
                ProgressView(value: max(0.05, item.progressFraction))
                    .progressViewStyle(.linear)
                    .frame(width: 44)
                Text(remainingTimeLabel(item))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.accentColor)
            }
        case .unwatched:
            Text(L10n.tr("Unwatched", "未观看"))
                .font(.system(size: 10.5))
                .foregroundColor(.secondary.opacity(0.75))
        @unknown default:
            EmptyView()
        }
    }

    private func seriesActionLabel(_ ep: SilkMediaLibraryRecord) -> String {
        let code = String(format: "S%02dE%02d", ep.seasonNumber ?? 1, ep.episodeNumber ?? 1)
        if ep.watchState == .inProgress {
            return L10n.tr("Resume \(code)", "续播 \(code)")
        }
        return L10n.tr("Play \(code)", "播放 \(code)")
    }

    private func remainingTimeLabel(_ item: SilkMediaLibraryRecord) -> String {
        if item.durationSeconds > 1 {
            let remMins = max(1, Int(ceil((item.durationSeconds - item.positionSeconds) / 60.0)))
            return L10n.tr("\(remMins)m left", "剩\(remMins)m")
        }
        let posMins = max(1, Int(item.positionSeconds / 60.0))
        return L10n.tr("@\(posMins)m", "看至\(posMins)m")
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let gb = Double(bytes) / 1_073_741_824.0
        if gb >= 1.0 {
            return String(format: "%.1fG", gb)
        }
        let mb = max(1, Int(round(Double(bytes) / 1_048_576.0)))
        return "\(mb)M"
    }

    private func pickLocalFolderAndAdd() {
        NSCursor.unhide()
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = L10n.tr("Add Folder", "加入片库")
        if panel.runModal() == .OK, let url = panel.url {
            Task {
                if let added = await library.addLocalSource(url: url, scanImmediately: false) {
                    library.enqueueBackgroundRescan(sourceIds: [added.id])
                }
            }
        }
        NSCursor.unhide()
    }
}

// MARK: - Lightweight Off-Main-Thread Cached Poster Thumbnail

private final class SilkPosterCache {
    @MainActor static let shared = NSCache<NSString, NSImage>()
}

private struct SilkPosterThumbnailView: View {
    let posterPath: String?
    let fallbackIcon: String
    let size: CGSize

    @State private var loadedImage: NSImage? = nil

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(Color.primary.opacity(0.07))

            if let img = loadedImage {
                Image(nsImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size.width, height: size.height)
                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            } else {
                Image(systemName: fallbackIcon)
                    .font(.system(size: min(size.width, size.height) * 0.44, weight: .medium))
                    .foregroundColor(.secondary.opacity(0.8))
            }
        }
        .frame(width: size.width, height: size.height)
        .onAppear { loadIfNeeded() }
        .onChange(of: posterPath) { _, _ in loadIfNeeded() }
    }

    private func loadIfNeeded() {
        guard let path = posterPath, !path.isEmpty else {
            loadedImage = nil
            return
        }
        let targetMaxPx = Int(max(size.width, size.height) * 2.5)
        let cacheKeyString = "\(path)#\(targetMaxPx)"
        if let cached = SilkPosterCache.shared.object(forKey: cacheKeyString as NSString) {
            loadedImage = cached
            return
        }
        Task.detached(priority: .utility) {
            let fileURL = URL(fileURLWithPath: path)
            guard let source = CGImageSourceCreateWithURL(fileURL as CFURL, nil) else { return }
            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: max(64, targetMaxPx),
                kCGImageSourceShouldCacheImmediately: true
            ]
            guard let cgThumb = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return }
            await MainActor.run {
                let image = NSImage(cgImage: cgThumb, size: NSSize(width: cgThumb.width, height: cgThumb.height))
                SilkPosterCache.shared.setObject(image, forKey: cacheKeyString as NSString)
                loadedImage = image
            }
        }
    }
}

// MARK: - Interactive Lazy Folder Tree Selection Model

enum SilkFolderCheckState: Equatable {
    case checked
    case mixed
    case unchecked

    var symbolName: String {
        switch self {
        case .checked: return "checkmark.square.fill"
        case .mixed: return "minus.square.fill"
        case .unchecked: return "square"
        }
    }
}

struct SilkFolderSelectionRule: Equatable {
    var includedPaths: Set<String> = []
    var excludedPaths: Set<String> = []

    init(includedRelativePaths: [String] = [], excludedRelativePaths: [String] = []) {
        let hasRoot = includedRelativePaths.isEmpty || includedRelativePaths.contains { raw in
            let t = raw.trimmingCharacters(in: CharacterSet(charactersIn: "/ \t\r\n"))
            return t.isEmpty || t == "."
        }
        let nestedInc = includedRelativePaths.map(Self.normalize).filter { !$0.isEmpty && $0 != "." }
        let cleanExc = excludedRelativePaths.map(Self.normalize).filter { !$0.isEmpty && $0 != "." }

        var incSet = Set(nestedInc)
        if hasRoot { incSet.insert("") }
        self.includedPaths = incSet
        self.excludedPaths = Set(cleanExc)
    }

    init(emptyUnselected: Bool) {
        self.includedPaths = emptyUnselected ? [] : [""]
        self.excludedPaths = []
    }

    static func normalize(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: CharacterSet(charactersIn: "/ \t\r\n"))
        guard !trimmed.isEmpty, trimmed != "." else { return "" }
        return trimmed
            .split(separator: "/")
            .filter { $0 != "." && $0 != ".." && !$0.isEmpty }
            .joined(separator: "/")
    }

    var isActive: Bool { !includedPaths.isEmpty }

    var exportedIncludedRelativePaths: [String] {
        guard !includedPaths.isEmpty else { return [] }
        if includedPaths.contains("") {
            let nested = includedPaths.filter { !$0.isEmpty }.sorted()
            return nested.isEmpty ? [] : ["."] + nested
        }
        return includedPaths.sorted()
    }

    var exportedExcludedRelativePaths: [String] {
        excludedPaths.sorted()
    }

    var summaryLabel: String {
        guard isActive else { return "" }
        let includesRoot = includedPaths.contains("")
        let excludedCount = excludedPaths.count
        let nestedIncludeCount = includedPaths.filter { !$0.isEmpty }.count

        if includesRoot && excludedCount == 0 {
            return L10n.tr("Entire Drive", "全部目录")
        }
        if includesRoot && excludedCount > 0 {
            return L10n.tr("Excl. \(excludedCount) folder(s)", "已屏蔽 \(excludedCount) 个目录")
        }
        if excludedCount > 0 {
            return L10n.tr("\(nestedIncludeCount) folder(s) · Excl. \(excludedCount)", "选 \(nestedIncludeCount) 个 · 屏蔽 \(excludedCount) 个")
        }
        return L10n.tr("\(nestedIncludeCount) folder(s)", "仅选 \(nestedIncludeCount) 个目录")
    }

    private func isSelfCovered(_ normPath: String) -> Bool {
        var bestIncludeScore = 0
        for inc in includedPaths {
            if inc.isEmpty {
                bestIncludeScore = max(bestIncludeScore, 1)
            } else if normPath == inc || normPath.hasPrefix(inc + "/") {
                bestIncludeScore = max(bestIncludeScore, inc.count + 1)
            }
        }
        var bestExcludeScore = 0
        for ex in excludedPaths where !ex.isEmpty {
            if normPath == ex || normPath.hasPrefix(ex + "/") {
                bestExcludeScore = max(bestExcludeScore, ex.count + 1)
            }
        }
        return bestIncludeScore > bestExcludeScore
    }

    private func isStrictDescendant(_ candidate: String, of normParent: String) -> Bool {
        guard candidate != normParent else { return false }
        if normParent.isEmpty { return !candidate.isEmpty }
        return candidate.hasPrefix(normParent + "/")
    }

    func state(for rawPath: String) -> SilkFolderCheckState {
        let p = Self.normalize(rawPath)
        if isSelfCovered(p) {
            let hasExcludedChild = excludedPaths.contains { isStrictDescendant($0, of: p) && !isSelfCovered($0) }
            return hasExcludedChild ? .mixed : .checked
        } else {
            let hasIncludedChild = includedPaths.contains { isStrictDescendant($0, of: p) }
            return hasIncludedChild ? .mixed : .unchecked
        }
    }

    mutating func toggle(_ rawPath: String) {
        let p = Self.normalize(rawPath)
        let current = state(for: p)

        includedPaths = includedPaths.filter { $0 != p && !isStrictDescendant($0, of: p) }
        excludedPaths = excludedPaths.filter { $0 != p && !isStrictDescendant($0, of: p) }

        if current == .checked {
            if !p.isEmpty && isSelfCovered(p) {
                excludedPaths.insert(p)
            }
        } else {
            if !isSelfCovered(p) {
                includedPaths.insert(p)
            }
        }
    }
}

private struct SilkFolderTreeRowItem: Identifiable {
    let id: String
    let shareName: String
    let relativePath: String
    let title: String
    let depth: Int
    let isShareRoot: Bool
    let isMounted: Bool
    let isExpanded: Bool
    let isLoading: Bool
    let isKnownEmptyLeaf: Bool
    let checkState: SilkFolderCheckState
    let summaryText: String?
}

private struct SilkFolderTreeNodeRow: View {
    let row: SilkFolderTreeRowItem
    let onToggleExpand: () -> Void
    let onToggleCheck: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            if row.depth > 0 {
                Color.clear
                    .frame(width: CGFloat(row.depth) * 16, height: 1)
            }

            // Lazy expand chevron
            Button {
                onToggleExpand()
            } label: {
                ZStack {
                    if row.isLoading {
                        ProgressView()
                            .controlSize(.small)
                            .scaleEffect(0.55)
                    } else if row.isKnownEmptyLeaf {
                        Color.clear
                    } else {
                        Image(systemName: row.isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                }
                .frame(width: 16, height: 18)
            }
            .buttonStyle(.plain)
            .disabled(row.isKnownEmptyLeaf || row.isLoading)

            // Tri-state checkbox
            Button {
                onToggleCheck()
            } label: {
                Image(systemName: row.checkState.symbolName)
                    .font(.system(size: 13.5))
                    .foregroundColor(row.checkState == .unchecked ? .secondary : .accentColor)
            }
            .buttonStyle(.plain)

            Image(systemName: row.isShareRoot ? "externaldrive.fill" : "folder.fill")
                .font(.system(size: 11.5))
                .foregroundColor(row.isShareRoot ? (row.isMounted ? .green : .secondary) : .accentColor.opacity(0.85))

            Text(row.title)
                .font(.system(size: 12, weight: row.isShareRoot ? .medium : .regular))
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer(minLength: 6)

            if let summaryText = row.summaryText, !summaryText.isEmpty {
                Text(summaryText)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.accentColor)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1.5)
                    .background(Capsule().fill(Color.accentColor.opacity(0.12)))
            }

            if row.isShareRoot && row.isMounted {
                Text(L10n.tr("Mounted", "已挂载"))
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundColor(.green)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1.5)
                    .background(Capsule().fill(Color.green.opacity(0.15)))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

// MARK: - LAN SMB Mount & Interactive Tree Discovery Sheet

@MainActor
private struct SilkSMBMountSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var smbService = SilkSMBMountService.shared
    @ObservedObject var library = SilkMediaLibraryEngine.shared
    var onMounted: (() -> Void)? = nil

    @State private var shareProtocol: SilkNetworkShareProtocol = .smb
    @State private var host: String = ""
    @State private var share: String = ""
    @State private var displayName: String = ""
    @State private var isGuest: Bool = false
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var autoScan: Bool = true
    @State private var isMounting: Bool = false
    @State private var isProbingShares: Bool = false

    @State private var availableShares: [SilkSMBShareEntry] = []
    @State private var shareRules: [String: SilkFolderSelectionRule] = [:]
    @State private var childrenByNodeKey: [String: [SilkFolderEntry]] = [:]
    @State private var expandedNodeKeys: Set<String> = []
    @State private var loadingNodeKeys: Set<String> = []
    @State private var emptyLeafKeys: Set<String> = []

    @State private var lastLoadedHost: String = ""
    @State private var errorMessage: String? = nil

    private var parsedHostInput: (shareProtocol: SilkNetworkShareProtocol, host: String, share: String?, username: String?, password: String?) {
        SilkSMBMountService.parseNetworkInput(host)
    }

    private var activeShareSpecs: [(name: String, rule: SilkFolderSelectionRule)] {
        var specs: [(String, SilkFolderSelectionRule)] = []
        for entry in availableShares {
            if let rule = shareRules[entry.name], rule.isActive {
                specs.append((entry.name, rule))
            }
        }
        for (name, rule) in shareRules.sorted(by: { $0.key < $1.key }) where rule.isActive {
            if !specs.contains(where: { $0.0 == name }) {
                specs.append((name, rule))
            }
        }
        if specs.isEmpty {
            if let typed = share.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty {
                return [(typed, SilkFolderSelectionRule(emptyUnselected: false))]
            }
            if let urlShare = parsedHostInput.share?.nilIfEmpty {
                return [(urlShare, SilkFolderSelectionRule(emptyUnselected: false))]
            }
        }
        return specs
    }

    private var primaryButtonTitle: String {
        if isProbingShares {
            return L10n.tr("Discovering Shares...", "正在探测共享目录…")
        }
        if isMounting {
            return L10n.tr("Mounting...", "正在挂载…")
        }
        let specs = activeShareSpecs
        if specs.isEmpty {
            return availableShares.isEmpty
                ? L10n.tr("Browse Shares", "连接并获取共享目录")
                : L10n.tr("Select Drives or Folders Above", "请先勾选上方目录")
        }
        if specs.count > 1 {
            return L10n.tr("Mount \(specs.count) Sources", "挂载并导入 (\(specs.count) 个目录)")
        }
        return L10n.tr("Confirm & Mount", "挂载并导入媒体库")
    }

    private var treeRows: [SilkFolderTreeRowItem] {
        var rows: [SilkFolderTreeRowItem] = []

        func appendSubtree(shareName: String, relParent: String, depth: Int) {
            let key = Self.nodeKey(share: shareName, relativePath: relParent)
            guard expandedNodeKeys.contains(key), let children = childrenByNodeKey[key] else { return }
            let rule = shareRules[shareName] ?? SilkFolderSelectionRule(emptyUnselected: true)
            for child in children {
                let cKey = Self.nodeKey(share: shareName, relativePath: child.relativePath)
                let isExpanded = expandedNodeKeys.contains(cKey)
                rows.append(SilkFolderTreeRowItem(
                    id: cKey,
                    shareName: shareName,
                    relativePath: child.relativePath,
                    title: child.name,
                    depth: depth,
                    isShareRoot: false,
                    isMounted: false,
                    isExpanded: isExpanded,
                    isLoading: loadingNodeKeys.contains(cKey),
                    isKnownEmptyLeaf: emptyLeafKeys.contains(cKey),
                    checkState: rule.state(for: child.relativePath),
                    summaryText: nil
                ))
                if isExpanded {
                    appendSubtree(shareName: shareName, relParent: child.relativePath, depth: depth + 1)
                }
            }
        }

        for entry in availableShares {
            let rKey = Self.nodeKey(share: entry.name, relativePath: "")
            let rule = shareRules[entry.name] ?? SilkFolderSelectionRule(emptyUnselected: true)
            let isExpanded = expandedNodeKeys.contains(rKey)
            rows.append(SilkFolderTreeRowItem(
                id: rKey,
                shareName: entry.name,
                relativePath: "",
                title: entry.name,
                depth: 0,
                isShareRoot: true,
                isMounted: entry.mountedPath != nil,
                isExpanded: isExpanded,
                isLoading: loadingNodeKeys.contains(rKey),
                isKnownEmptyLeaf: emptyLeafKeys.contains(rKey),
                checkState: rule.state(for: ""),
                summaryText: rule.isActive ? rule.summaryLabel : nil
            ))
            if isExpanded {
                appendSubtree(shareName: entry.name, relParent: "", depth: 1)
            }
        }
        return rows
    }

    private static func nodeKey(share: String, relativePath: String) -> String {
        "\(share)::\(relativePath)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.tr("Connect LAN Network Share", "连接局域网共享目录"))
                        .font(.system(size: 15, weight: .semibold))
                    Text(L10n.tr("Supports SMB 2/3 and NFS. Check folders below to include in your library.", "支持 SMB 2/3 与 NFS 协议，勾选需要导入的共享目录并由后台完成索引。"))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button(L10n.tr("Cancel", "取消")) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }

            Divider()

            // Discovered & Mounted Hosts
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(L10n.tr("Discovered & Mounted Devices", "已连接或局域网发现的设备"))
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundColor(.secondary)
                    if smbService.isScanning {
                        ProgressView().controlSize(.small).scaleEffect(0.6)
                    }
                    Spacer()
                }

                if smbService.discoveredHosts.isEmpty {
                    Text(L10n.tr("Scanning local network for SMB 2/3 and NFS hosts...", "正在扫描同一局域网下的 SMB 2/3 与 NFS 设备…"))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary.opacity(0.8))
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(smbService.discoveredHosts) { item in
                                hostChipButton(item)
                            }
                        }
                    }
                }
            }

            // Form Fields
            VStack(spacing: 9) {
                labeledField(L10n.tr("Protocol", "共享协议")) {
                    Picker("", selection: $shareProtocol) {
                        ForEach(SilkNetworkShareProtocol.allCases, id: \.self) { proto in
                            Text(proto.displayName).tag(proto)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(maxWidth: 220, alignment: .leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                labeledField(L10n.tr("Server IP / Host", "服务器 IP 或域名")) {
                    TextField(
                        shareProtocol == .nfs ? "192.168.100.234 / nfs://192.168.100.234/volume1/video" : "192.168.100.234 / nas.local",
                        text: $host
                    )
                    .textFieldStyle(.roundedBorder)
                }
                labeledField(shareProtocol == .nfs ? L10n.tr("Export Path", "NFS 导出路径") : L10n.tr("Manual Share", "手动指定共享名")) {
                    HStack(spacing: 6) {
                        TextField(
                            shareProtocol == .nfs
                                ? L10n.tr("/volume1/video (optional if browsing)", "/volume1/video（选填，可在下方探测列表勾选）")
                                : L10n.tr("Optional if picking from tree below", "选填（可在下方树状列表中展开勾选）"),
                            text: $share
                        )
                        .textFieldStyle(.roundedBorder)
                        Button {
                            probeShares()
                        } label: {
                            if isProbingShares {
                                ProgressView()
                                    .controlSize(.small)
                                    .scaleEffect(0.75)
                                    .frame(width: 68)
                            } else {
                                Text(L10n.tr("Browse", "探测目录"))
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(parsedHostInput.host.isEmpty || isProbingShares || isMounting)
                    }
                }

                if !availableShares.isEmpty {
                    shareTreePickerSection
                }

                labeledField(L10n.tr("Display Name", "显示名称")) {
                    TextField(L10n.tr("Optional (e.g. Home NAS)", "选填（默认使用主机/共享名）"), text: $displayName)
                        .textFieldStyle(.roundedBorder)
                }

                if shareProtocol == .smb {
                    Toggle(L10n.tr("Connect as Guest (No Password)", "以访客身份免密只读连接"), isOn: $isGuest)
                        .toggleStyle(.checkbox)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if !isGuest {
                        labeledField(L10n.tr("Username", "用户名")) {
                            TextField(L10n.tr("root / admin (blank uses Finder Keychain)", "root / admin（留空尝试访达钥匙串）"), text: $username)
                                .textFieldStyle(.roundedBorder)
                        }
                        labeledField(L10n.tr("Password", "密码")) {
                            SecureField(L10n.tr("•••••••• (optional if saved in Finder)", "••••••••（已在访达记住密码可留空）"), text: $password)
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                }

                Toggle(L10n.tr("Update automatically on launch", "启动时自动更新此媒体源"), isOn: $autoScan)
                    .toggleStyle(.checkbox)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let errorMessage {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .padding(.top, 2)
                    Text(errorMessage)
                        .font(.system(size: 11.5))
                        .foregroundColor(.orange)
                        .lineLimit(4)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack {
                Spacer()
                Button {
                    if availableShares.isEmpty && activeShareSpecs.isEmpty {
                        probeShares()
                    } else {
                        submitMount()
                    }
                } label: {
                    HStack(spacing: 6) {
                        if isMounting || isProbingShares {
                            ProgressView().controlSize(.small).scaleEffect(0.75)
                        }
                        Text(primaryButtonTitle)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(parsedHostInput.host.isEmpty || isMounting || isProbingShares || (!availableShares.isEmpty && activeShareSpecs.isEmpty))
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 540)
        .onAppear {
            smbService.startDiscovery()
        }
        .onDisappear {
            smbService.stopDiscovery()
        }
        .onChange(of: host) { _, newValue in
            syncHostChange(newValue)
        }
        .onChange(of: shareProtocol) { _, _ in
            resetTreeForHost(parsedHostInput.host)
        }
    }

    private func hostChipButton(_ item: SilkSMBBrowseHost) -> some View {
        let isActive = parsedHostInput.host.caseInsensitiveCompare(item.host) == .orderedSame && shareProtocol == item.shareProtocol
        return Button {
            selectDiscoveredHost(item)
        } label: {
            HStack(spacing: 5) {
                Image(systemName: item.isMounted ? "externaldrive.connected.to.line.below.fill" : "server.rack")
                    .font(.system(size: 10.5))
                    .foregroundColor(item.isMounted ? .green : .secondary)
                Text(item.name)
                    .font(.system(size: 11.5, weight: .medium))
                Text(item.shareProtocol == .nfs ? "NFS" : "SMB")
                    .font(.system(size: 9, weight: .semibold))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Capsule().fill(Color.primary.opacity(0.08)))
                    .foregroundColor(.secondary)
                if item.isMounted {
                    Text(L10n.tr("Mounted", "已挂载"))
                        .font(.system(size: 9.5, weight: .semibold))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(Color.green.opacity(0.18)))
                        .foregroundColor(.green)
                }
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isActive ? Color.accentColor.opacity(0.18) : Color.primary.opacity(0.06))
            )
        }
        .buttonStyle(.plain)
    }

    private var shareTreePickerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(L10n.tr("Select Drives or Expand ▸ to Filter Folders", "勾选磁盘或点击 ▸ 展开筛选文件夹（未勾选目录不会进入片库）"))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                Spacer()
            }

            ScrollView(.vertical, showsIndicators: true) {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(treeRows) { row in
                        SilkFolderTreeNodeRow(
                            row: row,
                            onToggleExpand: {
                                toggleExpandNode(shareName: row.shareName, relativePath: row.relativePath)
                            },
                            onToggleCheck: {
                                toggleCheckNode(shareName: row.shareName, relativePath: row.relativePath)
                            }
                        )
                    }
                }
                .padding(.vertical, 4)
            }
            .frame(minHeight: 110, maxHeight: 190)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color.primary.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.09), lineWidth: 1)
            )
        }
    }

    private func labeledField<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
                .frame(width: 118, alignment: .trailing)
            content()
        }
    }

    private func selectDiscoveredHost(_ item: SilkSMBBrowseHost) {
        shareProtocol = item.shareProtocol
        host = item.host
        if displayName.isEmpty { displayName = item.name }
        errorMessage = nil
        resetTreeForHost(item.host)
        lastLoadedHost = item.host
        probeShares()
    }

    private func resetTreeForHost(_ parsedHost: String) {
        childrenByNodeKey.removeAll()
        expandedNodeKeys.removeAll()
        loadingNodeKeys.removeAll()
        emptyLeafKeys.removeAll()
        shareRules.removeAll()
        availableShares = parsedHost.isEmpty
            ? []
            : SilkSMBMountService.listMountedShares(forHost: parsedHost, shareProtocol: shareProtocol)
        for entry in availableShares {
            shareRules[entry.name] = SilkFolderSelectionRule(emptyUnselected: true)
        }
    }

    private func syncHostChange(_ rawValue: String) {
        let parsed = SilkSMBMountService.parseNetworkInput(rawValue)
        let lowerRaw = rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if lowerRaw.hasPrefix("nfs://") && shareProtocol != .nfs {
            shareProtocol = .nfs
        } else if lowerRaw.hasPrefix("smb://") && shareProtocol != .smb {
            shareProtocol = .smb
        }
        guard parsed.host != lastLoadedHost else { return }
        lastLoadedHost = parsed.host
        errorMessage = nil

        if let parsedUser = parsed.username?.nilIfEmpty, username.isEmpty {
            username = parsedUser
            isGuest = false
        }
        if let parsedPass = parsed.password?.nilIfEmpty, password.isEmpty {
            password = parsedPass
        }
        if let parsedShare = parsed.share?.nilIfEmpty, share.isEmpty {
            share = parsedShare
        }

        resetTreeForHost(parsed.host)
    }

    private func toggleCheckNode(shareName: String, relativePath: String) {
        var rule = shareRules[shareName] ?? SilkFolderSelectionRule(emptyUnselected: true)
        rule.toggle(relativePath)
        shareRules[shareName] = rule
    }

    private func toggleExpandNode(shareName: String, relativePath: String) {
        let key = Self.nodeKey(share: shareName, relativePath: relativePath)
        if expandedNodeKeys.contains(key) {
            expandedNodeKeys.remove(key)
            return
        }
        expandedNodeKeys.insert(key)
        guard childrenByNodeKey[key] == nil, !loadingNodeKeys.contains(key) else { return }

        let parsed = parsedHostInput
        guard !parsed.host.isEmpty else { return }
        let activeProtocol = shareProtocol
        let effectiveUser = activeProtocol == .nfs ? "" : (username.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? parsed.username ?? "")
        let effectivePass = activeProtocol == .nfs ? "" : (password.isEmpty ? (parsed.password ?? "") : password)

        loadingNodeKeys.insert(key)
        errorMessage = nil
        Task {
            let result = await smbService.listSubfolders(
                host: parsed.host,
                share: shareName,
                shareProtocol: activeProtocol,
                relativePath: relativePath,
                username: effectiveUser,
                password: effectivePass,
                isGuest: isGuest
            )
            loadingNodeKeys.remove(key)
            switch result {
            case .success(let folders):
                childrenByNodeKey[key] = folders
                if folders.isEmpty {
                    emptyLeafKeys.insert(key)
                }
                if relativePath.isEmpty,
                   let idx = availableShares.firstIndex(where: { $0.name == shareName }),
                   availableShares[idx].mountedPath == nil,
                   let mountedNow = SilkSMBMountService.findExistingMountPath(host: parsed.host, share: shareName, shareProtocol: activeProtocol) {
                    availableShares[idx] = SilkSMBShareEntry(
                        name: availableShares[idx].name,
                        comment: availableShares[idx].comment,
                        mountedPath: mountedNow
                    )
                }
            case .failure(let err):
                expandedNodeKeys.remove(key)
                errorMessage = err.localizedDescription
            }
        }
    }

    private func probeShares() {
        let parsed = parsedHostInput
        guard !parsed.host.isEmpty else { return }
        let activeProtocol = shareProtocol
        let probeUser = activeProtocol == .nfs ? "" : (username.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? parsed.username ?? "")
        let probePass = activeProtocol == .nfs ? "" : (password.isEmpty ? (parsed.password ?? "") : password)

        isProbingShares = true
        errorMessage = nil
        Task {
            let result = await smbService.listShares(
                host: parsed.host,
                shareProtocol: activeProtocol,
                username: probeUser,
                password: probePass,
                isGuest: isGuest
            )
            isProbingShares = false
            switch result {
            case .shares(let entries):
                let sorted = entries.sorted { lhs, rhs in
                    let lMounted = lhs.mountedPath != nil
                    let rMounted = rhs.mountedPath != nil
                    if lMounted != rMounted { return lMounted && !rMounted }
                    return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
                }
                availableShares = sorted
                for entry in sorted where shareRules[entry.name] == nil {
                    shareRules[entry.name] = SilkFolderSelectionRule(emptyUnselected: true)
                }
                if sorted.isEmpty {
                    errorMessage = L10n.tr(
                        "Connected, but no mountable shares were returned. You can enter Manual Share / Export Path instead.",
                        "已连接到主机，但未返回可枚举的共享目录；你仍可手动填写共享名或导出路径。"
                    )
                }
            case .failure(let message):
                errorMessage = message
            @unknown default:
                break
            }
        }
    }

    private func submitMount() {
        let parsed = parsedHostInput
        let targetHost = parsed.host
        let specs = activeShareSpecs
        guard !targetHost.isEmpty else { return }
        if specs.isEmpty {
            probeShares()
            return
        }

        let activeProtocol = shareProtocol
        let effectiveUsername = activeProtocol == .nfs ? "" : (username.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? parsed.username ?? "")
        let effectivePassword = activeProtocol == .nfs ? "" : (password.isEmpty ? (parsed.password ?? "") : password)
        let effectiveGuest = activeProtocol == .nfs ? true : isGuest
        let customDisplay = displayName.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        let autoScanEnabled = autoScan

        isMounting = true
        errorMessage = nil
        Task {
            var mountedIds: [String] = []
            var errors: [String] = []

            await withTaskGroup(of: (String, Result<SilkLibrarySource, Error>).self) { group in
                for spec in specs {
                    let perShareName: String?
                    if specs.count == 1 {
                        perShareName = customDisplay
                    } else if let customDisplay {
                        perShareName = "\(customDisplay) · \(spec.name)"
                    } else {
                        perShareName = nil
                    }
                    let included = spec.rule.exportedIncludedRelativePaths
                    let excluded = spec.rule.exportedExcludedRelativePaths

                    group.addTask {
                        let res = await SilkMediaLibraryEngine.shared.addSMBSource(
                            host: targetHost,
                            share: spec.name,
                            shareProtocol: activeProtocol,
                            username: effectiveUsername,
                            password: effectivePassword,
                            isGuest: effectiveGuest,
                            displayName: perShareName,
                            autoScan: autoScanEnabled,
                            includedRelativePaths: included,
                            excludedRelativePaths: excluded,
                            scanImmediately: false
                        )
                        return (spec.name, res)
                    }
                }

                for await (shareName, result) in group {
                    switch result {
                    case .success(let source):
                        mountedIds.append(source.id)
                        shareRules[shareName] = SilkFolderSelectionRule(emptyUnselected: true)
                    case .failure(let err):
                        errors.append("\(shareName): \(err.localizedDescription)")
                    }
                }
            }

            isMounting = false
            if !mountedIds.isEmpty {
                library.enqueueBackgroundRescan(sourceIds: mountedIds)
            }
            if errors.isEmpty {
                dismiss()
                onMounted?()
            } else {
                errorMessage = errors.joined(separator: "\n")
            }
        }
    }
}

// MARK: - Sources Management & Per-Source Folder Filter Sheets

@MainActor
private struct SilkSourcesManagerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var library = SilkMediaLibraryEngine.shared
    var onAddSMB: () -> Void
    @State private var editingFoldersSource: SilkLibrarySource? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(L10n.tr("Manage Media Sources", "媒体源管理"))
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                Button(L10n.tr("Done", "完成")) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }

            Divider()

            if library.sources.isEmpty {
                Text(L10n.tr("No media folders added yet.", "尚未添加任何本地、SMB 或 NFS 媒体源。"))
                    .font(.system(size: 12.5))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 120)
            } else {
                List {
                    ForEach(library.sources) { source in
                        HStack(spacing: 10) {
                            Image(systemName: (source.kind == .smb || source.kind == .nfs) ? "network" : "folder.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.accentColor)

                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(source.displayName)
                                        .font(.system(size: 13, weight: .medium))
                                    if source.kind == .smb || source.kind == .nfs {
                                        Text(source.kind == .nfs ? "NFS" : "SMB")
                                            .font(.system(size: 9.5, weight: .semibold))
                                            .padding(.horizontal, 4)
                                            .padding(.vertical, 1)
                                            .background(Capsule().fill(Color.primary.opacity(0.08)))
                                            .foregroundColor(.secondary)
                                    }
                                    if !source.includedRelativePaths.isEmpty || !source.excludedRelativePaths.isEmpty {
                                        let rule = SilkFolderSelectionRule(
                                            includedRelativePaths: source.includedRelativePaths,
                                            excludedRelativePaths: source.excludedRelativePaths
                                        )
                                        Text(rule.summaryLabel)
                                            .font(.system(size: 9.5, weight: .semibold))
                                            .foregroundColor(.accentColor)
                                            .padding(.horizontal, 5)
                                            .padding(.vertical, 1)
                                            .background(Capsule().fill(Color.accentColor.opacity(0.12)))
                                    }
                                }
                                Text("\(source.path) · \(source.itemCount) items")
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }

                            Spacer()

                            Button {
                                editingFoldersSource = source
                            } label: {
                                Image(systemName: "folder.badge.gearshape")
                            }
                            .buttonStyle(.borderless)
                            .help(L10n.tr("Filter Included/Excluded Subfolders", "树状筛选包含或排除的子文件夹"))

                            Toggle("", isOn: Binding(
                                get: { source.autoScan },
                                set: { newVal in
                                    Task { await library.updateSourceAutoScan(id: source.id, enabled: newVal) }
                                }
                            ))
                            .labelsHidden()
                            .help(L10n.tr("Auto-scan on startup", "启动时自动更新媒体源"))

                            Button {
                                library.enqueueBackgroundRescan(sourceIds: [source.id])
                            } label: {
                                Image(systemName: "arrow.clockwise")
                            }
                            .buttonStyle(.borderless)
                            .disabled(library.isScanning)

                            Button {
                                Task { await library.removeSource(id: source.id) }
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.borderless)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .frame(minHeight: 200, maxHeight: 280)
            }

            HStack {
                Button {
                    onAddSMB()
                } label: {
                    Label(L10n.tr("Add SMB 2/3 / NFS...", "新增 SMB 2/3 / NFS…"), systemImage: "network")
                }

                Button {
                    NSCursor.unhide()
                    let panel = NSOpenPanel()
                    panel.canChooseFiles = false
                    panel.canChooseDirectories = true
                    panel.allowsMultipleSelection = false
                    if panel.runModal() == .OK, let url = panel.url {
                        Task {
                            if let added = await library.addLocalSource(url: url, scanImmediately: false) {
                                library.enqueueBackgroundRescan(sourceIds: [added.id])
                            }
                        }
                    }
                    NSCursor.unhide()
                } label: {
                    Label(L10n.tr("Add Local Folder...", "新增本机目录…"), systemImage: "folder.badge.plus")
                }

                Spacer()
            }
        }
        .padding(20)
        .frame(width: 560)
        .sheet(item: $editingFoldersSource) { src in
            SilkSourceFoldersSheet(source: src)
        }
    }
}

@MainActor
private struct SilkSourceFoldersSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var library = SilkMediaLibraryEngine.shared
    let source: SilkLibrarySource

    @State private var rule: SilkFolderSelectionRule
    @State private var childrenByRelPath: [String: [SilkFolderEntry]] = [:]
    @State private var expandedRelPaths: Set<String> = [""]
    @State private var loadingRelPaths: Set<String> = []
    @State private var emptyLeafRelPaths: Set<String> = []
    @State private var isSaving: Bool = false
    @State private var errorMessage: String? = nil

    init(source: SilkLibrarySource) {
        self.source = source
        _rule = State(initialValue: SilkFolderSelectionRule(
            includedRelativePaths: source.includedRelativePaths,
            excludedRelativePaths: source.excludedRelativePaths
        ))
    }

    private var visibleRows: [SilkFolderTreeRowItem] {
        var rows: [SilkFolderTreeRowItem] = [
            SilkFolderTreeRowItem(
                id: "__root__",
                shareName: source.displayName,
                relativePath: "",
                title: source.displayName,
                depth: 0,
                isShareRoot: true,
                isMounted: true,
                isExpanded: expandedRelPaths.contains(""),
                isLoading: loadingRelPaths.contains(""),
                isKnownEmptyLeaf: emptyLeafRelPaths.contains(""),
                checkState: rule.state(for: ""),
                summaryText: rule.isActive ? rule.summaryLabel : L10n.tr("None selected", "未选择任何目录")
            )
        ]

        func appendChildren(parentRel: String, depth: Int) {
            guard expandedRelPaths.contains(parentRel), let children = childrenByRelPath[parentRel] else { return }
            for child in children {
                let expanded = expandedRelPaths.contains(child.relativePath)
                rows.append(SilkFolderTreeRowItem(
                    id: child.relativePath,
                    shareName: source.displayName,
                    relativePath: child.relativePath,
                    title: child.name,
                    depth: depth,
                    isShareRoot: false,
                    isMounted: false,
                    isExpanded: expanded,
                    isLoading: loadingRelPaths.contains(child.relativePath),
                    isKnownEmptyLeaf: emptyLeafRelPaths.contains(child.relativePath),
                    checkState: rule.state(for: child.relativePath),
                    summaryText: nil
                ))
                if expanded {
                    appendChildren(parentRel: child.relativePath, depth: depth + 1)
                }
            }
        }

        if expandedRelPaths.contains("") {
            appendChildren(parentRel: "", depth: 1)
        }
        return rows
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.tr("Filter Source Directories", "树状目录白名单 / 敏感目录屏蔽"))
                        .font(.system(size: 15, weight: .semibold))
                    Text(L10n.tr("Unchecked folders are never scanned or exposed inside SilkPlayer.", "未勾选的子目录将立即从媒体库清理且永不被扫描读取。"))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button(L10n.tr("Cancel", "取消")) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }

            Divider()

            ScrollView(.vertical, showsIndicators: true) {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(visibleRows) { row in
                        SilkFolderTreeNodeRow(
                            row: row,
                            onToggleExpand: {
                                toggleExpand(row.relativePath)
                            },
                            onToggleCheck: {
                                rule.toggle(row.relativePath)
                            }
                        )
                    }
                }
                .padding(.vertical, 6)
            }
            .frame(minHeight: 220, maxHeight: 300)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.primary.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.09), lineWidth: 1)
            )

            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 11.5))
                    .foregroundColor(.orange)
            }

            HStack {
                Spacer()
                Button {
                    saveAndApply()
                } label: {
                    if isSaving {
                        ProgressView().controlSize(.small).scaleEffect(0.75)
                    } else {
                        Text(L10n.tr("Apply & Sync Library", "应用并同步媒体库"))
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isSaving || !rule.isActive)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 480)
        .onAppear {
            loadChildrenIfNeeded(for: "")
        }
    }

    private func toggleExpand(_ relativePath: String) {
        if expandedRelPaths.contains(relativePath) {
            expandedRelPaths.remove(relativePath)
        } else {
            expandedRelPaths.insert(relativePath)
            loadChildrenIfNeeded(for: relativePath)
        }
    }

    private func loadChildrenIfNeeded(for relativePath: String) {
        guard childrenByRelPath[relativePath] == nil, !loadingRelPaths.contains(relativePath) else { return }
        loadingRelPaths.insert(relativePath)
        errorMessage = nil

        Task {
            let result: Result<[SilkFolderEntry], Error>
            if (source.kind == .smb || source.kind == .nfs), let host = source.smbHost, let share = source.smbShare {
                let user = source.smbUsername ?? ""
                let isGuest = user.lowercased() == "guest"
                let proto: SilkNetworkShareProtocol = source.kind == .nfs ? .nfs : .smb
                result = await SilkSMBMountService.shared.listSubfolders(
                    host: host,
                    share: share,
                    shareProtocol: proto,
                    relativePath: relativePath,
                    username: (proto == .nfs || isGuest) ? "" : user,
                    password: "",
                    isGuest: proto == .nfs ? true : isGuest
                )
            } else {
                let rootPath = source.path
                let entries = await Task.detached(priority: .userInitiated) {
                    SilkSMBMountService.listImmediateSubfolders(rootPath: rootPath, relativePath: relativePath)
                }.value
                result = .success(entries)
            }

            loadingRelPaths.remove(relativePath)
            switch result {
            case .success(let folders):
                childrenByRelPath[relativePath] = folders
                if folders.isEmpty {
                    emptyLeafRelPaths.insert(relativePath)
                }
            case .failure(let err):
                if !relativePath.isEmpty {
                    expandedRelPaths.remove(relativePath)
                }
                errorMessage = err.localizedDescription
            }
        }
    }

    private func saveAndApply() {
        isSaving = true
        Task {
            await library.updateSourceFolderFilters(
                id: source.id,
                includedRelativePaths: rule.exportedIncludedRelativePaths,
                excludedRelativePaths: rule.exportedExcludedRelativePaths,
                rescan: true
            )
            isSaving = false
            dismiss()
        }
    }
}

// MARK: - Left-Edge Frosted LAN Sources Handle & Sidebar Drawer

public struct LeftLANSourceHandleTab: View {
    public let isDrawerVisible: Bool
    public let drawerWidth: CGFloat
    public var onHoverChange: ((Bool) -> Void)? = nil
    public let action: () -> Void

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
            SilkDrawerHandleRepresentable(
                isDrawerVisible: isDrawerVisible,
                isLeadingEdge: true,
                onHoverChange: onHoverChange,
                action: action
            )
            .frame(width: 28, height: 128)
            .help(L10n.tr("LAN & Media Sources", "局域网与媒体源"))
            .opacity(isDrawerVisible ? 0.0 : 1.0)
            .allowsHitTesting(!isDrawerVisible)

            Spacer()
                .allowsHitTesting(false)
        }
    }
}

@MainActor
public struct SilkLANSourceDrawerView: View {
    @ObservedObject var library = SilkMediaLibraryEngine.shared
    public var drawerWidth: CGFloat
    public var onCompletedConfiguration: () -> Void
    public var onClose: () -> Void

    @State private var showMountSheet: Bool = false
    @State private var editingFoldersSource: SilkLibrarySource? = nil

    public init(
        drawerWidth: CGFloat = 300,
        onCompletedConfiguration: @escaping () -> Void,
        onClose: @escaping () -> Void
    ) {
        self.drawerWidth = drawerWidth
        self.onCompletedConfiguration = onCompletedConfiguration
        self.onClose = onClose
    }

    public var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider().opacity(0.18)

            actionButtonsBar
            Divider().opacity(0.12)

            sourcesListBody

            if !library.sources.isEmpty {
                Divider().opacity(0.14)
                footerBar
            }
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
        .shadow(color: Color.black.opacity(0.45), radius: 24, x: 6, y: 4)
        .shadow(color: Color.black.opacity(0.20), radius: 6, x: 2, y: 2)
        .sheet(isPresented: $showMountSheet) {
            SilkSMBMountSheet(onMounted: {
                onCompletedConfiguration()
            })
        }
        .sheet(item: $editingFoldersSource) { src in
            SilkSourceFoldersSheet(source: src)
        }
    }

    private var headerBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "network")
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundColor(.white.opacity(0.85))
            Text(L10n.tr("LAN & Media Sources", "局域网与媒体源"))
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
            Spacer()
            Button {
                onClose()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(Color.white.opacity(0.08)))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private var actionButtonsBar: some View {
        HStack(spacing: 8) {
            Button {
                showMountSheet = true
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "plus")
                        .font(.system(size: 10.5, weight: .bold))
                    Text(L10n.tr("SMB 2/3 / NFS", "SMB 2/3 / NFS"))
                        .font(.system(size: 11.5, weight: .medium))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Color.accentColor.opacity(0.22)))
                .foregroundColor(.white)
            }
            .buttonStyle(.plain)

            Button {
                pickLocalFolder()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 11))
                    Text(L10n.tr("Local Folder", "本机目录"))
                        .font(.system(size: 11.5, weight: .medium))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Color.white.opacity(0.09)))
                .foregroundColor(.white.opacity(0.9))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private var sourcesListBody: some View {
        if library.sources.isEmpty {
            VStack(spacing: 10) {
                Spacer()
                Image(systemName: "externaldrive.connected.to.line.below")
                    .font(.system(size: 26))
                    .foregroundColor(.white.opacity(0.35))
                Text(L10n.tr("No LAN or local sources yet", "尚未接入局域网或本机媒体源"))
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                Text(L10n.tr("Add an SMB 2/3 share, NFS export, or local folder above to enter the media library.", "在上方添加 SMB 2/3、NFS 共享或本机目录并勾选文件夹后，将自动进入媒体库。"))
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView(.vertical, showsIndicators: true) {
                LazyVStack(spacing: 6) {
                    ForEach(library.sources) { source in
                        drawerSourceRow(source)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
        }
    }

    private func drawerSourceRow(_ source: SilkLibrarySource) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: (source.kind == .smb || source.kind == .nfs) ? "network" : "folder.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.accentColor)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 5) {
                        Text(source.displayName)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                            .lineLimit(1)

                        Text(source.kind == .nfs ? "NFS" : (source.kind == .smb ? "SMB" : L10n.tr("Local", "本机")))
                            .font(.system(size: 9, weight: .semibold))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(Color.white.opacity(0.12)))
                            .foregroundColor(.white.opacity(0.8))
                    }

                    Text("\(source.path) · \(source.itemCount)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.white.opacity(0.55))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer(minLength: 4)
            }

            HStack(spacing: 8) {
                if !source.includedRelativePaths.isEmpty || !source.excludedRelativePaths.isEmpty {
                    let rule = SilkFolderSelectionRule(
                        includedRelativePaths: source.includedRelativePaths,
                        excludedRelativePaths: source.excludedRelativePaths
                    )
                    Text(rule.summaryLabel)
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundColor(.accentColor)
                        .lineLimit(1)
                }

                Spacer()

                Button {
                    editingFoldersSource = source
                } label: {
                    Image(systemName: "folder.badge.gearshape")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.75))
                }
                .buttonStyle(.plain)
                .help(L10n.tr("Select Folders", "勾选子目录"))

                Button {
                    library.enqueueBackgroundRescan(sourceIds: [source.id])
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.75))
                }
                .buttonStyle(.plain)
                .disabled(library.isScanning)
                .help(L10n.tr("Rescan", "重新扫描"))

                Button {
                    Task { await library.removeSource(id: source.id) }
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                        .foregroundColor(.red.opacity(0.85))
                }
                .buttonStyle(.plain)
                .help(L10n.tr("Remove Source", "移除媒体源"))
            }
        }
        .padding(9)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.white.opacity(0.06)))
    }

    private var footerBar: some View {
        HStack {
            if library.isScanning {
                HStack(spacing: 5) {
                    ProgressView().controlSize(.small).scaleEffect(0.6)
                    Text(L10n.tr("Indexing...", "正在索引…"))
                        .font(.system(size: 10.5))
                        .foregroundColor(.white.opacity(0.65))
                }
            }
            Spacer()
            Button {
                onCompletedConfiguration()
            } label: {
                Text(L10n.tr("Enter Media Library", "确认进入媒体库"))
                    .font(.system(size: 11.5, weight: .semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Color.accentColor))
                    .foregroundColor(.white)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private func pickLocalFolder() {
        NSCursor.unhide()
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            Task {
                if let added = await library.addLocalSource(url: url, scanImmediately: false) {
                    library.enqueueBackgroundRescan(sourceIds: [added.id])
                    onCompletedConfiguration()
                }
            }
        }
        NSCursor.unhide()
    }
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
