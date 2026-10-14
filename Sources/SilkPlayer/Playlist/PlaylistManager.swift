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
        case .shuffle, .listLoop:
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
            return nil
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

    // MARK: - Upcoming Track Determination (Dynamic & Synchronized across all playback modes)
    public private(set) var nextShuffleIndex: Int? = nil

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
            return
        }
        if let cand = nextShuffleIndex, cand >= 0, cand < items.count, cand != currentIndex {
            return
        }
        var nextIdx = Int.random(in: 0..<items.count)
        if nextIdx == currentIndex {
            nextIdx = (nextIdx + 1) % items.count
        }
        nextShuffleIndex = nextIdx
    }

    public var displayIndexText: String {
        guard count > 0 && currentIndex >= 0 else { return "" }
        return "\(currentIndex + 1) / \(count)"
    }

    // MARK: - Playlist Configuration
    public func setPlaylist(items: [MediaItem], startingAt item: MediaItem) {
        self.items = items.map { PlaylistItem(from: $0) }
        if let idx = self.items.firstIndex(where: { $0.path == item.path || $0.id == item.id }) {
            self.currentIndex = idx
        } else {
            self.currentIndex = self.items.isEmpty ? -1 : 0
        }
        saveToStorage()
    }

    public func setPlaylist(playlistItems: [PlaylistItem], startingIndex: Int = 0) {
        self.items = playlistItems
        if playlistItems.isEmpty {
            self.currentIndex = -1
        } else {
            self.currentIndex = max(0, min(playlistItems.count - 1, startingIndex))
        }
        saveToStorage()
    }

    public func setSingleItem(path: String, title: String? = nil, duration: Double = 0.0) {
        let name = title ?? URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
        let item = PlaylistItem(path: path, title: name, duration: duration)
        self.items = [item]
        self.currentIndex = 0
        saveToStorage()
    }

    public func setSingleItem(_ item: MediaItem) {
        self.items = [PlaylistItem(from: item)]
        self.currentIndex = 0
        saveToStorage()
    }

    public func appendItem(_ item: PlaylistItem) {
        self.items.append(item)
        if currentIndex < 0 {
            currentIndex = 0
        }
        saveToStorage()
    }

    public func appendItems(_ newItems: [PlaylistItem]) {
        self.items.append(contentsOf: newItems)
        if currentIndex < 0 && !items.isEmpty {
            currentIndex = 0
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
            let targetIdx = nextShuffleIndex ?? ((currentIndex + 1) % items.count)
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
            var prevIdx = Int.random(in: 0..<items.count)
            if prevIdx == currentIndex {
                prevIdx = (prevIdx + 1) % items.count
            }
            currentIndex = prevIdx
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
            ensureShuffleCandidate()
        } else {
            nextShuffleIndex = nil
        }
        saveToStorage()
    }

    public func setPlaybackMode(_ mode: PlaybackMode) {
        self.playbackMode = mode
        if self.playbackMode == .shuffle {
            ensureShuffleCandidate()
        } else {
            nextShuffleIndex = nil
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
            let targetIdx = nextShuffleIndex ?? ((currentIndex + 1) % items.count)
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
        currentIndex = index
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
        if items.isEmpty {
            currentIndex = -1
        } else if index < currentIndex {
            currentIndex -= 1
        } else if currentIndex >= items.count {
            currentIndex = items.count - 1
        }
        saveToStorage()
    }

    public func clear() {
        items = []
        currentIndex = -1
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
