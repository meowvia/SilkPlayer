import Foundation
import SilkCoreKit

public struct PlaylistItem: Identifiable, Hashable, Sendable, Codable {
    public let id: UUID
    public let path: String
    public let title: String
    public var duration: Double
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

extension PlaylistItem: SilkAudioTrackItem {}

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

public enum PlaylistSortOrder: String, CaseIterable, Codable, Sendable {
    case manual = "manual"
    case title = "title"
    case artist = "artist"
    case album = "album"
    case duration = "duration"
    case format = "format"
    case dateModified = "dateModified"

    public var title: String {
        switch self {
        case .manual: return L10n.tr("Custom Order", "自定义顺序")
        case .title: return L10n.tr("Title", "歌曲名称")
        case .artist: return L10n.tr("Artist", "歌手名")
        case .album: return L10n.tr("Album", "所属专辑")
        case .duration: return L10n.tr("Duration", "歌曲时长")
        case .format: return L10n.tr("Format", "音频格式")
        case .dateModified: return L10n.tr("Date Modified", "添加/修改时间")
        }
    }
}

public enum SortDirection: String, Codable, Sendable {
    case ascending = "ascending"
    case descending = "descending"

    public var toggled: SortDirection {
        self == .ascending ? .descending : .ascending
    }
}
