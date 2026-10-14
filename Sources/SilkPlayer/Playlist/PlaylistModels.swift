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

public enum PlaybackMode: String, CaseIterable, Codable, Sendable {
    case sequential = "sequential"
    case listLoop = "listLoop"
    case singleLoop = "singleLoop"
    case shuffle = "shuffle"

    public var iconName: String {
        switch self {
        case .sequential: return "repeat"
        case .listLoop: return "repeat"
        case .singleLoop: return "repeat.1"
        case .shuffle: return "shuffle"
        }
    }

    public var next: PlaybackMode {
        switch self {
        case .sequential: return .listLoop
        case .listLoop: return .singleLoop
        case .singleLoop: return .shuffle
        case .shuffle: return .sequential
        }
    }

    public var title: String {
        switch self {
        case .sequential: return L10n.tr("Sequential", "顺序播放")
        case .listLoop: return L10n.tr("List Loop", "列表循环")
        case .singleLoop: return L10n.tr("Single Loop", "单曲循环")
        case .shuffle: return L10n.tr("Shuffle", "随机播放")
        }
    }
}
