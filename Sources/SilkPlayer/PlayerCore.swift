import Foundation
import AppKit
import SwiftUI
import Combine
import QuartzCore
import CoreMedia
import CoreImage
import AVFoundation
import VideoToolbox
import Darwin
import SilkCoreKit

// MARK: - Decoupled High Precision Playback Clock
@MainActor
@Observable public final class PlayerClock {
    public var currentTime: Double = 0.0
    public var duration: Double = 0.0

    public init() {}
}

@MainActor
public final class PlayerCore: NSObject, ObservableObject, PlayerControllable, SilkPlayerLayerDelegate {
    // MARK: - Singleton & Key Bindings
    public static let shared = PlayerCore()

    // MARK: - Decoupled Time Clock
    public let clock = PlayerClock()

    // MARK: - Published Playback State
    public var currentTime: Double {
        get { clock.currentTime }
        set { clock.currentTime = newValue }
    }
    @Published public var duration: Double = 0.0 {
        didSet { clock.duration = duration }
    }
    @Published public var cachedDuration: Double = 0.0
    @Published public var isLoaded: Bool = false
    @Published public var isPlaying: Bool = false
    @Published public var playbackState: PlaybackState = .idle
    @Published public var mediaTitle: String = ""
    @Published public var currentFilePath: String? = nil
    private var pendingResumeTime: Double? = nil

    // MARK: - Audio Only & Artwork Metadata
    @Published public var isAudioOnly: Bool = false
    @Published public var artworkImage: NSImage? = nil

    // MARK: - Video & Codec Metadata
    @Published public var videoCodec: String = "Unknown"
    @Published public var videoWidth: Int = 0
    @Published public var videoHeight: Int = 0
    @Published public var displayVideoWidth: Int = 0
    @Published public var displayVideoHeight: Int = 0
    @Published public var videoRotation: Int = 0
    @Published public var videoAspectRatio: String = "auto"
    @Published public var videoFps: Double = 0.0
    @Published public var hwdecCurrent: String = "VideoToolbox (Hardware Direct)"
    @Published public var statusMessage: String = "Ready"

    @Published public var transform: VideoTransform = VideoTransform()
    public var lastLandscapeContentSize: NSSize? = nil
    public var lastPortraitContentSize: NSSize? = nil

    public var sampleAspectRatio: (num: Int, den: Int)? = nil

    public var effectiveAspectRatio: CGFloat {
        transform.displayAspectRatio(
            rawWidth: displayVideoWidth > 0 ? displayVideoWidth : videoWidth,
            rawHeight: displayVideoHeight > 0 ? displayVideoHeight : videoHeight,
            ratioSetting: videoAspectRatio
        )
    }

    public var isEffectiveVertical: Bool {
        transform.isEffectiveVertical(
            rawWidth: displayVideoWidth > 0 ? displayVideoWidth : videoWidth,
            rawHeight: displayVideoHeight > 0 ? displayVideoHeight : videoHeight,
            ratioSetting: videoAspectRatio
        )
    }

    // MARK: - UI & Control State
    @Published public var isDragTargeted: Bool = false
    @Published public var isHUDVisible: Bool = true {
        didSet {
            updateTrafficLightsVisibility()
        }
    }
    @Published public var volume: Double = 100.0
    @Published public var isMuted: Bool = false
    @Published public var isFullscreen: Bool = false
    @Published public var isScrubbing: Bool = false
    @Published public var scrubTime: Double = 0.0
    private var wasPlayingBeforeScrub: Bool = false
    @Published public var isInspectorVisible: Bool = false
    @Published public var isPlaylistDrawerVisible: Bool = false
    @Published public var activeOSD: OSDNotification? = nil
    public var hasAppliedInitialWindowSize: Bool = false

    // MARK: - Tracks & Chapters
    @Published public var audioTracks: [TrackItem] = []
    @Published public var subtitleTracks: [TrackItem] = []
    @Published public var selectedAudioTrackId: Int = 1
    @Published public var selectedSubtitleTrackId: Int = 0
    @Published public var chapters: [ChapterItem] = []

    // MARK: - HDR, Color & Picture Controls
    @Published public var isDebandEnabled: Bool = false
    @Published public var isHDRContent: Bool = false
    @Published public var isHDREnabled: Bool = true
    @Published public var isDolbyVision: Bool = false
    @Published public var hdrFormatString: String = ""
    @Published public var sharpen: Double = 0.0
    @Published public var contrast: Double = 0.0
    @Published public var brightness: Double = 0.0
    @Published public var speed: Double = 1.0

    // MARK: - Delays & Scales
    @Published public var audioDelay: Double = 0.0
    @Published public var subtitleDelay: Double = 0.0 {
        didSet {
            subtitleModel.subtitleDelay = subtitleDelay
        }
    }
    @Published public var subtitleScale: Double = 1.0
    @Published public var isFastForwarding2x: Bool = false
    @Published public var isVolumeHUDVisible: Bool = false
    private var volumeHideTask: Task<Void, Never>? = nil

    // MARK: - Window & Environment
    public weak var hostWindow: NSWindow?

    // MARK: - External Callbacks
    public var onProgressUpdate: ((String, Double, Double) -> Void)?
    public var onPlaybackEndedNaturally: (() -> Void)?
    public var onFileLoadedFromDrop: ((String) -> Void)?
    public var onFilesDropped: (([String]) -> Void)?
    public var onEscapePressed: (() -> Void)?
    public var onNextTrackRequested: (@MainActor () -> Void)?
    public var onPreviousTrackRequested: (@MainActor () -> Void)?
    public var onPlayRequestedWhenIdle: (@MainActor () -> Void)?

    // MARK: - Underlying SilkPlayer Engine
    public private(set) var playerLayer: SilkPlayerLayer?
    public let options = SilkPlayerOptions()
    public let subtitleModel = SubtitleModel()
    weak var renderContainer: MetalPlayerContainerView?
    private var hudAutoHideTimer: Timer?
    private var osdDismissTimer: Timer?
    private var pre2xSpeed: Double = 1.0

    // MARK: - Real-time Audio Rhythm Metering
    @Published public var audioRhythmLevels: [CGFloat] = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
    private var audioRhythmTimer: Timer?

    // MARK: - Initialization & Teardown
    override public init() {
        super.init()
        setupOptions()
        resetHUDAutoHideTimer()
    }

    deinit {
        MainActor.assumeIsolated {
            destroy()
        }
    }

    private func setupOptions() {
        // Industry-standard hardware decode pipeline with zero-copy Metal presentation
        options.hardwareDecode = true
        options.asynchronousDecompression = true // Hardware asynchronous decode pipeline delivers frames ahead of V-Sync
        options.isAccurateSeek = true // Universal Accurate Seek: Perfectly aligns presentation with timeline previews & eliminates relative drift
        options.preferredForwardBufferDuration = 0.8 // Universal Agile Stream Cache (Immediate start & low memory pressure)
        options.maxBufferDuration = 2.0 // Compact bounded cache cap across all formats
        options.videoAdaptable = false
        options.autoRotate = true
        options.autoSelectEmbedSubtitle = true
        options.isSeekImageSubtitle = true
        options.display = .plane
    }

    // MARK: - Render Container Integration
    public func attachRenderContainer(_ container: MetalPlayerContainerView) {
        self.renderContainer = container
        if let view = playerLayer?.player.view {
            if view.superview !== container {
                view.removeFromSuperview()
                view.autoresizingMask = []
                container.addSubview(view, positioned: .below, relativeTo: nil)
            }
            container.applyRenderViewLayout()
        }
    }

    public func updateRenderViewFrame(_ frame: NSRect) {
        renderContainer?.applyRenderViewLayout()
    }

    // MARK: - Audiophile Crossfade Management (歌曲切换淡出淡入)
    private var fadeTask: Task<Void, Never>?

    /// Smoothly fade out current audio playback volume before track switching
    public func performFadeOut(duration: TimeInterval = 0.28) async {
        guard let layer = playerLayer, isPlaying else { return }
        let startVol = layer.player.playbackVolume
        guard startVol > 0.001 else { return }

        let steps = 10
        let delayNs = UInt64((duration / Double(steps)) * 1_000_000_000)
        for i in (0...steps).reversed() {
            if Task.isCancelled { break }
            let frac = Float(i) / Float(steps)
            layer.player.playbackVolume = startVol * frac
            try? await Task.sleep(nanoseconds: delayNs)
        }
    }

    /// Smoothly fade in newly loaded audio playback from zero to target volume
    public func performFadeIn(targetVolume: Float, duration: TimeInterval = 0.38) {
        fadeTask?.cancel()
        fadeTask = Task { @MainActor [weak self] in
            guard let self = self, let layer = self.playerLayer else { return }
            layer.player.playbackVolume = 0.0
            let steps = 12
            let delayNs = UInt64((duration / Double(steps)) * 1_000_000_000)
            for i in 1...steps {
                if Task.isCancelled { break }
                try? await Task.sleep(nanoseconds: delayNs)
                guard self.playerLayer === layer else { break }
                let frac = Float(i) / Float(steps)
                layer.player.playbackVolume = targetVolume * frac
            }
            if !Task.isCancelled, self.playerLayer === layer {
                layer.player.playbackVolume = targetVolume
            }
        }
    }

    /// Smart load media with smooth crossfade (fade-out current audio track, load, and fade-in new audio track)
    public func loadMediaWithCrossfade(path: String, startTime: Double = 0.0, autoPlay: Bool? = nil) {
        fadeTask?.cancel()

        let resolvedURL: URL
        if path.contains("://") {
            resolvedURL = URL(string: path) ?? URL(fileURLWithPath: path)
        } else {
            resolvedURL = URL(fileURLWithPath: path)
        }
        let isIncomingAudio = MediaFileClassifier.classify(url: resolvedURL) == .audio
        let isCurrentAudio = self.isAudioOnly
        let shouldCrossfade = isPlaying && (isIncomingAudio || isCurrentAudio)

        if shouldCrossfade {
            fadeTask = Task { @MainActor [weak self] in
                guard let self = self else { return }
                await self.performFadeOut(duration: 0.28)
                guard !Task.isCancelled else { return }
                self.loadFile(path: path, startTime: startTime, autoPlay: autoPlay, fadeInOnStart: true)
            }
        } else {
            self.loadFile(path: path, startTime: startTime, autoPlay: autoPlay, fadeInOnStart: false)
        }
    }

    // MARK: - Playback Lifecycle
    public func loadFile(path: String, startTime: Double = 0.0, autoPlay: Bool? = nil, fadeInOnStart: Bool = false) {
        let resolvedURL: URL
        if path.contains("://") {
            resolvedURL = URL(string: path) ?? URL(fileURLWithPath: path)
        } else {
            resolvedURL = URL(fileURLWithPath: path)
        }

        let isIncomingAudio = MediaFileClassifier.classify(url: resolvedURL) == .audio
        stop(resetUI: false)

        self.currentFilePath = path
        SilkThumbnailEngine.shared.prepare(for: path)

        self.mediaTitle = resolvedURL.deletingPathExtension().lastPathComponent
        self.statusMessage = "Loading \(mediaTitle)..."
        self.hostWindow?.title = mediaTitle
        self.playbackState = .loading
        self.currentTime = startTime
        self.cachedDuration = 0.0
        self.duration = 0.0
        self.isLoaded = false
        self.isAudioOnly = isIncomingAudio
        if !isIncomingAudio {
            self.artworkImage = nil
        }

        options.startPlayTime = startTime
        self.pendingResumeTime = startTime > 0 ? startTime : nil

        let newLayer = SilkPlayerLayer(options: options, delegate: self)
        self.playerLayer = newLayer

        if let container = self.renderContainer, let renderView = newLayer.player.view {
            for subview in container.subviews {
                subview.removeFromSuperview()
            }
            renderView.autoresizingMask = []
            container.addSubview(renderView, positioned: .below, relativeTo: nil)
            container.applyRenderViewLayout()
        }

        let targetVolume = Float(self.volume / 100.0)
        // Apply initial volume & rate (starts at 0.0 when fadeInOnStart is active)
        newLayer.player.playbackVolume = fadeInOnStart ? 0.0 : targetVolume
        newLayer.player.isMuted = self.isMuted
        newLayer.player.playbackRate = Float(self.speed)

        self.subtitleModel.url = resolvedURL

        let shouldAutoPlay = autoPlay ?? AppSettings.shared.autoPlayOnLoad

        // Open media file asynchronously (0ms MainActor freeze, zero beachball)
        newLayer.openAsync(url: resolvedURL, autoPlay: shouldAutoPlay) { [weak self, weak newLayer] success in
            guard let self = self, let layer = newLayer, self.playerLayer === layer else { return }
            guard success else {
                self.playbackState = .error
                self.statusMessage = "Failed to load media"
                return
            }
            if shouldAutoPlay {
                layer.play()
                self.isPlaying = true
                self.playbackState = .playing
                if fadeInOnStart {
                    self.performFadeIn(targetVolume: targetVolume, duration: 0.38)
                }
            } else {
                layer.pause()
                self.isPlaying = false
                self.playbackState = .paused
            }
        }
    }

    public func play() {
        guard let layer = playerLayer else { return }
        layer.play()
        isPlaying = true
        playbackState = .playing
        resetHUDAutoHideTimer()
        startAudioRhythmMonitoring()
    }

    public func pause() {
        guard let layer = playerLayer else { return }
        layer.pause()
        isPlaying = false
        playbackState = .paused
        isHUDVisible = true
        hudAutoHideTimer?.invalidate()
        stopAudioRhythmMonitoring()
        if let path = currentFilePath, currentTime > 0 {
            onProgressUpdate?(path, currentTime, duration)
        }
    }

    public func togglePlayPause() {
        if playbackState == .ended {
            replay()
            if !isAudioOnly {
                showOSD(.playPause(isPlaying: true))
            }
            return
        }
        if !isLoaded {
            onPlayRequestedWhenIdle?()
            return
        }
        if isPlaying {
            pause()
            if !isAudioOnly {
                showOSD(.playPause(isPlaying: false))
            }
        } else {
            play()
            if !isAudioOnly {
                showOSD(.playPause(isPlaying: true))
            }
        }
    }

    public func stop() {
        stop(resetUI: true)
    }

    public func stop(resetUI: Bool) {
        stopAudioRhythmMonitoring()
        if let path = currentFilePath, currentTime > 0 {
            onProgressUpdate?(path, currentTime, duration)
        }
        if let layer = playerLayer {
            layer.delegate = nil
            layer.player.view?.removeFromSuperview()
            layer.pause()
            layer.stop()
            layer.close()
            playerLayer = nil
        }
        if resetUI, let container = self.renderContainer {
            for subview in container.subviews {
                subview.removeFromSuperview()
            }
        }
        isPlaying = false
        isLoaded = false
        playbackState = .idle
        currentTime = 0.0
        duration = 0.0
        cachedDuration = 0.0
        subtitleModel.url = nil
        subtitleModel.selectedSubtitleInfo = nil
        audioTracks.removeAll()
        subtitleTracks.removeAll()
        chapters.removeAll()
        currentFilePath = nil
        if resetUI {
            isPlaylistDrawerVisible = false
            isInspectorVisible = false
        }
        hasAppliedInitialWindowSize = false
        isDolbyVision = false
        isHDRContent = false
        hdrFormatString = "SDR (BT.709)"
        self.transform = VideoTransform()
        self.videoRotation = 0
        self.videoWidth = 0
        self.videoHeight = 0
        self.displayVideoWidth = 0
        self.displayVideoHeight = 0
        self.lastLandscapeContentSize = nil
        self.lastPortraitContentSize = nil

        // Purge subtitle bitmap and thumbnail engine cache from memory
        SubtitleImageCache.shared.clear()
        SilkThumbnailEngine.shared.reset()
        // PERF-002: Reclaim unused heap pages across all malloc zones on background utility queue (0ms main-thread freeze)
        DispatchQueue.global(qos: .utility).async {
            PlayerCore.trimMemoryFootprint()
        }

        if resetUI, let window = hostWindow ?? NSApp.keyWindow {
            window.title = "SilkPlayer"
            window.contentAspectRatio = .zero
            window.aspectRatio = .zero
            window.resizeIncrements = NSSize(width: 1, height: 1)
            let emptyMin = NSSize(width: 640, height: 360)
            window.minSize = emptyMin
            window.contentMinSize = emptyMin
        }
    }

    // MARK: - Memory Optimization & Trim
    public nonisolated static func trimMemoryFootprint() {
        #if canImport(Darwin)
        var count: UInt32 = 0
        var zones: UnsafeMutablePointer<vm_address_t>? = nil
        if malloc_get_all_zones(mach_task_self_, nil, &zones, &count) == KERN_SUCCESS, let z = zones {
            for i in 0..<Int(count) {
                if let ptr = UnsafeMutableRawPointer(bitPattern: UInt(z[i])) {
                    let zone = ptr.assumingMemoryBound(to: malloc_zone_t.self)
                    malloc_zone_pressure_relief(zone, 0)
                }
            }
        } else {
            malloc_zone_pressure_relief(nil, 0)
        }
        #endif
    }

    public func replay() {
        seek(to: 0.0)
        play()
    }

    // MARK: - Seeking & Scrubbing
    public func seek(to seconds: Double) {
        guard let layer = playerLayer else { return }
        let clamped = max(0.0, min(duration > 0 ? duration : seconds, seconds))
        self.currentTime = clamped
        layer.seek(time: clamped, autoPlay: isPlaying, completion: { _ in })
        _ = self.subtitleModel.subtitle(currentTime: clamped)
        if let path = currentFilePath, clamped > 0 {
            onProgressUpdate?(path, clamped, duration)
        }
        reportUserActivity()
    }

    public func step(seconds: Double) {
        guard duration > 0 else { return }
        let target = max(0.0, min(duration, currentTime + seconds))
        seek(to: target)
        showSeekOSD(targetTime: target, offset: seconds, duration: duration)
    }

    public func stepFrame(forward: Bool) {
        if isPlaying {
            pause()
        }
        playerLayer?.player.stepFrame(forward: forward)
        let fps = (playerLayer?.player.nominalFrameRate ?? 0) > 0 ? Double(playerLayer!.player.nominalFrameRate) : 24.0
        let delta = forward ? (1.0 / fps) : (-1.0 / fps)
        let newEstimatedTime = max(0.0, min(duration, currentTime + delta))
        self.currentTime = newEstimatedTime
        showSeekOSD(targetTime: newEstimatedTime, offset: delta, duration: duration)
        reportUserActivity()
    }


    public func startScrubbing() {
        isScrubbing = true
        scrubTime = currentTime
        wasPlayingBeforeScrub = isPlaying
        if isPlaying {
            playerLayer?.pause()
        }
        reportUserActivity()
    }

    private var lastScrubSeekTime: CFTimeInterval = 0

    public func updateScrubbing(to time: Double) {
        isScrubbing = true
        let clamped = max(0.0, min(duration > 0 ? duration : time, time))
        scrubTime = clamped
        self.currentTime = clamped

        let now = CACurrentMediaTime()
        if (now - lastScrubSeekTime) >= 0.050 { // 20Hz Throttle (P1-2)
            lastScrubSeekTime = now
            playerLayer?.requestSeek(time: clamped, exact: false)
        }
        _ = self.subtitleModel.subtitle(currentTime: clamped)
        reportUserActivity()
    }

    public func finishScrubbing(to time: Double) {
        isScrubbing = false
        let clamped = max(0.0, min(duration > 0 ? duration : time, time))
        scrubTime = clamped
        self.currentTime = clamped
        lastScrubSeekTime = 0
        playerLayer?.requestSeek(time: clamped, exact: true)
        if wasPlayingBeforeScrub {
            playerLayer?.play()
            isPlaying = true
            playbackState = .playing
            resetHUDAutoHideTimer()
            startAudioRhythmMonitoring()
        }
        _ = self.subtitleModel.subtitle(currentTime: clamped)
        if let path = currentFilePath, clamped > 0 {
            onProgressUpdate?(path, clamped, duration)
        }
        reportUserActivity()
    }

    // MARK: - Volume & Audio
    public func setVolume(_ val: Double, maxLimit: Double = 150.0, showOSD: Bool = true) {
        let clamped = max(0.0, min(maxLimit, val))
        self.volume = clamped
        if isMuted && clamped > 0 {
            isMuted = false
        }
        playerLayer?.player.playbackVolume = Float(clamped / 100.0)
        playerLayer?.player.isMuted = isMuted

        if showOSD {
            showVolumeOSD()
        }
    }

    public func adjustVolume(by delta: Double = 10.0) {
        setVolume(volume + delta, showOSD: true)
    }

    public func handleScrollWheelVolume(deltaY: Double) {
        let step = deltaY * 5.0
        adjustVolume(by: step)
    }

    public func toggleMute() {
        isMuted.toggle()
        playerLayer?.player.isMuted = isMuted
        showVolumeOSD()
    }

    // MARK: - Speed Controls
    public func setSpeed(_ targetSpeed: Double) {
        let clamped = max(0.25, min(4.0, targetSpeed))
        self.speed = clamped
        playerLayer?.player.playbackRate = Float(clamped)
        showOSD(.pictureAdjustment(name: "播放倍速", value: String(format: "%.2fx", clamped)))
    }

    public func startFastForward2x() {
        guard !isFastForwarding2x else { return }
        pre2xSpeed = speed
        isFastForwarding2x = true
        playerLayer?.player.playbackRate = 2.0
        showOSD(.pictureAdjustment(name: "Playback", value: "2.0x Fast Forward"))
    }

    public func stopFastForward2x() {
        guard isFastForwarding2x else { return }
        isFastForwarding2x = false
        playerLayer?.player.playbackRate = Float(pre2xSpeed)
        showOSD(.pictureAdjustment(name: "Playback", value: String(format: "%.2fx", pre2xSpeed)))
    }

    // MARK: - Track Management
    public func setAudioTrack(id: Int, notifyOSD: Bool = false) {
        guard let player = playerLayer?.player else { return }
        let tracks = player.tracks(mediaType: .audio)
        if let target = tracks.first(where: { $0.trackID == Int32(id) }) {
            player.select(track: target)
            selectedAudioTrackId = id
            refreshTracks()
            if notifyOSD {
                showOSD(.track(type: "Audio", title: target.name))
            }
        }
    }

    public func cycleAudioTrack() {
        guard !audioTracks.isEmpty else { return }
        let currentIndex = audioTracks.firstIndex(where: { $0.id == selectedAudioTrackId }) ?? 0
        let nextIndex = (currentIndex + 1) % audioTracks.count
        setAudioTrack(id: audioTracks[nextIndex].id, notifyOSD: true)
    }

    public func setSubtitleTrack(id: Int, notifyOSD: Bool = false) {
        guard let player = playerLayer?.player else { return }
        let tracks = player.tracks(mediaType: .subtitle)
        if id == 0 {
            // Disable subtitles
            subtitleModel.selectedSubtitleInfo = nil
            player.deselectTrack(mediaType: .subtitle)
            for track in tracks {
                track.isEnabled = false
            }
            selectedSubtitleTrackId = 0
            refreshTracks()
            if notifyOSD {
                showOSD(.track(type: "Subtitle", title: L10n.disableSubtitles))
            }
            return
        }

        if !subtitleModel.subtitleInfos.isEmpty {
            let targetIdx = id - 1
            guard targetIdx >= 0 && targetIdx < subtitleModel.subtitleInfos.count else { return }
            let targetInfo = subtitleModel.subtitleInfos[targetIdx]
            subtitleModel.selectedSubtitleInfo = targetInfo
            if let mediaTrack = targetInfo as? (any MediaPlayerTrack) {
                player.select(track: mediaTrack) { [weak self] in
                    self?.subtitleModel.objectWillChange.send()
                    self?.subtitleModel.updateActiveSubtitles()
                }
            } else if let matched = tracks.first(where: { String($0.trackID) == targetInfo.subtitleID }) {
                player.select(track: matched)
            }
            selectedSubtitleTrackId = id
            refreshTracks()
            if notifyOSD {
                let name = targetInfo.name.isEmpty ? "\(L10n.subtitles) #\(id)" : targetInfo.name
                showOSD(.track(type: "Subtitle", title: name))
            }
        } else {
            if let target = tracks.first(where: { $0.trackID == Int32(id) }) {
                player.select(track: target)
                selectedSubtitleTrackId = id
                refreshTracks()
                if notifyOSD {
                    showOSD(.track(type: "Subtitle", title: target.name))
                }
            }
        }
    }

    public func cycleSubtitleTrack() {
        let allOptions = [0] + subtitleTracks.map { $0.id }
        guard let currentIndex = allOptions.firstIndex(of: selectedSubtitleTrackId) else { return }
        let nextIndex = (currentIndex + 1) % allOptions.count
        setSubtitleTrack(id: allOptions[nextIndex], notifyOSD: true)
    }

    public func addSubtitle(path: String) {
        let subURL = URL(fileURLWithPath: path)
        let info = URLSubtitleInfo(url: subURL)
        subtitleModel.addSubtitle(info: info)
        subtitleModel.selectedSubtitleInfo = info
        refreshTracks()
        showOSD(.track(type: "Subtitle Added", title: subURL.lastPathComponent))
    }

    public func openSubtitleDialog() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [
            .init(filenameExtension: "srt")!,
            .init(filenameExtension: "ass")!,
            .init(filenameExtension: "vtt")!
        ]
        if panel.runModal() == .OK, let url = panel.url {
            addSubtitle(path: url.path)
        }
    }

    public func refreshTracks() {
        guard let player = playerLayer?.player else { return }
        let aTracks = player.tracks(mediaType: .audio)
        self.audioTracks = aTracks.map { track in
            let codec = track.codecName
            return TrackItem(
                id: Int(track.trackID),
                type: "audio",
                title: track.name,
                lang: track.languageCode ?? "",
                codec: codec,
                isExternal: false,
                isSelected: track.isEnabled
            )
        }
        if let selectedA = aTracks.first(where: { $0.isEnabled }) {
            self.selectedAudioTrackId = Int(selectedA.trackID)
        }

        if !subtitleModel.subtitleInfos.isEmpty {
            // Auto-select subtitle based on user's preferred language if none selected yet
            if subtitleModel.selectedSubtitleInfo == nil && options.autoSelectEmbedSubtitle {
                let preferred = AppSettings.shared.preferredSubtitleLang.lowercased()
                var matched: SubtitleInfo? = nil
                if preferred != "auto" {
                    let prefLangs = preferred.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                    // Priority 1: Match non-commentary tracks with preferred language
                    matched = subtitleModel.subtitleInfos.first { info in
                        let lang = ((info as? MediaPlayerTrack)?.languageCode ?? (info as? FFmpegAssetTrack)?.languageCode ?? "").lowercased()
                        let name = info.name.lowercased()
                        let isCommentary = name.contains("commentary") || name.contains("导评") || name.contains("评论")
                        return !isCommentary && prefLangs.contains(where: { p in !p.isEmpty && (lang.contains(p) || name.contains(p)) })
                    }
                    // Priority 2: Match any track with preferred language
                    if matched == nil {
                        matched = subtitleModel.subtitleInfos.first { info in
                            let lang = ((info as? MediaPlayerTrack)?.languageCode ?? (info as? FFmpegAssetTrack)?.languageCode ?? "").lowercased()
                            let name = info.name.lowercased()
                            return prefLangs.contains(where: { p in !p.isEmpty && (lang.contains(p) || name.contains(p)) })
                        }
                    }
                }
                if matched == nil {
                    matched = subtitleModel.subtitleInfos.first(where: { $0.isEnabled })
                        ?? subtitleModel.subtitleInfos.first(where: { !$0.name.lowercased().contains("commentary") })
                        ?? subtitleModel.subtitleInfos.first
                }
                if let found = matched {
                    subtitleModel.selectedSubtitleInfo = found
                }
            }

            // Guarantee the underlying engine selects and decodes the chosen subtitle track
            if let active = subtitleModel.selectedSubtitleInfo, let mediaTrack = active as? (any MediaPlayerTrack) {
                player.select(track: mediaTrack) { [weak self] in
                    self?.subtitleModel.objectWillChange.send()
                    self?.subtitleModel.updateActiveSubtitles()
                }
            }
            self.subtitleTracks = subtitleModel.subtitleInfos.enumerated().map { idx, subInfo in
                let lang = (subInfo as? MediaPlayerTrack)?.languageCode ?? (subInfo as? FFmpegAssetTrack)?.languageCode ?? ""
                let codec: String
                if let ffmpegTrack = subInfo as? FFmpegAssetTrack {
                    codec = ffmpegTrack.isImageSubtitle ? "PGS" : ffmpegTrack.codecName.uppercased()
                } else if let urlSub = subInfo as? URLSubtitleInfo {
                    codec = urlSub.downloadURL.pathExtension.uppercased()
                } else {
                    codec = ""
                }
                let rawName = subInfo.name.trimmingCharacters(in: .whitespacesAndNewlines)
                let title = rawName.isEmpty ? "\(L10n.subtitles) #\(idx + 1)" : rawName
                return TrackItem(
                    id: idx + 1,
                    type: "sub",
                    title: title,
                    lang: lang,
                    codec: codec,
                    isExternal: subInfo is URLSubtitleInfo,
                    isSelected: subInfo === subtitleModel.selectedSubtitleInfo
                )
            }
            if let selected = subtitleModel.selectedSubtitleInfo,
               let selIdx = subtitleModel.subtitleInfos.firstIndex(where: { $0 === selected }) {
                self.selectedSubtitleTrackId = selIdx + 1
            } else {
                self.selectedSubtitleTrackId = 0
            }
        } else {
            let sTracks = player.tracks(mediaType: .subtitle)
            self.subtitleTracks = sTracks.map { track in
                let codec = track.codecName
                return TrackItem(
                    id: Int(track.trackID),
                    type: "sub",
                    title: track.name,
                    lang: track.languageCode ?? "",
                    codec: codec,
                    isExternal: false,
                    isSelected: track.isEnabled
                )
            }
            if let selectedS = sTracks.first(where: { $0.isEnabled }) {
                self.selectedSubtitleTrackId = Int(selectedS.trackID)
            }
        }
    }

    public func refreshChapters() {
        guard let player = playerLayer?.player else { return }
        self.chapters = player.chapters.enumerated().map { idx, ch in
            ChapterItem(id: idx, title: ch.title, time: ch.start)
        }
    }

    // MARK: - HDR, Color & Adjustments
    public func checkHDRStatus() {
        detectMetadata()
    }

    public func toggleHDR() {
        isHDREnabled.toggle()
        showOSD(.pictureAdjustment(name: "HDR", value: isHDREnabled ? "Enabled" : "Disabled"))
    }

    public func setHDREnabled(_ enabled: Bool) {
        isHDREnabled = enabled
    }

    public func toggleDeband() {
        isDebandEnabled.toggle()
        showOSD(.pictureAdjustment(name: "Deband", value: isDebandEnabled ? "On" : "Off"))
    }

    // MARK: - Video Transform & Orientation Rotation
    public func rotateVideo(clockwise: Bool = true) {
        let oldIsPerp = transform.isPerpendicular
        if clockwise {
            transform.rotateClockwise()
        } else {
            transform.rotateCounterclockwise()
        }
        let newIsPerp = transform.isPerpendicular
        let isOrientationChange = (oldIsPerp != newIsPerp)

        applyTransformChange(isOrientationChange: isOrientationChange)
        showOSD(.pictureAdjustment(name: L10n.tr("Rotation", "画面旋转"), value: "\(transform.effectiveRotation)°"))
    }

    public func setExactRotation(_ targetEffectiveAngle: Int) {
        let oldIsPerp = transform.isPerpendicular
        let step = ((targetEffectiveAngle - transform.intrinsicRotation) % 360 + 360) % 360
        transform.userRotation = step
        let newIsPerp = transform.isPerpendicular
        let isOrientationChange = (oldIsPerp != newIsPerp)

        applyTransformChange(isOrientationChange: isOrientationChange)
        showOSD(.pictureAdjustment(name: L10n.tr("Rotation", "画面旋转"), value: "\(transform.effectiveRotation)°"))
    }

    public func resetVideoRotation() {
        let oldIsPerp = transform.isPerpendicular
        transform.resetToNatural()
        let newIsPerp = transform.isPerpendicular
        let isOrientationChange = (oldIsPerp != newIsPerp)

        applyTransformChange(isOrientationChange: isOrientationChange)
        showOSD(.pictureAdjustment(name: L10n.tr("Rotation", "画面旋转"), value: L10n.tr("Natural Orientation", "已复位")))
    }

    public func toggleFlipHorizontal() {
        transform.toggleFlipH()
        applyTransformChange(isOrientationChange: false)
        showOSD(.pictureAdjustment(name: L10n.tr("Flip Horizontal", "水平翻转"), value: transform.flipH ? L10n.tr("On", "开启") : L10n.tr("Off", "关闭")))
    }

    public func toggleFlipVertical() {
        transform.toggleFlipV()
        applyTransformChange(isOrientationChange: false)
        showOSD(.pictureAdjustment(name: L10n.tr("Flip Vertical", "垂直翻转"), value: transform.flipV ? L10n.tr("On", "开启") : L10n.tr("Off", "关闭")))
    }

    private func applyTransformChange(isOrientationChange: Bool) {
        self.videoRotation = transform.effectiveRotation

        // 1. 同步给 Metal 渲染器并触发暂停态即时重绘
        if let renderView = renderContainer?.metalRenderView ?? (playerLayer?.player.view as? SilkMetalRenderView) {
            renderView.transformUniforms = MetalTransformUniforms(
                rotation: Int32(transform.effectiveRotation),
                flipH: transform.flipH ? 1 : 0,
                flipV: transform.flipV ? 1 : 0
            )
            renderView.targetAspect = transform.displayAspectRatio(
                rawWidth: displayVideoWidth > 0 ? displayVideoWidth : videoWidth,
                rawHeight: displayVideoHeight > 0 ? displayVideoHeight : videoHeight,
                ratioSetting: videoAspectRatio
            )
            renderView.renderCurrentFrameImmediately()
        }
        renderContainer?.applyRenderViewLayout()

        // 2. 窗口模式交互
        applyRotationWindowAdaptation(isOrientationChange: isOrientationChange)
    }



    public func adjustSharpen(by delta: Double) {
        sharpen = max(-1.0, min(1.0, sharpen + delta))
        showOSD(.pictureAdjustment(name: "Sharpen", value: String(format: "%+.1f", sharpen)))
    }

    public func adjustContrast(by delta: Double) {
        contrast = max(-1.0, min(1.0, contrast + delta))
        showOSD(.pictureAdjustment(name: "Contrast", value: String(format: "%+.1f", contrast)))
    }

    public func adjustBrightness(by delta: Double) {
        brightness = max(-1.0, min(1.0, brightness + delta))
        showOSD(.pictureAdjustment(name: "Brightness", value: String(format: "%+.1f", brightness)))
    }

    public func resetPictureAdjustments() {
        sharpen = 0.0
        contrast = 0.0
        brightness = 0.0
        showOSD(.pictureAdjustment(name: "Picture", value: "Reset"))
    }

    public func adjustAudioDelay(by delta: Double) {
        audioDelay += delta
        showOSD(.pictureAdjustment(name: "Audio Delay", value: String(format: "%+.2fs", audioDelay)))
    }

    public func setAudioDelay(_ val: Double) {
        audioDelay = val
    }

    public func resetAudioDelay() {
        audioDelay = 0.0
        showOSD(.pictureAdjustment(name: "Audio Delay", value: "0.00s"))
    }

    public func adjustSubtitleDelay(by delta: Double) {
        subtitleDelay += delta
        showOSD(.pictureAdjustment(name: "Subtitle Delay", value: String(format: "%+.2fs", subtitleDelay)))
    }

    public func setSubtitleDelay(_ val: Double) {
        subtitleDelay = val
    }

    public func resetSubtitleDelay() {
        subtitleDelay = 0.0
        showOSD(.pictureAdjustment(name: "Subtitle Delay", value: "0.00s"))
    }

    public func adjustSubtitleScale(by delta: Double) {
        subtitleScale = max(0.5, min(2.5, subtitleScale + delta))
        showOSD(.pictureAdjustment(name: "Subtitle Scale", value: String(format: "%.1fx", subtitleScale)))
    }

    public func setSubtitleScale(_ scale: Double) {
        subtitleScale = max(0.5, min(2.5, scale))
        subtitleModel.objectWillChange.send()
        objectWillChange.send()
    }

    public func resetSubtitleScale() {
        subtitleScale = 1.0
        subtitleModel.objectWillChange.send()
        objectWillChange.send()
        showOSD(.pictureAdjustment(name: "Subtitle Scale", value: "1.0x"))
    }

    public func setNightModeEnabled(_ enabled: Bool) {
        // Dialogue boost audio filter placeholder silenced
    }

    // MARK: - Screenshot Capture
    public func takeScreenshot() {
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            let dir = AppSettings.shared.screenshotDirectory
            try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)

            let formatter = DateFormatter()
            formatter.dateFormat = "yyyyMMdd_HHmmss"
            let timestamp = formatter.string(from: Date())
            let isJPEG = AppSettings.shared.screenshotFormat.lowercased() == "jpeg"
            let ext = isJPEG ? "jpg" : "png"
            let filename = "SilkPlayer_\(timestamp).\(ext)"
            let fileURL = URL(fileURLWithPath: dir).appendingPathComponent(filename)

            // Frame capture pipeline:
            var finalCGImage: CGImage? = nil

            // 1. Dolby Vision (Profile 5 etc.): Priority to SilkThumbnailEngine for true-color tone-mapped rendering (COLOR-002)
            if self.isDolbyVision, let path = self.currentFilePath, !path.isEmpty {
                finalCGImage = await SilkThumbnailEngine.shared.captureScreenshotCGImage(for: path, at: max(0, self.currentTime))
            }

            // 2. Standard SDR / Hardware video layer thumbnail capture
            if finalCGImage == nil {
                finalCGImage = await self.playerLayer?.player.thumbnailImageAtCurrentTime()
            }

            // 3. Fallback to SilkThumbnailEngine if hardware capture fails or for other formats
            if finalCGImage == nil, let path = self.currentFilePath, !path.isEmpty {
                finalCGImage = await SilkThumbnailEngine.shared.captureScreenshotCGImage(for: path, at: max(0, self.currentTime))
            }

            // 4. Fallback: Extract direct frame from AVAsset for local or stream files
            if finalCGImage == nil, let path = self.currentFilePath, !path.isEmpty {
                let url = path.contains("://") ? (URL(string: path) ?? URL(fileURLWithPath: path)) : URL(fileURLWithPath: path)
                let asset = AVURLAsset(url: url)
                let generator = AVAssetImageGenerator(asset: asset)
                generator.appliesPreferredTrackTransform = true
                generator.requestedTimeToleranceBefore = CMTime(seconds: 0.5, preferredTimescale: 600)
                generator.requestedTimeToleranceAfter = CMTime(seconds: 0.5, preferredTimescale: 600)
                let cmTime = CMTime(seconds: max(0, self.currentTime), preferredTimescale: 600)
                if let (img, _) = try? await generator.image(at: cmTime) {
                    finalCGImage = img
                }
            }

            // Fallback 2: Window Server composite capture for current video view
            if finalCGImage == nil {
                if let view = self.renderContainer ?? self.playerLayer?.player.view,
                   let window = view.window, view.bounds.width > 0, view.bounds.height > 0 {
                    let windowID = CGWindowID(window.windowNumber)
                    if let windowImg = CGWindowListCreateImage(
                        .null,
                        .optionIncludingWindow,
                        windowID,
                        [.boundsIgnoreFraming, .bestResolution]
                    ) {
                        finalCGImage = windowImg
                    }
                }
            }

            guard var image = finalCGImage else { return }

            if self.transform.userRotation != 0 || self.transform.flipH || self.transform.flipV {
                let ci = CIImage(cgImage: image)
                var xform = CGAffineTransform.identity
                if self.transform.userRotation != 0 {
                    let rad = -CGFloat(self.transform.userRotation) * .pi / 180.0
                    xform = xform.rotated(by: rad)
                }
                if self.transform.flipH {
                    xform = xform.scaledBy(x: -1, y: 1)
                }
                if self.transform.flipV {
                    xform = xform.scaledBy(x: 1, y: -1)
                }
                let transformedCi = ci.transformed(by: xform)
                let ctx = CIContext()
                if let rotatedCg = ctx.createCGImage(transformedCi, from: transformedCi.extent) {
                    image = rotatedCg
                }
            }

            let rep = NSBitmapImageRep(cgImage: image)
            let fileType: NSBitmapImageRep.FileType = isJPEG ? .jpeg : .png
            let props: [NSBitmapImageRep.PropertyKey: Any] = isJPEG ? [.compressionFactor: 0.92] : [:]
            if let data = rep.representation(using: fileType, properties: props) {
                do {
                    try data.write(to: fileURL)

                    // Also copy image to macOS General Pasteboard for immediate pasting (Cmd+V)
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    let nsImage = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
                    pasteboard.writeObjects([nsImage])

                    self.showOSD(.screenshot(filename: filename))
                } catch {
                    // silently ignore write errors
                }
            }
        }
    }

    // MARK: - Window & UI Navigation
    public func toggleFullscreen() {
        guard let window = hostWindow ?? NSApp.keyWindow else { return }
        if !isFullscreen {
            isPlaylistDrawerVisible = false
        }
        window.toggleFullScreen(nil)
    }

    public func setFullscreenState(_ fullscreen: Bool) {
        isFullscreen = fullscreen
        if fullscreen {
            isPlaylistDrawerVisible = false
        }
        updateTrafficLightsVisibility()
    }

    public func fitWindow(scale: Double) {
        guard let window = hostWindow ?? NSApp.keyWindow, videoWidth > 0, videoHeight > 0 else { return }
        let screenFrame = window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)
        let aspect = effectiveAspectRatio
        let isPerpendicular = transform.isPerpendicular
        let rawW = CGFloat(displayVideoWidth > 0 ? displayVideoWidth : videoWidth)
        let rawH = CGFloat(displayVideoHeight > 0 ? displayVideoHeight : videoHeight)
        let baseW = isPerpendicular ? rawH : rawW

        var targetContentW = round(baseW * CGFloat(scale))
        var targetContentH = round(targetContentW / aspect)

        let maxSafeSz = PlayerGeometry.maximumSafeContentSize(for: aspect, screenVisibleSize: screenFrame.size)
        let maxW = maxSafeSz.width
        let maxH = maxSafeSz.height
        if targetContentW > maxW {
            targetContentW = maxW
            targetContentH = round(targetContentW / aspect)
        }
        if targetContentH > maxH {
            targetContentH = maxH
            targetContentW = round(targetContentH * aspect)
        }
        let minContentSz = PlayerGeometry.minimumContentSize(for: aspect, screenVisibleHeight: screenFrame.height)
        if targetContentW < minContentSz.width {
            targetContentW = minContentSz.width
            targetContentH = round(targetContentW / aspect)
        }
        if targetContentH < minContentSz.height {
            targetContentH = minContentSz.height
            targetContentW = round(targetContentH * aspect)
        }

        let frameW = targetContentW
        let frameH = targetContentH

        let currentCenter = CGPoint(x: window.frame.midX, y: window.frame.midY)
        let newX = max(screenFrame.minX, min(screenFrame.maxX - frameW, currentCenter.x - frameW / 2))
        let newY = max(screenFrame.minY, min(screenFrame.maxY - frameH, currentCenter.y - frameH / 2))
        window.setFrame(NSRect(x: newX, y: newY, width: frameW, height: frameH), display: true, animate: true)
        applyContentAspectRatioLock()
    }

    public func toggleInspector() {
        isInspectorVisible.toggle()
        if isInspectorVisible {
            isPlaylistDrawerVisible = false
        }
    }

    public func togglePlaylistDrawer() {
        isPlaylistDrawerVisible.toggle()
        if isPlaylistDrawerVisible {
            isInspectorVisible = false
        }
    }

    public func toggleHUDVisibility() {
        isHUDVisible.toggle()
        if isHUDVisible {
            resetHUDAutoHideTimer()
        }
    }

    public func reportUserActivity() {
        if !isHUDVisible {
            isHUDVisible = true
        }
        guard !isAudioOnly else { return }
        resetHUDAutoHideTimer()
    }

    private func resetHUDAutoHideTimer() {
        hudAutoHideTimer?.invalidate()
        guard isPlaying, !isAudioOnly else { return }
        hudAutoHideTimer = Timer.scheduledTimer(withTimeInterval: 1.8, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, self.isPlaying, !self.isScrubbing, !self.isAudioOnly else { return }
                self.isHUDVisible = false
            }
        }
    }

    // MARK: - Audio Rhythm Monitoring Lifecycle
    public func startAudioRhythmMonitoring() {
        guard isAudioOnly && isPlaying else { return }
        guard audioRhythmTimer == nil else { return }
        audioRhythmTimer = Timer.scheduledTimer(withTimeInterval: 0.033, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, self.isPlaying, self.isAudioOnly else {
                    self?.stopAudioRhythmMonitoring()
                    return
                }
                if let bands = self.playerLayer?.audioRhythmBands, bands.count == 7 {
                    let mapped = bands.map { CGFloat($0) }
                    var changed = false
                    for (i, val) in mapped.enumerated() {
                        if abs(val - self.audioRhythmLevels[i]) > 0.02 {
                            changed = true
                            break
                        }
                    }
                    if changed {
                        self.audioRhythmLevels = mapped
                    }
                }
            }
        }
    }

    public func stopAudioRhythmMonitoring() {
        audioRhythmTimer?.invalidate()
        audioRhythmTimer = nil
        audioRhythmLevels = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
    }

    public func setTrafficLightsHidden(_ hidden: Bool, animated: Bool = true) {
        guard let window = hostWindow ?? NSApp.keyWindow else { return }
        if window.styleMask.contains(.fullScreen) { return }
        let buttons: [NSWindow.ButtonType] = [.closeButton, .miniaturizeButton, .zoomButton]
        let targetAlpha: CGFloat = hidden ? 0.0 : 1.0
        for btnType in buttons {
            if animated {
                window.standardWindowButton(btnType)?.animator().alphaValue = targetAlpha
            } else {
                window.standardWindowButton(btnType)?.alphaValue = targetAlpha
            }
        }
    }

    public func updateTrafficLightsVisibility(animated: Bool = true) {
        setTrafficLightsHidden(!isHUDVisible, animated: animated)
    }

    public func showOSD(_ notification: OSDNotification) {
        activeOSD = notification
        osdDismissTimer?.invalidate()
        osdDismissTimer = Timer.scheduledTimer(withTimeInterval: 1.8, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.activeOSD = nil
            }
        }
    }

    @MainActor
    public func triggerVolumeHUD() {
        withAnimation(SilkAnimation.snappy) {
            isVolumeHUDVisible = true
        }
        volumeHideTask?.cancel()
        volumeHideTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_600_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.35)) {
                self.isVolumeHUDVisible = false
            }
        }
    }

    @MainActor
    public func keepVolumeHUDAlive() {
        volumeHideTask?.cancel()
        if !isVolumeHUDVisible {
            withAnimation(SilkAnimation.snappy) {
                isVolumeHUDVisible = true
            }
        }
    }

    @MainActor
    public func scheduleVolumeHUDDismiss() {
        volumeHideTask?.cancel()
        volumeHideTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.35)) {
                self.isVolumeHUDVisible = false
            }
        }
    }

    public func showVolumeOSD() {
        triggerVolumeHUD()
    }

    public func showSeekOSD(targetTime: Double, offset: Double, duration: Double) {
        showOSD(.seek(targetTime: targetTime, offset: offset, duration: duration))
    }

    public func closePlaybackOrReturnToEmpty() {
        stop()
    }

    public func stopAndReturnToLibrary() {
        stop()
    }

    public func destroy() {
        stop()
        hudAutoHideTimer?.invalidate()
        osdDismissTimer?.invalidate()
    }

    // MARK: - Drag and Drop Handling
    public func handleDroppedURLs(_ urls: [URL]) {
        var pathsToPlay: [String] = []
        var subPaths: [String] = []

        for url in urls {
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
                let found = MediaFileClassifier.findVideos(in: url)
                pathsToPlay.append(contentsOf: found.map(\.path))
            } else {
                let type = MediaFileClassifier.classify(url: url)
                if type == .video || type == .audio {
                    pathsToPlay.append(url.path)
                } else if type == .subtitle {
                    subPaths.append(url.path)
                }
            }
        }

        if !pathsToPlay.isEmpty {
            if let onFilesDropped = onFilesDropped {
                onFilesDropped(pathsToPlay)
            } else if let first = pathsToPlay.first {
                onFileLoadedFromDrop?(first)
                loadFile(path: first)
            }
        }

        for sub in subPaths {
            addSubtitle(path: sub)
        }
    }

    // MARK: - Key Event Handling
    public func handleKeyDown(event: NSEvent) -> NSEvent? {
        switch event.keyCode {
        case 49: // Space
            togglePlayPause()
            return nil
        case 123: // Left Arrow
            let stepSec = event.modifierFlags.contains(.shift) ? AppSettings.shared.longSeekStep : AppSettings.shared.shortSeekStep
            step(seconds: -stepSec)
            return nil
        case 124: // Right Arrow
            let stepSec = event.modifierFlags.contains(.shift) ? AppSettings.shared.longSeekStep : AppSettings.shared.shortSeekStep
            step(seconds: stepSec)
            return nil
        case 126: // Up Arrow
            adjustVolume(by: 5.0)
            return nil
        case 125: // Down Arrow
            adjustVolume(by: -5.0)
            return nil
        case 15: // R
            rotateVideo(clockwise: true)
            return nil
        case 0: // A
            cycleAudioTrack()
            return nil
        case 1: // S
            cycleSubtitleTrack()
            return nil
        case 3: // F
            toggleFullscreen()
            return nil
        case 46: // M
            toggleMute()
            return nil
        case 34: // I
            toggleInspector()
            return nil
        case 35: // P
            togglePlaylistDrawer()
            return nil
        case 53: // Escape
            if isPlaylistDrawerVisible || isInspectorVisible {
                isPlaylistDrawerVisible = false
                isInspectorVisible = false
            } else if isFullscreen {
                toggleFullscreen()
            } else {
                onEscapePressed?()
            }
            return nil
        default:
            return event
        }
    }

    private func syncEmbeddedSubtitles(from dataSource: SubtitleDataSouce) {
        for info in dataSource.infos {
            if !self.subtitleModel.subtitleInfos.contains(where: { $0.subtitleID == info.subtitleID }) {
                self.subtitleModel.addSubtitle(info: info)
            }
        }
        self.refreshTracks()
    }

    // MARK: - SilkPlayerLayerDelegate Callbacks
    public func player(layer: SilkPlayerLayer, state: SilkPlayerState) {
        switch state {
        case .readyToPlay:
            self.isLoaded = true
            if let path = self.currentFilePath {
                SilkThumbnailEngine.shared.prepare(for: path)
            }
            if let resume = self.pendingResumeTime, resume > 0 {
                self.pendingResumeTime = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                    self?.seek(to: resume)
                }
            }
            if AppSettings.shared.autoPlayOnLoad {
                self.playbackState = .playing
                self.isPlaying = true
            } else {
                self.playbackState = .paused
                self.isPlaying = false
            }
            self.detectMetadata(for: layer)
            if let subtitleDataSouce = layer.player.subtitleDataSouce {
                self.syncEmbeddedSubtitles(from: subtitleDataSouce)
            }
            self.refreshTracks()
            self.refreshChapters()
            // PERF-002: Reclaim demuxer/codec initial allocation slack once playback stabilizes
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 2.0) {
                PlayerCore.trimMemoryFootprint()
            }
        case .buffering:
            self.playbackState = .loading
        case .bufferFinished:
            if self.isPlaying {
                self.playbackState = .playing
            } else {
                self.playbackState = .paused
            }
        case .paused:
            self.playbackState = .paused
            self.isPlaying = false
        case .playedToTheEnd:
            self.playbackState = .ended
            self.isPlaying = false
            self.onPlaybackEndedNaturally?()
        case .error:
            self.playbackState = .error
            self.statusMessage = "Playback error"
        @unknown default:
            break
        }
    }

    public func player(layer: SilkPlayerLayer, currentTime: TimeInterval, totalTime: TimeInterval) {
        if !self.isScrubbing {
            self.currentTime = currentTime
        }
        self.duration = totalTime
        self.cachedDuration = totalTime
        _ = self.subtitleModel.subtitle(currentTime: currentTime)
        self.onProgressUpdate?(self.currentFilePath ?? "", currentTime, totalTime)
    }

    public func player(layer: SilkPlayerLayer, finish error: Error?) {
        if let error = error {
            self.playbackState = .error
            self.statusMessage = error.localizedDescription
        } else {
            self.playbackState = .ended
            self.isPlaying = false
            self.onPlaybackEndedNaturally?()
        }
    }

    public func player(layer: SilkPlayerLayer, bufferedCount: Int, consumeTime: TimeInterval) {
        // Native buffer monitoring
    }

    public func player(layer: SilkPlayerLayer, didReceiveSubtitleCue cue: SubtitleCue) {
        self.subtitleModel.appendLiveCue(cue)
    }

    // MARK: - Media Metadata Detection
    private func detectMetadata(for layer: SilkPlayerLayer? = nil) {
        guard let player = layer?.player ?? playerLayer?.player else { return }

        let wasAudioMode = self.isAudioOnly
        self.isAudioOnly = layer?.isAudioOnly ?? player.isAudioOnly
        if self.isAudioOnly {
            let picData = layer?.attachedPictureData ?? player.attachedPictureData
            if let picData = picData, let img = NSImage(data: picData) {
                self.artworkImage = img
            } else {
                self.artworkImage = nil
            }
            self.videoWidth = 0
            self.videoHeight = 0
            self.displayVideoWidth = 0
            self.displayVideoHeight = 0
            self.videoCodec = "Audio Stream"
            self.hwdecCurrent = "CoreAudio (Hardware Master Clock)"
            self.isHUDVisible = true
            if isPlaying {
                startAudioRhythmMonitoring()
            }
            if !wasAudioMode {
                applyAudioWindowGeometry(animated: false)
            }
            return
        }

        stopAudioRhythmMonitoring()

        let size = player.naturalSize
        self.videoWidth = Int(size.width)
        self.videoHeight = Int(size.height)
        self.displayVideoWidth = Int(size.width)
        self.displayVideoHeight = Int(size.height)

        if let vTrack = player.tracks(mediaType: .video).first {
            let intrinsicRot = Int(vTrack.rotation)
            self.transform = VideoTransform(intrinsicRotation: intrinsicRot, userRotation: 0)
            self.videoRotation = transform.effectiveRotation
            renderContainer?.applyRenderViewLayout()
            if let dovi = vTrack.dovi {
                self.isDolbyVision = true
                self.isHDRContent = true
                self.hdrFormatString = "Dolby Vision Profile \(dovi.dv_profile)"
            } else if vTrack.isDoviProfile5 {
                self.isDolbyVision = true
                self.isHDRContent = true
                self.hdrFormatString = "Dolby Vision Profile 5"
            } else if let desc = vTrack.formatDescription {
                let extensions = CMFormatDescriptionGetExtensions(desc) as? [String: Any] ?? [:]
                if let primaries = extensions[kCMFormatDescriptionExtension_ColorPrimaries as String] as? String,
                   primaries == (kCMFormatDescriptionColorPrimaries_ITU_R_2020 as String) {
                    self.isDolbyVision = false
                    self.isHDRContent = true
                    self.hdrFormatString = "HDR10 (BT.2020)"
                } else {
                    self.isDolbyVision = false
                    self.isHDRContent = false
                    self.hdrFormatString = "SDR (BT.709)"
                }
            } else {
                self.isDolbyVision = false
                self.isHDRContent = false
                self.hdrFormatString = "SDR (BT.709)"
            }
        } else {
            self.isDolbyVision = false
            self.isHDRContent = false
            self.hdrFormatString = "SDR (BT.709)"
        }

        // Universal Agile Dynamic Pipeline (Rule #6: Universal across all formats & resolutions)
        self.options.preferredForwardBufferDuration = 1.5
        self.options.maxBufferDuration = 4.0

        self.videoFps = Double(player.nominalFrameRate)
        let rawCodec = player.dynamicInfo?.metadata["codec"] ?? ""
        self.videoCodec = !rawCodec.isEmpty ? rawCodec : "HEVC / H.264"
        self.hwdecCurrent = "VideoToolbox (Hardware Direct)"

        applyContentAspectRatioLock()
        applyAdaptiveWindowGeometry(animated: true)
    }
}
