import Observation
import Foundation
import Combine

@MainActor
@Observable public final class PlaylistManager {
    public nonisolated static let defaultItemsStorageKey = "com.silkplayer.playlist.items"
    public nonisolated static let defaultIndexStorageKey = "com.silkplayer.playlist.currentIndex"
    public nonisolated static let defaultModeStorageKey = "com.silkplayer.playlist.playbackMode"

    public static let shared = PlaylistManager(isPersistenceEnabled: true, autoRestore: true)

    public private(set) var items: [PlaylistItem] = []
    public private(set) var currentIndex: Int = -1
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
            return !playHistory.isEmpty
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
            guard let lastIndex = playHistory.last, lastIndex >= 0, lastIndex < items.count else {
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
    private var shuffleQueue: [Int] = []
    private var playHistory: [Int] = []

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
            ensureShuffleCandidate()
            if let candidate = nextShuffleIndex, candidate >= 0, candidate < items.count {
                return items[candidate]
            }
            let fallbackIdx = (currentIndex + 1) % items.count
            return items[fallbackIdx]
        }
    }

    public func ensureShuffleCandidate() {
        guard playbackMode == .shuffle, items.count > 1 else {
            nextShuffleIndex = nil
            shuffleQueue.removeAll()
            return
        }

        // Clean out invalid indices
        shuffleQueue.removeAll { $0 < 0 || $0 >= items.count }

        // If queue is exhausted, generate a fresh Fisher-Yates cycle
        if shuffleQueue.isEmpty {
            var candidatePool = Array(0..<items.count)
            if currentIndex >= 0 && currentIndex < items.count {
                candidatePool.removeAll { $0 == currentIndex }
            }
            candidatePool.shuffle()
            shuffleQueue = candidatePool
        }

        // Boundary protection: If head of queue matches current track, swap or move to end
        if let first = shuffleQueue.first, first == currentIndex, shuffleQueue.count > 1 {
            let dup = shuffleQueue.removeFirst()
            shuffleQueue.append(dup)
        }

        nextShuffleIndex = shuffleQueue.first
    }

    public var displayIndexText: String {
        guard count > 0 && currentIndex >= 0 else { return "" }
        return "\(currentIndex + 1) / \(count)"
    }

    // MARK: - Playlist Configuration
    public func setPlaylist(items: [MediaItem], startingAt item: MediaItem) {
        self.items = items.map { PlaylistItem(from: $0) }
        self.playHistory.removeAll()
        self.shuffleQueue.removeAll()
        self.nextShuffleIndex = nil
        if let idx = self.items.firstIndex(where: { $0.path == item.path || $0.id == item.id }) {
            self.currentIndex = idx
        } else {
            self.currentIndex = self.items.isEmpty ? -1 : 0
        }
        if playbackMode == .shuffle {
            ensureShuffleCandidate()
        }
        saveToStorage()
    }

    public func setPlaylist(playlistItems: [PlaylistItem], startingIndex: Int = 0) {
        self.items = playlistItems
        self.playHistory.removeAll()
        self.shuffleQueue.removeAll()
        self.nextShuffleIndex = nil
        if playlistItems.isEmpty {
            self.currentIndex = -1
        } else {
            self.currentIndex = max(0, min(playlistItems.count - 1, startingIndex))
        }
        if playbackMode == .shuffle {
            ensureShuffleCandidate()
        }
        saveToStorage()
    }

    public func setSingleItem(path: String, title: String? = nil, duration: Double = 0.0) {
        let name = title ?? URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
        let item = PlaylistItem(path: path, title: name, duration: duration)
        self.items = [item]
        self.currentIndex = 0
        self.playHistory.removeAll()
        self.shuffleQueue.removeAll()
        self.nextShuffleIndex = nil
        saveToStorage()
    }

    public func setSingleItem(_ item: MediaItem) {
        self.items = [PlaylistItem(from: item)]
        self.currentIndex = 0
        self.playHistory.removeAll()
        self.shuffleQueue.removeAll()
        self.nextShuffleIndex = nil
        saveToStorage()
    }

    public func appendItem(_ item: PlaylistItem) {
        self.items.append(item)
        if currentIndex < 0 {
            currentIndex = 0
        }
        if playbackMode == .shuffle {
            ensureShuffleCandidate()
        }
        saveToStorage()
    }

    public func appendItems(_ newItems: [PlaylistItem]) {
        self.items.append(contentsOf: newItems)
        if currentIndex < 0 && !items.isEmpty {
            currentIndex = 0
        }
        if playbackMode == .shuffle {
            ensureShuffleCandidate()
        }
        saveToStorage()
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
                playHistory.append(currentIndex)
                if playHistory.count > 200 { playHistory.removeFirst() }
            }
            let targetIdx: Int
            if !shuffleQueue.isEmpty {
                targetIdx = shuffleQueue.removeFirst()
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
            guard let prevIdx = playHistory.popLast(), prevIdx >= 0, prevIdx < items.count else {
                return nil
            }
            if currentIndex >= 0 && currentIndex < items.count {
                shuffleQueue.removeAll { $0 == currentIndex }
                shuffleQueue.insert(currentIndex, at: 0)
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
            shuffleQueue.removeAll()
            ensureShuffleCandidate()
        } else {
            nextShuffleIndex = nil
            shuffleQueue.removeAll()
        }
        saveToStorage()
    }

    public func setPlaybackMode(_ mode: PlaybackMode) {
        self.playbackMode = mode
        if self.playbackMode == .shuffle {
            shuffleQueue.removeAll()
            ensureShuffleCandidate()
        } else {
            nextShuffleIndex = nil
            shuffleQueue.removeAll()
        }
        saveToStorage()
    }

    // MARK: - Natural EOF Navigation
    /// Advances to the next item when the current video ends naturally.
    /// Returns the next item, or nil if at the end of the playlist.
    public func handleNaturalEOF() -> PlaylistItem? {
        guard !items.isEmpty else { return nil }
        switch playbackMode {
        case .singleLoop:
            return currentItem
        case .shuffle:
            if items.count == 1 { return currentItem }
            ensureShuffleCandidate()
            if currentIndex >= 0 && currentIndex < items.count {
                playHistory.append(currentIndex)
                if playHistory.count > 200 { playHistory.removeFirst() }
            }
            let targetIdx: Int
            if !shuffleQueue.isEmpty {
                targetIdx = shuffleQueue.removeFirst()
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
            playHistory.append(currentIndex)
            if playHistory.count > 200 { playHistory.removeFirst() }
        }
        currentIndex = index
        if playbackMode == .shuffle {
            shuffleQueue.removeAll { $0 == index }
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
        items.remove(at: index)
        playHistory = playHistory.compactMap { idx in
            if idx == index { return nil }
            return idx > index ? idx - 1 : idx
        }
        shuffleQueue = shuffleQueue.compactMap { idx in
            if idx == index { return nil }
            return idx > index ? idx - 1 : idx
        }
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
        playHistory.removeAll()
        shuffleQueue.removeAll()
        nextShuffleIndex = nil
        saveToStorage()
    }

    // MARK: - Persistence & Storage Management
    public func saveToStorage() {
        guard isPersistenceEnabled else { return }
        do {
            let data = try JSONEncoder().encode(items)
            userDefaults.set(data, forKey: itemsStorageKey)
            userDefaults.set(currentIndex, forKey: indexStorageKey)
            userDefaults.set(playbackMode.rawValue, forKey: modeStorageKey)
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
            return true
        } catch {
            return false
        }
    }

    public func clearStorage() {
        userDefaults.removeObject(forKey: itemsStorageKey)
        userDefaults.removeObject(forKey: indexStorageKey)
        userDefaults.removeObject(forKey: modeStorageKey)
    }
}
