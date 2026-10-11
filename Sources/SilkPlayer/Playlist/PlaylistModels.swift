import Foundation

public struct PlaylistItem: Identifiable, Hashable, Sendable, Codable {
    public let id: UUID
    public let path: String
    public let title: String
    public let duration: Double
    public let mediaItemId: UUID?

    public var url: URL {
        URL(fileURLWithPath: path)
    }

    public init(
        id: UUID = UUID(),
        path: String,
        title: String,
        duration: Double = 0.0,
        mediaItemId: UUID? = nil
    ) {
        self.id = id
        self.path = path
        self.title = title
        self.duration = duration
        self.mediaItemId = mediaItemId
    }

    public init(from mediaItem: MediaItem) {
        self.id = mediaItem.id
        self.path = mediaItem.path
        self.title = mediaItem.title
        self.duration = mediaItem.duration
        self.mediaItemId = mediaItem.id
    }
}
