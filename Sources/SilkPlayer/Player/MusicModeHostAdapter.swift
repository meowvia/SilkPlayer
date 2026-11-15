import SwiftUI
import AppKit
import Combine
import SilkCoreKit

/// Open-source host bridge forwarding playback, playlist, window, and shared HUD chrome into `SilkMusicModeView`.
@MainActor
public final class SilkMusicPlayerHost: SilkMusicModeHost {
    public let player: PlayerCore
    public let playlist: PlaylistManager
    public var onSelectPlaylistItem: (PlaylistItem) -> Void
    public var onClosePlayback: () -> Void

    private var settings = AppSettings.shared
    private var cancellables: Set<AnyCancellable> = []

    public init(
        player: PlayerCore,
        playlist: PlaylistManager,
        onSelectPlaylistItem: @escaping (PlaylistItem) -> Void,
        onClosePlayback: @escaping () -> Void
    ) {
        self.player = player
        self.playlist = playlist
        self.onSelectPlaylistItem = onSelectPlaylistItem
        self.onClosePlayback = onClosePlayback

        player.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    public var isPlaying: Bool { player.isPlaying }
    public var isAudioOnly: Bool { player.isAudioOnly }
    public var isMuted: Bool { player.isMuted }
    public var volume: Double { player.volume }
    public var maxVolumeLimit: Double { settings.maxVolumeLimit }
    public var duration: Double { player.duration }
    public var mediaTitle: String { player.mediaTitle }
    public var currentFilePath: String? { player.currentFilePath }
    public var artworkImage: NSImage? { player.artworkImage }
    public var audioRhythmLevels: [CGFloat] { player.audioRhythmLevels }
    public var canRewindToStart: Bool { player.canRewindToStart }
    public var isFullscreen: Bool { player.isFullscreen }
    public var hostWindow: NSWindow? { player.hostWindow }

    public var activeAudioCodec: String? {
        if let codec = player.audioTracks.first(where: { $0.id == player.selectedAudioTrackId })?.codec,
           !codec.isEmpty {
            return codec.uppercased()
        }
        return nil
    }

    public var isMusicQueueCollapsed: Bool { settings.isMusicQueueCollapsed }
    public var keepWindowOnTop: Bool { settings.keepWindowOnTop }
    public var dualPlaylistMode: Bool { settings.dualPlaylistMode }
    public var activeMediaCategory: SilkMusicMediaCategory {
        Self.mapCategory(playlist.activeCategory)
    }

    public var audioCount: Int { playlist.audioCount }
    public var videoCount: Int { playlist.videoCount }
    public var audioCurrentIndex: Int { playlist.audioCurrentIndex }
    public var audioQueueItems: [SilkMusicQueueEntry] { playlist.audioItems.map(Self.makeEntry) }
    public var videoQueueItems: [SilkMusicQueueEntry] { playlist.videoItems.map(Self.makeEntry) }
    public var unifiedQueueItems: [SilkMusicQueueEntry] { playlist.unifiedItems.map(Self.makeEntry) }
    public var currentPlaylistEntry: SilkMusicQueueEntry? { playlist.currentItem.map(Self.makeEntry) }
    public var upcomingQueueEntry: SilkMusicQueueEntry? { playlist.upcomingItem.map(Self.makeEntry) }
    public var hasPreviousTrack: Bool { playlist.hasPrevious }
    public var hasNextTrack: Bool { playlist.hasNext }

    public var isSingleLoopMode: Bool { playlist.playbackMode == .singleLoop }
    public var isNonSequentialPlaybackMode: Bool { playlist.playbackMode != .sequential }
    public var playbackModeIconName: String { playlist.playbackMode.iconName }
    public var playbackModeTitle: String { playlist.playbackMode.title }

    public var sortOptions: [SilkMusicSortOptionItem] {
        PlaylistSortOrder.allCases.map {
            SilkMusicSortOptionItem(id: $0.rawValue, title: $0.title, iconName: "")
        }
    }

    public var currentSortOptionID: String { playlist.audioSortOrder.rawValue }
    public var isSortAscending: Bool { playlist.audioSortDirection == .ascending }

    public func isSettingsWindow(_ window: NSWindow) -> Bool {
        if let settingsWin = PlayerWindowManager.shared.settingsWindow {
            return window === settingsWin
        }
        return false
    }

    public func toggleAlwaysOnTop() {
        PlayerWindowManager.shared.toggleAlwaysOnTop()
        objectWillChange.send()
    }

    public func togglePlayPause() {
        player.togglePlayPause()
    }

    public func seek(to time: Double) {
        player.seek(to: time)
    }

    public func toggleMute() {
        player.toggleMute()
    }

    public func setVolume(_ volume: Double, maxLimit: Double, showOSD: Bool) {
        player.setVolume(volume, maxLimit: maxLimit, showOSD: showOSD)
    }

    public func cyclePlaybackModeAndShowOSD() {
        playlist.togglePlaybackMode()
        objectWillChange.send()
    }

    public func toggleMusicQueueCollapsed() {
        player.toggleMusicQueueCollapsed()
        objectWillChange.send()
    }

    public func setMusicQueueCollapsed(_ collapsed: Bool, animated: Bool) {
        player.setMusicQueueCollapsed(collapsed, animated: animated)
        objectWillChange.send()
    }

    public func openSettings() {
        PlayerWindowManager.shared.openSettings()
    }

    public func dismissAuxiliaryDrawersForClose() {
        player.isPlaylistDrawerVisible = false
        player.isInspectorVisible = false
    }

    public func minimizeToStatusBar() {
        SilkStatusBarManager.shared.enterBackgroundMode(window: player.hostWindow)
    }

    public func beginWindowDrag(on window: NSWindow, with event: NSEvent) {
        MusicWindowDragCoordinator.shared.beginDrag(on: window, with: event)
    }

    public func cleanDisplayTitle(_ raw: String) -> String {
        MediaFilenameSanitizer.sanitize(raw).cleanTitle
    }

    public func switchPlaylistCategory(_ category: SilkMusicMediaCategory) {
        playlist.switchCategory(Self.unmapCategory(category))
        objectWillChange.send()
    }

    public func importMediaPaths(_ paths: [String], onAdded: @escaping @MainActor ([SilkMusicQueueEntry]) -> Void) {
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

            Task { @MainActor [weak self] in
                guard let self else { return }
                let wasEmpty = self.playlist.isEmpty
                let needsAutoPlay = wasEmpty || !self.player.isLoaded
                self.playlist.appendItems(newItems)
                let entries = newItems.map { Self.makeEntry($0) }
                self.objectWillChange.send()
                onAdded(entries)
                if needsAutoPlay, let target = newItems.first {
                    let category = PlaylistManager.category(for: target.url)
                    self.selectQueueItem(id: target.id, in: Self.mapCategory(category))
                }
            }
        }
    }

    public func clearPlaylist(category: SilkMusicMediaCategory?) {
        if let category {
            playlist.clearCategory(Self.unmapCategory(category))
        } else {
            playlist.clear()
        }
        objectWillChange.send()
    }

    public func removePlaylistItem(id: UUID, in category: SilkMusicMediaCategory?) {
        if let category {
            playlist.removeItem(id: id, inCategory: Self.unmapCategory(category))
        } else {
            playlist.removeItem(id: id)
        }
        objectWillChange.send()
    }

    public func selectQueueItem(id: UUID, in category: SilkMusicMediaCategory) {
        let mappedCategory = Self.unmapCategory(category)
        if settings.dualPlaylistMode && playlist.activeCategory != mappedCategory {
            playlist.switchCategory(mappedCategory)
        }
        let pool = mappedCategory == .video ? playlist.videoItems : playlist.audioItems
        if let item = pool.first(where: { $0.id == id })
            ?? playlist.unifiedItems.first(where: { $0.id == id }) {
            onSelectPlaylistItem(item)
        }
        objectWillChange.send()
    }

    public func sortAudioQueue(optionID: String, forceDirectionAscending: Bool?) {
        let order = PlaylistSortOrder(rawValue: optionID) ?? .manual
        let direction: SortDirection? = forceDirectionAscending.map { $0 ? .ascending : .descending }
        let metadataService = AudioTrackMetadataService.shared
        playlist.sortAudioItems(
            by: order,
            direction: direction,
            metadataProvider: { metadataService.metadata(for: $0) }
        )
        objectWillChange.send()
    }

    public func toggleAudioSortDirection() {
        let metadataService = AudioTrackMetadataService.shared
        playlist.sortAudioItems(
            by: playlist.audioSortOrder,
            direction: playlist.audioSortDirection.toggled,
            metadataProvider: { metadataService.metadata(for: $0) }
        )
        objectWillChange.send()
    }

    public func makeProgressSectionView(windowWidth: CGFloat, isCollapsed: Bool) -> AnyView {
        let scrubberTier = HUDLayoutTier.determine(width: windowWidth, isFullscreen: false)
        return AnyView(
            PlayerProgressSection(
                player: player,
                clock: player.clock,
                playlist: playlist,
                tier: scrubberTier,
                showsHoverPreview: false,
                compactScrubberHeight: isCollapsed ? 18 : 20
            )
        )
    }

    public func makeSpeedMenuButtonView() -> AnyView {
        AnyView(HUDSpeedMenuButton(player: player))
    }

    public func makeVinylDiscView(diameter: CGFloat, isPlaying: Bool) -> AnyView {
        AnyView(
            FloatingVinylDiscView(
                diameter: diameter,
                isPlaying: isPlaying,
                rhythm: player.audioRhythm
            )
        )
    }

    private static func mapCategory(_ category: MediaCategory) -> SilkMusicMediaCategory {
        category == .video ? .video : .audio
    }

    private static func unmapCategory(_ category: SilkMusicMediaCategory) -> MediaCategory {
        category == .video ? .video : .audio
    }

    private static func makeEntry(_ item: PlaylistItem) -> SilkMusicQueueEntry {
        SilkMusicQueueEntry(
            id: item.id,
            path: item.path,
            title: item.title,
            duration: item.duration,
            isAudio: PlaylistManager.category(for: item.url) == .audio
        )
    }
}

/// Thin wrapper presenting the closed-source `SilkMusicModeView` with SilkPlayer's playback host.
@MainActor
public struct MusicModeView: View {
    @StateObject private var host: SilkMusicPlayerHost
    private let onPlayNext: () -> Void
    private let onPlayPrevious: () -> Void
    private let onClosePlayback: () -> Void

    public init(
        player: PlayerCore,
        playlist: PlaylistManager,
        onPlayNext: @escaping () -> Void,
        onPlayPrevious: @escaping () -> Void,
        onSelectPlaylistItem: @escaping (PlaylistItem) -> Void,
        onClosePlayback: @escaping () -> Void
    ) {
        _host = StateObject(
            wrappedValue: SilkMusicPlayerHost(
                player: player,
                playlist: playlist,
                onSelectPlaylistItem: onSelectPlaylistItem,
                onClosePlayback: onClosePlayback
            )
        )
        self.onPlayNext = onPlayNext
        self.onPlayPrevious = onPlayPrevious
        self.onClosePlayback = onClosePlayback
    }

    public var body: some View {
        SilkMusicModeView(
            host: host,
            onPlayNext: onPlayNext,
            onPlayPrevious: onPlayPrevious,
            onClosePlayback: onClosePlayback
        )
    }

    public static func shouldSuppressAutoScroll(
        suppressedID: UUID?,
        deadline: Date,
        selectedID: UUID?,
        now: Date = Date()
    ) -> Bool {
        SilkMusicModeScrollPolicy.shouldSuppressAutoScroll(
            suppressedID: suppressedID,
            deadline: deadline,
            selectedID: selectedID,
            now: now
        )
    }
}
