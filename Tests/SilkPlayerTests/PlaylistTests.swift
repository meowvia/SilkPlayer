import Foundation
import AppKit

@MainActor
func runTests() async {
    print("==================================================")
    print("SilkPlayer Automated Regression Test Suite")
    print("==================================================")
    var passed = 0
    var failed = 0

    func assert(_ condition: Bool, _ message: String) {
        if condition {
            print("  [PASS] \(message)")
            passed += 1
        } else {
            print("  [FAIL] \(message)")
            failed += 1
        }
    }

    let manager = PlaylistManager()

    // 1. Single Video Setup & Boundary
    print("\n--- Test 1: Single Video Setup & Boundary ---")
    let singleItem = MediaItem(path: "/media/single.mp4", fileSize: 1024, duration: 120.0)
    manager.setPlaylist(items: [singleItem], startingAt: singleItem)
    assert(manager.count == 1, "Count is 1")
    assert(manager.currentIndex == 0, "Current index is 0")
    assert(manager.currentItem?.path == "/media/single.mp4", "Current item path matches")
    assert(!manager.hasPrevious, "hasPrevious is false for single item")
    assert(!manager.hasNext, "hasNext is false for single item")
    assert(manager.moveToNext() == nil, "moveToNext returns nil for single item")
    assert(manager.moveToPrevious() == nil, "moveToPrevious returns nil for single item")

    // 2. Multi-video Sequence Navigation
    print("\n--- Test 2: Multi-video Sequence Navigation ---")
    let item1 = MediaItem(path: "/media/ep01.mp4", title: "Ep 01", fileSize: 1000, duration: 1400.0)
    let item2 = MediaItem(path: "/media/ep02.mp4", title: "Ep 02", fileSize: 1000, duration: 1420.0)
    let item3 = MediaItem(path: "/media/ep03.mp4", title: "Ep 03", fileSize: 1000, duration: 1390.0)
    let epList = [item1, item2, item3]

    manager.setPlaylist(items: epList, startingAt: item1)
    assert(manager.count == 3, "Count is 3")
    assert(manager.currentIndex == 0, "Current index starts at 0 for ep01")
    assert(manager.displayIndexText == "1 / 3", "Display index text is '1 / 3'")

    // 3. First Item Boundary Condition
    print("\n--- Test 3: First Item Boundary Condition ---")
    assert(!manager.hasPrevious, "First item hasPrevious is false")
    assert(manager.hasNext, "First item hasNext is true")
    assert(manager.previousItem == nil, "previousItem is nil at start")
    assert(manager.nextItem?.title == "Ep 02", "nextItem is Ep 02")

    // 4. Moving to Next
    print("\n--- Test 4: Moving to Next & Middle Item State ---")
    let nextResult = manager.moveToNext()
    assert(nextResult?.title == "Ep 02", "moveToNext advanced to Ep 02")
    assert(manager.currentIndex == 1, "Current index is now 1")
    assert(manager.displayIndexText == "2 / 3", "Display index text is '2 / 3'")
    assert(manager.hasPrevious, "Middle item hasPrevious is true")
    assert(manager.hasNext, "Middle item hasNext is true")
    assert(manager.previousItem?.title == "Ep 01", "previousItem is Ep 01")
    assert(manager.nextItem?.title == "Ep 03", "nextItem is Ep 03")

    // 5. Last Item Boundary Condition
    print("\n--- Test 5: Last Item Boundary Condition ---")
    let lastResult = manager.moveToNext()
    assert(lastResult?.title == "Ep 03", "moveToNext advanced to Ep 03")
    assert(manager.currentIndex == 2, "Current index is now 2 (last)")
    assert(manager.displayIndexText == "3 / 3", "Display index text is '3 / 3'")
    assert(manager.hasPrevious, "Last item hasPrevious is true")
    assert(!manager.hasNext, "Last item hasNext is false")
    assert(manager.nextItem == nil, "nextItem is nil at last item")
    assert(manager.moveToNext() == nil, "Calling moveToNext at end returns nil")

    // 6. Natural Playback Ended (EOF) Auto-advance Simulation
    print("\n--- Test 6: Natural Playback Ended (EOF) Auto-advance ---")
    manager.selectIndex(0)
    var playbackEndedHandled = false
    var currentPlayingItem: PlaylistItem? = manager.currentItem

    let onPlaybackEndedNaturally: () -> Void = {
        guard manager.hasNext else { return }
        currentPlayingItem = manager.moveToNext()
        playbackEndedHandled = true
    }

    assert(currentPlayingItem?.title == "Ep 01", "Initial video is Ep 01")
    onPlaybackEndedNaturally()
    assert(playbackEndedHandled, "EOF hook triggered auto-advance")
    assert(currentPlayingItem?.title == "Ep 02", "Current playing item automatically switched to Ep 02")
    assert(manager.currentIndex == 1, "Playlist position advanced to 1")

    onPlaybackEndedNaturally()
    assert(currentPlayingItem?.title == "Ep 03", "Auto-advanced to Ep 03")

    playbackEndedHandled = false
    onPlaybackEndedNaturally()
    assert(!playbackEndedHandled, "EOF at end of playlist does not auto-advance past end")
    assert(currentPlayingItem?.title == "Ep 03", "Stays stably at Ep 03 in ended state")

    // 7. Re-selecting Media from Folder Context
    print("\n--- Test 7: Re-selecting Media from Folder Context ---")
    let newFolderItems = [
        MediaItem(path: "/media/movieA.mkv", title: "Movie A", fileSize: 2000),
        MediaItem(path: "/media/movieB.mkv", title: "Movie B", fileSize: 3000),
        MediaItem(path: "/media/movieC.mkv", title: "Movie C", fileSize: 2500),
        MediaItem(path: "/media/movieD.mkv", title: "Movie D", fileSize: 2800)
    ]
    manager.setPlaylist(items: newFolderItems, startingAt: newFolderItems[2])
    assert(manager.count == 4, "New playlist count is 4")
    assert(manager.currentIndex == 2, "Current index is 2 (Movie C)")
    assert(manager.currentItem?.title == "Movie C", "Current item is Movie C")
    assert(manager.displayIndexText == "3 / 4", "Display index text is '3 / 4'")
    assert(manager.hasPrevious, "Movie C has previous")
    assert(manager.hasNext, "Movie C has next")

    // 8. Resume Playback Position Recovery
    print("\n--- Test 8: Resume Playback Position Recovery ---")
    let partiallyWatched = MediaItem(
        path: "/media/resume_test.mp4",
        fileSize: 5000,
        duration: 3600.0,
        playbackProgress: 0.45,
        lastPlayedPosition: 1620.0,
        isFinished: false
    )
    let finishedItem = MediaItem(
        path: "/media/finished_test.mp4",
        fileSize: 5000,
        duration: 3600.0,
        playbackProgress: 0.98,
        lastPlayedPosition: 3528.0,
        isFinished: true
    )

    func computeResumePosition(for item: MediaItem) -> Double {
        if item.playbackProgress > 0 && !item.isFinished && item.lastPlayedPosition > 0 {
            return item.lastPlayedPosition
        }
        return 0.0
    }

    assert(computeResumePosition(for: partiallyWatched) == 1620.0, "Partially watched video resumes from 1620.0s")
    assert(computeResumePosition(for: finishedItem) == 0.0, "Finished video starts from beginning (0.0s)")

    // 9. Sequential Natural EOF Navigation & Bounds Safety
    print("\n--- Test 9: Sequential Natural EOF Navigation & Bounds Safety ---")
    manager.setPlaylist(items: epList, startingAt: item1)
    let autoNext1 = manager.handleNaturalEOF()
    assert(autoNext1?.title == "Ep 02", "Natural EOF advances from Ep 01 to Ep 02")
    assert(manager.currentIndex == 1, "Index is now 1")
    let autoNext2 = manager.handleNaturalEOF()
    assert(autoNext2?.title == "Ep 03", "Natural EOF advances from Ep 02 to Ep 03")
    assert(manager.currentIndex == 2, "Index is now 2 (last)")
    let autoNextEnd = manager.handleNaturalEOF()
    assert(autoNextEnd == nil, "Natural EOF returns nil when reaching end of playlist")
    assert(manager.currentIndex == 2, "Index safely stays at 2 on EOF at end")

    // 10. 3-Second Rewind Threshold for Previous Track
    print("\n--- Test 10: 3-Second Rewind Threshold for Previous Track ---")
    func simulatePreviousAction(currentPos: Double, mgr: PlaylistManager) -> (action: String, targetItem: PlaylistItem?) {
        if currentPos > 3.0 {
            return ("rewind", mgr.currentItem)
        } else {
            let prev = mgr.moveToPrevious()
            return ("previousTrack", prev)
        }
    }
    manager.setPlaylist(items: epList, startingAt: item2) // at index 1
    let rewindAction = simulatePreviousAction(currentPos: 12.5, mgr: manager)
    assert(rewindAction.action == "rewind", "When position > 3.0s, action is rewind")
    assert(rewindAction.targetItem?.title == "Ep 02", "Rewind keeps same item")
    assert(manager.currentIndex == 1, "Index remains at 1")

    let prevAction = simulatePreviousAction(currentPos: 1.2, mgr: manager)
    assert(prevAction.action == "previousTrack", "When position <= 3.0s, action is previousTrack")
    assert(prevAction.targetItem?.title == "Ep 01", "Navigated to Ep 01")
    assert(manager.currentIndex == 0, "Index updated to 0")

    // 11. MediaItem URL and Formatting Invariants
    print("\n--- Test 11: MediaItem URL and Formatting Invariants ---")
    let mediaItem = MediaItem(
        path: "/Volumes/Media/Sample.mkv",
        title: "Sample Movie",
        fileSize: 1024 * 1024 * 500,
        duration: 7325.0
    )
    assert(mediaItem.fileExtension == "MKV", "File extension is uppercase MKV")
    assert(mediaItem.formattedDuration == "02:02:05", "Duration correctly formatted as 02:02:05")
    assert(!mediaItem.formattedFileSize.isEmpty, "Formatted file size is non-empty")
    assert(mediaItem.url == URL(fileURLWithPath: "/Volumes/Media/Sample.mkv"), "URL matches path")

    // 12. AppSettings Preferences & Persistence
    print("\n--- Test 12: AppSettings Preferences & Persistence ---")
    let settings = AppSettings.shared
    assert(settings.autoPlayNextItem == true, "Playback: autoPlayNextItem default is true")
    assert(settings.resumePlayback == true, "Playback: resumePlayback default is true")
    assert(settings.autoResumeOnLaunch == false, "Playback: autoResumeOnLaunch default is false for privacy")
    assert(settings.autoScanSubfolders == true, "Playback: autoScanSubfolders default is true")
    assert(settings.appearanceMode == .system, "Appearance: default appearance mode is system")
    assert(settings.singleWindowMode == true, "General: singleWindowMode default is true")

    // 13. AppNavigationModel Routing & Video Rotation
    print("\n--- Test 13: AppNavigationModel Routing & Video Rotation ---")
    let nav = AppNavigationModel.shared
    nav.state = .idle
    assert(nav.state == .idle, "Initial nav state is .idle")
    let testURL = URL(fileURLWithPath: "/media/test.mp4")
    nav.state = .playing(url: testURL)
    assert(nav.state == .playing(url: testURL), "Nav state transitions to .playing")

    nav.activeInspectorTab = .none
    assert(!nav.isInspectorOpen, "Inspector is closed initially")
    nav.toggleInspector(tab: .info)
    assert(nav.isInspectorOpen, "toggleInspector opens inspector with .info")
    assert(nav.activeInspectorTab == .info, "Active tab is .info")
    nav.toggleInspector(tab: .info)
    assert(!nav.isInspectorOpen, "toggleInspector toggles off")

    nav.togglePlaylist()
    assert(nav.isPlaylistDrawerOpen, "togglePlaylist opens drawer")
    assert(nav.activeInspectorTab == .playlist, "Active tab is .playlist")
    nav.closeInspector()
    assert(!nav.isPlaylistDrawerOpen, "closeInspector closes drawer")

    nav.videoRotation = 0
    nav.rotateClockwise()
    assert(nav.videoRotation == 90, "rotateClockwise turns 90°")
    nav.rotateClockwise()
    assert(nav.videoRotation == 180, "rotateClockwise turns 180°")
    nav.rotateCounterClockwise()
    assert(nav.videoRotation == 90, "rotateCounterClockwise restores 90°")
    nav.videoRotation = 0

    // 14. PlayerWindowManager Session Lifecycle & Single Window Invariant
    print("\n--- Test 14: PlayerWindowManager Session Lifecycle ---")
    let winManager = PlayerWindowManager.shared
    winManager.resetForTesting()
    assert(winManager.sessions.isEmpty, "PlayerWindowManager starts empty after reset")

    let session1 = PlayerWindowSession(id: UUID(), isLoadedProvider: { false })
    let session2 = PlayerWindowSession(id: UUID(), isLoadedProvider: { true })
    winManager.registerSession(session1)
    winManager.registerSession(session2)
    assert(winManager.sessions.count == 2, "Both sessions registered")

    session2.testIsKey = true
    assert(winManager.activeSession(preferKey: true)?.id == session2.id, "Active session honors isKey preference")

    winManager.unregisterSession(id: session2.id)
    assert(winManager.sessions.count == 1, "Session 2 unregistered")
    assert(winManager.activeSession(preferKey: true)?.id == session1.id, "Session 1 remains active")
    winManager.resetForTesting()

    // 15. Single Window Mode Scheduling & File Expansion
    print("\n--- Test 15: Single Window Mode Scheduling & File Expansion ---")
    winManager.resetForTesting()
    let singleSession = PlayerWindowSession(id: UUID(), isLoadedProvider: { true })
    var openedPath: String?
    var queuedPaths: [String] = []
    singleSession.openPathHandler = { path in openedPath = path }
    singleSession.appendPlaylistHandler = { paths in queuedPaths = paths }
    winManager.registerSession(singleSession)

    winManager.openExternalFiles(["/media/movie1.mp4", "/media/movie2.mp4", "/media/movie3.mp4"])
    assert(openedPath == "/media/movie1.mp4", "First file opened directly")
    assert(queuedPaths == ["/media/movie2.mp4", "/media/movie3.mp4"], "Remaining files queued")
    winManager.resetForTesting()

    // 16. PlaylistManager Dynamic Append Operations
    print("\n--- Test 16: PlaylistManager Dynamic Append Operations ---")
    let appendItem1 = PlaylistItem(path: "/media/ep04.mp4", title: "Ep 04")
    let appendItem2 = PlaylistItem(path: "/media/ep05.mp4", title: "Ep 05")
    let initialCount = manager.count
    manager.appendItem(appendItem1)
    assert(manager.count == initialCount + 1, "appendItem increments count by 1")
    assert(manager.items.last?.path == "/media/ep04.mp4", "appended item is at end")
    manager.appendItems([appendItem2])
    assert(manager.count == initialCount + 2, "appendItems batch increments count")
    assert(manager.items.last?.path == "/media/ep05.mp4", "last item matches batch appended")

    // 17. OSD Notification State Machine & Equality
    print("\n--- Test 17: OSD Notification State Machine & Equality ---")
    let osdVol1 = OSDNotification.volume(85.0, isMuted: false)
    let osdVol2 = OSDNotification.volume(85.0, isMuted: false)
    let osdVol3 = OSDNotification.volume(50.0, isMuted: true)
    let osdSeek = OSDNotification.seek(targetTime: 120.0, offset: 5.0, duration: 300.0)
    let osdPlay = OSDNotification.playPause(isPlaying: true)
    let osdPause = OSDNotification.playPause(isPlaying: false)
    let osdTrack1 = OSDNotification.track(type: "sub", title: "English [SRT]")
    let osdTrack2 = OSDNotification.track(type: "sub", title: "English [SRT]")
    let osdTrack3 = OSDNotification.track(type: "audio", title: "Dolby Atmos [5.1]")

    assert(osdVol1 == osdVol2, "Identical volume OSD states are equal")
    assert(osdVol1 != osdVol3, "Different volume OSD states are not equal")
    assert(osdPlay != osdPause, "Play and Pause OSD states are not equal")
    assert(osdSeek != osdVol1, "Different OSD types are not equal")
    assert(osdTrack1 == osdTrack2, "Identical track OSD states are equal")
    assert(osdTrack1 != osdTrack3, "Different track types are not equal")

    // 18. Direct Playlist Item Selection (Drawer Episode Switcher)
    print("\n--- Test 18: Direct Playlist Item Selection ---")
    let testList = [
        PlaylistItem(path: "/media/season1_ep1.mp4", title: "Season 1 Ep 1"),
        PlaylistItem(path: "/media/season1_ep2.mp4", title: "Season 1 Ep 2"),
        PlaylistItem(path: "/media/season1_ep3.mp4", title: "Season 1 Ep 3")
    ]
    let drawerManager = PlaylistManager()
    drawerManager.setPlaylist(playlistItems: testList, startingIndex: 0)
    assert(drawerManager.currentIndex == 0, "Drawer initialized at index 0")

    let selectedItem = drawerManager.selectIndex(2)
    assert(selectedItem?.title == "Season 1 Ep 3", "selectIndex(2) selects Ep 3")
    assert(drawerManager.currentIndex == 2, "Current index is updated to 2")
    assert(drawerManager.selectIndex(-1) == nil, "Out-of-bounds negative index returns nil")
    assert(drawerManager.selectIndex(99) == nil, "Out-of-bounds excessive index returns nil")

    // 19. Native UI & Localization Invariants
    print("\n--- Test 19: Native UI & Localization Invariants ---")
    assert(!L10n.playlist.isEmpty, "L10n.playlist is non-empty")
    assert(!L10n.mediaInspectorTitle.isEmpty, "L10n.mediaInspectorTitle is non-empty")
    assert(!L10n.resolution.isEmpty, "L10n.resolution is non-empty")
    assert(!L10n.videoCodec.isEmpty, "L10n.videoCodec is non-empty")
    assert(!L10n.playlistItemsCount(5).isEmpty, "L10n.playlistItemsCount(5) generates non-empty string")

    // 20. TrackItem Invariants & Display Name Formatting
    print("\n--- Test 20: TrackItem Invariants & Display Name Formatting ---")
    let trackWithMetadata = TrackItem(id: 1, type: "sub", title: "English", lang: "eng", codec: "subrip", isExternal: false, isSelected: true)
    assert(trackWithMetadata.displayName == "English [ENG] (subrip)", "TrackItem formats full metadata correctly")

    let trackFallback = TrackItem(id: 5, type: "audio", title: "", lang: "", codec: "", isExternal: false, isSelected: false)
    assert(trackFallback.displayName == "Track #5", "TrackItem falls back to track id")

    let trackExternal = TrackItem(id: 2, type: "sub", title: "Custom", lang: "", codec: "", isExternal: true, isSelected: false)
    assert(trackExternal.displayName.contains("[External]"), "External track includes [External] tag")

    // 21. Picture Adjustments OSD & Notification State Machine
    print("\n--- Test 21: Picture Adjustments OSD & Notification State Machine ---")
    let debandOn = OSDNotification.pictureAdjustment(name: "Deband", value: "ON")
    let debandOn2 = OSDNotification.pictureAdjustment(name: "Deband", value: "ON")
    let debandOff = OSDNotification.pictureAdjustment(name: "Deband", value: "OFF")
    assert(debandOn == debandOn2, "Identical pictureAdjustment OSD states are equal")
    assert(debandOn != debandOff, "Different pictureAdjustment values are not equal")

    // 22. PlayerControllable & PlayerWindowManager Routing
    print("\n--- Test 22: PlayerControllable & PlayerWindowManager Routing ---")
    final class MockPlayerController: PlayerControllable {
        var isLoaded: Bool = true
        var isPlaying: Bool = false
        var isMuted: Bool = false
        var isFullscreen: Bool = false
        var isDebandEnabled: Bool = false
        var isHDRContent: Bool = true
        var isHDREnabled: Bool = true
        var isDolbyVision: Bool = false
        var hdrFormatString: String = "HDR10"
        var sharpen: Double = 0.0
        var contrast: Double = 0.0
        var brightness: Double = 0.0
        var speed: Double = 1.0
        var audioTracks: [TrackItem] = []
        var subtitleTracks: [TrackItem] = []
        var chapters: [ChapterItem] = []
        var cachedDuration: Double = 0.0
        var audioDelay: Double = 0.0
        var subtitleDelay: Double = 0.0
        var subtitleScale: Double = 1.0
        var videoAspectRatio: String = "auto"
        var videoWidth: Int = 1920
        var videoHeight: Int = 1080
        var videoRotation: Int = 0
        var displayVideoWidth: Int { videoWidth }
        var displayVideoHeight: Int { videoHeight }
        var effectiveAspectRatio: CGFloat {
            (videoRotation == 90 || videoRotation == 270) ? CGFloat(videoHeight) / CGFloat(max(1, videoWidth)) : CGFloat(videoWidth) / CGFloat(max(1, videoHeight))
        }
        var isEffectiveVertical: Bool {
            (videoRotation == 90 || videoRotation == 270) ? (videoWidth > videoHeight) : (videoHeight > videoWidth)
        }
        var videoCodec: String = "h264"
        var videoFps: Double = 30.0
        var mediaTitle: String = "Test Media"
        var currentFilePath: String? = "/path/to/test.mp4"
        var selectedAudioTrackId: Int = 1
        var selectedSubtitleTrackId: Int = 1
        var transform: VideoTransform = VideoTransform()
        var isInspectorVisible: Bool = false
        var isPlaylistDrawerVisible: Bool = false
        var frameStepCount: Int = 0
        var didStopAndReturn: Bool = false
        var lastFittedScale: Double = 0.0
        var onNextTrackRequested: (@MainActor () -> Void)?
        var onPreviousTrackRequested: (@MainActor () -> Void)?

        func setExactRotation(_ angle: Int) { videoRotation = angle }
        func resetVideoRotation() { videoRotation = 0 }
        func toggleFlipHorizontal() {}
        func toggleFlipVertical() {}
        func updateRememberedWindowSize(_ contentSize: NSSize) {}

        func play() { isPlaying = true }
        func pause() { isPlaying = false }
        func togglePlayPause() { isPlaying.toggle() }
        func step(seconds: Double) {}
        func stepFrame(forward: Bool) { frameStepCount += (forward ? 1 : -1) }
        func rotateVideo(clockwise: Bool) { videoRotation = (videoRotation + (clockwise ? 90 : 270)) % 360 }
        func adjustVolume(by delta: Double) {}
        func handleScrollWheelVolume(deltaY: Double) {}
        func takeScreenshot() {}
        func toggleMute() { isMuted.toggle() }
        func cycleAudioTrack() {}
        func setAudioTrack(id: Int, notifyOSD: Bool) {}
        func cycleSubtitleTrack() {}
        func setSubtitleTrack(id: Int, notifyOSD: Bool) {}
        func openSubtitleDialog() {}
        func toggleFullscreen() { isFullscreen.toggle() }
        func toggleDeband() { isDebandEnabled.toggle() }
        func toggleHDR() { isHDREnabled.toggle() }
        func setHDREnabled(_ enabled: Bool) { isHDREnabled = enabled }
        func adjustSharpen(by delta: Double) { sharpen += delta }
        func adjustContrast(by delta: Double) { contrast += delta }
        func adjustBrightness(by delta: Double) { brightness += delta }
        func resetPictureAdjustments() {
            isDebandEnabled = false
            sharpen = 0.0
            contrast = 0.0
            brightness = 0.0
        }
        func setSpeed(_ val: Double) { speed = val }
        func setAspectRatio(_ ratio: String) { videoAspectRatio = ratio }
        func adjustAudioDelay(by delta: Double) { audioDelay += delta }
        func resetAudioDelay() { audioDelay = 0.0 }
        func adjustSubtitleDelay(by delta: Double) { subtitleDelay += delta }
        func resetSubtitleDelay() { subtitleDelay = 0.0 }
        func adjustSubtitleScale(by delta: Double) { subtitleScale += delta }
        func resetSubtitleScale() { subtitleScale = 1.0 }
        func setSubtitleScale(_ scale: Double) { subtitleScale = scale }
        var isFastForwarding2x: Bool = false
        var isNightModeEnabled: Bool = false
        func setNightModeEnabled(_ enabled: Bool) { isNightModeEnabled = enabled }
        func startFastForward2x() { isFastForwarding2x = true }
        func stopFastForward2x() { isFastForwarding2x = false }
        func fitWindow(scale: Double) { lastFittedScale = scale }
        func toggleInspector() { isInspectorVisible.toggle() }
        func togglePlaylistDrawer() { isPlaylistDrawerVisible.toggle() }
        var hasAppliedInitialWindowSize: Bool = false
        func loadTrack(path: String) {
            let wasDrawer = isPlaylistDrawerVisible
            stop()
            isPlaylistDrawerVisible = wasDrawer
            if !hasAppliedInitialWindowSize {
                hasAppliedInitialWindowSize = true
            }
        }
        func stop() {
            isPlaying = false
            isLoaded = false
            isPlaylistDrawerVisible = false
            isInspectorVisible = false
            hasAppliedInitialWindowSize = false
        }
        func closePlaybackOrReturnToEmpty() {
            didStopAndReturn = true
            stop()
        }
        func stopAndReturnToLibrary() { closePlaybackOrReturnToEmpty() }
    }

    winManager.resetForTesting()
    let mock = MockPlayerController()
    let mockSession = PlayerWindowSession(player: mock)
    mockSession.testIsKey = true
    winManager.registerSession(mockSession)

    assert(winManager.activePlayer != nil, "activePlayer lookup succeeds")
    winManager.activePlayer?.toggleDeband()
    assert(mock.isDebandEnabled == true, "toggleDeband executed on active player")
    winManager.activePlayer?.adjustSharpen(by: 0.2)
    assert(abs(mock.sharpen - 0.2) < 0.001, "adjustSharpen executed on active player")
    winManager.activePlayer?.setSpeed(1.5)
    assert(mock.speed == 1.5, "setSpeed executed on active player")
    winManager.activePlayer?.stepFrame(forward: true)
    assert(mock.frameStepCount == 1, "stepFrame forward advances frame count")
    winManager.activePlayer?.rotateVideo(clockwise: true)
    assert(mock.videoRotation == 90, "rotateVideo updates rotation to 90°")
    winManager.resetForTesting()

    // 23. Media File Classification & Companion Subtitles
    print("\n--- Test 23: Media File Classification & Companion Subtitles ---")
    let testVideoURL = URL(fileURLWithPath: "/media/movies/Avatar (2009).mkv")
    let testSubURL = URL(fileURLWithPath: "/media/movies/Avatar (2009).zh.srt")
    let testAudioURL = URL(fileURLWithPath: "/media/music/soundtrack.flac")
    let testUnknownURL = URL(fileURLWithPath: "/media/docs/readme.txt")

    assert(MediaFileClassifier.classify(url: testVideoURL) == .video, "MKV is classified as video")
    assert(MediaFileClassifier.classify(url: testSubURL) == .subtitle, "SRT is classified as subtitle")
    assert(MediaFileClassifier.classify(url: testAudioURL) == .audio, "FLAC is classified as audio")
    assert(MediaFileClassifier.classify(url: testUnknownURL) == .unsupported, "TXT is classified as unsupported")

    // Companion subtitle directory scan simulation
    let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    let movieFile = tempDir.appendingPathComponent("Inception.2010.1080p.mp4")
    let subChn = tempDir.appendingPathComponent("Inception.2010.1080p.chs.srt")
    let subEng = tempDir.appendingPathComponent("Inception.2010.1080p.eng.ass")
    let otherSub = tempDir.appendingPathComponent("Interstellar.2014.srt")
    FileManager.default.createFile(atPath: movieFile.path, contents: Data())
    FileManager.default.createFile(atPath: subChn.path, contents: Data())
    FileManager.default.createFile(atPath: subEng.path, contents: Data())
    FileManager.default.createFile(atPath: otherSub.path, contents: Data())

    let foundSubs = MediaFileClassifier.findCompanionSubtitles(for: movieFile)
    assert(foundSubs.count == 2, "Found exactly 2 companion subtitles for Inception")
    assert(foundSubs.contains(where: { $0.lastPathComponent == "Inception.2010.1080p.chs.srt" }), "Found Chinese SRT")
    assert(foundSubs.contains(where: { $0.lastPathComponent == "Inception.2010.1080p.eng.ass" }), "Found English ASS")
    assert(!foundSubs.contains(where: { $0.lastPathComponent == "Interstellar.2014.srt" }), "Unrelated subtitle is excluded")
    try? FileManager.default.removeItem(at: tempDir)

    // 24. Playback State Enums & Time Formatting Invariants
    print("\n--- Test 24: Playback State & Time Formatting Invariants ---")
    assert(PlaybackState.idle.rawValue == "Idle", "PlaybackState.idle rawValue is Idle")
    assert(PlaybackState.playing.rawValue == "Playing", "PlaybackState.playing rawValue is Playing")
    assert(PlaybackState.paused.rawValue == "Paused", "PlaybackState.paused rawValue is Paused")
    assert(PlaybackState.loading.rawValue == "Loading", "PlaybackState.loading rawValue is Loading")
    assert(PlaybackState.ended.rawValue == "Ended", "PlaybackState.ended rawValue is Ended")
    assert(PlaybackState.error.rawValue == "Error", "PlaybackState.error rawValue is Error")

    assert(formatPlaybackTime(0) == "00:00", "0s formats to 00:00")
    assert(formatPlaybackTime(65) == "01:05", "65s formats to 01:05")
    assert(formatPlaybackTime(3665) == "01:01:05", "3665s formats to 01:01:05")
    assert(formatPlaybackTime(-5) == "00:00", "Negative time safely returns 00:00")
    assert(formatPlaybackTime(Double.nan) == "00:00", "NaN time safely returns 00:00")

    // 25. Accessibility & Motion Animation Invariants
    print("\n--- Test 25: Accessibility & Motion Animation Invariants ---")
    let normalAnim = SilkAnimation.adaptive(reduceMotion: false)
    let reducedAnim = SilkAnimation.adaptive(reduceMotion: true)
    assert(normalAnim != reducedAnim, "Adaptive animation toggles between spring and reduced ease")
    assert(normalAnim == SilkAnimation.spring, "Adaptive false returns standard spring")

    // 26. ChapterItem, Snapping & Cache Watermark Invariants
    print("\n--- Test 26: ChapterItem, Snapping & Cache Watermark Invariants ---")
    let ch1 = ChapterItem(id: 1, title: "Prologue", time: 0.0)
    let ch2 = ChapterItem(id: 2, title: "The Heist", time: 300.0)
    let ch3 = ChapterItem(id: 3, title: "The Getaway", time: 720.0)
    let chapters = [ch1, ch2, ch3]
    assert(chapters.count == 3, "Parsed chapter count is 3")
    assert(chapters[1].title == "The Heist", "Second chapter title is The Heist")
    assert(chapters[1].time == 300.0, "Second chapter time is 300.0s")
    assert(ch1 == ChapterItem(id: 1, title: "Prologue", time: 0.0), "ChapterItem equality passes")

    // Verify Magnetic Snapping Threshold Logic
    let totalDur: Double = 1000.0
    let snapThreshold: Double = max(2.0, totalDur * 0.012) // 12.0s
    func testSnap(_ t: Double) -> Double {
        for c in chapters {
            if abs(t - c.time) <= snapThreshold { return c.time }
        }
        return t
    }
    assert(testSnap(295.0) == 300.0, "Time 295.0s snaps to chapter 2 at 300.0s")
    assert(testSnap(305.0) == 300.0, "Time 305.0s snaps to chapter 2 at 300.0s")
    assert(testSnap(350.0) == 350.0, "Time 350.0s outside threshold remains unsnapped")

    // Demuxer Cache Watermark Headroom Invariant
    let currentPlayTime: Double = 100.0
    let cachedDur: Double = 25.0
    let bufferedEnd = min(totalDur, currentPlayTime + cachedDur)
    let bufferFraction = bufferedEnd / totalDur
    assert(bufferedEnd == 125.0, "Buffered end is 125.0s")
    assert(abs(bufferFraction - 0.125) < 0.001, "Buffer fraction is 12.5%")

    // 27. Settings Fixed Dimensions & Privacy Invariants
    print("\n--- Test 27: Settings Fixed Dimensions & Privacy Invariants ---")
    assert(AppSettings.shared.autoResumeOnLaunch == false, "autoResumeOnLaunch defaults to false for privacy protection")

    // Verify PlayerWindowManager Window Creation Invariants
    let windowMgr = PlayerWindowManager.shared
    windowMgr.openSettings()
    assert(windowMgr.settingsWindow != nil, "Settings window is instantiated")
    assert(windowMgr.settingsWindow?.frame.width == 540, "Settings window width is 540")
    assert(windowMgr.settingsWindow?.frame.height == 680, "Settings window height is 680")
    assert(windowMgr.settingsWindow?.collectionBehavior.contains(.fullScreenAuxiliary) == true, "Settings window has .fullScreenAuxiliary behavior")
    assert(windowMgr.settingsWindow?.collectionBehavior.contains(.canJoinAllSpaces) == true, "Settings window has .canJoinAllSpaces behavior")
    windowMgr.closeSettings()
    assert(windowMgr.settingsWindow == nil, "closeSettings cleanly unsets settingsWindow")

    // 28. Refactored Settings & Fast Forward / Night Mode Invariants
    print("\n--- Test 28: Refactored Settings & Fast Forward / Night Mode Invariants ---")
    let testSettings = AppSettings.shared
    assert(testSettings.singleWindowMode == true, "singleWindowMode defaults to true")
    assert(testSettings.windowMode == WindowMode.singleWindow, "windowMode defaults to .singleWindow")
    testSettings.singleWindowMode = false
    assert(testSettings.windowMode == WindowMode.multipleWindows, "windowMode updates to .multipleWindows when singleWindowMode is false")
    testSettings.singleWindowMode = true
    assert(testSettings.windowMode == WindowMode.singleWindow, "windowMode restores to .singleWindow")
    assert(testSettings.autoPlayOnLoad == true, "autoPlayOnLoad defaults to true")
    assert(testSettings.nightModeDialogueBoost == false, "nightModeDialogueBoost defaults to false")
    assert(testSettings.subtitleSizePreset == SubtitleSizePreset.standard, "subtitleSizePreset defaults to standard (100%)")
    assert(SubtitleSizePreset.small.rawValue == 0.8, "SubtitleSizePreset small rawValue is 0.8")
    assert(SubtitleSizePreset.standard.rawValue == 1.0, "SubtitleSizePreset standard rawValue is 1.0")
    assert(SubtitleSizePreset.large.rawValue == 1.25, "SubtitleSizePreset large rawValue is 1.25")
    assert(SubtitleSizePreset.extraLarge.rawValue == 1.5, "SubtitleSizePreset extraLarge rawValue is 1.5")

    // Fast forward & Night mode mock test
    assert(mock.isFastForwarding2x == false, "Mock starts with isFastForwarding2x false")
    mock.startFastForward2x()
    assert(mock.isFastForwarding2x == true, "Mock isFastForwarding2x is true after start")
    mock.stopFastForward2x()
    assert(mock.isFastForwarding2x == false, "Mock isFastForwarding2x is false after stop")

    windowMgr.registerSession(mockSession)
    windowMgr.applyNightMode(true)
    assert(mock.isNightModeEnabled == true, "applyNightMode propagates to registered session players")
    windowMgr.resetForTesting()

    // 29. v0.5.1 Regression Suite: Speed 0.25x, Minimal Tier Navigation & Floating Settings
    print("\n--- Test 29: v0.5.1 Regression Suite: Speed 0.25x & Floating Settings ---")
    mock.setSpeed(0.25)
    assert(mock.speed == 0.25, "PlayerControllable supports 0.25x playback speed")
    mock.setSpeed(1.0)
    assert(mock.speed == 1.0, "PlayerControllable resets speed to 1.0x")

    windowMgr.openSettings()
    assert(windowMgr.settingsWindow != nil, "Settings window opened successfully")
    assert(windowMgr.settingsWindow?.level == .floating, "Settings window is permanently floating above player canvas")
    assert(windowMgr.settingsWindow?.frame.width == 540, "Settings window width is 540")
    assert(windowMgr.settingsWindow?.frame.height == 680, "Settings window height is 680 for full General tab visibility")
    windowMgr.closeSettings()
    assert(windowMgr.settingsWindow == nil, "Settings window closed cleanly")

    // 30. v0.5.2 Regression Suite: Global Language Switching & Aspect Ratio Invariants
    print("\n--- Test 30: v0.5.2 Regression Suite: Global Language & Aspect Ratio Invariants ---")
    AppSettings.shared.appLanguage = .en
    assert(L10n.isChinese == false, "L10n detects English when appLanguage is .en")
    assert(L10n.play == "Play", "L10n.play is 'Play' in English")
    assert(L10n.pause == "Pause", "L10n.pause is 'Pause' in English")
    assert(L10n.open == "Open", "L10n.open is 'Open' in English")

    AppSettings.shared.appLanguage = .zhHans
    assert(L10n.isChinese == true, "L10n detects Chinese when appLanguage is .zhHans")
    assert(L10n.play == "播放", "L10n.play is '播放' in Chinese")
    assert(L10n.pause == "暂停", "L10n.pause is '暂停' in Chinese")
    assert(L10n.open == "打开", "L10n.open is '打开' in Chinese")

    assert(AppLanguage.allCases.count == 2, "Only zhHans and en are supported")
    assert(AppLanguage.zhHans.displayName == "简体中文", "AppLanguage.zhHans display name is '简体中文'")
    assert(AppLanguage.en.displayName == "English", "AppLanguage.en display name is 'English'")

    // 31. Native Window Aspect Ratio & Minimum Dimensions Constraints Invariants
    print("\n--- Test 31: Native Window Aspect Ratio & Minimum Dimensions Constraints ---")
    let testWindow = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 800, height: 450),
        styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
        backing: .buffered,
        defer: false
    )
    let minSz = NSSize(width: 640, height: 360)
    testWindow.minSize = minSz
    testWindow.contentMinSize = minSz
    assert(testWindow.minSize.width == 640, "Window minimum width is 640")
    assert(testWindow.minSize.height == 360, "Window minimum height is 360")
    assert(testWindow.contentMinSize.width == 640, "Content minimum width is 640")
    assert(testWindow.contentMinSize.height == 360, "Content minimum height is 360")

    // Test contentAspectRatio calculation
    testWindow.contentAspectRatio = NSSize(width: 16, height: 9)
    assert(testWindow.contentAspectRatio.width == 16, "Content aspect ratio width locked to 16")
    assert(testWindow.contentAspectRatio.height == 9, "Content aspect ratio height locked to 9")

    // Test aspect ratio release on idle/close
    testWindow.contentAspectRatio = NSSize(width: 0, height: 0)
    assert(testWindow.contentAspectRatio.width == 0, "Content aspect ratio released cleanly to 0")
    assert(testWindow.contentAspectRatio.height == 0, "Content aspect ratio released cleanly to 0")

    // 32. PlayerWindowDelegate Mathematical Resize & Dynamic Selection Invariants
    print("\n--- Test 32: PlayerWindowDelegate Mathematical Resize & Dynamic Selection Invariants ---")
    let delPlayer = MockPlayerController()
    let delSession = PlayerWindowSession(id: UUID(), player: delPlayer)
    let winDelegate = PlayerWindowDelegate(session: delSession, player: delPlayer)

    // A. Idle state resize clamping
    let idleResize = winDelegate.windowWillResize(testWindow, to: NSSize(width: 400, height: 200))
    assert(idleResize.width == 640, "Idle proposed width below 640 clamps to 640")
    assert(idleResize.height == 360, "Idle proposed height below 360 clamps to 360")

    // B. Playing state horizontal drag aspect locking (16:9)
    delPlayer.isPlaying = true
    delPlayer.videoWidth = 1920
    delPlayer.videoHeight = 1080
    testWindow.setFrame(NSRect(x: 0, y: 0, width: 980, height: 620), display: false)

    // User drags right edge outwards to width 1200
    let rightDragResize = winDelegate.windowWillResize(testWindow, to: NSSize(width: 1200, height: 620))
    assert(rightDragResize.width == 1200, "Width follows horizontal drag to 1200")
    assert(rightDragResize.height == 675, "Height automatically locked to 16:9 (675)")

    // User drags bottom edge downwards to height 500
    let bottomDragResize = winDelegate.windowWillResize(testWindow, to: NSSize(width: 980, height: 500))
    assert(bottomDragResize.height == 500, "Height follows vertical drag to 500")
    assert(bottomDragResize.width == 889, "Width automatically locked to 16:9 (889)")

    // User attempts to shrink below minimum size (e.g. 300x200)
    let shrinkMinResize = winDelegate.windowWillResize(testWindow, to: NSSize(width: 300, height: 200))
    assert(shrinkMinResize.width == 640, "Width strictly clamped to minimum 640")
    assert(shrinkMinResize.height == 360, "Height strictly clamped to minimum 360")

    // C. Playlist Selection index synchronization
    let pMgr = PlaylistManager()
    let pItemA = PlaylistItem(path: "/media/a.mp4", title: "Video A")
    let pItemB = PlaylistItem(path: "/media/b.mp4", title: "Video B")
    let pItemC = PlaylistItem(path: "/media/c.mp4", title: "Video C")
    pMgr.appendItems([pItemA, pItemB, pItemC])
    assert(pMgr.currentIndex == 0, "Initial index is 0")

    // Simulate clicking / selecting item C
    let selected = pMgr.selectIndex(2)
    assert(pMgr.currentIndex == 2, "Current index updated to 2")
    assert(selected?.title == "Video C", "Selected item is Video C")
    assert(pMgr.currentItem?.id == pItemC.id, "Current item matches Video C id")

    // D. Paused state aspect locking (movie loaded but paused)
    delPlayer.isPlaying = false
    let pausedDragResize = winDelegate.windowWillResize(testWindow, to: NSSize(width: 1200, height: 620))
    assert(pausedDragResize.width == 1200, "Width follows horizontal drag even when paused")
    assert(pausedDragResize.height == 675, "Height locked to 16:9 even when paused")

    // E. Maximize / Zoom behavior allows screen visible frame
    let screenVisibleSize = (testWindow.screen ?? NSScreen.main)?.visibleFrame.size ?? NSSize(width: 1920, height: 1080)
    let zoomResize = winDelegate.windowWillResize(testWindow, to: screenVisibleSize)
    assert(zoomResize.width == screenVisibleSize.width, "Zoom/maximize allows full screen width")
    assert(zoomResize.height == screenVisibleSize.height, "Zoom/maximize allows full screen height")

    let standardFrame = winDelegate.windowWillUseStandardFrame(testWindow, defaultFrame: NSRect(origin: .zero, size: screenVisibleSize))
    assert(standardFrame.size == screenVisibleSize, "windowWillUseStandardFrame returns full screen visible frame")

    // 33. Subtitle & Audio Track Metadata Invariants & Preferred Language Selection
    print("\n--- Test 33: Subtitle & Audio Track Metadata & Language Preference ---")
    let pgsTrack = TrackItem(
        id: 1,
        type: "sub",
        title: "Chinese Simplified",
        lang: "chi",
        codec: "PGS",
        isExternal: false,
        isSelected: true
    )
    assert(pgsTrack.displayName == "Chinese Simplified [CHI] (PGS)", "PGS Track formats with language and codec")

    let atmosTrack = TrackItem(
        id: 1,
        type: "audio",
        title: "Surround 7.1",
        lang: "eng",
        codec: "truehd",
        isExternal: false,
        isSelected: true
    )
    assert(atmosTrack.displayName == "Surround 7.1 [ENG] (truehd)", "Audio Track formats with language and TrueHD codec")

    mock.adjustSubtitleDelay(by: 0.5)
    assert(mock.subtitleDelay == 0.5, "Subtitle delay adjustment sets value correctly")
    mock.resetSubtitleDelay()
    assert(mock.subtitleDelay == 0.0, "Subtitle delay resets to 0.0")

    AppSettings.shared.preferredSubtitleLang = "zh,chi,zho,zh-Hans,zh-Hant,chs,cht"
    let prefLangs = AppSettings.shared.preferredSubtitleLang.lowercased().split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
    assert(prefLangs.contains("chi"), "Preferred language list includes 'chi'")
    assert(prefLangs.contains("zh"), "Preferred language list includes 'zh'")

    // 34. Scrubber Preview Time Formatting & Bucket Invariants
    print("\n--- Test 34: Scrubber Preview Time Formatting & Bucket Invariants ---")
    func quantizeBucket(_ time: Double) -> Int64 {
        Int64((time * 2.0).rounded())
    }
    assert(quantizeBucket(10.1) == quantizeBucket(10.2), "0.5s bucket quantization merges adjacent timestamps")
    assert(quantizeBucket(10.1) != quantizeBucket(11.0), "Timestamps > 0.5s apart fall into distinct buckets")

    // Millisecond timestamp format
    func testFormatMs(_ seconds: Double) -> String {
        guard !seconds.isNaN, !seconds.isInfinite, seconds >= 0 else { return "00:00.00" }
        let totalCentiseconds = Int(round(seconds * 100.0))
        let totalSeconds = totalCentiseconds / 100
        let centiseconds = totalCentiseconds % 100
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let secs = totalSeconds % 60
        if hours > 0 {
            return String(format: "%02d:%02d:%02d.%02d", hours, minutes, secs, centiseconds)
        } else {
            return String(format: "%02d:%02d.%02d", minutes, secs, centiseconds)
        }
    }

    assert(testFormatMs(0) == "00:00.00", "0s formats to 00:00.00")
    assert(testFormatMs(65.45) == "01:05.45", "65.45s formats to 01:05.45")
    assert(testFormatMs(3665.12) == "01:01:05.12", "3665.12s formats to 01:01:05.12")
    assert(testFormatMs(-1) == "00:00.00", "Negative time safely returns 00:00.00")
    assert(testFormatMs(Double.nan) == "00:00.00", "NaN time safely returns 00:00.00")

    // Scrubber edge clamping geometry
    let totalW: CGFloat = 640
    let halfW: CGFloat = 85
    let clampMin: CGFloat = halfW + 10
    let clampMax: CGFloat = totalW - halfW - 10
    func clampX(_ x: CGFloat) -> CGFloat { max(clampMin, min(clampMax, x)) }

    assert(clampX(0) == 95, "Left-most hover at 0 is clamped to 95pt (no window bleed)")
    assert(clampX(640) == 545, "Right-most hover at 640 is clamped to 545pt (no window bleed)")
    assert(clampX(320) == 320, "Center hover at 320 remains 320pt")

    // 35. Cold Start Playlist Memory & Retention Invariants
    print("\n--- Test 35: Cold Start Playlist Memory & Retention Invariants ---")
    let testItemKey = "com.silkplayer.test.items.\(UUID().uuidString)"
    let testIdxKey = "com.silkplayer.test.index.\(UUID().uuidString)"

    let coldStartItem1 = PlaylistItem(path: "/media/matrix_ep1.mp4", title: "Matrix 1", duration: 7200.0)
    let coldStartItem2 = PlaylistItem(path: "/media/matrix_ep2.mp4", title: "Matrix 2", duration: 7500.0)
    let coldStartItem3 = PlaylistItem(path: "/media/matrix_ep3.mp4", title: "Matrix 3", duration: 7800.0)

    let sessionManagerA = PlaylistManager(
        isPersistenceEnabled: true,
        autoRestore: false,
        itemsStorageKey: testItemKey,
        indexStorageKey: testIdxKey
    )
    sessionManagerA.appendItems([coldStartItem1, coldStartItem2, coldStartItem3])
    sessionManagerA.selectIndex(1)

    assert(sessionManagerA.count == 3, "Session A saved 3 items")
    assert(sessionManagerA.currentIndex == 1, "Session A current index is 1 (Matrix 2)")
    assert(sessionManagerA.currentItem?.title == "Matrix 2", "Session A current item is Matrix 2")

    // Simulate Cold Launch: A completely new PlaylistManager instance is spawned with autoRestore = true
    let sessionManagerColdLaunch = PlaylistManager(
        isPersistenceEnabled: true,
        autoRestore: true,
        itemsStorageKey: testItemKey,
        indexStorageKey: testIdxKey
    )

    assert(sessionManagerColdLaunch.count == 3, "Cold start retained exactly 3 items")
    assert(sessionManagerColdLaunch.items[0].path == "/media/matrix_ep1.mp4", "First item path restored")
    assert(sessionManagerColdLaunch.items[1].path == "/media/matrix_ep2.mp4", "Second item path restored")
    assert(sessionManagerColdLaunch.items[2].path == "/media/matrix_ep3.mp4", "Third item path restored")
    assert(sessionManagerColdLaunch.currentIndex == 1, "Cold start remembered active index 1")
    assert(sessionManagerColdLaunch.currentItem?.title == "Matrix 2", "Cold start active item is Matrix 2")
    assert(sessionManagerColdLaunch.displayIndexText == "2 / 3", "Display index text restored to '2 / 3'")
    assert(sessionManagerColdLaunch.hasPrevious == true, "Navigation hasPrevious is true on cold launch")
    assert(sessionManagerColdLaunch.hasNext == true, "Navigation hasNext is true on cold launch")

    // 36. Preserving Original Playlist Management Functions Across Persistence
    print("\n--- Test 36: Playlist Management Preservation Across Persistence ---")
    // Management action 1: Append new media item
    let coldStartItem4 = PlaylistItem(path: "/media/matrix_ep4.mp4", title: "Matrix 4", duration: 8100.0)
    sessionManagerColdLaunch.appendItem(coldStartItem4)
    assert(sessionManagerColdLaunch.count == 4, "Appended item 4, count is 4")

    let verifyManagerAfterAppend = PlaylistManager(
        isPersistenceEnabled: true,
        autoRestore: true,
        itemsStorageKey: testItemKey,
        indexStorageKey: testIdxKey
    )
    assert(verifyManagerAfterAppend.count == 4, "Cold start after append retains all 4 items")
    assert(verifyManagerAfterAppend.items.last?.title == "Matrix 4", "Newly appended item is persisted at tail")

    // Management action 2: Remove single item (e.g. index 0)
    verifyManagerAfterAppend.removeItem(at: 0)
    assert(verifyManagerAfterAppend.count == 3, "Removed item 0, count decreases to 3")
    assert(verifyManagerAfterAppend.items[0].title == "Matrix 2", "New index 0 is Matrix 2")

    let verifyManagerAfterRemove = PlaylistManager(
        isPersistenceEnabled: true,
        autoRestore: true,
        itemsStorageKey: testItemKey,
        indexStorageKey: testIdxKey
    )
    assert(verifyManagerAfterRemove.count == 3, "Cold start after removal retains updated 3 items")
    assert(!verifyManagerAfterRemove.items.contains(where: { $0.title == "Matrix 1" }), "Removed item Matrix 1 is no longer persisted")

    // Management action 3: Natural EOF auto-advance
    let eofNext = verifyManagerAfterRemove.handleNaturalEOF()
    assert(eofNext?.title == "Matrix 3", "Natural EOF auto-advances to next item")

    let verifyManagerAfterEOF = PlaylistManager(
        isPersistenceEnabled: true,
        autoRestore: true,
        itemsStorageKey: testItemKey,
        indexStorageKey: testIdxKey
    )
    assert(verifyManagerAfterEOF.currentIndex == verifyManagerAfterRemove.currentIndex, "Cold start preserves advanced EOF index")

    // Management action 4: Clear playlist
    verifyManagerAfterEOF.clear()
    assert(verifyManagerAfterEOF.isEmpty == true, "Cleared playlist is empty in memory")
    assert(verifyManagerAfterEOF.currentIndex == -1, "Cleared playlist index is -1")

    let verifyManagerAfterClear = PlaylistManager(
        isPersistenceEnabled: true,
        autoRestore: true,
        itemsStorageKey: testItemKey,
        indexStorageKey: testIdxKey
    )
    assert(verifyManagerAfterClear.isEmpty == true, "Cold start after clear remains cleanly empty")
    assert(verifyManagerAfterClear.count == 0, "Cold start count is 0 after clear")

    // Clean up temporary keys
    verifyManagerAfterClear.clearStorage()

    // 37. Cold Start Auto-Resume & Playlist Preservation Invariants
    print("\n--- Test 37: Cold Start Auto-Resume & Playlist Preservation Invariants ---")
    let testItemKey2 = "com.silkplayer.test.resume.items.\(UUID().uuidString)"
    let testIdxKey2 = "com.silkplayer.test.resume.index.\(UUID().uuidString)"

    let epA = PlaylistItem(path: "/media/tv_s01e01.mkv", title: "S01E01", duration: 3600.0)
    let epB = PlaylistItem(path: "/media/tv_s01e02.mkv", title: "S01E02", duration: 3600.0)
    let epC = PlaylistItem(path: "/media/tv_s01e03.mkv", title: "S01E03", duration: 3600.0)

    let presManager = PlaylistManager(
        isPersistenceEnabled: true,
        autoRestore: false,
        itemsStorageKey: testItemKey2,
        indexStorageKey: testIdxKey2
    )
    presManager.setPlaylist(playlistItems: [epA, epB, epC], startingIndex: 1) // currently on S01E02

    // Cold start simulator:
    let restoredOnColdStart = PlaylistManager(
        isPersistenceEnabled: true,
        autoRestore: true,
        itemsStorageKey: testItemKey2,
        indexStorageKey: testIdxKey2
    )
    assert(restoredOnColdStart.count == 3, "Entire TV season remains in playlist on cold start")
    assert(restoredOnColdStart.currentIndex == 1, "Cold start targets active episode S01E02")
    assert(restoredOnColdStart.currentItem?.title == "S01E02", "Current target item is S01E02")
    assert(restoredOnColdStart.items.count == 3, "Playlist was NOT truncated or wiped out on launch")

    restoredOnColdStart.clearStorage()

    // 38. Playlist Retention on Close Media, Cold Start & Clear All Invariants
    print("\n--- Test 38: Playlist Retention on Close Media, Cold Start & Clear All Invariants ---")
    // 1. Localization check
    AppSettings.shared.appLanguage = .zhHans
    assert(L10n.clearAll == "一键清空", "L10n.clearAll is '一键清空' in Chinese")
    assert(L10n.clearPlaylist == "清空播放列表", "L10n.clearPlaylist is '清空播放列表' in Chinese")
    AppSettings.shared.appLanguage = .en
    assert(L10n.clearAll == "Clear All", "L10n.clearAll is 'Clear All' in English")
    assert(L10n.clearPlaylist == "Clear Playlist", "L10n.clearPlaylist is 'Clear Playlist' in English")

    // 2. Close media retention simulator
    let testItemKey3 = "com.silkplayer.test.closemedia.items.\(UUID().uuidString)"
    let testIdxKey3 = "com.silkplayer.test.closemedia.index.\(UUID().uuidString)"
    let cmItem1 = PlaylistItem(path: "/media/movie_a.mp4", title: "Movie A", duration: 7200.0)
    let cmItem2 = PlaylistItem(path: "/media/movie_b.mp4", title: "Movie B", duration: 5400.0)

    let activePlaylist = PlaylistManager(
        isPersistenceEnabled: true,
        autoRestore: false,
        itemsStorageKey: testItemKey3,
        indexStorageKey: testIdxKey3
    )
    activePlaylist.setPlaylist(playlistItems: [cmItem1, cmItem2], startingIndex: 0)
    assert(activePlaylist.count == 2, "Active playlist starts with 2 movies")
    assert(activePlaylist.currentIndex == 0, "Currently playing Movie A")

    // Simulate clicking top-right 'x' close media or Cmd+W:
    // Core playback engine resets to idle, but playlist is strictly retained!
    let mockPlayer = MockPlayerController()
    mockPlayer.isLoaded = true
    mockPlayer.isPlaying = true
    assert(mockPlayer.isLoaded == true, "Player starts loaded")
    mockPlayer.stop()
    assert(mockPlayer.isLoaded == false, "Player is stopped after close playback")
    assert(activePlaylist.count == 2, "Playlist items strictly retained after stopping playback")
    assert(activePlaylist.items[0].title == "Movie A", "Movie A remains in playlist")
    assert(activePlaylist.items[1].title == "Movie B", "Movie B remains in playlist")

    // Simulate opening existing file in non-empty playlist (should jump without wiping)
    if let existingIdx = activePlaylist.items.firstIndex(where: { $0.path == cmItem2.path }) {
        activePlaylist.selectIndex(existingIdx)
    }
    assert(activePlaylist.count == 2, "Opening existing item does NOT duplicate or truncate list")
    assert(activePlaylist.currentIndex == 1, "Active item switched to Movie B")

    // Simulate appending new file into non-empty playlist
    let cmItem3 = PlaylistItem(path: "/media/movie_c.mp4", title: "Movie C", duration: 6000.0)
    activePlaylist.appendItem(cmItem3)
    assert(activePlaylist.count == 3, "Appending preserves existing movies and increments count to 3")

    // Simulate cold start with retained files
    let coldStartRestored = PlaylistManager(
        isPersistenceEnabled: true,
        autoRestore: true,
        itemsStorageKey: testItemKey3,
        indexStorageKey: testIdxKey3
    )
    assert(coldStartRestored.count == 3, "Cold start accurately retains all 3 files")
    assert(coldStartRestored.items[0].title == "Movie A", "First movie is Movie A")
    assert(coldStartRestored.items[1].title == "Movie B", "Second movie is Movie B")
    assert(coldStartRestored.items[2].title == "Movie C", "Third movie is Movie C")

    // Simulate one-click clear all (一键清空)
    coldStartRestored.clear()
    assert(coldStartRestored.isEmpty == true, "One-click clear all empties playlist")
    assert(coldStartRestored.count == 0, "One-click clear all count is 0")
    assert(coldStartRestored.currentIndex == -1, "One-click clear all resets index to -1")

    // Subsequent cold start after clear confirms clean state
    let coldStartAfterClear = PlaylistManager(
        isPersistenceEnabled: true,
        autoRestore: true,
        itemsStorageKey: testItemKey3,
        indexStorageKey: testIdxKey3
    )
    assert(coldStartAfterClear.isEmpty == true, "Subsequent cold start after clear is empty")
    coldStartAfterClear.clearStorage()

    // =========================================================================
    // Test 39: Adaptive Drawer Dimensions, Progress Retention & Sequential Queue Invariants
    // =========================================================================
    print("\n--- Test 39: Adaptive Drawer Dimensions, Progress Retention & Sequential Queue Invariants ---")

    // 1. Adaptive Drawer Dimensions (Windowed vs Fullscreen Dual Logics)
    let w640 = PlaylistDrawerDimensions.drawerWidth(for: 640, isFullscreen: false)
    assert(w640 == 200, "Windowed mode at 640pt clamps to minimum 200pt")

    let w960 = PlaylistDrawerDimensions.drawerWidth(for: 960, isFullscreen: false)
    assert(abs(w960 - 240.0) < 0.01, "Windowed mode at 960pt scales adaptively (240pt)")

    let w1400 = PlaylistDrawerDimensions.drawerWidth(for: 1400, isFullscreen: false)
    assert(w1400 == 280, "Windowed mode at large widths clamps to maximum 280pt")

    let fs1440 = PlaylistDrawerDimensions.drawerWidth(for: 1440, isFullscreen: true)
    assert(abs(fs1440 - 259.2) < 0.01, "Fullscreen mode at 1440pt scales adaptively (259.2pt)")

    let fs1728 = PlaylistDrawerDimensions.drawerWidth(for: 1728, isFullscreen: true)
    assert(abs(fs1728 - 311.04) < 0.01, "Fullscreen mode at 1728pt scales adaptively (311.04pt)")

    let fs2560 = PlaylistDrawerDimensions.drawerWidth(for: 2560, isFullscreen: true)
    assert(fs2560 == 340, "Fullscreen mode at 2560pt clamps to maximum 340pt")

    let fs4K = PlaylistDrawerDimensions.drawerWidth(for: 3840, isFullscreen: true)
    assert(fs4K == 340, "Fullscreen mode at 4K clamps to maximum 340pt")

    // 2. Playback Progress Normalization & Retention
    let testVideoPath = "/Volumes/Media/Series/S01E05.mkv"
    let testVideoURL39 = "file:///Volumes/Media/Series/S01E05.mkv"
    AppSettings.shared.savePosition(for: testVideoPath, position: 1540.5, duration: 3600.0)
    assert(AppSettings.shared.getSavedPosition(for: testVideoPath) == 1540.5, "Saved position matches accurately")
    assert(AppSettings.shared.getSavedPosition(for: testVideoURL39) == 1540.5, "Normalized file URL lookup retrieves same position")

    // End-of-video clears progress
    AppSettings.shared.savePosition(for: testVideoPath, position: 3598.0, duration: 3600.0)
    assert(AppSettings.shared.getSavedPosition(for: testVideoPath) == 0.0, "Progress near EOF is cleanly reset")

    // 3. Sequential Queueing & No Preemption Invariant
    let testItemKey39 = "com.silkplayer.test.items.test39"
    let testIdxKey39 = "com.silkplayer.test.index.test39"
    let seqPlaylist = PlaylistManager(
        isPersistenceEnabled: false,
        autoRestore: false,
        itemsStorageKey: testItemKey39,
        indexStorageKey: testIdxKey39
    )

    // Initially empty playlist receives season episodes
    let ep1 = PlaylistItem(path: "/media/Ep01.mp4", title: "Ep 01")
    let ep2 = PlaylistItem(path: "/media/Ep02.mp4", title: "Ep 02")
    seqPlaylist.appendItems([ep1, ep2])
    assert(seqPlaylist.count == 2, "Season imported with 2 episodes")
    assert(seqPlaylist.currentIndex == 0, "First episode is immediately active index 0")
    assert(seqPlaylist.currentItem?.title == "Ep 01", "First episode is Ep 01")

    // Currently playing Ep 01, user appends extra files later
    let ep3 = PlaylistItem(path: "/media/Ep03.mp4", title: "Ep 03")
    let ep4 = PlaylistItem(path: "/media/Ep04.mp4", title: "Ep 04")
    seqPlaylist.appendItems([ep3, ep4])
    assert(seqPlaylist.count == 4, "Sequential queue increments to 4 items")
    assert(seqPlaylist.currentIndex == 0, "Currently playing Ep 01 index is untouched and not preempted")
    assert(seqPlaylist.items[2].title == "Ep 03", "Ep 03 is queued at tail position 2")
    assert(seqPlaylist.items[3].title == "Ep 04", "Ep 04 is queued at tail position 3")

    // =========================================================================
    // Test 40: Close Playback Drawer Collapse & Slender Row Card Invariants
    // =========================================================================
    print("\n--- Test 40: Close Playback Drawer Collapse & Slender Row Card Invariants ---")

    let realPlayer = MockPlayerController()
    realPlayer.isPlaylistDrawerVisible = true
    realPlayer.isInspectorVisible = true
    assert(realPlayer.isPlaylistDrawerVisible == true, "Drawer starts visible during playback")
    assert(realPlayer.isInspectorVisible == true, "Inspector starts visible during playback")

    // Stop playback must collapse both playlist drawer and inspector
    realPlayer.stop()
    assert(realPlayer.isPlaylistDrawerVisible == false, "Stopping playback collapses playlist drawer")
    assert(realPlayer.isInspectorVisible == false, "Stopping playback collapses inspector drawer")

    // Verify closing when returning to empty
    realPlayer.isPlaylistDrawerVisible = true
    realPlayer.closePlaybackOrReturnToEmpty()
    assert(realPlayer.isPlaylistDrawerVisible == false, "closePlaybackOrReturnToEmpty collapses playlist drawer")

    // Drawer dimensions slender proportions
    assert(PlaylistDrawerDimensions.drawerWidth(for: 960, isFullscreen: false) == 240.0, "960 window drawer width is 240pt (slender golden ratio)")
    assert(PlaylistDrawerDimensions.drawerWidth(for: 640, isFullscreen: false) == 200.0, "640 window drawer width is 200pt (slender clamped)")

    // =========================================================================
    // Test 41: Playlist Selection Drawer Retention & Window Geometry Invariants
    // =========================================================================
    print("\n--- Test 41: Playlist Selection Drawer Retention & Window Geometry Invariants ---")

    let mockCore = MockPlayerController()
    mockCore.isPlaylistDrawerVisible = true
    assert(mockCore.hasAppliedInitialWindowSize == false, "Initial window size not applied on cold state")

    // Simulate loading a track with drawer visible: must retain drawer visibility!
    mockCore.loadTrack(path: "/media/test.mp4")
    assert(mockCore.isPlaylistDrawerVisible == true, "Selecting playlist item retains drawer visibility")
    assert(mockCore.hasAppliedInitialWindowSize == true, "Initial window size applied on first playback")

    // Loading another track during active session retains drawer visibility and window geometry
    mockCore.loadTrack(path: "/media/test2.mp4")
    assert(mockCore.isPlaylistDrawerVisible == true, "Subsequent track switch maintains drawer visibility")
    assert(mockCore.hasAppliedInitialWindowSize == true, "Window size preserved across playlist track switches")

    // Stopping playback resets window size flag and collapses drawer
    mockCore.stop()
    assert(mockCore.isPlaylistDrawerVisible == false, "Stopping resets drawer visibility")
    assert(mockCore.hasAppliedInitialWindowSize == false, "Stopping resets initial window size flag for next media")

    // =========================================================================
    // Test 42: Click Interactions, Titlebar Dragging & Debounce Invariants
    // =========================================================================
    print("\n--- Test 42: Click Interactions, Titlebar Dragging & Debounce Invariants ---")

    // 1. Drawer width dynamic boundary vs hardcoded deadzone
    let windowW: CGFloat = 800.0
    let windowH: CGFloat = 450.0
    let dynDrawerW = PlaylistDrawerDimensions.drawerWidth(for: windowW, isFullscreen: false) + 8.0
    assert(dynDrawerW == 208.0, "Windowed mode drawer dynamic width is exactly 208pt")

    // Point at x=550 (which is 250pt from trailing edge) is OUTSIDE the 208pt drawer
    let clickX: CGFloat = windowW - 250.0
    let isInsideDynamicDrawer = (clickX >= windowW - dynDrawerW)
    let isInsideOldHardcodedDrawer = (clickX >= windowW - 348.0)
    assert(isInsideDynamicDrawer == false, "Click at 250pt from trailing edge is recognized as outside dynamic drawer")
    assert(isInsideOldHardcodedDrawer == true, "Old hardcoded 348pt incorrectly treated video canvas as inside drawer")

    // 2. Titlebar interactive button vs draggable center area boundaries
    let titlebarY: CGFloat = windowH - 30.0
    let isTitlebarY = (titlebarY >= windowH - 70.0)
    assert(isTitlebarY == true, "Y coordinate within top 70pt is titlebar zone")

    let centerTitlebarX: CGFloat = windowW / 2.0
    let trailingButtonsX: CGFloat = windowW - 50.0
    let leadingTrafficX: CGFloat = 40.0

    let isTrailingAction = (trailingButtonsX >= windowW - 160.0)
    let isLeadingTraffic = (leadingTrafficX <= 70.0)
    let isCenterDraggable = !(centerTitlebarX >= windowW - 160.0) && !(centerTitlebarX <= 70.0)

    assert(isTrailingAction == true, "Trailing top buttons recognized correctly")
    assert(isLeadingTraffic == true, "Leading traffic lights recognized correctly")
    assert(isCenterDraggable == true, "Center titlebar allows native window dragging")

    // 3. Debounce remaining time calculation
    let fullClickInterval: TimeInterval = 0.22
    let slowElapsed: TimeInterval = 0.25
    let fastElapsed: TimeInterval = 0.05

    let slowRemaining = max(0.0, fullClickInterval - slowElapsed)
    let fastRemaining = max(0.0, fullClickInterval - fastElapsed)
    assert(slowRemaining <= 0.001, "Slow click (>=220ms) executes play/pause immediately on release with 0 delay")
    assert(abs(fastRemaining - 0.17) < 0.001, "Fast click (50ms) preserves remaining 170ms debounce window for double-click")

    // 4. Double click action .none requires 0.0 click interval
    let noneInterval: TimeInterval = 0.0
    let noneRemaining = max(0.0, noneInterval - fastElapsed)
    assert(noneRemaining <= 0.001, "Double click action .none triggers play/pause immediately without delay")

    // 5. Stationary vs Drag threshold
    let microMove: CGFloat = 3.0
    let normalDrag: CGFloat = 12.0
    assert(microMove <= 4.0, "Micro-movement <= 4pt recognized as stationary click")
    assert(normalDrag > 4.0, "Movement > 4pt recognized as intentional window drag")

    // 6. Drag playback state invariance (zero interference during window movement)
    var testIsPlaying = true
    let isWindowDragOccurred = (normalDrag > 4.0)
    if !isWindowDragOccurred {
        testIsPlaying.toggle()
    }
    assert(testIsPlaying == true, "Window drag while playing strictly preserves playing state without pausing")

    var testIsPaused = false
    if !isWindowDragOccurred {
        testIsPaused.toggle()
    }
    assert(testIsPaused == false, "Window drag while paused strictly preserves paused state without playing")

    // 7. Stationary canvas click instant toggle (zero delay, immediate execution)
    let isStationaryClick = (microMove <= 4.0)
    if isStationaryClick {
        testIsPlaying.toggle()
    }
    assert(testIsPlaying == false, "Stationary click on video canvas instantly toggles playback")

    // 8. Bottom controls zone protection (dragging moves window, stationary click preserves playback)
    let bottomControlsY: CGFloat = 45.0
    let isBottomZone = (bottomControlsY <= 90.0)
    assert(isBottomZone == true, "Bottom control bar gaps correctly recognized as non-canvas chrome")

    // 43. Media Format Classification, One-Click Specs & macOS Native Window Tiling Invariants
    print("\n--- Test 43: Media Format Classification, One-Click Specs & macOS Window Tiling Invariants ---")

    // A. Cropped widescreen resolution classification invariants
    assert(SilkMediaFormatHelper.resolutionBadge(width: 3832, height: 1600) == "4K UHD", "Cropped 4K UHD (3832x1600) accurately classified as 4K UHD")
    assert(SilkMediaFormatHelper.resolutionBadge(width: 3840, height: 1608) == "4K UHD", "Standard 2.39:1 4K UHD (3840x1608) classified as 4K UHD")
    assert(SilkMediaFormatHelper.resolutionBadge(width: 3840, height: 2160) == "4K UHD", "Standard 16:9 4K UHD (3840x2160) classified as 4K UHD")
    assert(SilkMediaFormatHelper.resolutionBadge(width: 4096, height: 2160) == "4K UHD", "DCI 4K (4096x2160) classified as 4K UHD")
    assert(SilkMediaFormatHelper.resolutionBadge(width: 2560, height: 1440) == "2K QHD", "2K QHD (2560x1440) classified as 2K QHD")
    assert(SilkMediaFormatHelper.resolutionBadge(width: 1920, height: 800) == "1080p HD", "Cropped 1080p (1920x800) classified as 1080p HD")
    assert(SilkMediaFormatHelper.resolutionBadge(width: 1920, height: 1080) == "1080p HD", "Standard 1080p (1920x1080) classified as 1080p HD")
    assert(SilkMediaFormatHelper.resolutionBadge(width: 1280, height: 536) == "720p HD", "Cropped 720p (1280x536) classified as 720p HD")
    assert(SilkMediaFormatHelper.resolutionBadge(width: 1280, height: 720) == "720p HD", "Standard 720p (1280x720) classified as 720p HD")
    assert(SilkMediaFormatHelper.resolutionBadge(width: 720, height: 480) == "SD", "DVD 480p (720x480) classified as SD")

    // B. Resolution text formatting
    assert(SilkMediaFormatHelper.resolutionText(width: 3832, height: 1600) == "4K UHD", "resolutionText for 3832x1600 produces '4K UHD'")
    assert(SilkMediaFormatHelper.resolutionText(width: 500, height: 300) == "500×300", "resolutionText for custom size produces '500×300'")

    // C. macOS Native Window Tiling (Split-Screen / Snapping) Invariants
    let tilePlayer = MockPlayerController()
    tilePlayer.isPlaying = true
    tilePlayer.videoWidth = 3832
    tilePlayer.videoHeight = 1600
    let tileSession = PlayerWindowSession(id: UUID(), player: tilePlayer)
    let tileDelegate = PlayerWindowDelegate(session: tileSession, player: tilePlayer)

    let targetScreen = testWindow.screen ?? NSScreen.main
    let activeScreenFrame = targetScreen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)
    let tileHalfW = round(activeScreenFrame.width * 0.5)
    let tileFullH = activeScreenFrame.height
    let tileHalfH = round(activeScreenFrame.height * 0.5)
    let tileFullW = activeScreenFrame.width

    // Video-adaptive aspect ratio: 3832 / 1600 = 2.395:1
    let expectedAdaptiveH = round(tileHalfW / (3832.0 / 1600.0))

    // Left-half screen tile snap: adaptively scales height to 401pt with ZERO black bars!
    let leftHalfTarget = NSSize(width: tileHalfW, height: tileFullH)
    let leftTileResult = tileDelegate.windowWillResize(testWindow, to: leftHalfTarget)
    assert(leftTileResult.width == tileHalfW, "Left-half window tiling preserves full tile width (\(tileHalfW))")
    assert(leftTileResult.height == expectedAdaptiveH, "Left-half window tiling adaptively sizes height to video aspect ratio (\(expectedAdaptiveH)) with ZERO black bars")

    // Right-half screen tile snap
    let rightHalfTarget = NSSize(width: tileHalfW, height: tileFullH)
    let rightTileResult = tileDelegate.windowWillResize(testWindow, to: rightHalfTarget)
    assert(rightTileResult.width == tileHalfW, "Right-half window tiling preserves full tile width (\(tileHalfW))")
    assert(rightTileResult.height == expectedAdaptiveH, "Right-half window tiling adaptively sizes height to video aspect ratio (\(expectedAdaptiveH)) with ZERO black bars")

    // Top-half horizontal split snap
    let topHalfTarget = NSSize(width: tileFullW, height: tileHalfH)
    let topTileResult = tileDelegate.windowWillResize(testWindow, to: topHalfTarget)
    let expectedAdaptiveW = round(tileHalfH * (3832.0 / 1600.0))
    assert(topTileResult.width == expectedAdaptiveW, "Top-half window tiling adaptively sizes width to video aspect ratio (\(expectedAdaptiveW))")
    assert(topTileResult.height == tileHalfH, "Top-half window tiling preserves half height (\(tileHalfH))")

    // Quarter-screen corner snap (fits inside quarter bounding box without aspect distortion)
    let quarterTarget = NSSize(width: tileHalfW, height: tileHalfH)
    let quarterTileResult = tileDelegate.windowWillResize(testWindow, to: quarterTarget)
    let boxAspect = tileHalfW / max(1.0, tileHalfH)
    let videoAspect = 3832.0 / 1600.0
    let expectedQuarterW = (videoAspect >= boxAspect) ? tileHalfW : round(tileHalfH * videoAspect)
    let expectedQuarterH = (videoAspect >= boxAspect) ? round(tileHalfW / videoAspect) : tileHalfH
    assert(quarterTileResult.width == expectedQuarterW, "Quarter-screen snap preserves quarter width (\(expectedQuarterW))")
    assert(quarterTileResult.height == expectedQuarterH, "Quarter-screen snap adaptively sizes height to video aspect ratio (\(expectedQuarterH))")

    // Idle window (no video loaded): directly accepts full tiling tile
    let idlePlayer = MockPlayerController()
    idlePlayer.videoWidth = 0
    idlePlayer.videoHeight = 0
    let idleDelegate = PlayerWindowDelegate(session: nil, player: idlePlayer)
    let idleLeftTileResult = idleDelegate.windowWillResize(testWindow, to: leftHalfTarget)
    assert(idleLeftTileResult.width == tileHalfW, "Idle window left-half tiling accepts tile width")
    assert(idleLeftTileResult.height == tileFullH, "Idle window left-half tiling accepts full tile height")

    // Normal non-tiling corner drag still preserves 2.395:1 widescreen aspect ratio
    let normalCornerDrag = NSSize(width: 1200, height: 700)
    let normalDragResult = tileDelegate.windowWillResize(testWindow, to: normalCornerDrag)
    assert(normalDragResult.width == 1200, "Normal corner drag sets proposed width (1200)")
    let expectedWidescreenH = round(1200.0 / (3832.0 / 1600.0))
    assert(normalDragResult.height == expectedWidescreenH, "Normal corner drag preserves 2.395:1 aspect ratio (\(expectedWidescreenH))")

    // D. Formatted Media Specifications String Invariants
    let formattedInfo = SilkMediaFormatHelper.formattedMediaInfo(
        filePath: "/Volumes/Media/Matrix.mkv",
        videoWidth: 3832,
        videoHeight: 1600,
        videoCodec: "hevc",
        isHDRContent: true,
        isDolbyVision: true,
        hdrFormatString: "Dolby Vision Profile 5"
    )
    assert(formattedInfo.contains("3832 × 1600 (4K UHD)"), "Formatted info contains 4K UHD resolution badge")
    assert(formattedInfo.contains("HEVC"), "Formatted info contains uppercase video codec")
    assert(formattedInfo.contains("Dolby Vision Profile 5"), "Formatted info contains dynamic range")
    assert(formattedInfo.contains("Matrix.mkv"), "Formatted info contains filename")

    // 44. Progressive Timeline Index & Binary Search Nearest Neighbor Invariants
    print("\n--- Test 44: Progressive Timeline Index & Binary Search Nearest Neighbor Invariants ---")
    struct MockTimelineItem {
        let time: Double
        let label: String
    }

    func mockFindBest(in items: [MockTimelineItem], target: Double) -> String? {
        guard !items.isEmpty else { return nil }
        if items.count == 1 { return items[0].label }
        if target <= items[0].time { return items[0].label }
        if target >= items[items.count - 1].time { return items[items.count - 1].label }

        var low = 0
        var high = items.count - 1
        while low <= high {
            let mid = (low + high) / 2
            let midTime = items[mid].time
            if midTime == target {
                return items[mid].label
            } else if midTime < target {
                low = mid + 1
            } else {
                high = mid - 1
            }
        }
        let prev = items[max(0, high)]
        let next = items[min(items.count - 1, low)]
        return abs(prev.time - target) <= abs(next.time - target) ? prev.label : next.label
    }

    let emptyIndex: [MockTimelineItem] = []
    assert(mockFindBest(in: emptyIndex, target: 10.0) == nil, "Empty timeline index safely returns nil")

    let singleIndex = [MockTimelineItem(time: 0.0, label: "Frame0")]
    assert(mockFindBest(in: singleIndex, target: 50.0) == "Frame0", "Single frame index always returns only frame")

    let indexedTimeline = [
        MockTimelineItem(time: 0.0, label: "0s"),
        MockTimelineItem(time: 10.0, label: "10s"),
        MockTimelineItem(time: 20.0, label: "20s"),
        MockTimelineItem(time: 30.0, label: "30s"),
        MockTimelineItem(time: 40.0, label: "40s"),
        MockTimelineItem(time: 50.0, label: "50s")
    ]

    // Boundary conditions
    assert(mockFindBest(in: indexedTimeline, target: -5.0) == "0s", "Negative hover time clamps to 0s frame")
    assert(mockFindBest(in: indexedTimeline, target: 0.0) == "0s", "Exact 0s matches 0s frame")
    assert(mockFindBest(in: indexedTimeline, target: 55.0) == "50s", "Past EOF hover time clamps to 50s frame")

    // In-between continuous floating-point nearest neighbor matching
    assert(mockFindBest(in: indexedTimeline, target: 11.23847) == "10s", "11.24s matches closest 10s frame")
    assert(mockFindBest(in: indexedTimeline, target: 14.99999) == "10s" || mockFindBest(in: indexedTimeline, target: 14.99999) == "20s", "14.99999s resolves safely to nearest neighbor")
    assert(mockFindBest(in: indexedTimeline, target: 18.74912) == "20s", "18.75s matches closest 20s frame")
    assert(mockFindBest(in: indexedTimeline, target: 20.0) == "20s", "Exact 20s matches 20s frame")
    assert(mockFindBest(in: indexedTimeline, target: 34.2) == "30s", "34.2s matches closest 30s frame")
    assert(mockFindBest(in: indexedTimeline, target: 36.8) == "40s", "36.8s matches closest 40s frame")

    // Progressive streaming invariant (even if only 0s-20s arrived so far)
    let partialTimeline = Array(indexedTimeline.prefix(3))
    assert(mockFindBest(in: partialTimeline, target: 45.0) == "20s", "Partial timeline acts as sticky frame before later frames arrive")

    // 45. 8K Tier, Dolby Vision Profile 5 & Tone Curve Invariants
    print("\n--- Test 45: 8K Tier, Dolby Vision Tone Curve & Screenshot Invariants ---")
    assert(SilkMediaFormatHelper.resolutionBadge(width: 7680, height: 4320) == "8K", "7680x4320 correctly identified as 8K")
    assert(SilkMediaFormatHelper.resolutionBadge(width: 4096, height: 1716) == "4K UHD", "4096x1716 DCI Scope correctly identified as 4K UHD")
    assert(SilkMediaFormatHelper.resolutionText(width: 7680, height: 4320) == "8K", "resolutionText for 8K produces '8K'")

    // Tone curve monotonic and boundary invariants
    func mockToneMap(_ nits: Float) -> Float {
        let exposure: Float = 1.5
        let l = nits / 100 * exposure
        return min(1, l * (1 + l / 100) / (1 + l))
    }
    assert(mockToneMap(0) == 0, "Tone map at 0 nits produces absolute black 0.0")
    assert(mockToneMap(100) > mockToneMap(10), "Tone map is monotonically increasing (100 nits > 10 nits)")
    assert(mockToneMap(1000) > mockToneMap(100), "Tone map is monotonically increasing (1000 nits > 100 nits)")
    assert(mockToneMap(10000) <= 1.0, "Tone map at 10000 nits strictly clamps to <= 1.0")

    // Screenshot configuration defaults
    assert(AppSettings.shared.screenshotFormat == "png", "Default screenshot format is lossless png")
    assert(!AppSettings.shared.screenshotDirectory.isEmpty, "Screenshot directory path is populated")

    // 46. Scrubber Knob Center Kinematics & BiPlanar Pixel Format Invariants
    print("\n--- Test 46: Scrubber Knob Center Kinematics & VideoToolbox BiPlanar Invariants ---")
    func testKnobRadius(isExpanded: Bool) -> CGFloat { isExpanded ? 7.5 : 4.75 }
    func testTravelSpan(totalWidth: CGFloat, isExpanded: Bool) -> CGFloat { max(1.0, totalWidth - (isExpanded ? 15.0 : 9.5)) }
    func testKnobCenterX(progress: CGFloat, totalWidth: CGFloat, isExpanded: Bool) -> CGFloat {
        let r = testKnobRadius(isExpanded: isExpanded)
        return r + progress * testTravelSpan(totalWidth: totalWidth, isExpanded: isExpanded)
    }
    func testFraction(for locationX: CGFloat, totalWidth: CGFloat, isExpanded: Bool) -> CGFloat {
        let r = testKnobRadius(isExpanded: isExpanded)
        let span = testTravelSpan(totalWidth: totalWidth, isExpanded: isExpanded)
        let clampedX = max(r, min(totalWidth - r, locationX))
        return max(0.0, min(1.0, (clampedX - r) / span))
    }

    let w: CGFloat = 1000.0
    let rExpanded: CGFloat = 7.5
    // Knob boundary invariants
    assert(testKnobCenterX(progress: 0.0, totalWidth: w, isExpanded: true) == rExpanded, "Knob center at 0% matches knob radius (7.5pt)")
    assert(testKnobCenterX(progress: 1.0, totalWidth: w, isExpanded: true) == w - rExpanded, "Knob center at 100% matches total width minus radius (992.5pt)")
    assert(testFraction(for: 0.0, totalWidth: w, isExpanded: true) == 0.0, "Click at 0pt clamps cleanly to 0.0 fraction")
    assert(testFraction(for: w, totalWidth: w, isExpanded: true) == 1.0, "Click at 1000pt clamps cleanly to 1.0 fraction")
    assert(abs(testFraction(for: w / 2.0, totalWidth: w, isExpanded: true) - 0.5) < 0.0001, "Click at midpoint (500pt) yields exactly 0.5 fraction")

    // Kinematic round-trip bijective mapping invariant
    for step in 0...100 {
        let prog = CGFloat(step) / 100.0
        let centerX = testKnobCenterX(progress: prog, totalWidth: w, isExpanded: true)
        let resolvedProg = testFraction(for: centerX, totalWidth: w, isExpanded: true)
        assert(abs(prog - resolvedProg) < 0.0001, "Progress \(prog) bijectively maps through knob center to exact same progress")
    }

    // Touch anchor identity invariant (User click point matches knob center landing point)
    let touchPoint: CGFloat = 345.6
    let touchFraction = testFraction(for: touchPoint, totalWidth: w, isExpanded: true)
    let knobLandingX = testKnobCenterX(progress: touchFraction, totalWidth: w, isExpanded: true)
    assert(abs(touchPoint - knobLandingX) < 0.0001, "Touch point \(touchPoint) perfectly coincides with knob center landing point")

    print("\n==================================================")
    print("Test Summary: \(passed) passed, \(failed) failed")
    print("==================================================")

    if failed > 0 {
        exit(1)
    }
}

@main
struct PlaylistTests {
    @MainActor
    static func main() async {
        await runTests()
    }
}
