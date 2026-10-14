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

    public func renderCurrentFrameImmediately() {}
    public func updateColorPipeline() {}
    public func clear() {}
}

@MainActor
public final class SilkPlayerEngine: ObservableObject {
    public let renderView = SilkMetalRenderView()
    @Published public private(set) var isPlaying: Bool = false
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

public enum SilkMediaFormatHelper {
    public static func resolutionText(width: Int, height: Int) -> String { "\(width)x\(height)" }
}

extension SilkPlayerEngine: @unchecked Sendable {}
extension SilkPlayerWrapper: @unchecked Sendable {}
extension SilkPlayerLayer: @unchecked Sendable {}
extension SilkSubtitleModel: @unchecked Sendable {}
extension SilkThumbnailEngine: @unchecked Sendable {}
