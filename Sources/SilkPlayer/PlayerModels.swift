import Foundation

public enum MediaType: Sendable {
    case video
    case subtitle
    case audio
    case unsupported
}

public enum PlaybackState: String, Sendable {
    case idle = "Idle"
    case loading = "Loading"
    case playing = "Playing"
    case paused = "Paused"
    case ended = "Ended"
    case error = "Error"
}

public struct MediaFileClassifier: Sendable {
    public static let videoExtensions: Set<String> = [
        "mp4", "mkv", "mov", "m4v", "ts", "m2ts", "webm", "avi",
        "flv", "wmv", "3gp", "mpg", "mpeg", "vob", "iso", "rmvb", "ogv"
    ]
    
    public static let subtitleExtensions: Set<String> = [
        "srt", "ass", "ssa", "vtt", "sub", "idx", "sup"
    ]

    public static let audioExtensions: Set<String> = [
        "mp3", "flac", "aac", "m4a", "wav", "ogg", "opus", "alac", "aiff"
    ]
    
    public static func classify(url: URL) -> MediaType {
        let ext = url.pathExtension.lowercased()
        if videoExtensions.contains(ext) {
            return .video
        } else if subtitleExtensions.contains(ext) {
            return .subtitle
        } else if audioExtensions.contains(ext) {
            return .audio
        }
        return .unsupported
    }

    /// Automatically locates companion subtitle files matching the media basename in the parent directory
    public static func findCompanionSubtitles(for url: URL) -> [URL] {
        guard url.isFileURL else { return [] }
        let parentDir = url.deletingLastPathComponent()
        let baseName = url.deletingPathExtension().lastPathComponent.lowercased()
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: parentDir,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }
        let subExtensions: Set<String> = ["ass", "ssa", "srt", "vtt", "sub"]
        return contents.filter { fileURL in
            let ext = fileURL.pathExtension.lowercased()
            guard subExtensions.contains(ext) else { return false }
            let name = fileURL.deletingPathExtension().lastPathComponent.lowercased()
            return name.hasPrefix(baseName) || name == baseName
        }
    }

    /// Scans a directory or external volume for playable video files (respects autoScanSubfolders setting)
    public static func findVideos(in directoryURL: URL, maxDepth: Int? = nil, maxCount: Int = 500) -> [URL] {
        guard directoryURL.isFileURL else { return [] }
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: directoryURL.path, isDirectory: &isDir), isDir.boolValue else {
            return []
        }

        let scanSubfolders = UserDefaults.standard.object(forKey: "autoScanSubfolders") as? Bool ?? true
        let effectiveDepth = maxDepth ?? (scanSubfolders ? 4 : 1)
        let keys: [URLResourceKey] = [.isDirectoryKey, .fileSizeKey, .nameKey]
        guard let enumerator = fm.enumerator(
            at: directoryURL,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return []
        }

        var results: [URL] = []
        for case let fileURL as URL in enumerator {
            if enumerator.level > effectiveDepth {
                enumerator.skipDescendants()
                continue
            }
            let ext = fileURL.pathExtension.lowercased()
            if videoExtensions.contains(ext) {
                results.append(fileURL)
                if results.count >= maxCount {
                    break
                }
            }
        }

        // Natural sort order (e.g. Episode 01 before Episode 02, S01 before S02)
        results.sort { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
        return results
    }
}

public struct TrackItem: Identifiable, Sendable, Equatable {
    public let id: Int
    public let type: String // "audio", "sub", "video"
    public let title: String
    public let lang: String
    public let codec: String
    public let isExternal: Bool
    public let isSelected: Bool

    public var displayName: String {
        var parts: [String] = []
        let localizedLang = SilkLanguageHelper.localizedLanguageName(for: lang)

        if !title.isEmpty && !title.hasPrefix("Track #") && !title.hasPrefix("Subtitle #") && !title.hasPrefix("Audio #") {
            parts.append(title)
        } else if !localizedLang.isEmpty {
            parts.append(localizedLang)
        } else if !title.isEmpty {
            parts.append(title)
        }

        if !lang.isEmpty {
            parts.append("[\(lang.uppercased())]")
        }
        if !codec.isEmpty {
            parts.append("(\(codec))")
        }
        if isExternal {
            parts.append("[External]")
        }
        if parts.isEmpty {
            return "Track #\(id)"
        }
        return parts.joined(separator: " ")
    }
}

public struct ChapterItem: Identifiable, Sendable, Equatable {
    public let id: Int
    public let title: String
    public let time: Double

    public init(id: Int, title: String, time: Double) {
        self.id = id
        self.title = title
        self.time = time
    }
}

public func formatPlaybackTime(_ seconds: Double) -> String {
    guard !seconds.isNaN && !seconds.isInfinite && seconds >= 0 else { return "00:00" }
    let total = Int(seconds)
    let h = total / 3600
    let m = (total % 3600) / 60
    let s = total % 60
    if h > 0 {
        return String(format: "%02d:%02d:%02d", h, m, s)
    } else {
        return String(format: "%02d:%02d", m, s)
    }
}

public enum OSDNotification: Equatable, Sendable {
    case volume(Double, isMuted: Bool)
    case seek(targetTime: Double, offset: Double, duration: Double)
    case playPause(isPlaying: Bool)
    case track(type: String, title: String)
    case pictureAdjustment(name: String, value: String)
    case screenshot(filename: String)
}

/// Abstract playback interface decoupling window manager & commands from the playback engine
@MainActor
public protocol PlayerControllable: AnyObject {
    var isLoaded: Bool { get }
    var isPlaying: Bool { get }
    var isMuted: Bool { get }
    var isFullscreen: Bool { get }
    var isDebandEnabled: Bool { get }
    var isHDRContent: Bool { get }
    var isHDREnabled: Bool { get }
    var isDolbyVision: Bool { get }
    var hdrFormatString: String { get }
    var sharpen: Double { get }
    var contrast: Double { get }
    var brightness: Double { get }
    var speed: Double { get }
    var audioTracks: [TrackItem] { get }
    var subtitleTracks: [TrackItem] { get }
    var chapters: [ChapterItem] { get }
    var cachedDuration: Double { get }
    var audioDelay: Double { get }
    var subtitleDelay: Double { get }
    var subtitleScale: Double { get }
    var videoAspectRatio: String { get }
    var videoWidth: Int { get }
    var videoHeight: Int { get }
    var displayVideoWidth: Int { get }
    var displayVideoHeight: Int { get }
    var videoRotation: Int { get }
    var effectiveAspectRatio: CGFloat { get }
    var isEffectiveVertical: Bool { get }
    var videoCodec: String { get }
    var videoFps: Double { get }
    var mediaTitle: String { get }
    var currentFilePath: String? { get }
    var selectedAudioTrackId: Int { get }
    var selectedSubtitleTrackId: Int { get }
    var isInspectorVisible: Bool { get }
    var isPlaylistDrawerVisible: Bool { get }
    var onNextTrackRequested: (@MainActor () -> Void)? { get set }
    var onPreviousTrackRequested: (@MainActor () -> Void)? { get set }

    var transform: VideoTransform { get }
    func play()
    func pause()
    func togglePlayPause()
    func step(seconds: Double)
    func stepFrame(forward: Bool)
    func rotateVideo(clockwise: Bool)
    func setExactRotation(_ angle: Int)
    func resetVideoRotation()
    func toggleFlipHorizontal()
    func toggleFlipVertical()
    func updateRememberedWindowSize(_ contentSize: NSSize)
    func adjustVolume(by delta: Double)
    func handleScrollWheelVolume(deltaY: Double)
    func takeScreenshot()
    func toggleMute()
    func cycleAudioTrack()
    func setAudioTrack(id: Int, notifyOSD: Bool)
    func cycleSubtitleTrack()
    func setSubtitleTrack(id: Int, notifyOSD: Bool)
    func openSubtitleDialog()
    func toggleFullscreen()
    func toggleDeband()
    func toggleHDR()
    func setHDREnabled(_ enabled: Bool)
    func adjustSharpen(by delta: Double)
    func adjustContrast(by delta: Double)
    func adjustBrightness(by delta: Double)
    func resetPictureAdjustments()
    func setSpeed(_ val: Double)
    func setAspectRatio(_ ratio: String)
    func adjustAudioDelay(by delta: Double)
    func resetAudioDelay()
    func adjustSubtitleDelay(by delta: Double)
    func resetSubtitleDelay()
    func adjustSubtitleScale(by delta: Double)
    func resetSubtitleScale()
    func setSubtitleScale(_ scale: Double)
    func setNightModeEnabled(_ enabled: Bool)
    var isFastForwarding2x: Bool { get }
    func startFastForward2x()
    func stopFastForward2x()
    func fitWindow(scale: Double)
    func toggleInspector()
    func togglePlaylistDrawer()
    func applyContentAspectRatioLock()
    func setFullscreenState(_ fullscreen: Bool)
    func stop()
    func closePlaybackOrReturnToEmpty()
    func stopAndReturnToLibrary()
}

public extension PlayerControllable {
    var mediaTitle: String { "" }
    var currentFilePath: String? { nil }
    var videoCodec: String { "" }
    var videoFps: Double { 0.0 }
    var selectedAudioTrackId: Int { -1 }
    var selectedSubtitleTrackId: Int { -1 }

    var transform: VideoTransform { VideoTransform() }
    func applyContentAspectRatioLock() {}
    func setFullscreenState(_ fullscreen: Bool) {}
    func setExactRotation(_ angle: Int) {}
    func resetVideoRotation() {}
    func updateRememberedWindowSize(_ contentSize: NSSize) {}
    func closePlaybackOrReturnToEmpty() {
        stop()
    }

    func stopAndReturnToLibrary() {
        closePlaybackOrReturnToEmpty()
    }
}

/// Pure mathematical geometry coordinate and size calculations for SilkPlayer.
public enum PlayerGeometry: Sendable {
    /// Objective physical minimum content size strictly preserving target aspect ratio and UI layout constraints:
    /// - Horizontal (aspect >= 1.0): Long edge (width) >= 640pt, Short edge (height) >= 360pt, exact aspect ratio.
    /// - Vertical (aspect < 1.0): Width >= 280pt (fits compact controls), height strictly aspect-driven,
    ///   capped at 55% of visible screen height to guarantee ample bidirectional resizing headroom.
    /// - Startup/Idle window: 640 x 360 base.
    public static func minimumContentSize(for aspect: CGFloat, screenVisibleHeight: CGFloat? = nil) -> NSSize {
        let safeAspect = max(0.001, aspect)
        if safeAspect < 1.0 {
            // 竖屏体系：宽为短边 (>= 280pt 容纳控制栏)，高严格以视频高宽比为准则，
            // 且严格受制于安全上限的 55%，杜绝倒挂死锁，保障充足自由缩放区间
            var baseW: CGFloat = 280.0
            var baseH = round(baseW / safeAspect)

            if let sH = screenVisibleHeight, sH > 0 {
                let maxSafeH = floor(sH * 0.85)
                let maxAllowedMinH = floor(maxSafeH * 0.55)
                if baseH > maxAllowedMinH {
                    baseH = maxAllowedMinH
                    baseW = max(200.0, round(baseH * safeAspect))
                }
            } else if baseH > 480.0 {
                baseH = 480.0
                baseW = max(200.0, round(baseH * safeAspect))
            }
            return NSSize(width: baseW, height: baseH)
        } else {
            // 横屏体系：宽为长边 (>= 640pt)，高为短边 (>= 360pt)，且严格以适配视频高宽比为准则
            let baseW: CGFloat = 640.0
            let targetH = round(baseW / safeAspect)
            if targetH < 360.0 {
                let clampedH: CGFloat = 360.0
                let clampedW = round(clampedH * safeAspect)
                return NSSize(width: clampedW, height: clampedH)
            } else {
                return NSSize(width: baseW, height: targetH)
            }
        }
    }

    /// Objective physical maximum safe content size preserving target aspect ratio and natural desktop breathing margins:
    /// - Vertical (aspect < 1.0): strictly capped at 85% of visible screen height to prevent jamming against menu bar and Dock
    /// - Horizontal (aspect >= 1.0): capped at 88% of visible screen bounds
    public static func maximumSafeContentSize(for aspect: CGFloat, screenVisibleSize: NSSize) -> NSSize {
        let safeAspect = max(0.001, aspect)
        let maxSafeH = floor(screenVisibleSize.height * 0.85)
        let maxSafeW = floor(screenVisibleSize.width * 0.88)

        var targetW = maxSafeW
        var targetH = round(targetW / safeAspect)

        if targetH > maxSafeH {
            targetH = maxSafeH
            targetW = round(targetH * safeAspect)
        }
        if targetW > maxSafeW {
            targetW = maxSafeW
            targetH = round(targetW / safeAspect)
        }
        return NSSize(width: targetW, height: targetH)
    }
}

public struct PlaylistDrawerDimensions: Sendable {
    /// Calculates adaptive playlist drawer width based on viewport width and fullscreen state
    /// - Parameters:
    ///   - viewportWidth: Current window or display width
    ///   - isFullscreen: Whether the player is currently in macOS fullscreen mode
    /// - Returns: Clamped adaptive width for the drawer
    public static func drawerWidth(for viewportWidth: CGFloat, isFullscreen: Bool) -> CGFloat {
        if isFullscreen {
            // Fullscreen mode: clamped between 250 and 340, scaling at ~18% of viewport
            return min(max(viewportWidth * 0.18, 250), 340)
        } else {
            // Windowed mode:
            // For compact / portrait windows (viewportWidth <= 480), clamp to 200..230 to balance
            // drawer content breathing room with leaving ample video/canvas tapping room (>140pt).
            // For standard / landscape windows, drawer scales at ~25% of window width, clamped to 200..280.
            if viewportWidth <= 480 {
                return min(max(viewportWidth * 0.55, 200), 230)
            } else {
                return min(max(viewportWidth * 0.25, 200), 280)
            }
        }
    }
}
