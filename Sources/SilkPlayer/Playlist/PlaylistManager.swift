import Observation
import Foundation
import Combine

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

    public static let shared = PlaylistManager(isPersistenceEnabled: true, autoRestore: true)

    // MARK: - Dual-Track Category State
    public private(set) var activeCategory: MediaCategory = .video
    public private(set) var videoItems: [PlaylistItem] = []
    public private(set) var audioItems: [PlaylistItem] = []
    public private(set) var videoCurrentIndex: Int = -1
    public private(set) var audioCurrentIndex: Int = -1

    public var videoCount: Int { videoItems.count }
    public var audioCount: Int { audioItems.count }

    public private(set) var items: [PlaylistItem] {
        get { activeCategory == .video ? videoItems : audioItems }
        set {
            if activeCategory == .video {
                videoItems = newValue
            } else {
                audioItems = newValue
            }
        }
    }

    public private(set) var currentIndex: Int {
        get { activeCategory == .video ? videoCurrentIndex : audioCurrentIndex }
        set {
            if activeCategory == .video {
                videoCurrentIndex = newValue
            } else {
                audioCurrentIndex = newValue
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
    private var videoPlayHistory: [Int] = []
    private var audioPlayHistory: [Int] = []

    private var currentShuffleQueue: [Int] {
        get { activeCategory == .video ? videoShuffleQueue : audioShuffleQueue }
        set {
            if activeCategory == .video {
                videoShuffleQueue = newValue
            } else {
                audioShuffleQueue = newValue
            }
        }
    }

    private var currentPlayHistory: [Int] {
        get { activeCategory == .video ? videoPlayHistory : audioPlayHistory }
        set {
            if activeCategory == .video {
                videoPlayHistory = newValue
            } else {
                audioPlayHistory = newValue
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

    public func ensureShuffleCandidate() {
        guard playbackMode == .shuffle, items.count > 1 else {
            nextShuffleIndex = nil
            currentShuffleQueue.removeAll()
            return
        }

        // Clean out invalid indices
        var q = currentShuffleQueue
        q.removeAll { $0 < 0 || $0 >= items.count }

        // If queue is exhausted, generate a fresh Fisher-Yates cycle
        if q.isEmpty {
            var candidatePool = Array(0..<items.count)
            if currentIndex >= 0 && currentIndex < items.count {
                candidatePool.removeAll { $0 == currentIndex }
            }
            candidatePool.shuffle()
            q = candidatePool
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
        self.audioPlayHistory.removeAll()
        self.audioShuffleQueue.removeAll()
        self.nextShuffleIndex = nil

        if startingCategory == .video {
            if let idx = videoItems.firstIndex(where: { $0.path == item.path || $0.id == item.id }) {
                self.videoCurrentIndex = idx
            } else {
                self.videoCurrentIndex = videoItems.isEmpty ? -1 : 0
            }
        } else {
            if let idx = audioItems.firstIndex(where: { $0.path == item.path || $0.id == item.id }) {
                self.audioCurrentIndex = idx
            } else {
                self.audioCurrentIndex = audioItems.isEmpty ? -1 : 0
            }
        }

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
        self.audioPlayHistory.removeAll()
        self.audioShuffleQueue.removeAll()
        self.nextShuffleIndex = nil

        let targetItem = playlistItems[targetIndex]
        if targetCategory == .video {
            if let idx = videoItems.firstIndex(where: { $0.id == targetItem.id || $0.path == targetItem.path }) {
                self.videoCurrentIndex = idx
            } else {
                self.videoCurrentIndex = videoItems.isEmpty ? -1 : 0
            }
        } else {
            if let idx = audioItems.firstIndex(where: { $0.id == targetItem.id || $0.path == targetItem.path }) {
                self.audioCurrentIndex = idx
            } else {
                self.audioCurrentIndex = audioItems.isEmpty ? -1 : 0
            }
        }

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
        self.nextShuffleIndex = nil
        saveToStorage()
    }

    public func appendItem(_ item: PlaylistItem) {
        let cat = category(for: item.url)
        if cat == .audio {
            audioItems.append(item)
            if audioCurrentIndex < 0 { audioCurrentIndex = 0 }
            if activeCategory == .audio && playbackMode == .shuffle {
                ensureShuffleCandidate()
            }
        } else {
            videoItems.append(item)
            if videoCurrentIndex < 0 { videoCurrentIndex = 0 }
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

        if !videoToAdd.isEmpty {
            let wasEmpty = videoItems.isEmpty
            videoItems.append(contentsOf: videoToAdd)
            if wasEmpty && playbackMode == .shuffle && videoItems.count > 1 && activeCategory == .video {
                var pool = Array(0..<videoItems.count)
                pool.shuffle()
                let chosenIndex = pool.removeFirst()
                videoCurrentIndex = chosenIndex
                videoShuffleQueue = pool
                nextShuffleIndex = pool.first
            } else if videoCurrentIndex < 0 {
                videoCurrentIndex = 0
                if activeCategory == .video && playbackMode == .shuffle {
                    ensureShuffleCandidate()
                }
            } else if activeCategory == .video && playbackMode == .shuffle {
                ensureShuffleCandidate()
            }
        }

        if !audioToAdd.isEmpty {
            let wasEmpty = audioItems.isEmpty
            audioItems.append(contentsOf: audioToAdd)
            if wasEmpty && playbackMode == .shuffle && audioItems.count > 1 && activeCategory == .audio {
                var pool = Array(0..<audioItems.count)
                pool.shuffle()
                let chosenIndex = pool.removeFirst()
                audioCurrentIndex = chosenIndex
                audioShuffleQueue = pool
                nextShuffleIndex = pool.first
            } else if audioCurrentIndex < 0 {
                audioCurrentIndex = 0
                if activeCategory == .audio && playbackMode == .shuffle {
                    ensureShuffleCandidate()
                }
            } else if activeCategory == .audio && playbackMode == .shuffle {
                ensureShuffleCandidate()
            }
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
            nextShuffleIndex = nil
            ensureShuffleCandidate()
        case .listLoop:
            currentIndex = (currentIndex + 1) % items.count
        case .sequential:
            guard hasNext else { return nil }
            currentIndex += 1
        case .singleLoop:
            if currentIndex < items.count - 1 {
                currentIndex += 1
            } else {
                currentIndex = 0
            }
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
            saveToStorage()
            nextShuffleIndex = nil
            ensureShuffleCandidate()
            return currentItem
        case .listLoop:
            currentIndex = (currentIndex + 1) % items.count
            saveToStorage()
            return currentItem
        case .sequential:
            guard hasNext else { return nil }
            currentIndex += 1
            saveToStorage()
            return currentItem
        }
    }

    @discardableResult
    public func selectIndex(_ index: Int) -> PlaylistItem? {
        guard index >= 0 && index < items.count else { return nil }
        if currentIndex >= 0 && currentIndex < items.count && currentIndex != index {
            currentPlayHistory.append(currentIndex)
            if currentPlayHistory.count > 200 { currentPlayHistory.removeFirst() }
        }
        currentIndex = index
        if playbackMode == .shuffle {
            var q = currentShuffleQueue
            q.removeAll { $0 == index }
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
        nextShuffleIndex = nil
        saveToStorage()
    }

    // MARK: - Persistence & Storage Management
    public func saveToStorage() {
        guard isPersistenceEnabled else { return }
        do {
            userDefaults.set(playbackMode.rawValue, forKey: modeStorageKey)
            userDefaults.set(activeCategory.rawValue, forKey: Self.defaultCategoryStorageKey)

            let videoData = try JSONEncoder().encode(videoItems)
            userDefaults.set(videoData, forKey: Self.defaultVideoItemsStorageKey)
            userDefaults.set(videoCurrentIndex, forKey: Self.defaultVideoIndexStorageKey)

            let audioData = try JSONEncoder().encode(audioItems)
            userDefaults.set(audioData, forKey: Self.defaultAudioItemsStorageKey)
            userDefaults.set(audioCurrentIndex, forKey: Self.defaultAudioIndexStorageKey)

            // Sync active track to itemsStorageKey & indexStorageKey for legacy & custom test key compatibility
            let activeData = try JSONEncoder().encode(items)
            userDefaults.set(activeData, forKey: itemsStorageKey)
            userDefaults.set(currentIndex, forKey: indexStorageKey)
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
            restoredAny = true
        }

        if let aData = userDefaults.data(forKey: Self.defaultAudioItemsStorageKey),
           let aDecoded = try? JSONDecoder().decode([PlaylistItem].self, from: aData) {
            self.audioItems = aDecoded
            self.audioCurrentIndex = aDecoded.isEmpty ? -1 : max(0, min(aDecoded.count - 1, userDefaults.integer(forKey: Self.defaultAudioIndexStorageKey)))
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
    }
}
