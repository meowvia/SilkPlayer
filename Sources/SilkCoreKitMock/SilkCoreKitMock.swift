import AppKit
import AVFoundation
import AudioToolbox
import Combine
import CoreAudio
import CoreGraphics
import CoreImage
import CoreMedia
import CoreVideo
import Foundation
import Metal
import MetalKit
import QuartzCore
import SwiftUI
import VideoToolbox

// MARK: - Playback State & Metadata
public enum SilkPlaybackState: Sendable, Equatable {
    case idle
    case loading
    case readyToPlay
    case playing
    case paused
    case buffering
    case ended
    case failed(String)
}

public struct SilkTrackInfo: Identifiable, Sendable, Equatable {
    public let id: Int32
    public let mediaType: AVMediaType
    public let name: String
    public let language: String
    public let isDefault: Bool
    public let rotation: Int
    public let bitDepth: Int
    public let codecName: String

    public init(
        id: Int32 = 0,
        mediaType: AVMediaType = .video,
        name: String = "",
        language: String = "",
        isDefault: Bool = false,
        rotation: Int = 0,
        bitDepth: Int = 8,
        codecName: String = ""
    ) {
        self.id = id
        self.mediaType = mediaType
        self.name = name
        self.language = language
        self.isDefault = isDefault
        self.rotation = rotation
        self.bitDepth = bitDepth
        self.codecName = codecName
    }
}

public struct MetalTransformUniforms: Sendable, Equatable {
    public var rotation: Int32
    public var flipH: Int32
    public var flipV: Int32
    public var padding: Int32

    public init(rotation: Int32 = 0, flipH: Int32 = 0, flipV: Int32 = 0) {
        self.rotation = rotation
        self.flipH = flipH
        self.flipV = flipV
        self.padding = 0
    }
}

@MainActor
public protocol SilkEngineDelegate: AnyObject {
    func engineDidUpdateState(_ state: SilkPlaybackState)
    func engineDidUpdateTime(currentTime: TimeInterval, duration: TimeInterval)
    func engineDidFinishPlayback(error: (any Error)?)
    func engineDidUpdateBuffering(progress: Double)
    func engineDidReceiveSubtitleCue(_ cue: SubtitleCue)
}

extension SilkEngineDelegate {
    public func engineDidReceiveSubtitleCue(_ cue: SubtitleCue) {}
}

@MainActor
public class SilkMetalRenderView: NSView {
    public var isDolbyVision: Bool = false
    public var isHDR10: Bool = false
    public var targetAspect: CGFloat? = 16.0 / 9.0
    public var transformUniforms = MetalTransformUniforms()
    public var videoRotation: Int = 0
    public var currentPixelBuffer: CVPixelBuffer? = nil
    public var isWindowOccluded: Bool = false
    public var isQualityEnhancementEnabled: Bool = false

    public func renderCurrentFrameImmediately() {}
    public func updateMetalGeometryAndRedraw() {}
    public func updateColorPipeline() {}
    public func clear() {}

    override public func hitTest(_ point: NSPoint) -> NSView? {
        return nil
    }
}

@MainActor
public final class SilkPlayerEngine: ObservableObject {
    public let renderView = SilkMetalRenderView()
    @Published public private(set) var isPlaying: Bool = false
    public var preferredAudioOutputChannels: Int = 0
    public var currentAudioChannels: Int = 2
    public weak var delegate: (any SilkEngineDelegate)?
    public var duration: TimeInterval = 0.0
    @Published public private(set) var currentTime: TimeInterval = 0.0
    public var videoWidth: Int = 1920
    public var videoHeight: Int = 1080
    public var displayVideoWidth: Int = 1920
    public var displayVideoHeight: Int = 1080
    public var videoFps: Double = 60.0
    public var videoCodecName: String = "hevc"
    public var isDolbyVision: Bool = false
    public var dolbyVisionProfile: Int = 0
    public var mediaTracks: [SilkMediaTrack] = []
    public var chapters: [SilkChapter] = []
    public var hasVideo: Bool = true
    public var hasAudio: Bool = true
    public var attachedPictureData: Data? = nil
    public var volume: Float = 1.0
    public var isMuted: Bool = false
    public var playbackRate: Double = 1.0

    public init() {}
    public func open(url: URL) -> Bool { true }
    public func openAsync(url: URL, autoPlay: Bool = false, completion: @escaping @MainActor @Sendable (Bool) -> Void) {
        completion(true)
    }
    public func play() { isPlaying = true }
    public func pause() { isPlaying = false }
    public func stop() { isPlaying = false }
    public func close() { isPlaying = false }
    public func setVolume(_ val: Float) { volume = val }
    public func setPlaybackRate(_ rate: Double) { playbackRate = rate }
    public func stepFrame(forward: Bool) {}
    public func selectTrack(id: Int32, mediaType: AVMediaType) {}
    public func extractSubtitleCues(streamIndex: Int32) -> [SubtitleCue] { [] }
    public func currentFrameImage() async -> CGImage? { nil }
    public func requestSeek(to seconds: TimeInterval, exact: Bool = true) {}
    public func seek(to seconds: TimeInterval) {}
}

public enum SilkPlayerState: Sendable, Equatable, Hashable {
    case readyToPlay
    case buffering
    case bufferFinished
    case paused
    case playedToTheEnd
    case error
}

@MainActor
public protocol SilkPlayerLayerDelegate: AnyObject {
    func player(layer: SilkPlayerLayer, state: SilkPlayerState)
    func player(layer: SilkPlayerLayer, currentTime: TimeInterval, totalTime: TimeInterval)
    func player(layer: SilkPlayerLayer, finish error: (any Error)?)
    func player(layer: SilkPlayerLayer, bufferedCount: Int, consumeTime: TimeInterval)
    func player(layer: SilkPlayerLayer, didReceiveSubtitleCue cue: SubtitleCue)
}

extension SilkPlayerLayerDelegate {
    public func player(layer: SilkPlayerLayer, didReceiveSubtitleCue cue: SubtitleCue) {}
}

public final class SilkPlayerOptions: @unchecked Sendable {
    public var hardwareDecode: Bool = true
    public var asynchronousDecompression: Bool = true
    public var isAccurateSeek: Bool = true
    public var preferredForwardBufferDuration: Double = 0.8
    public var maxBufferDuration: Double = 2.0
    public var videoAdaptable: Bool = false
    public var autoRotate: Bool = true
    public var autoSelectEmbedSubtitle: Bool = true
    public var isSeekImageSubtitle: Bool = true
    public var display: DisplayMode = .plane
    public var startPlayTime: Double = 0.0

    public enum DisplayMode: Sendable, Equatable, Hashable {
        case plane
    }

    public init() {}
}

public struct SilkDoviInfo: Sendable {
    public let dv_profile: Int
    public let dv_level: Int
    public init(dv_profile: Int, dv_level: Int = 0) {
        self.dv_profile = dv_profile
        self.dv_level = dv_level
    }
}

public class SilkMediaTrack: NSObject, @unchecked Sendable, MediaPlayerTrack {
    public let trackID: Int32
    public let mediaType: AVMediaType
    public let name: String
    public let languageCode: String?
    public var isEnabled: Bool
    public let rotation: Int
    public let dovi: SilkDoviInfo?
    public let isDoviProfile5: Bool
    public let formatDescription: CMFormatDescription?
    public let codecName: String
    public let isImageSubtitle: Bool

    public init(
        trackID: Int32 = 0,
        mediaType: AVMediaType = .video,
        name: String = "",
        languageCode: String? = nil,
        isEnabled: Bool = false,
        rotation: Int = 0,
        dovi: SilkDoviInfo? = nil,
        isDoviProfile5: Bool = false,
        formatDescription: CMFormatDescription? = nil,
        codecName: String = "",
        isImageSubtitle: Bool = false
    ) {
        self.trackID = trackID
        self.mediaType = mediaType
        self.name = name
        self.languageCode = languageCode
        self.isEnabled = isEnabled
        self.rotation = rotation
        self.dovi = dovi
        self.isDoviProfile5 = isDoviProfile5
        self.formatDescription = formatDescription
        self.codecName = codecName
        self.isImageSubtitle = isImageSubtitle
        super.init()
    }
}

public struct SilkChapter: Sendable {
    public let title: String
    public let start: Double
    public init(title: String = "", start: Double = 0.0) {
        self.title = title
        self.start = start
    }
}

public struct SilkDynamicInfo: Sendable {
    public let metadata: [String: String]
    public init(metadata: [String: String] = [:]) {
        self.metadata = metadata
    }
}

@MainActor
public final class SilkPlayerWrapper: NSObject, ObservableObject {
    public let engine: SilkPlayerEngine
    public weak var layerDelegate: SilkPlayerLayer?
    public var view: NSView? { engine.renderView }
    public var playbackVolume: Float {
        get { engine.volume }
        set { engine.volume = newValue }
    }
    public var isMuted: Bool {
        get { engine.isMuted }
        set { engine.isMuted = newValue }
    }
    public var playbackRate: Float {
        get { Float(engine.playbackRate) }
        set { engine.playbackRate = Double(newValue) }
    }
    public var nominalFrameRate: Float { Float(engine.videoFps) }
    public var naturalSize: CGSize { CGSize(width: engine.videoWidth, height: engine.videoHeight) }
    public var chapters: [SilkChapter] { engine.chapters }
    public var dynamicInfo: SilkDynamicInfo? { nil }
    public var hasVideo: Bool { engine.hasVideo }
    public var isAudioOnly: Bool { !engine.hasVideo && engine.hasAudio }
    public var attachedPictureData: Data? { engine.attachedPictureData }
    public var audioRhythmBands: [Float] { [0.4, 0.6, 0.3, 0.7, 0.5, 0.4, 0.3] }
    public var subtitleDataSouce: SubtitleDataSouce? { nil }

    public init(engine: SilkPlayerEngine = SilkPlayerEngine()) {
        self.engine = engine
        super.init()
    }

    public func stepFrame(forward: Bool) {}
    public func tracks(mediaType: AVMediaType) -> [SilkMediaTrack] { [] }
    public func select(track: SilkMediaTrack) {}
    public func select(track: any MediaPlayerTrack, completion: (@MainActor @Sendable () -> Void)? = nil) {
        completion?()
    }
    public func thumbnailImageAtCurrentTime() async -> CGImage? { nil }
    public func deselectTrack(mediaType: AVMediaType) {}
}

@MainActor
public final class SilkPlayerLayer: NSObject, SilkEngineDelegate {
    public let player: SilkPlayerWrapper
    public weak var delegate: (any SilkPlayerLayerDelegate)?
    public let options: SilkPlayerOptions

    public var hasVideo: Bool { player.hasVideo }
    public var isAudioOnly: Bool { player.isAudioOnly }
    public var attachedPictureData: Data? { player.attachedPictureData }
    public var audioRhythmBands: [Float] { player.audioRhythmBands }
    public var isQualityEnhancementEnabled: Bool = false

    public init(options: SilkPlayerOptions = SilkPlayerOptions(), delegate: (any SilkPlayerLayerDelegate)? = nil) {
        self.options = options
        self.delegate = delegate
        self.player = SilkPlayerWrapper()
        super.init()
    }

    public convenience init(url: URL, options: SilkPlayerOptions = SilkPlayerOptions(), delegate: (any SilkPlayerLayerDelegate)? = nil) {
        self.init(options: options, delegate: delegate)
    }

    public func open(url: URL) -> Bool { true }
    public func openAsync(url: URL, autoPlay: Bool = false, completion: @escaping @MainActor @Sendable (Bool) -> Void) {
        completion(true)
    }
    public func play() {}
    public func pause() {}
    public func stop() {}
    public func close() {}
    public func requestSeek(time: Double, exact: Bool = true) {}
    public func seek(time: Double, autoPlay: Bool = true, completion: ((Bool) -> Void)? = nil) {
        completion?(true)
    }
    public func engineDidUpdateState(_ state: SilkPlaybackState) {}
    public func engineDidUpdateTime(currentTime: TimeInterval, duration: TimeInterval) {}
    public func engineDidFinishPlayback(error: (any Error)?) {}
    public func engineDidUpdateBuffering(progress: Double) {}
    public func engineDidReceiveSubtitleCue(_ cue: SubtitleCue) {}
}

// MARK: - Subtitles & Models
public enum VerticalAlign: Sendable, Equatable, Hashable {
    case top
    case center
    case bottom
}

public struct TextPosition: Sendable {
    public var verticalAlign: VerticalAlign
    public init(verticalAlign: VerticalAlign = .bottom) {
        self.verticalAlign = verticalAlign
    }
}

public struct SubtitlePart: Identifiable, @unchecked Sendable {
    public let id: UUID
    public var image: NSImage?
    public var origin: CGPoint
    public var text: NSAttributedString?
    public var textPosition: TextPosition?

    public init(
        id: UUID = UUID(),
        image: NSImage? = nil,
        origin: CGPoint = .zero,
        text: NSAttributedString? = nil,
        textPosition: TextPosition? = nil
    ) {
        self.id = id
        self.image = image
        self.origin = origin
        self.text = text
        self.textPosition = textPosition
    }
}

public struct SubtitleCue: @unchecked Sendable {
    public let startTime: TimeInterval
    public let endTime: TimeInterval
    public let text: String
    public let attributedText: NSAttributedString?
    public let image: NSImage?
    public let origin: CGPoint
    public let position: TextPosition?

    public init(
        startTime: TimeInterval = 0,
        endTime: TimeInterval = 0,
        text: String = "",
        attributedText: NSAttributedString? = nil,
        image: NSImage? = nil,
        origin: CGPoint = .zero,
        position: TextPosition? = nil
    ) {
        self.startTime = startTime
        self.endTime = endTime
        self.text = text
        self.attributedText = attributedText
        self.image = image
        self.origin = origin
        self.position = position
    }
}

public class SubtitleInfo: Identifiable, @unchecked Sendable {
    public let id: UUID
    public var subtitleID: String
    public var name: String
    public var languageCode: String?
    public var isEnabled: Bool
    public var isExternal: Bool
    public var cues: [SubtitleCue]

    public init(
        id: UUID = UUID(),
        subtitleID: String = "",
        name: String = "",
        languageCode: String? = nil,
        isEnabled: Bool = false,
        isExternal: Bool = false,
        cues: [SubtitleCue] = []
    ) {
        self.id = id
        self.subtitleID = subtitleID
        self.name = name
        self.languageCode = languageCode
        self.isEnabled = isEnabled
        self.isExternal = isExternal
        self.cues = cues
    }
}

public class URLSubtitleInfo: SubtitleInfo, @unchecked Sendable {
    public let downloadURL: URL

    public init(url: URL) {
        self.downloadURL = url
        super.init(
            subtitleID: url.lastPathComponent,
            name: url.deletingPathExtension().lastPathComponent,
            languageCode: nil,
            isEnabled: true,
            isExternal: true
        )
    }
}

public struct SubtitleDataSouce: Sendable {
    public var infos: [SubtitleInfo]
    public init(infos: [SubtitleInfo] = []) {
        self.infos = infos
    }
}

public protocol MediaPlayerTrack: AnyObject {
    var trackID: Int32 { get }
    var name: String { get }
    var languageCode: String? { get }
    var isEnabled: Bool { get set }
}

public class FFmpegAssetTrack: SubtitleInfo, MediaPlayerTrack, @unchecked Sendable {
    public var trackID: Int32
    public var codecName: String
    public var isImageSubtitle: Bool

    public init(
        trackID: Int32,
        name: String,
        languageCode: String?,
        codecName: String = "",
        isImageSubtitle: Bool = false
    ) {
        self.trackID = trackID
        self.codecName = codecName
        self.isImageSubtitle = isImageSubtitle
        super.init(
            subtitleID: "\(trackID)",
            name: name,
            languageCode: languageCode,
            isEnabled: false,
            isExternal: false
        )
    }
}

public enum SilkSubtitleParser {
    public static func decodeString(from data: Data) -> String? { String(data: data, encoding: .utf8) }
    public static func parse(url: URL) -> [SubtitleCue] { [] }
    public static func parseSRT(_ text: String) -> [SubtitleCue] { [] }
    public static func parseVTT(_ text: String) -> [SubtitleCue] { [] }
    public static func parseASS(_ text: String) -> [SubtitleCue] { [] }
    public static func cleanSubtitleText(_ s: String) -> String { s }
    public static func makeCinemaAttributedText(_ text: String) -> NSAttributedString { NSAttributedString(string: text) }
}

@MainActor
public final class SilkSubtitleModel: ObservableObject {
    @Published public var parts: [SubtitlePart] = []
    @Published public var subtitleInfos: [SubtitleInfo] = []
    @Published public var selectedSubtitleInfo: SubtitleInfo? = nil
    @Published public var subtitleDelay: Double = 0.0
    @Published public var url: URL? = nil

    public init() {}
    public func addSubtitle(info: SubtitleInfo) {
        subtitleInfos.append(info)
    }
    public func subtitle(currentTime: Double) -> [SubtitlePart] { parts }
    public func updateActiveSubtitles() {}
    public func appendLiveCue(_ cue: SubtitleCue) {}
}

public typealias SubtitleModel = SilkSubtitleModel
public typealias SilkThumbEngine = SilkThumbnailEngine

@MainActor
public final class SilkThumbnailEngine: ObservableObject {
    public static let shared = SilkThumbnailEngine()

    @Published public private(set) var activeThumbnail: NSImage? = nil
    @Published public private(set) var activeThumbnailTime: Double = -1.0
    @Published public private(set) var isLoading: Bool = false

    public init() {}
    public func prepare(for filePath: String?) {}
    public func requestThumbnail(for filePath: String?, at time: Double) {}
    public func clearCurrent() {}
    public func reset() {}
    public func captureScreenshot(for filePath: String?, at time: Double) async -> NSImage? { nil }
    public func captureScreenshotCGImage(for filePath: String?, at time: Double) async -> CGImage? { nil }
    public func captureScreenshotSync(for filePath: String?, at time: Double) -> NSImage? { nil }
}

extension SilkPlayerEngine: @unchecked Sendable {}
extension SilkPlayerWrapper: @unchecked Sendable {}
extension SilkPlayerLayer: @unchecked Sendable {}
extension SilkSubtitleModel: @unchecked Sendable {}
extension SilkThumbnailEngine: @unchecked Sendable {}

// MARK: - Pro Licensing & Unified Library API Mocks (CI Only)

public struct SilkProReceipt: Codable, Sendable, Equatable {
    public let keyId: String
    public let licenseKeyMask: String
    public let planName: String
    public let maxDevices: Int
    public let deviceCount: Int
    public let hardwareId: String
    public let issuedAt: Date
    public let expiresAt: Date?
    public let rawToken: String

    public init(
        keyId: String,
        licenseKeyMask: String,
        planName: String = "SilkPlayer Pro",
        maxDevices: Int = 3,
        deviceCount: Int = 1,
        hardwareId: String,
        issuedAt: Date = Date(),
        expiresAt: Date? = nil,
        rawToken: String
    ) {
        self.keyId = keyId
        self.licenseKeyMask = licenseKeyMask
        self.planName = planName
        self.maxDevices = maxDevices
        self.deviceCount = deviceCount
        self.hardwareId = hardwareId
        self.issuedAt = issuedAt
        self.expiresAt = expiresAt
        self.rawToken = rawToken
    }
}

public enum SilkProLicenseStatus: Sendable, Equatable {
    case unlicensed
    case activated(SilkProReceipt)
    case invalid(String)

    public var isProActive: Bool {
        if case .activated = self { return true }
        return false
    }

    public var receipt: SilkProReceipt? {
        if case let .activated(r) = self { return r }
        return nil
    }
}

public enum SilkProActivationResult: Sendable, Equatable {
    case success(SilkProReceipt)
    case failure(String)
}

public enum SilkLicenseVerificationError: Error, Sendable, Equatable {
    case malformedToken
    case malformedEncoding
    case invalidPublicKey
    case invalidSignature
    case malformedPayload
    case expired
    case hardwareMismatch

    public var localizedMessage: String { "Mock license verification error." }
}

@MainActor
public final class SilkProLicenseEngine: ObservableObject {
    public static let shared = SilkProLicenseEngine()
    public static let defaultPublicKeyBase64 = ""
    public static let defaultEndpointBase = "https://license.1999909.xyz/v1/silkplayer/licenses"

    @Published public private(set) var status: SilkProLicenseStatus = .unlicensed
    @Published public private(set) var isProcessing: Bool = false
    @Published public private(set) var lastErrorMessage: String? = nil
    @Published public var purchaseURLString: String = ""

    public var activationEndpoint: String
    public let hardwareId: String

    public var isProActive: Bool { status.isProActive }
    public var activeReceipt: SilkProReceipt? { status.receipt }
    public var purchaseURL: URL? {
        let trimmed = purchaseURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let url = URL(string: trimmed), url.scheme?.lowercased() == "https" else { return nil }
        return url
    }

    public init(
        publicKeyBase64: String = "",
        endpointBase: String = SilkProLicenseEngine.defaultEndpointBase,
        hardwareId: String? = nil,
        usePersistentStorage: Bool? = nil
    ) {
        self.activationEndpoint = endpointBase
        self.hardwareId = hardwareId ?? "mock-hw-id"
    }

    public static func resolveHardwareFingerprint() -> String { "mock-hw-id" }

    public func verifySignedToken(_ token: String) -> Result<SilkProReceipt, SilkLicenseVerificationError> {
        .failure(.malformedToken)
    }

    @discardableResult
    public func activate(licenseKey rawInput: String) async -> SilkProActivationResult {
        let msg = "Mock license engine in CI build."
        lastErrorMessage = msg
        return .failure(msg)
    }

    public func deactivate() async {
        status = .unlicensed
        lastErrorMessage = nil
    }

    public func clearError() {
        lastErrorMessage = nil
    }
}

extension SilkProLicenseEngine: @unchecked Sendable {}

public enum SilkNetworkShareProtocol: String, Codable, Sendable, CaseIterable {
    case smb
    case nfs

    public var displayName: String {
        switch self {
        case .smb: return "SMB 2/3"
        case .nfs: return "NFS"
        }
    }
}

public enum SilkLibrarySourceKind: String, Codable, Sendable, CaseIterable {
    case local
    case smb
    case nfs
}

public struct SilkLibrarySource: Identifiable, Codable, Sendable, Equatable {
    public let id: String
    public var kind: SilkLibrarySourceKind
    public var displayName: String
    public var path: String
    public var smbHost: String?
    public var smbShare: String?
    public var smbUsername: String?
    public var bookmarkData: Data?
    public var autoScan: Bool
    public var includedRelativePaths: [String]
    public var excludedRelativePaths: [String]
    public var lastScannedAt: Date?
    public var itemCount: Int

    public init(
        id: String = UUID().uuidString,
        kind: SilkLibrarySourceKind,
        displayName: String,
        path: String,
        smbHost: String? = nil,
        smbShare: String? = nil,
        smbUsername: String? = nil,
        bookmarkData: Data? = nil,
        autoScan: Bool = true,
        includedRelativePaths: [String] = [],
        excludedRelativePaths: [String] = [],
        lastScannedAt: Date? = nil,
        itemCount: Int = 0
    ) {
        self.id = id
        self.kind = kind
        self.displayName = displayName
        self.path = path
        self.smbHost = smbHost
        self.smbShare = smbShare
        self.smbUsername = smbUsername
        self.bookmarkData = bookmarkData
        self.autoScan = autoScan
        self.includedRelativePaths = includedRelativePaths
        self.excludedRelativePaths = excludedRelativePaths
        self.lastScannedAt = lastScannedAt
        self.itemCount = itemCount
    }
}

public enum SilkLibraryMediaKind: String, Codable, Sendable, CaseIterable {
    case movie
    case seriesEpisode
    case audio
}

public enum SilkWatchState: String, Codable, Sendable, CaseIterable {
    case unwatched
    case inProgress
    case watched
}

public struct SilkMediaLibraryRecord: Identifiable, Codable, Sendable, Equatable {
    public var id: String { path }
    public let sourceId: String
    public let path: String
    public let fileName: String
    public var title: String
    public var pinyinTokens: String
    public var kind: SilkLibraryMediaKind
    public var seriesName: String?
    public var seasonNumber: Int?
    public var episodeNumber: Int?
    public var albumName: String?
    public var artistName: String?
    public var trackNumber: Int?
    public var resolutionTag: String
    public var videoCodecTag: String
    public var audioSpecTag: String
    public var durationSeconds: Double
    public var fileSizeBytes: Int64
    public var createdTimestamp: Double
    public var modifiedTimestamp: Double
    public var positionSeconds: Double
    public var watchState: SilkWatchState
    public var lastPlayedAt: Double?
    public var posterPath: String?
    public var isHDR: Bool
    public var isDolbyVision: Bool

    public init(
        sourceId: String,
        path: String,
        fileName: String,
        title: String,
        pinyinTokens: String = "",
        kind: SilkLibraryMediaKind,
        seriesName: String? = nil,
        seasonNumber: Int? = nil,
        episodeNumber: Int? = nil,
        albumName: String? = nil,
        artistName: String? = nil,
        trackNumber: Int? = nil,
        resolutionTag: String = "",
        videoCodecTag: String = "",
        audioSpecTag: String = "",
        durationSeconds: Double = 0,
        fileSizeBytes: Int64 = 0,
        createdTimestamp: Double = 0,
        modifiedTimestamp: Double = 0,
        positionSeconds: Double = 0,
        watchState: SilkWatchState = .unwatched,
        lastPlayedAt: Double? = nil,
        posterPath: String? = nil,
        isHDR: Bool = false,
        isDolbyVision: Bool = false
    ) {
        self.sourceId = sourceId
        self.path = path
        self.fileName = fileName
        self.title = title
        self.pinyinTokens = pinyinTokens
        self.kind = kind
        self.seriesName = seriesName
        self.seasonNumber = seasonNumber
        self.episodeNumber = episodeNumber
        self.albumName = albumName
        self.artistName = artistName
        self.trackNumber = trackNumber
        self.resolutionTag = resolutionTag
        self.videoCodecTag = videoCodecTag
        self.audioSpecTag = audioSpecTag
        self.durationSeconds = durationSeconds
        self.fileSizeBytes = fileSizeBytes
        self.createdTimestamp = createdTimestamp
        self.modifiedTimestamp = modifiedTimestamp
        self.positionSeconds = positionSeconds
        self.watchState = watchState
        self.lastPlayedAt = lastPlayedAt
        self.posterPath = posterPath
        self.isHDR = isHDR
        self.isDolbyVision = isDolbyVision
    }

    public var progressFraction: Double {
        guard durationSeconds > 1 else { return 0 }
        return min(1.0, max(0.0, positionSeconds / durationSeconds))
    }
}

public struct SilkSMBBrowseHost: Identifiable, Codable, Sendable, Equatable {
    public var id: String { "\(shareProtocol.rawValue):\(host):\(port)" }
    public let name: String
    public let host: String
    public let port: Int
    public let isMounted: Bool
    public let shareProtocol: SilkNetworkShareProtocol

    public init(name: String, host: String, port: Int = 445, isMounted: Bool = false, shareProtocol: SilkNetworkShareProtocol = .smb) {
        self.name = name
        self.host = host
        self.port = port
        self.isMounted = isMounted
        self.shareProtocol = shareProtocol
    }
}

public struct SilkSMBShareEntry: Identifiable, Codable, Sendable, Equatable {
    public var id: String { name.lowercased() }
    public let name: String
    public let comment: String
    public let mountedPath: String?

    public init(name: String, comment: String = "", mountedPath: String? = nil) {
        self.name = name
        self.comment = comment
        self.mountedPath = mountedPath
    }
}

public enum SilkSMBShareListResult: Sendable, Equatable {
    case shares([SilkSMBShareEntry])
    case failure(String)
}

public enum SilkSMBMountResult: Sendable, Equatable {
    case mounted(mountPath: String)
    case failure(String)
}

public struct SilkFolderEntry: Identifiable, Codable, Sendable, Equatable {
    public var id: String { relativePath }
    public let name: String
    public let relativePath: String

    public init(name: String, relativePath: String) {
        self.name = name
        self.relativePath = relativePath
    }
}

@MainActor
public final class SilkSMBMountService: ObservableObject {
    public static let shared = SilkSMBMountService()
    @Published public private(set) var discoveredHosts: [SilkSMBBrowseHost] = []
    @Published public private(set) var isScanning: Bool = false
    private init() {}
    public func startDiscovery() {}
    public func stopDiscovery() {}
    nonisolated public static func parseNetworkInput(_ rawInput: String, defaultProtocol: SilkNetworkShareProtocol = .smb) -> (shareProtocol: SilkNetworkShareProtocol, host: String, share: String?, username: String?, password: String?) {
        (defaultProtocol, "", nil, nil, nil)
    }
    nonisolated public static func parseSMBInput(_ rawInput: String) -> (host: String, share: String?, username: String?, password: String?) {
        ("", nil, nil, nil)
    }
    nonisolated public static func listMountedSMBHosts() -> [SilkSMBBrowseHost] { [] }
    nonisolated public static func listMountedShares(forHost rawHost: String, shareProtocol: SilkNetworkShareProtocol = .smb) -> [SilkSMBShareEntry] { [] }
    public func listShares(host: String, shareProtocol: SilkNetworkShareProtocol = .smb, username: String = "", password: String = "", isGuest: Bool = false) async -> SilkSMBShareListResult {
        .failure("Mock LAN share list in CI build.")
    }
    nonisolated public static func parseSmbutilViewOutput(_ output: String) -> [SilkSMBShareEntry] { [] }
    nonisolated public static func parseShowmountOutput(_ output: String) -> [SilkSMBShareEntry] { [] }
    nonisolated public static func listImmediateSubfolders(rootPath: String, relativePath: String = "") -> [SilkFolderEntry] { [] }
    public func listSubfolders(host: String, share: String, shareProtocol: SilkNetworkShareProtocol = .smb, relativePath: String = "", username: String = "", password: String = "", isGuest: Bool = false) async -> Result<[SilkFolderEntry], Error> {
        .failure(NSError(domain: "SilkCoreKitMock", code: 0))
    }
    public static func saveCredential(host: String, share: String, username: String, password: String) {}
    public static func loadCredential(host: String, share: String, username: String) -> String? { nil }
    public static func deleteCredential(host: String, share: String, username: String) {}
    nonisolated public static func findExistingMountPath(host: String, share: String, shareProtocol: SilkNetworkShareProtocol = .smb) -> String? { nil }
    public func mountShare(host: String, share: String, shareProtocol: SilkNetworkShareProtocol = .smb, username: String = "", password: String = "", isGuest: Bool = false) async -> SilkSMBMountResult {
        .failure("Mock LAN mount in CI build.")
    }
}

extension SilkSMBMountService: @unchecked Sendable {}

@MainActor
public final class SilkMediaLibraryEngine: ObservableObject {
    public static let shared = SilkMediaLibraryEngine()
    @Published public private(set) var sources: [SilkLibrarySource] = []
    @Published public private(set) var items: [SilkMediaLibraryRecord] = []
    @Published public private(set) var isScanning: Bool = false
    @Published public private(set) var scanningSourceName: String? = nil
    @Published public private(set) var scanningDiscoveredCount: Int = 0
    @Published public private(set) var lastScanError: String? = nil

    public init(databaseURL: URL? = nil, usePersistentBookmarkStorage: Bool = true) {}
    public func loadFromDatabase() async {}
    @discardableResult
    public func addLocalSource(url: URL, displayName: String? = nil, autoScan: Bool = true, includedRelativePaths: [String] = [], excludedRelativePaths: [String] = [], scanImmediately: Bool = true) async -> SilkLibrarySource? { nil }
    public func addSMBSource(host: String, share: String, shareProtocol: SilkNetworkShareProtocol = .smb, username: String = "", password: String = "", isGuest: Bool = false, displayName: String? = nil, autoScan: Bool = true, includedRelativePaths: [String] = [], excludedRelativePaths: [String] = [], scanImmediately: Bool = true) async -> Result<SilkLibrarySource, Error> {
        .failure(NSError(domain: "SilkCoreKitMock", code: 0))
    }
    public func updateSourceFolderFilters(id: String, includedRelativePaths: [String], excludedRelativePaths: [String], rescan: Bool = true) async {}
    public func removeSource(id: String) async { sources.removeAll { $0.id == id } }
    public func updateSourceAutoScan(id: String, enabled: Bool) async {}
    public func enqueueBackgroundRescan(sourceIds: [String]) {}
    public func rescanAll() async {}
    public func rescanAutoSourcesOnLaunch() async {}
    public func rescanSource(id: String) async {}
    public func search(query: String) async -> [SilkMediaLibraryRecord] { items }
    public func recordPlaybackProgress(path: String, position: Double, duration: Double) async {}
    public func setWatchState(path: String, state: SilkWatchState) async {}
    public func clearAllWatchMemory() async {}
    public func renameMediaItem(path: String, newTitle: String) async {}
    public func renameSeriesGroup(sourceId: String?, oldSeriesName: String, newSeriesName: String) async {}
    public func removeMediaItemFromLibrary(path: String) async {}
    public func removeSeriesFromLibrary(seriesName: String, sourceId: String?) async {}
    public func deleteMediaItemFile(path: String) async -> Result<Void, Error> { .success(()) }
    public func deleteSeriesFiles(paths: [String]) async -> Result<Int, Error> { .success(0) }
    public func resolvePlayableURL(for path: String) async -> URL? { URL(fileURLWithPath: path) }
}

extension SilkMediaLibraryEngine: @unchecked Sendable {}

// MARK: - Closed-Source Pro Library & Music Mode UI Stubs (CI Only)

public enum SilkLibraryTheme: String, CaseIterable, Identifiable, Sendable, Codable {
    case shenghui = "shenghui"
    case yaojin = "yaojin"
    case nuanbai = "nuanbai"
    case qingci = "qingci"

    public var id: String { rawValue }
    public static let userDefaultsKey = "proLibraryThemeId"

    public static func current() -> SilkLibraryTheme {
        if let raw = UserDefaults.standard.string(forKey: userDefaultsKey),
           let parsed = SilkLibraryTheme(rawValue: raw) {
            return parsed
        }
        return .shenghui
    }

    public var displayName: String {
        switch self {
        case .shenghui: return "深灰"
        case .yaojin: return "曜金"
        case .nuanbai: return "暖白"
        case .qingci: return "青瓷"
        }
    }

    public var isLight: Bool {
        switch self {
        case .shenghui, .yaojin: return false
        case .nuanbai, .qingci: return true
        }
    }

    public var nsAppearance: NSAppearance? {
        isLight ? NSAppearance(named: .aqua) : NSAppearance(named: .darkAqua)
    }

    public var swatchColor: Color {
        switch self {
        case .shenghui: return Color(red: 0.31, green: 0.53, blue: 0.85)
        case .yaojin: return Color(red: 0.878, green: 0.624, blue: 0.243)
        case .nuanbai: return Color(red: 0.980, green: 0.965, blue: 0.941)
        case .qingci: return Color(red: 0.863, green: 0.914, blue: 0.898)
        }
    }

    public var accentColor: Color {
        switch self {
        case .shenghui: return Color(red: 0.31, green: 0.53, blue: 0.85)
        case .yaojin: return Color(red: 0.878, green: 0.624, blue: 0.243)
        case .nuanbai: return Color(red: 0.784, green: 0.408, blue: 0.180)
        case .qingci: return Color(red: 0.165, green: 0.482, blue: 0.435)
        }
    }

    public var backgroundBase: Color {
        switch self {
        case .shenghui: return Color(red: 0.118, green: 0.122, blue: 0.133)
        case .yaojin: return Color(red: 0.071, green: 0.063, blue: 0.055)
        case .nuanbai: return Color(red: 0.980, green: 0.965, blue: 0.941)
        case .qingci: return Color(red: 0.945, green: 0.961, blue: 0.953)
        }
    }

    public var backgroundHighlight: Color {
        switch self {
        case .shenghui: return Color(red: 0.140, green: 0.148, blue: 0.165)
        case .yaojin: return Color(red: 0.110, green: 0.094, blue: 0.082)
        case .nuanbai: return Color(red: 0.953, green: 0.914, blue: 0.859)
        case .qingci: return Color(red: 0.890, green: 0.922, blue: 0.910)
        }
    }

    public var cardSurface: Color {
        switch self {
        case .shenghui: return Color(red: 0.149, green: 0.157, blue: 0.173).opacity(0.92)
        case .yaojin: return Color(red: 0.125, green: 0.108, blue: 0.094).opacity(0.94)
        case .nuanbai: return Color.white.opacity(0.96)
        case .qingci: return Color.white.opacity(0.95)
        }
    }

    public var cardFocusedSurface: Color {
        switch self {
        case .shenghui: return accentColor.opacity(0.14)
        case .yaojin: return Color(red: 0.878, green: 0.624, blue: 0.243).opacity(0.15)
        case .nuanbai: return Color(red: 0.965, green: 0.933, blue: 0.890)
        case .qingci: return Color(red: 0.898, green: 0.937, blue: 0.925)
        }
    }

    public var pillSurface: Color {
        switch self {
        case .shenghui: return Color.white.opacity(0.065)
        case .yaojin: return Color(red: 0.96, green: 0.88, blue: 0.74).opacity(0.075)
        case .nuanbai: return Color(red: 0.941, green: 0.902, blue: 0.839)
        case .qingci: return Color(red: 0.863, green: 0.906, blue: 0.894)
        }
    }

    public var pillSelectedSurface: Color {
        accentColor.opacity(isLight ? 0.18 : 0.22)
    }

    public var borderColor: Color {
        switch self {
        case .shenghui: return Color.white.opacity(0.095)
        case .yaojin: return Color(red: 0.92, green: 0.78, blue: 0.52).opacity(0.16)
        case .nuanbai: return Color(red: 0.894, green: 0.827, blue: 0.749)
        case .qingci: return Color(red: 0.776, green: 0.839, blue: 0.820)
        }
    }

    public var dividerColor: Color {
        switch self {
        case .shenghui: return Color.white.opacity(0.22)
        case .yaojin: return Color(red: 0.92, green: 0.78, blue: 0.52).opacity(0.22)
        case .nuanbai: return Color(red: 0.922, green: 0.863, blue: 0.796)
        case .qingci: return Color(red: 0.808, green: 0.863, blue: 0.847)
        }
    }

    public var primaryText: Color {
        switch self {
        case .shenghui: return Color(red: 0.925, green: 0.933, blue: 0.949)
        case .yaojin: return Color(red: 0.961, green: 0.937, blue: 0.902)
        case .nuanbai: return Color(red: 0.169, green: 0.137, blue: 0.110)
        case .qingci: return Color(red: 0.094, green: 0.141, blue: 0.129)
        }
    }

    public var secondaryText: Color {
        switch self {
        case .shenghui: return Color(red: 0.604, green: 0.627, blue: 0.667)
        case .yaojin: return Color(red: 0.639, green: 0.588, blue: 0.533)
        case .nuanbai: return Color(red: 0.431, green: 0.369, blue: 0.314)
        case .qingci: return Color(red: 0.337, green: 0.420, blue: 0.396)
        }
    }

    public var volumeBoostColor: Color {
        isLight ? Color(red: 0.82, green: 0.18, blue: 0.22) : Color(red: 0.92, green: 0.45, blue: 0.12)
    }

    public var tertiaryText: Color { .white.opacity(0.5) }
    public var controlFill: Color { .white.opacity(0.08) }
    public var controlHoverFill: Color { .white.opacity(0.14) }
    public var surfaceFill: Color { backgroundBase }
    public var surfaceElevatedFill: Color { cardSurface }
    public var surfaceBorder: Color { borderColor }
    public var colorScheme: ColorScheme { isLight ? .light : .dark }
}

@MainActor
public struct SilkProLibraryView: View {
    public init(
        onPlayItem: @escaping (SilkMediaLibraryRecord, [SilkMediaLibraryRecord], Bool) -> Void,
        onOpenFile: @escaping () -> Void,
        onFilesDropped: @escaping ([URL]) -> Void,
        onOpenSettings: @escaping (Int) -> Void = { _ in }
    ) {}

    public var body: some View { EmptyView() }
}

public enum SilkFolderCheckState: Equatable, Sendable {
    case checked
    case mixed
    case unchecked
    public var symbolName: String { "square" }
}

public struct SilkFolderSelectionRule: Equatable, Sendable {
    public var includedPaths: Set<String> = []
    public var excludedPaths: Set<String> = []
    public init(includedRelativePaths: [String] = [], excludedRelativePaths: [String] = []) {}
    public init(emptyUnselected: Bool) {}
    public var isActive: Bool { false }
    public var exportedIncludedRelativePaths: [String] { [] }
    public var exportedExcludedRelativePaths: [String] { [] }
    public func state(for rawPath: String) -> SilkFolderCheckState { .unchecked }
    public mutating func toggle(_ rawPath: String) {}
}

@MainActor
public struct SilkLANSourceDrawerView: View {
    public init(
        drawerWidth: CGFloat = 300,
        isInMediaLibrary: Bool = false,
        onCompletedConfiguration: @escaping () -> Void,
        onClose: @escaping () -> Void
    ) {}

    public var body: some View { EmptyView() }
}

public enum MusicModeGeometry: Sendable {
    public static let minWidth: CGFloat = 520.0
    public static let maxWidth: CGFloat = 768.0
    public static let minHeight: CGFloat = 500.0
    public static let collapsedStandardHeight: CGFloat = 224.0
    public static let collapsedExtendedHeight: CGFloat = 232.0
    public static let collapseDragThreshold: CGFloat = 370.0
    public static let expandDragThreshold: CGFloat = 330.0
    public static let extendedQueueWidthThreshold: CGFloat = 680.0
    public static let compactBottomHUDWidthThreshold: CGFloat = 640.0
    public static let contentHorizontalPadding: CGFloat = 20.0

    public static func lockedWidth(forScreenWidth visibleWidth: CGFloat) -> CGFloat {
        minWidth
    }

    public static func effectiveMinHeight(forScreenHeight visibleHeight: CGFloat) -> CGFloat {
        guard visibleHeight.isFinite, visibleHeight > 0 else { return minHeight }
        return min(minHeight, floor(visibleHeight))
    }

    public static func resolvedHeight(forScreenHeight visibleHeight: CGFloat, rememberedHeight: CGFloat? = nil) -> CGFloat {
        rememberedHeight ?? max(minHeight, floor(visibleHeight * 0.8))
    }

    public static func collapsedHeight(forWindowWidth width: CGFloat, screenVisibleHeight: CGFloat? = nil) -> CGFloat {
        let base = collapsedStandardHeight
        if let screenVisibleHeight, screenVisibleHeight.isFinite, screenVisibleHeight > 0 {
            return min(base, floor(screenVisibleHeight))
        }
        return base
    }

    public static func clampedFrame(
        around currentFrame: NSRect?,
        targetHeight: CGFloat? = nil,
        rememberedHeight: CGFloat? = nil,
        clampToExpandedMin: Bool = true,
        screenVisibleFrame: NSRect
    ) -> NSRect {
        let w = lockedWidth(forScreenWidth: screenVisibleFrame.width)
        let h = targetHeight ?? resolvedHeight(forScreenHeight: screenVisibleFrame.height, rememberedHeight: rememberedHeight)
        return NSRect(x: currentFrame?.minX ?? screenVisibleFrame.minX, y: currentFrame?.minY ?? screenVisibleFrame.minY, width: w, height: h)
    }

    public static func clampedResizeProposal(_ proposedSize: NSSize, screenVisibleFrame: NSRect) -> NSSize {
        NSSize(
            width: lockedWidth(forScreenWidth: screenVisibleFrame.width),
            height: min(screenVisibleFrame.height, max(effectiveMinHeight(forScreenHeight: screenVisibleFrame.height), proposedSize.height))
        )
    }

    public static func magneticResizeProposal(
        _ proposedSize: NSSize,
        isCollapsed: Bool,
        collapseThreshold: CGFloat = collapseDragThreshold,
        expandThreshold: CGFloat = expandDragThreshold,
        screenVisibleFrame: NSRect
    ) -> (size: NSSize, isCollapsed: Bool) {
        (clampedResizeProposal(proposedSize, screenVisibleFrame: screenVisibleFrame), isCollapsed)
    }

    public static func toggledCollapseFrame(
        around currentFrame: NSRect,
        targetCollapsed: Bool,
        rememberedExpandedHeight: CGFloat?,
        screenVisibleFrame: NSRect
    ) -> NSRect {
        let w = lockedWidth(forScreenWidth: screenVisibleFrame.width)
        let h = targetCollapsed
            ? collapsedHeight(forWindowWidth: w, screenVisibleHeight: screenVisibleFrame.height)
            : (rememberedExpandedHeight ?? minHeight)
        return NSRect(x: currentFrame.minX, y: currentFrame.minY, width: w, height: h)
    }

    public static func showsExtendedQueueColumns(width: CGFloat) -> Bool { false }
    public static func usesCompactBottomControls(width: CGFloat) -> Bool { true }
    public static func bottomVolumeTrackWidth(forWindowWidth width: CGFloat) -> CGFloat { 60.0 }
    public static func showsVolumePercentage(forWindowWidth width: CGFloat) -> Bool { false }
    public static func heroArtworkSize(forWindowWidth width: CGFloat) -> CGFloat { 56.0 }
}

public protocol SilkAudioTrackItem: Sendable {
    var id: UUID { get }
    var path: String { get }
    var title: String { get }
    var duration: Double { get }
}

extension SilkAudioTrackItem {
    public var url: URL { URL(fileURLWithPath: path) }
}

public struct SilkAudioTrackDescriptor: SilkAudioTrackItem, Identifiable, Hashable, Sendable {
    public let id: UUID
    public let path: String
    public let title: String
    public let duration: Double
    public let isAudio: Bool

    public init(id: UUID = UUID(), path: String, title: String, duration: Double = 0, isAudio: Bool = true) {
        self.id = id
        self.path = path
        self.title = title
        self.duration = duration
        self.isAudio = isAudio
    }
}

public struct AudioTrackMetadata: Sendable, Equatable, Codable {
    public let path: String
    public var title: String
    public var artist: String
    public var album: String
    public var formatLabel: String
    public var sampleRateHz: Double?
    public var bitDepth: Int?
    public var duration: Double?
    public var modificationDate: Date?

    public init(
        path: String,
        title: String,
        artist: String = "",
        album: String = "",
        formatLabel: String = "",
        sampleRateHz: Double? = nil,
        bitDepth: Int? = nil,
        duration: Double? = nil,
        modificationDate: Date? = nil
    ) {
        self.path = path
        self.title = title
        self.artist = artist
        self.album = album
        self.formatLabel = formatLabel
        self.sampleRateHz = sampleRateHz
        self.bitDepth = bitDepth
        self.duration = duration
        self.modificationDate = modificationDate
    }

    public var heroSpecText: String { formatLabel }
    public var queueDisplayTitle: String { title }
}

@MainActor
public final class AudioTrackMetadataService {
    public static let shared = AudioTrackMetadataService(cacheURL: defaultDiskCacheURL())
    public private(set) var cache: [String: AudioTrackMetadata] = [:]

    public init(cacheURL: URL? = nil) {}
    public nonisolated static func defaultDiskCacheURL() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("mock_audio_cache.json")
    }
    public func metadata<T: SilkAudioTrackItem>(for item: T) -> AudioTrackMetadata {
        Self.fallbackMetadata(for: item)
    }
    public func ensureLoaded<T: SilkAudioTrackItem>(for items: [T], priorityPath: String? = nil) {}
    public func mergeLiveStreamInfo(path: String, rawTitle: String, codec: String?, sampleRateHz: Double?, bitDepth: Int?, duration: Double?, tags: [String: String]?) {}
    public func clearCache() { cache.removeAll() }
    public nonisolated static func repairMojibakeIfNeeded(_ raw: String) -> String { raw }
    public nonisolated static func isCorruptPlaceholderTag(_ text: String) -> Bool { false }
    public nonisolated static func sanitizeTagValue(_ raw: String) -> String { raw }
    public nonisolated static func decodeTagData(_ rawData: Data) -> String { "" }
    public nonisolated static func fallbackMetadata<T: SilkAudioTrackItem>(for item: T) -> AudioTrackMetadata {
        AudioTrackMetadata(path: item.path, title: item.title, duration: item.duration > 0 ? item.duration : nil)
    }
    public nonisolated static func splitArtistAndTitle(from sanitizedName: String) -> (artist: String, title: String) {
        ("", sanitizedName)
    }
    public nonisolated static func extractMetadataFromDisk<T: SilkAudioTrackItem>(item: T) async -> AudioTrackMetadata {
        fallbackMetadata(for: item)
    }
}

extension AudioTrackMetadataService: @unchecked Sendable {}

public enum SilkMusicMediaCategory: String, CaseIterable, Sendable {
    case video
    case audio

    public var title: String { self == .video ? "Videos" : "Music" }
    public var iconName: String { self == .video ? "film" : "music.note" }
}

public struct SilkMusicSortOptionItem: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let iconName: String

    public init(id: String, title: String, iconName: String) {
        self.id = id
        self.title = title
        self.iconName = iconName
    }
}

public enum SilkMusicModeScrollPolicy: Sendable {
    public static func shouldSuppressAutoScroll(
        suppressedID: UUID?,
        deadline: Date,
        selectedID: UUID?,
        now: Date = Date()
    ) -> Bool {
        guard let suppressedID, now < deadline else { return false }
        if let selectedID { return selectedID == suppressedID }
        return true
    }
}

@MainActor
public protocol SilkMusicModeHost: ObservableObject {
    var isPlaying: Bool { get }
    var isAudioOnly: Bool { get }
    var isMuted: Bool { get }
    var volume: Double { get }
    var maxVolumeLimit: Double { get }
    var duration: Double { get }
    var mediaTitle: String { get }
    var currentFilePath: String? { get }
    var activeAudioCodec: String? { get }
    var artworkImage: NSImage? { get }
    var audioRhythmLevels: [CGFloat] { get }
    var canRewindToStart: Bool { get }
    var isFullscreen: Bool { get }
    var hostWindow: NSWindow? { get }
    var isMusicQueueCollapsed: Bool { get }
    var keepWindowOnTop: Bool { get }
    var dualPlaylistMode: Bool { get }
    var activeMediaCategory: SilkMusicMediaCategory { get }
    var audioCount: Int { get }
    var videoCount: Int { get }
    var audioCurrentIndex: Int { get }
    var audioQueueItems: [SilkMusicQueueEntry] { get }
    var videoQueueItems: [SilkMusicQueueEntry] { get }
    var unifiedQueueItems: [SilkMusicQueueEntry] { get }
    var currentPlaylistEntry: SilkMusicQueueEntry? { get }
    var upcomingQueueEntry: SilkMusicQueueEntry? { get }
    var hasPreviousTrack: Bool { get }
    var hasNextTrack: Bool { get }
    var isSingleLoopMode: Bool { get }
    var isNonSequentialPlaybackMode: Bool { get }
    var playbackModeIconName: String { get }
    var playbackModeTitle: String { get }
    var sortOptions: [SilkMusicSortOptionItem] { get }
    var currentSortOptionID: String { get }
    var isSortAscending: Bool { get }

    func isSettingsWindow(_ window: NSWindow) -> Bool
    func toggleAlwaysOnTop()
    func togglePlayPause()
    func seek(to time: Double)
    func toggleMute()
    func setVolume(_ volume: Double, maxLimit: Double, showOSD: Bool)
    func cyclePlaybackModeAndShowOSD()
    func toggleMusicQueueCollapsed()
    func setMusicQueueCollapsed(_ collapsed: Bool, animated: Bool)
    func openSettings()
    func dismissAuxiliaryDrawersForClose()
    func beginWindowDrag(on window: NSWindow, with event: NSEvent)
    func cleanDisplayTitle(_ raw: String) -> String
    func switchPlaylistCategory(_ category: SilkMusicMediaCategory)
    func importMediaPaths(_ paths: [String], onAdded: @escaping @MainActor ([SilkMusicQueueEntry]) -> Void)
    func clearPlaylist(category: SilkMusicMediaCategory?)
    func removePlaylistItem(id: UUID, in category: SilkMusicMediaCategory?)
    func selectQueueItem(id: UUID, in category: SilkMusicMediaCategory)
    func sortAudioQueue(optionID: String, forceDirectionAscending: Bool?)
    func toggleAudioSortDirection()
    func makeProgressSectionView(windowWidth: CGFloat, isCollapsed: Bool) -> AnyView
    func makeSpeedMenuButtonView() -> AnyView
    func makeVinylDiscView(diameter: CGFloat, isPlaying: Bool) -> AnyView
}

public struct SilkMusicQueueEntry: SilkAudioTrackItem, Identifiable, Hashable, Sendable {
    public let id: UUID
    public let path: String
    public let title: String
    public let duration: Double
    public let isAudio: Bool

    public init(id: UUID, path: String, title: String, duration: Double, isAudio: Bool) {
        self.id = id
        self.path = path
        self.title = title
        self.duration = duration
        self.isAudio = isAudio
    }
}

@MainActor
public struct SilkMusicModeView<Host: SilkMusicModeHost>: View {
    public init(
        host: Host,
        onPlayNext: @escaping () -> Void,
        onPlayPrevious: @escaping () -> Void,
        onClosePlayback: @escaping () -> Void
    ) {}

    public var body: some View { EmptyView() }
}

public struct SilkCloudSyncRecord: Codable, Sendable, Equatable {
    public let key: String
    public let fileName: String
    public let positionSeconds: Double
    public let durationSeconds: Double
    public let watchState: String
    public let lastPlayedAt: Double

    public init(key: String, fileName: String, positionSeconds: Double, durationSeconds: Double, watchState: String, lastPlayedAt: Double) {
        self.key = key
        self.fileName = fileName
        self.positionSeconds = positionSeconds
        self.durationSeconds = durationSeconds
        self.watchState = watchState
        self.lastPlayedAt = lastPlayedAt
    }
}

@MainActor
public final class SilkCloudSyncService: ObservableObject {
    public static let shared = SilkCloudSyncService()
    public var onRemoteRecordsMerged: (([SilkCloudSyncRecord]) -> Void)?
    public init() {}
    public static func makeSyncKey(fileName: String, durationSeconds: Double) -> String {
        "\(fileName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())::\(Int(durationSeconds))"
    }
    public func publish(record: SilkCloudSyncRecord) {}
    public func pullRemoteChanges() {}
}
