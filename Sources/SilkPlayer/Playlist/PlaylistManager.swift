import Observation
import Foundation
import Combine

@MainActor
@Observable public final class PlaylistManager {
    public nonisolated static let defaultItemsStorageKey = "com.silkplayer.playlist.items"
    public nonisolated static let defaultIndexStorageKey = "com.silkplayer.playlist.currentIndex"

    public static let shared = PlaylistManager(isPersistenceEnabled: true, autoRestore: true)

    public private(set) var items: [PlaylistItem] = []
    public private(set) var currentIndex: Int = -1

    public var isPersistenceEnabled: Bool
    private let itemsStorageKey: String
    private let indexStorageKey: String
    private let userDefaults: UserDefaults

    public init(
        isPersistenceEnabled: Bool = true,
        autoRestore: Bool = false,
        itemsStorageKey: String = defaultItemsStorageKey,
        indexStorageKey: String = defaultIndexStorageKey,
        userDefaults: UserDefaults = .standard
    ) {
        self.isPersistenceEnabled = isPersistenceEnabled
        self.itemsStorageKey = itemsStorageKey
        self.indexStorageKey = indexStorageKey
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
        currentIndex > 0
    }

    public var hasNext: Bool {
        currentIndex >= 0 && currentIndex < items.count - 1
    }

    public var previousItem: PlaylistItem? {
        hasPrevious ? items[currentIndex - 1] : nil
    }

    public var nextItem: PlaylistItem? {
        hasNext ? items[currentIndex + 1] : nil
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
        guard hasNext else { return nil }
        currentIndex += 1
        saveToStorage()
        return currentItem
    }

    @discardableResult
    public func moveToPrevious() -> PlaylistItem? {
        guard hasPrevious else { return nil }
        currentIndex -= 1
        saveToStorage()
        return currentItem
    }

    // MARK: - Natural EOF Navigation
    /// Advances to the next item when the current video ends naturally.
    /// Returns the next item, or nil if at the end of the playlist.
    public func handleNaturalEOF() -> PlaylistItem? {
        guard hasNext else { return nil }
        currentIndex += 1
        saveToStorage()
        return currentItem
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
        } catch {
            // Silently fail-safe
        }
    }

    @discardableResult
    public func restoreFromStorage() -> Bool {
        guard isPersistenceEnabled else { return false }
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
    }
}
