import Foundation

public struct MediaItem: Identifiable, Hashable, Sendable, Codable {
    public let id: UUID
    public let path: String
    public let title: String
    public let fileSize: Int64
    public var duration: Double // seconds
    public let lastModified: Date
    public var folderId: UUID?
    public var playbackProgress: Double // 0.0 ... 1.0
    public var lastPlayedPosition: Double // seconds
    public var lastPlayedDate: Date?
    public var isFinished: Bool
    public var videoWidth: Int?
    public var videoHeight: Int?
    public var videoCodec: String?

    public var url: URL {
        URL(fileURLWithPath: path)
    }

    public var fileExtension: String {
        url.pathExtension.uppercased()
    }

    public var formattedFileSize: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }

    public var formattedDuration: String {
        if duration <= 0 {
            return "--:--"
        }
        return formatPlaybackTime(duration)
    }

    public init(
        id: UUID = UUID(),
        path: String,
        title: String? = nil,
        fileSize: Int64,
        duration: Double = 0.0,
        lastModified: Date = Date(),
        folderId: UUID? = nil,
        playbackProgress: Double = 0.0,
        lastPlayedPosition: Double = 0.0,
        lastPlayedDate: Date? = nil,
        isFinished: Bool = false,
        videoWidth: Int? = nil,
        videoHeight: Int? = nil,
        videoCodec: String? = nil
    ) {
        self.id = id
        self.path = path
        if let explicitTitle = title, !explicitTitle.isEmpty {
            self.title = explicitTitle
        } else {
            let fileURL = URL(fileURLWithPath: path)
            self.title = fileURL.deletingPathExtension().lastPathComponent
        }
        self.fileSize = fileSize
        self.duration = duration
        self.lastModified = lastModified
        self.folderId = folderId
        self.playbackProgress = playbackProgress
        self.lastPlayedPosition = lastPlayedPosition
        self.lastPlayedDate = lastPlayedDate
        self.isFinished = isFinished
        self.videoWidth = videoWidth
        self.videoHeight = videoHeight
        self.videoCodec = videoCodec
    }
}
