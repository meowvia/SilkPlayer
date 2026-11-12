import Observation
import Foundation
import Combine
import SilkCoreKit

public enum MediaCategory: String, CaseIterable, Codable, Sendable {
    case video = "video"
    case audio = "audio"

    public var title: String {
        switch self {
        case .video: return L10n.tr("Videos", "视频")
        case .audio: return L10n.tr("Music", "音乐")
        }
    }

    public var iconName: String {
        switch self {
        case .video: return "film"
        case .audio: return "music.note"
        }
    }
}

@MainActor
@Observable public final class PlaylistManager {
    public nonisolated static let defaultItemsStorageKey = "com.silkplayer.playlist.items"
    public nonisolated static let defaultIndexStorageKey = "com.silkplayer.playlist.currentIndex"
    public nonisolated static let defaultModeStorageKey = "com.silkplayer.playlist.playbackMode"
    public nonisolated static let defaultCategoryStorageKey = "com.silkplayer.playlist.activeCategory"
    public nonisolated static let defaultVideoItemsStorageKey = "com.silkplayer.playlist.video.items"
    public nonisolated static let defaultAudioItemsStorageKey = "com.silkplayer.playlist.audio.items"
    public nonisolated static let defaultVideoIndexStorageKey = "com.silkplayer.playlist.video.currentIndex"
    public nonisolated static let defaultAudioIndexStorageKey = "com.silkplayer.playlist.audio.currentIndex"
    public nonisolated static let defaultVideoShuffleQueueKey = "com.silkplayer.playlist.video.shuffleQueue"
    public nonisolated static let defaultAudioShuffleQueueKey = "com.silkplayer.playlist.audio.shuffleQueue"
    public nonisolated static let defaultVideoPlayHistoryKey = "com.silkplayer.playlist.video.playHistory"
    public nonisolated static let defaultAudioPlayHistoryKey = "com.silkplayer.playlist.audio.playHistory"
    public nonisolated static let defaultVideoRecentKeysStorageKey = "com.silkplayer.playlist.video.recentTrackKeys"
    public nonisolated static let defaultAudioRecentKeysStorageKey = "com.silkplayer.playlist.audio.recentTrackKeys"
    private nonisolated static let maxRecentTrackKeysCount = 500

    public static let shared = PlaylistManager(isPersistenceEnabled: true, autoRestore: true)

    // MARK: - Dual-Track Category State
    public var isDualPlaylistMode: Bool = true {
        didSet {
            handleDualPlaylistModeChange()
        }
    }
    public private(set) var activeCategory: MediaCategory = .video
    public private(set) var videoItems: [PlaylistItem] = []
    public private(set) var audioItems: [PlaylistItem] = []
    public private(set) var unifiedItems: [PlaylistItem] = []
    public private(set) var videoCurrentIndex: Int = -1
    public private(set) var audioCurrentIndex: Int = -1
    public private(set) var unifiedCurrentIndex: Int = -1

    public var videoCount: Int { videoItems.count }
    public var audioCount: Int { audioItems.count }

    public private(set) var items: [PlaylistItem] {
        get {
            if !isDualPlaylistMode {
                return unifiedItems
            }
            return activeCategory == .video ? videoItems : audioItems
        }
        set {
            if !isDualPlaylistMode {
                unifiedItems = newValue
                videoItems = newValue.filter { Self.category(for: $0.url) == .video }
                audioItems = newValue.filter { Self.category(for: $0.url) == .audio }
            } else {
                if activeCategory == .video {
                    videoItems = newValue
                } else {
                    audioItems = newValue
                }
                syncUnifiedItems()
            }
        }
    }

    public private(set) var currentIndex: Int {
        get {
            if !isDualPlaylistMode {
                return unifiedCurrentIndex
            }
            return activeCategory == .video ? videoCurrentIndex : audioCurrentIndex
        }
        set {
            if !isDualPlaylistMode {
                unifiedCurrentIndex = newValue
                if newValue >= 0 && newValue < unifiedItems.count {
                    let cur = unifiedItems[newValue]
                    if Self.category(for: cur.url) == .audio {
                        activeCategory = .audio
                        audioCurrentIndex = audioItems.firstIndex(where: { $0.id == cur.id })
                            ?? audioItems.firstIndex(where: { $0.path == cur.path }) ?? -1
                    } else {
                        activeCategory = .video
                        videoCurrentIndex = videoItems.firstIndex(where: { $0.id == cur.id })
                            ?? videoItems.firstIndex(where: { $0.path == cur.path }) ?? -1
                    }
                } else {
                    videoCurrentIndex = -1
                    audioCurrentIndex = -1
                }
            } else {
                if activeCategory == .video {
                    videoCurrentIndex = newValue
                } else {
                    audioCurrentIndex = newValue
                }
                syncUnifiedCurrentIndex()
            }
        }
    }

    public func applyDualPlaylistMode(_ enabled: Bool) {
        guard isDualPlaylistMode != enabled else { return }
        isDualPlaylistMode = enabled
        saveToStorage()
    }

    private func handleDualPlaylistModeChange() {
        if !isDualPlaylistMode {
            syncUnifiedItems()
            syncUnifiedCurrentIndex()
            if unifiedRecentTrackKeys.isEmpty {
                var seeded: [String] = []
                for path in audioRecentTrackKeys + videoRecentTrackKeys {
                    recordRecentTrack(path: path, in: &seeded)
                }
                if let currentPath = currentItem?.path {
                    recordRecentTrack(path: currentPath, in: &seeded)
                }
                unifiedRecentTrackKeys = seeded
            }
            if playbackMode == .shuffle {
                unifiedShuffleQueue.removeAll()
                ensureShuffleCandidate()
            }
        } else {
            if unifiedCurrentIndex >= 0 && unifiedCurrentIndex < unifiedItems.count {
                let cur = unifiedItems[unifiedCurrentIndex]
                activeCategory = Self.category(for: cur.url)
                if activeCategory == .video {
                    videoCurrentIndex = videoItems.firstIndex(where: { $0.id == cur.id })
                        ?? videoItems.firstIndex(where: { $0.path == cur.path }) ?? -1
                } else {
                    audioCurrentIndex = audioItems.firstIndex(where: { $0.id == cur.id })
                        ?? audioItems.firstIndex(where: { $0.path == cur.path }) ?? -1
                }
            }
            if playbackMode == .shuffle {
                ensureShuffleCandidate()
            }
        }
    }

    private func syncUnifiedItems() {
        unifiedItems = videoItems + audioItems
    }

    private func syncUnifiedCurrentIndex() {
        if activeCategory == .video {
            if videoCurrentIndex >= 0 && videoCurrentIndex < videoItems.count {
                unifiedCurrentIndex = videoCurrentIndex
            } else {
                unifiedCurrentIndex = -1
            }
        } else {
            if audioCurrentIndex >= 0 && audioCurrentIndex < audioItems.count {
                unifiedCurrentIndex = videoItems.count + audioCurrentIndex
            } else {
                unifiedCurrentIndex = -1
            }
        }
    }

    public private(set) var playbackMode: PlaybackMode = .sequential

    public var isPersistenceEnabled: Bool
    private let itemsStorageKey: String
    private let indexStorageKey: String
    private let modeStorageKey: String
    private let userDefaults: UserDefaults

    public init(
        isPersistenceEnabled: Bool = true,
        autoRestore: Bool = false,
        itemsStorageKey: String = defaultItemsStorageKey,
        indexStorageKey: String = defaultIndexStorageKey,
        modeStorageKey: String = defaultModeStorageKey,
        userDefaults: UserDefaults = .standard
    ) {
        self.isPersistenceEnabled = isPersistenceEnabled
        self.itemsStorageKey = itemsStorageKey
        self.indexStorageKey = indexStorageKey
        self.modeStorageKey = modeStorageKey
        self.userDefaults = userDefaults

        if isPersistenceEnabled && autoRestore {
            self.restoreFromStorage()
        }
    }

    public var currentItem: PlaylistItem? {
        guard currentIndex >= 0 && currentIndex < items.count else { return nil }
        return items[currentIndex]
    }

    public var count: Int {
        items.count
    }

    public var isEmpty: Bool {
        items.isEmpty
    }

    public var hasPrevious: Bool {
        guard !items.isEmpty, currentIndex >= 0 else { return false }
        switch playbackMode {
        case .shuffle:
            return !currentPlayHistory.isEmpty
        case .listLoop:
            return items.count > 1
        case .sequential, .singleLoop:
            return currentIndex > 0
        }
    }

    public var hasNext: Bool {
        guard !items.isEmpty, currentIndex >= 0 else { return false }
        switch playbackMode {
        case .shuffle, .listLoop:
            return items.count > 1
        case .sequential, .singleLoop:
            return currentIndex < items.count - 1
        }
    }

    public var previousItem: PlaylistItem? {
        guard hasPrevious else { return nil }
        switch playbackMode {
        case .shuffle:
            guard let lastIndex = currentPlayHistory.last, lastIndex >= 0, lastIndex < items.count else {
                return nil
            }
            return items[lastIndex]
        case .listLoop:
            let idx = (currentIndex - 1 + items.count) % items.count
            return items[idx]
        case .sequential, .singleLoop:
            return currentIndex > 0 ? items[currentIndex - 1] : nil
        }
    }

    public var nextItem: PlaylistItem? {
        upcomingItem
    }

    // MARK: - Upcoming Track Determination & Shuffle Deck State
    public private(set) var nextShuffleIndex: Int? = nil

    private var videoShuffleQueue: [Int] = []
    private var audioShuffleQueue: [Int] = []
    private var unifiedShuffleQueue: [Int] = []
    private var videoPlayHistory: [Int] = []
    private var audioPlayHistory: [Int] = []
    private var unifiedPlayHistory: [Int] = []
    private var videoRecentTrackKeys: [String] = []
    private var audioRecentTrackKeys: [String] = []
    private var unifiedRecentTrackKeys: [String] = []

    private var currentShuffleQueue: [Int] {
        get {
            if !isDualPlaylistMode { return unifiedShuffleQueue }
            return activeCategory == .video ? videoShuffleQueue : audioShuffleQueue
        }
        set {
            if !isDualPlaylistMode {
                unifiedShuffleQueue = newValue
            } else if activeCategory == .video {
                videoShuffleQueue = newValue
            } else {
                audioShuffleQueue = newValue
            }
        }
    }

    private var currentPlayHistory: [Int] {
        get {
            if !isDualPlaylistMode { return unifiedPlayHistory }
            return activeCategory == .video ? videoPlayHistory : audioPlayHistory
        }
        set {
            if !isDualPlaylistMode {
                unifiedPlayHistory = newValue
            } else if activeCategory == .video {
                videoPlayHistory = newValue
            } else {
                audioPlayHistory = newValue
            }
        }
    }

    private var currentRecentTrackKeys: [String] {
        get {
            if !isDualPlaylistMode { return unifiedRecentTrackKeys }
            return activeCategory == .video ? videoRecentTrackKeys : audioRecentTrackKeys
        }
        set {
            if !isDualPlaylistMode {
                unifiedRecentTrackKeys = newValue
            } else if activeCategory == .video {
                videoRecentTrackKeys = newValue
            } else {
                audioRecentTrackKeys = newValue
            }
        }
    }

    public var upcomingItem: PlaylistItem? {
        guard !items.isEmpty, currentIndex >= 0, currentIndex < items.count else { return nil }
        switch playbackMode {
        case .singleLoop:
            return currentItem
        case .listLoop:
            guard items.count > 1 else { return currentItem }
            let nextIdx = (currentIndex + 1) % items.count
            return items[nextIdx]
        case .sequential:
            if currentIndex < items.count - 1 {
                return items[currentIndex + 1]
            }
            return nil
        case .shuffle:
            if items.count == 1 { return currentItem }
            if let candidate = nextShuffleIndex, candidate >= 0, candidate < items.count {
                return items[candidate]
            }
            if let first = currentShuffleQueue.first, first >= 0, first < items.count {
                return items[first]
            }
            let fallbackIdx = (currentIndex + 1) % items.count
            return items[fallbackIdx]
        }
    }

    private func recordRecentTrack(path: String, in recentKeys: inout [String]) {
        guard !path.isEmpty else { return }
        recentKeys.removeAll { $0 == path }
        recentKeys.append(path)
        if recentKeys.count > Self.maxRecentTrackKeysCount {
            recentKeys.removeFirst(recentKeys.count - Self.maxRecentTrackKeysCount)
        }
    }

    private func recordRecentTrack(path: String) {
        if !isDualPlaylistMode {
            recordRecentTrack(path: path, in: &unifiedRecentTrackKeys)
        } else if activeCategory == .video {
            recordRecentTrack(path: path, in: &videoRecentTrackKeys)
        } else {
            recordRecentTrack(path: path, in: &audioRecentTrackKeys)
        }
    }

    private func recordRecentTrack(at index: Int) {
        guard index >= 0 && index < items.count else { return }
        recordRecentTrack(path: items[index].path)
    }

    /// Generates a weighted random permutation (Efraimidis-Spirakis) that suppresses
    /// recently played and manually selected tracks during their cooldown window while
    /// preserving full-cycle coverage across all candidates.
    private func weightedShuffledIndices(from candidateIndices: [Int]) -> [Int] {
        let filtered = candidateIndices.filter { $0 >= 0 && $0 < items.count && $0 != currentIndex }
        guard filtered.count > 1 else { return filtered }

        let totalCount = items.count
        let currentPath = (currentIndex >= 0 && currentIndex < items.count) ? items[currentIndex].path : nil

        var orderedHistoryPaths = currentRecentTrackKeys
        if let currentPath, orderedHistoryPaths.last == currentPath {
            orderedHistoryPaths.removeLast()
        }
        var ageByPath: [String: Int] = [:]
        for (offsetFromTail, path) in orderedHistoryPaths.reversed().enumerated() {
            if ageByPath[path] == nil {
                ageByPath[path] = offsetFromTail + 1
            }
        }

        let cooldownWindow: Int = {
            guard totalCount > 2 else { return 0 }
            return min(totalCount - 2, max(1, min(totalCount / 2, 100)))
        }()

        var scored: [(index: Int, key: Double)] = []
        scored.reserveCapacity(filtered.count)

        for idx in filtered {
            let path = items[idx].path
            let weight: Double
            if let currentPath, path == currentPath {
                weight = 0.0002
            } else if cooldownWindow > 0, let age = ageByPath[path], age <= cooldownWindow {
                let progress = Double(age) / Double(cooldownWindow + 1)
                let quartic = progress * progress * progress * progress
                weight = max(0.0005, quartic)
            } else {
                weight = 1.0
            }

            let u = Double.random(in: 1e-12...(1.0 - 1e-12))
            scored.append((index: idx, key: -log(u) / weight))
        }

        scored.sort { $0.key < $1.key }
        var result = scored.map(\.index)

        // Prevent immediate ping-pong repeats among the most recent tracks whenever alternatives exist.
        let hardGuardSteps = min(4, max(0, result.count - 1))
        if hardGuardSteps > 0, result.count > 1 {
            let headPath = items[result[0]].path
            let headIsTooRecent = (currentPath != nil && headPath == currentPath)
                || (ageByPath[headPath].map { $0 <= hardGuardSteps } ?? false)
            if headIsTooRecent {
                if let betterPos = result.indices.dropFirst().first(where: { pos in
                    let p = items[result[pos]].path
                    if let currentPath, p == currentPath { return false }
                    return ageByPath[p].map { $0 > hardGuardSteps } ?? true
                }) {
                    let chosen = result.remove(at: betterPos)
                    result.insert(chosen, at: 0)
                }
            }
        }

        return result
    }

    public func ensureShuffleCandidate() {
        guard playbackMode == .shuffle, items.count > 1 else {
            nextShuffleIndex = nil
            currentShuffleQueue.removeAll()
            return
        }

        // Clean out invalid indices
        var q = currentShuffleQueue
        q.removeAll { $0 < 0 || $0 >= items.count }

        // If queue is exhausted, generate a fresh cooldown-weighted cycle
        if q.isEmpty {
            let candidatePool = Array(0..<items.count).filter { $0 != currentIndex }
            q = weightedShuffledIndices(from: candidatePool)
        }

        // Boundary protection: If head of queue matches current track, swap or move to end
        if let first = q.first, first == currentIndex, q.count > 1 {
            let dup = q.removeFirst()
            q.append(dup)
        }

        currentShuffleQueue = q
        nextShuffleIndex = q.first
    }

    public var displayIndexText: String {
        guard count > 0 && currentIndex >= 0 else { return "" }
        return "\(currentIndex + 1) / \(count)"
    }

    // MARK: - Dual-Track Routing & Category Switching
    public func category(for url: URL) -> MediaCategory {
        let type = MediaFileClassifier.classify(url: url)
        if type == .audio { return .audio }
        if type == .video { return .video }
        return activeCategory
    }

    public static func category(for url: URL) -> MediaCategory {
        let type = MediaFileClassifier.classify(url: url)
        return type == .audio ? .audio : .video
    }

    public func switchCategory(_ category: MediaCategory) {
        guard activeCategory != category else { return }
        activeCategory = category
        nextShuffleIndex = nil
        if playbackMode == .shuffle {
            ensureShuffleCandidate()
        }
        saveToStorage()
    }

    // MARK: - Playlist Configuration
    public func setPlaylist(items: [MediaItem], startingAt item: MediaItem) {
        let startingCategory = category(for: item.url)
        self.activeCategory = startingCategory

        var vList: [PlaylistItem] = []
        var aList: [PlaylistItem] = []
        for m in items {
            let p = PlaylistItem(from: m)
            if category(for: m.url) == .audio {
                aList.append(p)
            } else {
                vList.append(p)
            }
        }

        self.videoItems = vList
        self.audioItems = aList
        self.videoPlayHistory.removeAll()
        self.videoShuffleQueue.removeAll()
        self.videoRecentTrackKeys.removeAll()
        self.audioPlayHistory.removeAll()
        self.audioShuffleQueue.removeAll()
        self.audioRecentTrackKeys.removeAll()
        self.unifiedPlayHistory.removeAll()
        self.unifiedShuffleQueue.removeAll()
        self.unifiedRecentTrackKeys.removeAll()
        self.nextShuffleIndex = nil

        if startingCategory == .video {
            if let idx = videoItems.firstIndex(where: { $0.id == item.id })
                ?? videoItems.firstIndex(where: { $0.path == item.path }) {
                self.videoCurrentIndex = idx
            } else {
                self.videoCurrentIndex = videoItems.isEmpty ? -1 : 0
            }
        } else {
            if let idx = audioItems.firstIndex(where: { $0.id == item.id })
                ?? audioItems.firstIndex(where: { $0.path == item.path }) {
                self.audioCurrentIndex = idx
            } else {
                self.audioCurrentIndex = audioItems.isEmpty ? -1 : 0
            }
        }

        syncUnifiedItems()
        syncUnifiedCurrentIndex()
        recordRecentTrack(at: currentIndex)
        if playbackMode == .shuffle {
            ensureShuffleCandidate()
        }
        saveToStorage()
    }

    public func setPlaylist(playlistItems: [PlaylistItem], startingIndex: Int = 0) {
        if playlistItems.isEmpty {
            self.items = []
            self.currentIndex = -1
            self.currentPlayHistory.removeAll()
            self.currentShuffleQueue.removeAll()
            self.currentRecentTrackKeys.removeAll()
            self.nextShuffleIndex = nil
            saveToStorage()
            return
        }

        let targetIndex = max(0, min(playlistItems.count - 1, startingIndex))
        let targetCategory = category(for: playlistItems[targetIndex].url)
        self.activeCategory = targetCategory

        var vList: [PlaylistItem] = []
        var aList: [PlaylistItem] = []
        for it in playlistItems {
            if category(for: it.url) == .audio {
                aList.append(it)
            } else {
                vList.append(it)
            }
        }

        self.videoItems = vList
        self.audioItems = aList
        self.videoPlayHistory.removeAll()
        self.videoShuffleQueue.removeAll()
        self.videoRecentTrackKeys.removeAll()
        self.audioPlayHistory.removeAll()
        self.audioShuffleQueue.removeAll()
        self.audioRecentTrackKeys.removeAll()
        self.unifiedPlayHistory.removeAll()
        self.unifiedShuffleQueue.removeAll()
        self.unifiedRecentTrackKeys.removeAll()
        self.nextShuffleIndex = nil

        let targetItem = playlistItems[targetIndex]
        if targetCategory == .video {
            if let idx = videoItems.firstIndex(where: { $0.id == targetItem.id })
                ?? videoItems.firstIndex(where: { $0.path == targetItem.path }) {
                self.videoCurrentIndex = idx
            } else {
                self.videoCurrentIndex = videoItems.isEmpty ? -1 : 0
            }
        } else {
            if let idx = audioItems.firstIndex(where: { $0.id == targetItem.id })
                ?? audioItems.firstIndex(where: { $0.path == targetItem.path }) {
                self.audioCurrentIndex = idx
            } else {
                self.audioCurrentIndex = audioItems.isEmpty ? -1 : 0
            }
        }

        syncUnifiedItems()
        syncUnifiedCurrentIndex()
        recordRecentTrack(at: currentIndex)
        if playbackMode == .shuffle {
            ensureShuffleCandidate()
        }
        saveToStorage()
    }

    public func setSingleItem(path: String, title: String? = nil, duration: Double = 0.0) {
        let url = URL(fileURLWithPath: path)
        let cat = category(for: url)
        self.activeCategory = cat
        let name = title ?? url.deletingPathExtension().lastPathComponent
        let item = PlaylistItem(path: path, title: name, duration: duration)
        self.items = [item]
        self.currentIndex = 0
        self.currentPlayHistory.removeAll()
        self.currentShuffleQueue.removeAll()
        self.currentRecentTrackKeys.removeAll()
        recordRecentTrack(path: path)
        self.nextShuffleIndex = nil
        saveToStorage()
    }

    public func setSingleItem(_ item: MediaItem) {
        let cat = category(for: item.url)
        self.activeCategory = cat
        self.items = [PlaylistItem(from: item)]
        self.currentIndex = 0
        self.currentPlayHistory.removeAll()
        self.currentShuffleQueue.removeAll()
        self.currentRecentTrackKeys.removeAll()
        recordRecentTrack(path: item.path)
        self.nextShuffleIndex = nil
        saveToStorage()
    }

    public func appendItem(_ item: PlaylistItem) {
        let cat = category(for: item.url)
        if cat == .audio {
            let newIdx = audioItems.count
            audioItems.append(item)
            if audioCurrentIndex < 0 {
                audioCurrentIndex = 0
                recordRecentTrack(path: item.path, in: &audioRecentTrackKeys)
            } else if isDualPlaylistMode && activeCategory == .audio && playbackMode == .shuffle && !audioShuffleQueue.isEmpty {
                audioShuffleQueue.append(newIdx)
                syncUnifiedItems()
                syncUnifiedCurrentIndex()
                audioShuffleQueue = weightedShuffledIndices(from: audioShuffleQueue)
                nextShuffleIndex = audioShuffleQueue.first
                saveToStorage()
                return
            }
            syncUnifiedItems()
            syncUnifiedCurrentIndex()
            if activeCategory == .audio && playbackMode == .shuffle {
                ensureShuffleCandidate()
            }
        } else {
            let newIdx = videoItems.count
            videoItems.append(item)
            if videoCurrentIndex < 0 {
                videoCurrentIndex = 0
                recordRecentTrack(path: item.path, in: &videoRecentTrackKeys)
            } else if isDualPlaylistMode && activeCategory == .video && playbackMode == .shuffle && !videoShuffleQueue.isEmpty {
                videoShuffleQueue.append(newIdx)
                syncUnifiedItems()
                syncUnifiedCurrentIndex()
                videoShuffleQueue = weightedShuffledIndices(from: videoShuffleQueue)
                nextShuffleIndex = videoShuffleQueue.first
                saveToStorage()
                return
            }
            syncUnifiedItems()
            syncUnifiedCurrentIndex()
            if activeCategory == .video && playbackMode == .shuffle {
                ensureShuffleCandidate()
            }
        }
        saveToStorage()
    }

    @discardableResult
    public func appendItems(_ newItems: [PlaylistItem]) -> PlaylistItem? {
        guard !newItems.isEmpty else { return currentItem }

        var videoToAdd: [PlaylistItem] = []
        var audioToAdd: [PlaylistItem] = []

        for item in newItems {
            if category(for: item.url) == .audio {
                audioToAdd.append(item)
            } else {
                videoToAdd.append(item)
            }
        }

        if activeCategory == .video && videoItems.isEmpty && !audioToAdd.isEmpty && videoToAdd.isEmpty {
            activeCategory = .audio
        } else if activeCategory == .audio && audioItems.isEmpty && !videoToAdd.isEmpty && audioToAdd.isEmpty {
            activeCategory = .video
        }

        var videoNewRange: Range<Int>? = nil
        var audioNewRange: Range<Int>? = nil

        if !videoToAdd.isEmpty {
            let wasEmpty = videoItems.isEmpty
            let oldCount = videoItems.count
            videoItems.append(contentsOf: videoToAdd)
            if wasEmpty && playbackMode == .shuffle && videoItems.count > 1 && activeCategory == .video {
                var pool = Array(0..<videoItems.count)
                pool.shuffle()
                let chosenIndex = pool.removeFirst()
                videoCurrentIndex = chosenIndex
                recordRecentTrack(path: videoItems[chosenIndex].path, in: &videoRecentTrackKeys)
                videoShuffleQueue = pool
                nextShuffleIndex = pool.first
            } else if videoCurrentIndex < 0 {
                videoCurrentIndex = 0
                recordRecentTrack(path: videoItems[0].path, in: &videoRecentTrackKeys)
                if activeCategory == .video && playbackMode == .shuffle {
                    ensureShuffleCandidate()
                }
            } else if !wasEmpty && oldCount < videoItems.count {
                videoNewRange = oldCount..<videoItems.count
            }
        }

        if !audioToAdd.isEmpty {
            let wasEmpty = audioItems.isEmpty
            let oldCount = audioItems.count
            audioItems.append(contentsOf: audioToAdd)
            if wasEmpty && playbackMode == .shuffle && audioItems.count > 1 && activeCategory == .audio {
                var pool = Array(0..<audioItems.count)
                pool.shuffle()
                let chosenIndex = pool.removeFirst()
                audioCurrentIndex = chosenIndex
                recordRecentTrack(path: audioItems[chosenIndex].path, in: &audioRecentTrackKeys)
                audioShuffleQueue = pool
                nextShuffleIndex = pool.first
            } else if audioCurrentIndex < 0 {
                audioCurrentIndex = 0
                recordRecentTrack(path: audioItems[0].path, in: &audioRecentTrackKeys)
                if activeCategory == .audio && playbackMode == .shuffle {
                    ensureShuffleCandidate()
                }
            } else if !wasEmpty && oldCount < audioItems.count {
                audioNewRange = oldCount..<audioItems.count
            }
        }

        syncUnifiedItems()
        syncUnifiedCurrentIndex()

        if isDualPlaylistMode && playbackMode == .shuffle {
            if activeCategory == .video, let range = videoNewRange {
                if !videoShuffleQueue.isEmpty {
                    videoShuffleQueue = weightedShuffledIndices(from: videoShuffleQueue + Array(range))
                }
                ensureShuffleCandidate()
            } else if activeCategory == .audio, let range = audioNewRange {
                if !audioShuffleQueue.isEmpty {
                    audioShuffleQueue = weightedShuffledIndices(from: audioShuffleQueue + Array(range))
                }
                ensureShuffleCandidate()
            }
        } else if !isDualPlaylistMode && playbackMode == .shuffle {
            unifiedShuffleQueue.removeAll()
            ensureShuffleCandidate()
        }

        saveToStorage()
        return currentItem
    }

    /// Evaluates previous track action against the 3.0s threshold:
    /// If playback position > 3.0s, rewinds current track; otherwise moves to previous track.
    public func determinePreviousAction(currentTime: Double) -> (action: String, targetItem: PlaylistItem?) {
        if currentTime > 3.0 {
            return ("rewind", currentItem)
        } else {
            let prev = moveToPrevious()
            return ("previousTrack", prev)
        }
    }

    // MARK: - Navigation
    @discardableResult
    public func moveToNext() -> PlaylistItem? {
        guard !items.isEmpty else { return nil }
        recordRecentTrack(at: currentIndex)
        switch playbackMode {
        case .shuffle:
            if items.count == 1 { return currentItem }
            ensureShuffleCandidate()
            if currentIndex >= 0 && currentIndex < items.count {
                currentPlayHistory.append(currentIndex)
                if currentPlayHistory.count > 200 { currentPlayHistory.removeFirst() }
            }
            let targetIdx: Int
            if !currentShuffleQueue.isEmpty {
                targetIdx = currentShuffleQueue.removeFirst()
            } else {
                targetIdx = nextShuffleIndex ?? ((currentIndex + 1) % items.count)
            }
            currentIndex = targetIdx
            recordRecentTrack(at: targetIdx)
            nextShuffleIndex = nil
            ensureShuffleCandidate()
        case .listLoop:
            currentIndex = (currentIndex + 1) % items.count
            recordRecentTrack(at: currentIndex)
        case .sequential:
            guard hasNext else { return nil }
            currentIndex += 1
            recordRecentTrack(at: currentIndex)
        case .singleLoop:
            if currentIndex < items.count - 1 {
                currentIndex += 1
            } else {
                currentIndex = 0
            }
            recordRecentTrack(at: currentIndex)
        }
        saveToStorage()
        return currentItem
    }

    @discardableResult
    public func moveToPrevious() -> PlaylistItem? {
        guard !items.isEmpty else { return nil }
        switch playbackMode {
        case .shuffle:
            if items.count == 1 { return currentItem }
            guard let prevIdx = currentPlayHistory.popLast(), prevIdx >= 0, prevIdx < items.count else {
                return nil
            }
            if currentIndex >= 0 && currentIndex < items.count {
                var q = currentShuffleQueue
                q.removeAll { $0 == currentIndex }
                q.insert(currentIndex, at: 0)
                currentShuffleQueue = q
            }
            currentIndex = prevIdx
            nextShuffleIndex = nil
            ensureShuffleCandidate()
        case .listLoop:
            currentIndex = (currentIndex - 1 + items.count) % items.count
        case .sequential:
            guard hasPrevious else { return nil }
            currentIndex -= 1
        case .singleLoop:
            if currentIndex > 0 {
                currentIndex -= 1
            } else {
                currentIndex = max(0, items.count - 1)
            }
        }
        saveToStorage()
        return currentItem
    }

    public func togglePlaybackMode() {
        self.playbackMode = self.playbackMode.next
        if self.playbackMode == .shuffle {
            currentShuffleQueue.removeAll()
            ensureShuffleCandidate()
        } else {
            nextShuffleIndex = nil
            currentShuffleQueue.removeAll()
        }
        saveToStorage()
    }

    public func setPlaybackMode(_ mode: PlaybackMode) {
        self.playbackMode = mode
        if self.playbackMode == .shuffle {
            currentShuffleQueue.removeAll()
            ensureShuffleCandidate()
        } else {
            nextShuffleIndex = nil
            currentShuffleQueue.removeAll()
        }
        saveToStorage()
    }

    // MARK: - Natural EOF Navigation
    public func handleNaturalEOF() -> PlaylistItem? {
        guard !items.isEmpty else { return nil }
        recordRecentTrack(at: currentIndex)
        switch playbackMode {
        case .singleLoop:
            return currentItem
        case .shuffle:
            if items.count == 1 { return currentItem }
            ensureShuffleCandidate()
            if currentIndex >= 0 && currentIndex < items.count {
                currentPlayHistory.append(currentIndex)
                if currentPlayHistory.count > 200 { currentPlayHistory.removeFirst() }
            }
            let targetIdx: Int
            if !currentShuffleQueue.isEmpty {
                targetIdx = currentShuffleQueue.removeFirst()
            } else {
                targetIdx = nextShuffleIndex ?? ((currentIndex + 1) % items.count)
            }
            currentIndex = targetIdx
            recordRecentTrack(at: targetIdx)
            saveToStorage()
            nextShuffleIndex = nil
            ensureShuffleCandidate()
            return currentItem
        case .listLoop:
            currentIndex = (currentIndex + 1) % items.count
            recordRecentTrack(at: currentIndex)
            saveToStorage()
            return currentItem
        case .sequential:
            guard hasNext else { return nil }
            currentIndex += 1
            recordRecentTrack(at: currentIndex)
            saveToStorage()
            return currentItem
        }
    }

    @discardableResult
    public func selectIndex(_ index: Int) -> PlaylistItem? {
        guard index >= 0 && index < items.count else { return nil }
        let isManualIntervention = (currentIndex != index)
        if isManualIntervention && currentIndex >= 0 && currentIndex < items.count {
            currentPlayHistory.append(currentIndex)
            if currentPlayHistory.count > 200 { currentPlayHistory.removeFirst() }
            recordRecentTrack(at: currentIndex)
        }
        currentIndex = index
        recordRecentTrack(at: index)
        if playbackMode == .shuffle {
            var q = currentShuffleQueue
            q.removeAll { $0 == index }
            if isManualIntervention && !q.isEmpty {
                // Re-weight remaining shuffle queue so recently played/picked tracks stay cooled down.
                q = weightedShuffledIndices(from: q)
            }
            currentShuffleQueue = q
            nextShuffleIndex = nil
            ensureShuffleCandidate()
        }
        saveToStorage()
        return currentItem
    }

    public func removeItem(id: UUID) {
        guard let idx = items.firstIndex(where: { $0.id == id }) else { return }
        removeItem(at: idx)
    }

    public func removeItem(id: UUID, inCategory category: MediaCategory) {
        if category == activeCategory {
            removeItem(id: id)
            return
        }
        if category == .video {
            guard let index = videoItems.firstIndex(where: { $0.id == id }) else { return }
            videoItems.remove(at: index)
            videoPlayHistory = videoPlayHistory.compactMap { $0 == index ? nil : ($0 > index ? $0 - 1 : $0) }
            videoShuffleQueue = videoShuffleQueue.compactMap { $0 == index ? nil : ($0 > index ? $0 - 1 : $0) }
            if videoItems.isEmpty {
                videoCurrentIndex = -1
            } else if index < videoCurrentIndex {
                videoCurrentIndex -= 1
            } else if videoCurrentIndex >= videoItems.count {
                videoCurrentIndex = videoItems.count - 1
            }
        } else {
            guard let index = audioItems.firstIndex(where: { $0.id == id }) else { return }
            audioItems.remove(at: index)
            audioPlayHistory = audioPlayHistory.compactMap { $0 == index ? nil : ($0 > index ? $0 - 1 : $0) }
            audioShuffleQueue = audioShuffleQueue.compactMap { $0 == index ? nil : ($0 > index ? $0 - 1 : $0) }
            if audioItems.isEmpty {
                audioCurrentIndex = -1
            } else if index < audioCurrentIndex {
                audioCurrentIndex -= 1
            } else if audioCurrentIndex >= audioItems.count {
                audioCurrentIndex = audioItems.count - 1
            }
        }
        syncUnifiedItems()
        syncUnifiedCurrentIndex()
        saveToStorage()
    }

    public func removeItem(at index: Int) {
        guard index >= 0 && index < items.count else { return }
        var currentItems = items
        currentItems.remove(at: index)
        items = currentItems

        var history = currentPlayHistory
        history = history.compactMap { idx in
            if idx == index { return nil }
            return idx > index ? idx - 1 : idx
        }
        currentPlayHistory = history

        var q = currentShuffleQueue
        q = q.compactMap { idx in
            if idx == index { return nil }
            return idx > index ? idx - 1 : idx
        }
        currentShuffleQueue = q

        if items.isEmpty {
            currentIndex = -1
        } else if index < currentIndex {
            currentIndex -= 1
        } else if currentIndex >= items.count {
            currentIndex = items.count - 1
        }
        if playbackMode == .shuffle {
            nextShuffleIndex = nil
            ensureShuffleCandidate()
        }
        saveToStorage()
    }

    public func clear() {
        items = []
        currentIndex = -1
        currentPlayHistory.removeAll()
        currentShuffleQueue.removeAll()
        currentRecentTrackKeys.removeAll()
        nextShuffleIndex = nil
        saveToStorage()
    }

    /// Clears a specific track category cleanly even while another category is actively playing.
    public func clearCategory(_ category: MediaCategory) {
        if category == activeCategory {
            clear()
            return
        }
        if category == .video {
            videoItems = []
            videoCurrentIndex = -1
            videoPlayHistory.removeAll()
            videoShuffleQueue.removeAll()
            videoRecentTrackKeys.removeAll()
        } else {
            audioItems = []
            audioCurrentIndex = -1
            audioPlayHistory.removeAll()
            audioShuffleQueue.removeAll()
            audioRecentTrackKeys.removeAll()
        }
        syncUnifiedItems()
        syncUnifiedCurrentIndex()
        if !isDualPlaylistMode && playbackMode == .shuffle {
            nextShuffleIndex = nil
            ensureShuffleCandidate()
        }
        saveToStorage()
    }

    // MARK: - Queue Sorting & Reordering

    public private(set) var audioSortOrder: PlaylistSortOrder = .manual
    public private(set) var audioSortDirection: SortDirection = .ascending

    private func remapIndexSequence(_ indices: [Int], from previousItems: [PlaylistItem], to idToNewIndex: [UUID: Int]) -> [Int] {
        indices.compactMap { idx in
            guard idx >= 0 && idx < previousItems.count else { return nil }
            return idToNewIndex[previousItems[idx].id]
        }
    }

    private func finalizeAudioReorder(
        previousAudioItems: [PlaylistItem],
        previousUnifiedItems: [PlaylistItem],
        playingId: UUID?
    ) {
        if let playingId = playingId,
           let newIdx = audioItems.firstIndex(where: { $0.id == playingId }) {
            audioCurrentIndex = newIdx
        }
        let audioIDMap = Dictionary(
            uniqueKeysWithValues: audioItems.enumerated().map { ($0.element.id, $0.offset) }
        )
        audioPlayHistory = remapIndexSequence(audioPlayHistory, from: previousAudioItems, to: audioIDMap)
        audioShuffleQueue = remapIndexSequence(audioShuffleQueue, from: previousAudioItems, to: audioIDMap)
            .filter { $0 != audioCurrentIndex }

        syncUnifiedItems()
        syncUnifiedCurrentIndex()

        let unifiedIDMap = Dictionary(
            uniqueKeysWithValues: unifiedItems.enumerated().map { ($0.element.id, $0.offset) }
        )
        unifiedPlayHistory = remapIndexSequence(unifiedPlayHistory, from: previousUnifiedItems, to: unifiedIDMap)
        unifiedShuffleQueue = remapIndexSequence(unifiedShuffleQueue, from: previousUnifiedItems, to: unifiedIDMap)
            .filter { $0 != unifiedCurrentIndex }

        if activeCategory == .audio || !isDualPlaylistMode {
            nextShuffleIndex = nil
            if playbackMode == .shuffle {
                ensureShuffleCandidate()
            }
        }
        saveToStorage()
    }

    /// Sorts the audio track queue in-place while keeping the currently playing item tracked cleanly.
    public func sortAudioItems(
        by order: PlaylistSortOrder,
        direction: SortDirection? = nil,
        metadataProvider: (PlaylistItem) -> AudioTrackMetadata
    ) {
        let resolvedDirection = direction ?? audioSortDirection
        audioSortOrder = order
        audioSortDirection = resolvedDirection

        guard order != .manual, audioItems.count > 1 else {
            saveToStorage()
            return
        }

        let previousAudioItems = audioItems
        let previousUnifiedItems = unifiedItems
        let playingId: UUID? = (audioCurrentIndex >= 0 && audioCurrentIndex < audioItems.count)
            ? audioItems[audioCurrentIndex].id
            : nil

        let metadataMap: [UUID: AudioTrackMetadata] = Dictionary(
            uniqueKeysWithValues: audioItems.map { ($0.id, metadataProvider($0)) }
        )

        audioItems = audioItems.sorted { lhs, rhs in
            let metaA = metadataMap[lhs.id] ?? AudioTrackMetadataService.fallbackMetadata(for: lhs)
            let metaB = metadataMap[rhs.id] ?? AudioTrackMetadataService.fallbackMetadata(for: rhs)
            let comparison = compareItems(lhs, rhs, metaA: metaA, metaB: metaB, by: order)
            if resolvedDirection == .ascending {
                return comparison == .orderedAscending
            } else {
                return comparison == .orderedDescending
            }
        }
        finalizeAudioReorder(
            previousAudioItems: previousAudioItems,
            previousUnifiedItems: previousUnifiedItems,
            playingId: playingId
        )
    }

    /// Moves an audio item in manual custom order while preserving current track index.
    public func moveAudioItem(fromOffsets source: IndexSet, toOffset destination: Int) {
        guard !audioItems.isEmpty else { return }
        let previousAudioItems = audioItems
        let previousUnifiedItems = unifiedItems
        let playingId: UUID? = (audioCurrentIndex >= 0 && audioCurrentIndex < audioItems.count)
            ? audioItems[audioCurrentIndex].id
            : nil

        var updated = audioItems
        let moving = source.sorted().map { updated[$0] }
        for index in source.sorted(by: >) {
            updated.remove(at: index)
        }
        let adjustedDest = max(0, min(updated.count, destination - source.filter { $0 < destination }.count))
        updated.insert(contentsOf: moving, at: adjustedDest)

        audioSortOrder = .manual
        audioItems = updated
        finalizeAudioReorder(
            previousAudioItems: previousAudioItems,
            previousUnifiedItems: previousUnifiedItems,
            playingId: playingId
        )
    }

    /// Selects a track inside a target category without disturbing an active category until playback triggers.
    @discardableResult
    public func selectItemInCategory(_ item: PlaylistItem, category: MediaCategory) -> PlaylistItem? {
        if activeCategory != category {
            switchCategory(category)
        }
        if let idx = items.firstIndex(where: { $0.id == item.id })
            ?? items.firstIndex(where: { $0.path == item.path }) {
            return selectIndex(idx)
        }
        return nil
    }

    private func compareItems(
        _ lhs: PlaylistItem,
        _ rhs: PlaylistItem,
        metaA: AudioTrackMetadata,
        metaB: AudioTrackMetadata,
        by order: PlaylistSortOrder
    ) -> ComparisonResult {
        switch order {
        case .manual:
            return .orderedSame
        case .title:
            let cmp = metaA.title.localizedStandardCompare(metaB.title)
            if cmp != .orderedSame { return cmp }
        case .artist:
            let cmp = metaA.artist.localizedStandardCompare(metaB.artist)
            if cmp != .orderedSame { return cmp }
        case .album:
            let cmp = metaA.album.localizedStandardCompare(metaB.album)
            if cmp != .orderedSame { return cmp }
        case .duration:
            let dA = metaA.duration ?? lhs.duration
            let dB = metaB.duration ?? rhs.duration
            if dA != dB {
                return dA < dB ? .orderedAscending : .orderedDescending
            }
        case .format:
            let cmp = metaA.formatLabel.localizedStandardCompare(metaB.formatLabel)
            if cmp != .orderedSame { return cmp }
        case .dateModified:
            let dateA = metaA.modificationDate ?? .distantPast
            let dateB = metaB.modificationDate ?? .distantPast
            if dateA != dateB {
                return dateA < dateB ? .orderedAscending : .orderedDescending
            }
        }
        return lhs.title.localizedStandardCompare(rhs.title)
    }

    // MARK: - Persistence & Storage Management
    private nonisolated var customShuffleQueueStorageKey: String { "\(itemsStorageKey).shuffleQueue" }
    private nonisolated var customPlayHistoryStorageKey: String { "\(itemsStorageKey).playHistory" }
    private nonisolated var customRecentKeysStorageKey: String { "\(itemsStorageKey).recentTrackKeys" }

    private func encodedIDs(for indices: [Int], in list: [PlaylistItem]) -> Data? {
        let ids = indices.compactMap { ($0 >= 0 && $0 < list.count) ? list[$0].id : nil }
        return try? JSONEncoder().encode(ids)
    }

    private func decodedIndices(forKey key: String, in list: [PlaylistItem]) -> [Int]? {
        guard let data = userDefaults.data(forKey: key),
              let ids = try? JSONDecoder().decode([UUID].self, from: data) else {
            return nil
        }
        var idMap: [UUID: Int] = [:]
        idMap.reserveCapacity(list.count)
        for (idx, item) in list.enumerated() {
            idMap[item.id] = idx
        }
        return ids.compactMap { idMap[$0] }
    }

    private func encodedStrings(_ strings: [String]) -> Data? {
        try? JSONEncoder().encode(strings)
    }

    private func decodedStrings(forKey key: String) -> [String]? {
        guard let data = userDefaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode([String].self, from: data)
    }

    public func saveToStorage() {
        guard isPersistenceEnabled else { return }
        do {
            userDefaults.set(playbackMode.rawValue, forKey: modeStorageKey)
            userDefaults.set(activeCategory.rawValue, forKey: Self.defaultCategoryStorageKey)
            userDefaults.set(isDualPlaylistMode, forKey: "dualPlaylistMode")

            let videoData = try JSONEncoder().encode(videoItems)
            userDefaults.set(videoData, forKey: Self.defaultVideoItemsStorageKey)
            userDefaults.set(videoCurrentIndex, forKey: Self.defaultVideoIndexStorageKey)

            let audioData = try JSONEncoder().encode(audioItems)
            userDefaults.set(audioData, forKey: Self.defaultAudioItemsStorageKey)
            userDefaults.set(audioCurrentIndex, forKey: Self.defaultAudioIndexStorageKey)

            if let data = encodedIDs(for: videoShuffleQueue, in: videoItems) {
                userDefaults.set(data, forKey: Self.defaultVideoShuffleQueueKey)
            }
            if let data = encodedIDs(for: audioShuffleQueue, in: audioItems) {
                userDefaults.set(data, forKey: Self.defaultAudioShuffleQueueKey)
            }
            if let data = encodedIDs(for: videoPlayHistory, in: videoItems) {
                userDefaults.set(data, forKey: Self.defaultVideoPlayHistoryKey)
            }
            if let data = encodedIDs(for: audioPlayHistory, in: audioItems) {
                userDefaults.set(data, forKey: Self.defaultAudioPlayHistoryKey)
            }
            if let data = encodedStrings(videoRecentTrackKeys) {
                userDefaults.set(data, forKey: Self.defaultVideoRecentKeysStorageKey)
            }
            if let data = encodedStrings(audioRecentTrackKeys) {
                userDefaults.set(data, forKey: Self.defaultAudioRecentKeysStorageKey)
            }

            // Sync active track to itemsStorageKey & indexStorageKey for legacy & custom test key compatibility
            let activeData = try JSONEncoder().encode(items)
            userDefaults.set(activeData, forKey: itemsStorageKey)
            userDefaults.set(currentIndex, forKey: indexStorageKey)
            if let data = encodedIDs(for: currentShuffleQueue, in: items) {
                userDefaults.set(data, forKey: customShuffleQueueStorageKey)
            }
            if let data = encodedIDs(for: currentPlayHistory, in: items) {
                userDefaults.set(data, forKey: customPlayHistoryStorageKey)
            }
            if let data = encodedStrings(currentRecentTrackKeys) {
                userDefaults.set(data, forKey: customRecentKeysStorageKey)
            }
        } catch {
            // Silently fail-safe
        }
    }

    @discardableResult
    public func restoreFromStorage() -> Bool {
        guard isPersistenceEnabled else { return false }
        if let modeRaw = userDefaults.string(forKey: modeStorageKey),
           let mode = PlaybackMode(rawValue: modeRaw) {
            self.playbackMode = mode
        }
        if let dualPref = userDefaults.object(forKey: "dualPlaylistMode") as? Bool {
            self.isDualPlaylistMode = dualPref
        }

        // Custom test keys handling: if non-default storage keys were provided
        if itemsStorageKey != Self.defaultItemsStorageKey {
            guard let data = userDefaults.data(forKey: itemsStorageKey) else { return false }
            do {
                let decoded = try JSONDecoder().decode([PlaylistItem].self, from: data)
                self.items = decoded
                if decoded.isEmpty {
                    self.currentIndex = -1
                } else {
                    let savedIndex = userDefaults.integer(forKey: indexStorageKey)
                    self.currentIndex = max(0, min(decoded.count - 1, savedIndex))
                }
                self.currentPlayHistory = decodedIndices(forKey: customPlayHistoryStorageKey, in: decoded) ?? []
                self.currentRecentTrackKeys = decodedStrings(forKey: customRecentKeysStorageKey) ?? []
                if currentRecentTrackKeys.isEmpty, currentIndex >= 0, currentIndex < decoded.count {
                    recordRecentTrack(path: decoded[currentIndex].path)
                }
                if let restoredQueue = decodedIndices(forKey: customShuffleQueueStorageKey, in: decoded) {
                    self.currentShuffleQueue = restoredQueue.filter { $0 != currentIndex }
                }
                if playbackMode == .shuffle {
                    ensureShuffleCandidate()
                }
                return true
            } catch {
                return false
            }
        }

        // Normal dual-track persistence
        var restoredAny = false

        if let catRaw = userDefaults.string(forKey: Self.defaultCategoryStorageKey),
           let cat = MediaCategory(rawValue: catRaw) {
            self.activeCategory = cat
        }

        if let vData = userDefaults.data(forKey: Self.defaultVideoItemsStorageKey),
           let vDecoded = try? JSONDecoder().decode([PlaylistItem].self, from: vData) {
            self.videoItems = vDecoded
            self.videoCurrentIndex = vDecoded.isEmpty ? -1 : max(0, min(vDecoded.count - 1, userDefaults.integer(forKey: Self.defaultVideoIndexStorageKey)))
            self.videoPlayHistory = decodedIndices(forKey: Self.defaultVideoPlayHistoryKey, in: vDecoded) ?? []
            self.videoRecentTrackKeys = decodedStrings(forKey: Self.defaultVideoRecentKeysStorageKey) ?? []
            if videoRecentTrackKeys.isEmpty, videoCurrentIndex >= 0, videoCurrentIndex < vDecoded.count {
                recordRecentTrack(path: vDecoded[videoCurrentIndex].path, in: &videoRecentTrackKeys)
            }
            if let vQueue = decodedIndices(forKey: Self.defaultVideoShuffleQueueKey, in: vDecoded) {
                self.videoShuffleQueue = vQueue.filter { $0 != videoCurrentIndex }
            }
            restoredAny = true
        }

        if let aData = userDefaults.data(forKey: Self.defaultAudioItemsStorageKey),
           let aDecoded = try? JSONDecoder().decode([PlaylistItem].self, from: aData) {
            self.audioItems = aDecoded
            self.audioCurrentIndex = aDecoded.isEmpty ? -1 : max(0, min(aDecoded.count - 1, userDefaults.integer(forKey: Self.defaultAudioIndexStorageKey)))
            self.audioPlayHistory = decodedIndices(forKey: Self.defaultAudioPlayHistoryKey, in: aDecoded) ?? []
            self.audioRecentTrackKeys = decodedStrings(forKey: Self.defaultAudioRecentKeysStorageKey) ?? []
            if audioRecentTrackKeys.isEmpty, audioCurrentIndex >= 0, audioCurrentIndex < aDecoded.count {
                recordRecentTrack(path: aDecoded[audioCurrentIndex].path, in: &audioRecentTrackKeys)
            }
            if let aQueue = decodedIndices(forKey: Self.defaultAudioShuffleQueueKey, in: aDecoded) {
                self.audioShuffleQueue = aQueue.filter { $0 != audioCurrentIndex }
            }
            restoredAny = true
        }

        // Legacy migration fallback from defaultItemsStorageKey
        if !restoredAny, let legacyData = userDefaults.data(forKey: itemsStorageKey) {
            if let decoded = try? JSONDecoder().decode([PlaylistItem].self, from: legacyData) {
                var vList: [PlaylistItem] = []
                var aList: [PlaylistItem] = []
                for it in decoded {
                    if category(for: it.url) == .audio {
                        aList.append(it)
                    } else {
                        vList.append(it)
                    }
                }
                self.videoItems = vList
                self.audioItems = aList
                let savedIndex = userDefaults.integer(forKey: indexStorageKey)
                if !vList.isEmpty {
                    self.activeCategory = .video
                    self.videoCurrentIndex = max(0, min(vList.count - 1, savedIndex))
                    self.audioCurrentIndex = aList.isEmpty ? -1 : 0
                } else if !aList.isEmpty {
                    self.activeCategory = .audio
                    self.audioCurrentIndex = max(0, min(aList.count - 1, savedIndex))
                    self.videoCurrentIndex = -1
                } else {
                    self.videoCurrentIndex = -1
                    self.audioCurrentIndex = -1
                }
                restoredAny = true
            }
        }

        syncUnifiedItems()
        syncUnifiedCurrentIndex()
        if !isDualPlaylistMode {
            self.unifiedPlayHistory = decodedIndices(forKey: customPlayHistoryStorageKey, in: unifiedItems) ?? []
            self.unifiedRecentTrackKeys = decodedStrings(forKey: customRecentKeysStorageKey) ?? []
            if unifiedRecentTrackKeys.isEmpty, unifiedCurrentIndex >= 0, unifiedCurrentIndex < unifiedItems.count {
                recordRecentTrack(path: unifiedItems[unifiedCurrentIndex].path, in: &unifiedRecentTrackKeys)
            }
            if let uQueue = decodedIndices(forKey: customShuffleQueueStorageKey, in: unifiedItems) {
                self.unifiedShuffleQueue = uQueue.filter { $0 != unifiedCurrentIndex }
            }
        }
        if playbackMode == .shuffle {
            ensureShuffleCandidate()
        }
        return restoredAny
    }

    public func clearStorage() {
        userDefaults.removeObject(forKey: itemsStorageKey)
        userDefaults.removeObject(forKey: indexStorageKey)
        userDefaults.removeObject(forKey: modeStorageKey)
        userDefaults.removeObject(forKey: Self.defaultCategoryStorageKey)
        userDefaults.removeObject(forKey: Self.defaultVideoItemsStorageKey)
        userDefaults.removeObject(forKey: Self.defaultAudioItemsStorageKey)
        userDefaults.removeObject(forKey: Self.defaultVideoIndexStorageKey)
        userDefaults.removeObject(forKey: Self.defaultAudioIndexStorageKey)
        userDefaults.removeObject(forKey: Self.defaultVideoShuffleQueueKey)
        userDefaults.removeObject(forKey: Self.defaultAudioShuffleQueueKey)
        userDefaults.removeObject(forKey: Self.defaultVideoPlayHistoryKey)
        userDefaults.removeObject(forKey: Self.defaultAudioPlayHistoryKey)
        userDefaults.removeObject(forKey: Self.defaultVideoRecentKeysStorageKey)
        userDefaults.removeObject(forKey: Self.defaultAudioRecentKeysStorageKey)
        userDefaults.removeObject(forKey: customShuffleQueueStorageKey)
        userDefaults.removeObject(forKey: customPlayHistoryStorageKey)
        userDefaults.removeObject(forKey: customRecentKeysStorageKey)
    }
}
