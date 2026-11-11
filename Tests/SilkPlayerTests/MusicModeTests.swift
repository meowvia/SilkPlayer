import XCTest
import AppKit
import Combine
@testable import SilkPlayer

final class MusicModeTests: XCTestCase {

    // MARK: - 1. Locked Widths & Responsive Breakpoints

    func testLockedWidthsAcrossScreenResolutions() {
        XCTAssertEqual(MusicModeGeometry.lockedWidth(forScreenWidth: 1280), 520)
        XCTAssertEqual(MusicModeGeometry.lockedWidth(forScreenWidth: 1440), 520)
        XCTAssertEqual(MusicModeGeometry.lockedWidth(forScreenWidth: 1728), 520)
        XCTAssertEqual(MusicModeGeometry.lockedWidth(forScreenWidth: 1920), 520)
        XCTAssertEqual(MusicModeGeometry.lockedWidth(forScreenWidth: 2560), 572)
        XCTAssertEqual(MusicModeGeometry.lockedWidth(forScreenWidth: 3008), 672)
        XCTAssertEqual(MusicModeGeometry.lockedWidth(forScreenWidth: 3440), 768)
        XCTAssertEqual(MusicModeGeometry.lockedWidth(forScreenWidth: 3840), 768)
    }

    func testVerticalResizeClampingAndLayoutBreakpoints() {
        let laptopFrame = NSRect(x: 0, y: 40, width: 1440, height: 820)
        let ultrawideFrame = NSRect(x: 0, y: 40, width: 3440, height: 1314)

        // Vertical resize strictly locks width while clamping height between minHeight (500) and visibleHeight
        let shrunkProposal = MusicModeGeometry.clampedResizeProposal(
            NSSize(width: 900, height: 240),
            screenVisibleFrame: laptopFrame
        )
        XCTAssertEqual(shrunkProposal.width, 520)
        XCTAssertEqual(shrunkProposal.height, 500)

        let expandedProposal = MusicModeGeometry.clampedResizeProposal(
            NSSize(width: 300, height: 1800),
            screenVisibleFrame: ultrawideFrame
        )
        XCTAssertEqual(expandedProposal.width, 768)
        XCTAssertEqual(expandedProposal.height, 1314)

        // Breakpoints match layout density spec
        XCTAssertFalse(MusicModeGeometry.showsExtendedQueueColumns(width: 520))
        XCTAssertFalse(MusicModeGeometry.showsExtendedQueueColumns(width: 572))
        XCTAssertFalse(MusicModeGeometry.showsExtendedQueueColumns(width: 672))
        XCTAssertTrue(MusicModeGeometry.showsExtendedQueueColumns(width: 680))
        XCTAssertTrue(MusicModeGeometry.showsExtendedQueueColumns(width: 768))

        XCTAssertTrue(MusicModeGeometry.usesCompactBottomControls(width: 520))
        XCTAssertEqual(MusicModeGeometry.bottomVolumeTrackWidth(forWindowWidth: 520), 60)
        XCTAssertFalse(MusicModeGeometry.showsVolumePercentage(forWindowWidth: 520))

        XCTAssertFalse(MusicModeGeometry.usesCompactBottomControls(width: 672))
        XCTAssertEqual(MusicModeGeometry.bottomVolumeTrackWidth(forWindowWidth: 768), 84)
        XCTAssertTrue(MusicModeGeometry.showsVolumePercentage(forWindowWidth: 768))
    }

    // MARK: - 2. Window Chrome Guards & Restoration

    @MainActor
    func testWindowChromeAndFullscreenGuards() {
        let player = PlayerCore()
        let window = NSWindow(
            contentRect: NSRect(x: 100, y: 100, width: 800, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.collectionBehavior.insert([.fullScreenPrimary, .fullScreenAllowsTiling])
        player.hostWindow = window

        player.isAudioOnly = true
        player.applyAudioWindowGeometry(animated: false)

        let screenFrame = (window.screen ?? NSScreen.main)?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)
        let expectedWidth = MusicModeGeometry.lockedWidth(forScreenWidth: screenFrame.width)

        XCTAssertEqual(window.minSize.width, expectedWidth)
        XCTAssertEqual(window.maxSize.width, expectedWidth)
        XCTAssertTrue(window.collectionBehavior.contains(.fullScreenNone))
        XCTAssertFalse(window.collectionBehavior.contains(.fullScreenPrimary))
        XCTAssertEqual(window.standardWindowButton(.zoomButton)?.isEnabled, false)

        // Drawer & fullscreen toggles must remain locked out while in Music Mode
        player.togglePlaylistDrawer()
        XCTAssertFalse(player.isPlaylistDrawerVisible)
        player.toggleFullscreen()
        XCTAssertFalse(player.isFullscreen)

        // Exiting back to idle / video restores standard window capabilities
        player.stop(resetUI: true)
        XCTAssertFalse(player.isAudioOnly)
        XCTAssertTrue(window.collectionBehavior.contains(.fullScreenPrimary))
        XCTAssertFalse(window.collectionBehavior.contains(.fullScreenNone))
        XCTAssertEqual(window.standardWindowButton(.zoomButton)?.isEnabled, true)
        XCTAssertGreaterThan(window.maxSize.width, expectedWidth)
    }

    func testTwoStageCollapseGeometryAndMagneticHysteresis() {
        let laptopFrame = NSRect(x: 0, y: 40, width: 1440, height: 820)
        let ultrawideFrame = NSRect(x: 0, y: 40, width: 3440, height: 1314)

        XCTAssertEqual(MusicModeGeometry.collapsedHeight(forWindowWidth: 520), 290)
        XCTAssertEqual(MusicModeGeometry.collapsedHeight(forWindowWidth: 672), 290)
        XCTAssertEqual(MusicModeGeometry.collapsedHeight(forWindowWidth: 768), 300)

        // Expanded -> drag gently above threshold holds expanded min height (500)
        let holdExpanded = MusicModeGeometry.magneticResizeProposal(
            NSSize(width: 768, height: 450),
            isCollapsed: false,
            screenVisibleFrame: ultrawideFrame
        )
        XCTAssertFalse(holdExpanded.isCollapsed)
        XCTAssertEqual(holdExpanded.size, NSSize(width: 768, height: 500))

        // Expanded -> drag past 410 snaps directly to collapsed height (300)
        let snapCollapse = MusicModeGeometry.magneticResizeProposal(
            NSSize(width: 768, height: 405),
            isCollapsed: false,
            screenVisibleFrame: ultrawideFrame
        )
        XCTAssertTrue(snapCollapse.isCollapsed)
        XCTAssertEqual(snapCollapse.size, NSSize(width: 768, height: 300))

        // Collapsed -> small downward pull (< 370) remains collapsed
        let holdCollapsed = MusicModeGeometry.magneticResizeProposal(
            NSSize(width: 520, height: 350),
            isCollapsed: true,
            screenVisibleFrame: laptopFrame
        )
        XCTAssertTrue(holdCollapsed.isCollapsed)
        XCTAssertEqual(holdCollapsed.size, NSSize(width: 520, height: 290))

        // Collapsed -> pull past 370 snaps back open to minHeight (500)
        let snapExpand = MusicModeGeometry.magneticResizeProposal(
            NSSize(width: 520, height: 375),
            isCollapsed: true,
            screenVisibleFrame: laptopFrame
        )
        XCTAssertFalse(snapExpand.isCollapsed)
        XCTAssertEqual(snapExpand.size, NSSize(width: 520, height: 500))

        // Top-anchored toggle keeps Hero Card maxY stationary when space below is sufficient
        let expandedMid = NSRect(x: 400, y: 180, width: 768, height: 640)
        let collapsedMid = MusicModeGeometry.toggledCollapseFrame(
            around: expandedMid,
            targetCollapsed: true,
            rememberedExpandedHeight: 640,
            screenVisibleFrame: ultrawideFrame
        )
        XCTAssertEqual(collapsedMid.height, 300)
        XCTAssertEqual(collapsedMid.maxY, expandedMid.maxY)

        let reExpandedMid = MusicModeGeometry.toggledCollapseFrame(
            around: collapsedMid,
            targetCollapsed: false,
            rememberedExpandedHeight: 640,
            screenVisibleFrame: ultrawideFrame
        )
        XCTAssertEqual(reExpandedMid.height, 640)
        XCTAssertEqual(reExpandedMid.maxY, expandedMid.maxY)

        // Expanding near bottom screen edge pushes frame upward instead of clipping below Dock
        let collapsedNearBottom = NSRect(x: 400, y: 50, width: 768, height: 300)
        let expandedClampedBottom = MusicModeGeometry.toggledCollapseFrame(
            around: collapsedNearBottom,
            targetCollapsed: false,
            rememberedExpandedHeight: 640,
            screenVisibleFrame: ultrawideFrame
        )
        XCTAssertEqual(expandedClampedBottom.height, 640)
        XCTAssertGreaterThanOrEqual(expandedClampedBottom.minY, ultrawideFrame.minY)
    }

    @MainActor
    func testCollapsePreservesExpandedHeightMemory() {
        let defaults = UserDefaults.standard
        let priorCollapsed = AppSettings.shared.isMusicQueueCollapsed
        let priorStoredHeight = defaults.object(forKey: PlayerCore.musicModeHeightDefaultsKey)
        defer {
            AppSettings.shared.isMusicQueueCollapsed = priorCollapsed
            if let priorStoredHeight {
                defaults.set(priorStoredHeight, forKey: PlayerCore.musicModeHeightDefaultsKey)
            } else {
                defaults.removeObject(forKey: PlayerCore.musicModeHeightDefaultsKey)
            }
        }

        AppSettings.shared.isMusicQueueCollapsed = false
        defaults.removeObject(forKey: PlayerCore.musicModeHeightDefaultsKey)

        let player = PlayerCore()
        let window = NSWindow(
            contentRect: NSRect(x: 120, y: 120, width: 768, height: 640),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        player.hostWindow = window
        player.isAudioOnly = true

        let screenFrame = (window.screen ?? NSScreen.main)?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)
        let lockedW = MusicModeGeometry.lockedWidth(forScreenWidth: screenFrame.width)
        let collapsedH = MusicModeGeometry.collapsedHeight(forWindowWidth: lockedW, screenVisibleHeight: screenFrame.height)

        window.setFrame(NSRect(x: screenFrame.minX + 100, y: screenFrame.minY + 120, width: lockedW, height: 640), display: false)
        player.setMusicQueueCollapsed(true, animated: false)

        XCTAssertTrue(AppSettings.shared.isMusicQueueCollapsed)
        XCTAssertEqual(window.frame.height, collapsedH, accuracy: 1.0)
        XCTAssertEqual(defaults.double(forKey: PlayerCore.musicModeHeightDefaultsKey), 640.0, accuracy: 1.0)

        player.setMusicQueueCollapsed(false, animated: false)
        XCTAssertFalse(AppSettings.shared.isMusicQueueCollapsed)
        XCTAssertEqual(window.frame.height, 640.0, accuracy: 1.0)
    }

    @MainActor
    func testAudioRhythmAndLocalizationCacheDecoupling() {
        let player = PlayerCore()
        var publishCount = 0
        let cancellable = player.objectWillChange.sink { _ in
            publishCount += 1
        }
        defer { cancellable.cancel() }

        player.audioRhythm.levels = [0.2, 0.5, 0.7, 0.4, 0.3, 0.2, 0.1]
        player.audioRhythmLevels = [0.6, 0.8, 0.5, 0.6, 0.7, 0.4, 0.3]
        XCTAssertEqual(publishCount, 0, "Rhythm updates must flow through @Observable leaf state without firing PlayerCore objectWillChange")

        let priorLang = AppSettings.shared.appLanguage
        defer { AppSettings.shared.appLanguage = priorLang }

        AppSettings.shared.appLanguage = .en
        XCTAssertFalse(L10n.isChinese)
        AppSettings.shared.appLanguage = .zhHans
        XCTAssertTrue(L10n.isChinese)

        UserDefaults.standard.set(AppLanguage.en.rawValue, forKey: "appLanguage")
        XCTAssertFalse(L10n.isChinese)
        UserDefaults.standard.set(priorLang.rawValue, forKey: "appLanguage")
    }

    @MainActor
    func testCommandSyncTokenInvalidatesOnPlayerStateTransitions() {
        let player = PlayerCore()
        let windowManager = PlayerWindowManager.shared
        let initialToken = windowManager.commandSyncToken

        player.isLoaded = true
        let afterLoadedToken = windowManager.commandSyncToken
        XCTAssertGreaterThan(afterLoadedToken, initialToken)

        player.isAudioOnly = true
        let afterAudioToken = windowManager.commandSyncToken
        XCTAssertGreaterThan(afterAudioToken, afterLoadedToken)

        player.isPlaying = true
        let afterPlayingToken = windowManager.commandSyncToken
        XCTAssertGreaterThan(afterPlayingToken, afterAudioToken)
    }

    // MARK: - 3. Audio Metadata Extraction & FLAC Header Parsing

    @MainActor
    func testAudioMetadataFallbackAndSpecFormatting() async throws {
        let item = PlaylistItem(path: "/tmp/Taylor Swift - Cruel Summer.flac", title: "Taylor Swift - Cruel Summer", duration: 178)
        var fallback = AudioTrackMetadataService.fallbackMetadata(for: item)
        XCTAssertEqual(fallback.artist, "Taylor Swift")
        XCTAssertEqual(fallback.title, "Cruel Summer")
        XCTAssertEqual(fallback.formatLabel, "FLAC")
        XCTAssertEqual(fallback.queueDisplayTitle, "Taylor Swift - Cruel Summer")

        fallback.sampleRateHz = 44100
        fallback.bitDepth = 16
        XCTAssertEqual(fallback.heroSpecText, "FLAC · 44.1 kHz / 16-bit")

        fallback.sampleRateHz = 96000
        fallback.bitDepth = 24
        XCTAssertEqual(fallback.heroSpecText, "FLAC · 96 kHz / 24-bit")

        // Create minimal valid FLAC container with STREAMINFO (48 kHz, 24-bit) + VORBIS_COMMENT tags
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("silk_test_\(UUID().uuidString).flac")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        var flacData = Data("fLaC".utf8)
        // STREAMINFO block (not last, type 0, length 34)
        flacData.append(contentsOf: [0x00, 0x00, 0x00, 34])
        var streamInfo = [UInt8](repeating: 0, count: 34)
        // 48000 Hz = 0x0BB80 (20 bits): byte10=0x0B, byte11=0xB8, upper nibble byte12=0x0
        // channels=2 ((2-1)<<1 = 0x2), bps=24 ((24-1)=23 = 0x17: bit0 byte12=1, upper nibble byte13=0x70)
        streamInfo[10] = 0x0B
        streamInfo[11] = 0xB8
        streamInfo[12] = 0x03
        streamInfo[13] = 0x70
        streamInfo[17] = 1 // minimal non-zero sample byte
        flacData.append(contentsOf: streamInfo)

        // VORBIS_COMMENT block (last = 0x80 | 4 = 0x84)
        func appendLE32(_ v: UInt32, to buf: inout Data) {
            var le = v.littleEndian
            buf.append(Data(bytes: &le, count: 4))
        }
        var commentsPayload = Data()
        let vendor = Data("SilkTest".utf8)
        appendLE32(UInt32(vendor.count), to: &commentsPayload)
        commentsPayload.append(vendor)
        let tags = ["TITLE=夜曲", "ARTIST=周杰伦", "ALBUM=十一月的萧邦"]
        appendLE32(UInt32(tags.count), to: &commentsPayload)
        for tag in tags {
            let bytes = Data(tag.utf8)
            appendLE32(UInt32(bytes.count), to: &commentsPayload)
            commentsPayload.append(bytes)
        }
        let cLen = commentsPayload.count
        flacData.append(0x84)
        flacData.append(UInt8((cLen >> 16) & 0xFF))
        flacData.append(UInt8((cLen >> 8) & 0xFF))
        flacData.append(UInt8(cLen & 0xFF))
        flacData.append(commentsPayload)
        try flacData.write(to: tempURL)

        let service = AudioTrackMetadataService()
        let testItem = PlaylistItem(path: tempURL.path, title: tempURL.deletingPathExtension().lastPathComponent, duration: 225)
        service.ensureLoaded(for: [testItem])

        for _ in 0..<25 {
            if service.cache[tempURL.path]?.album == "十一月的萧邦" { break }
            try await Task.sleep(nanoseconds: 20_000_000)
        }

        let resolved = service.metadata(for: testItem)
        XCTAssertEqual(resolved.title, "夜曲")
        XCTAssertEqual(resolved.artist, "周杰伦")
        XCTAssertEqual(resolved.album, "十一月的萧邦")
        XCTAssertEqual(resolved.sampleRateHz, 48000)
        XCTAssertEqual(resolved.bitDepth, 24)
        XCTAssertEqual(resolved.heroSpecText, "FLAC · 48 kHz / 24-bit")
    }

    // MARK: - 4. Queue Sorting & Category Isolation

    @MainActor
    func testAudioQueueSortingPreservesPlayingTrackAndIsolation() {
        let manager = PlaylistManager(isPersistenceEnabled: false, autoRestore: false)
        let video = PlaylistItem(path: "/videos/clip.mp4", title: "Clip", duration: 60)
        let songB = PlaylistItem(path: "/music/B - Zeta.flac", title: "B - Zeta", duration: 300)
        let songA = PlaylistItem(path: "/music/A - Alpha.mp3", title: "A - Alpha", duration: 180)
        let songC = PlaylistItem(path: "/music/C - Mid.m4a", title: "C - Mid", duration: 240)

        manager.appendItems([video, songB, songA, songC])
        manager.switchCategory(.audio)
        _ = manager.selectIndex(1) // songA
        XCTAssertEqual(manager.currentItem?.id, songA.id)

        let metaMap: [UUID: AudioTrackMetadata] = [
            songB.id: AudioTrackMetadata(path: songB.path, title: "Zeta", artist: "Artist Z", album: "Album 3", formatLabel: "FLAC", duration: 300),
            songA.id: AudioTrackMetadata(path: songA.path, title: "Alpha", artist: "Artist A", album: "Album 1", formatLabel: "MP3", duration: 180),
            songC.id: AudioTrackMetadata(path: songC.path, title: "Mid", artist: "Artist M", album: "Album 2", formatLabel: "ALAC", duration: 240)
        ]

        // Sort by title ascending -> Alpha, Mid, Zeta; currentItem stays songA
        manager.sortAudioItems(by: .title, direction: .ascending) { metaMap[$0.id]! }
        XCTAssertEqual(manager.audioItems.map(\.id), [songA.id, songC.id, songB.id])
        XCTAssertEqual(manager.currentItem?.id, songA.id)
        XCTAssertEqual(manager.upcomingItem?.id, songC.id)

        // Sort by duration descending -> 300 (songB), 240 (songC), 180 (songA)
        manager.sortAudioItems(by: .duration, direction: .descending) { metaMap[$0.id]! }
        XCTAssertEqual(manager.audioItems.map(\.id), [songB.id, songC.id, songA.id])
        XCTAssertEqual(manager.currentItem?.id, songA.id)

        // Clearing browsed video category preserves playing audio queue intact
        manager.clearCategory(.video)
        XCTAssertEqual(manager.videoCount, 0)
        XCTAssertEqual(manager.audioCount, 3)
        XCTAssertEqual(manager.currentItem?.id, songA.id)
    }

    // MARK: - 5. Mojibake Repair, APE/MP3 Parsers & Cache Persistence

    func testMojibakeRepairAndAccentedLatinPreservation() {
        XCTAssertEqual(
            AudioTrackMetadataService.repairMojibakeIfNeeded("ÕÅ°¬¼Î - °®µÄ´ú¼Û"),
            "张艾嘉 - 爱的代价"
        )
        XCTAssertEqual(
            AudioTrackMetadataService.repairMojibakeIfNeeded("Ì·Ó½÷ë - °®ÔÚÉîÇï"),
            "谭咏麟 - 爱在深秋"
        )
        XCTAssertEqual(
            AudioTrackMetadataService.repairMojibakeIfNeeded("ÓÃÐÄÁ¼¿à"),
            "用心良苦"
        )

        // Valid European accented Latin titles must remain intact
        XCTAssertEqual(AudioTrackMetadataService.repairMojibakeIfNeeded("Beyoncé"), "Beyoncé")
        XCTAssertEqual(AudioTrackMetadataService.repairMojibakeIfNeeded("Café del Mar"), "Café del Mar")
        XCTAssertEqual(AudioTrackMetadataService.repairMojibakeIfNeeded("Tiësto"), "Tiësto")
    }

    @MainActor
    func testApeAndMp3ParsersAndDiskCacheRoundTrip() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("silkplayer_meta_test_\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        func appendLE16(_ v: UInt16, to buf: inout Data) {
            var le = v.littleEndian
            buf.append(Data(bytes: &le, count: 2))
        }
        func appendLE32(_ v: UInt32, to buf: inout Data) {
            var le = v.littleEndian
            buf.append(Data(bytes: &le, count: 4))
        }

        // 1. Legacy APE v3970 + APEv2 tag block -> exact 200.0s @ 44.1 kHz / 16-bit
        let apeURL = tempDir.appendingPathComponent("01-sample.ape")
        var apeData = Data("MAC ".utf8)
        appendLE16(3970, to: &apeData)       // version
        appendLE16(2000, to: &apeData)       // compression level
        appendLE16(0, to: &apeData)          // flags (16-bit)
        appendLE16(2, to: &apeData)          // channels
        appendLE32(44100, to: &apeData)      // sample rate
        appendLE32(0, to: &apeData)          // wavHeaderBytes
        appendLE32(0, to: &apeData)          // terminatingDataBytes
        appendLE32(30, to: &apeData)         // totalFrames (29 * 294912 + 267552 = 8820000 = 200s)
        appendLE32(267552, to: &apeData)     // finalFrameBlocks
        apeData.append(Data(repeating: 0, count: 16))

        var apeItemsData = Data()
        for (k, v) in [("Title", "爱在深秋"), ("Artist", "谭咏麟"), ("Album", "爱的根源")] {
            let valBytes = Data(v.utf8)
            appendLE32(UInt32(valBytes.count), to: &apeItemsData)
            appendLE32(0, to: &apeItemsData) // UTF-8 text item
            apeItemsData.append(Data(k.utf8))
            apeItemsData.append(0)
            apeItemsData.append(valBytes)
        }
        let apeTagSize = UInt32(apeItemsData.count + 32)
        // APEv2 Header
        apeData.append(Data("APETAGEX".utf8))
        appendLE32(2000, to: &apeData)
        appendLE32(apeTagSize, to: &apeData)
        appendLE32(3, to: &apeData)
        appendLE32(0xA000_0000, to: &apeData)
        apeData.append(Data(repeating: 0, count: 8))
        apeData.append(apeItemsData)
        // APEv2 Footer
        apeData.append(Data("APETAGEX".utf8))
        appendLE32(2000, to: &apeData)
        appendLE32(apeTagSize, to: &apeData)
        appendLE32(3, to: &apeData)
        appendLE32(0x8000_0000, to: &apeData)
        apeData.append(Data(repeating: 0, count: 8))
        try apeData.write(to: apeURL)

        // 2. MP3 (MPEG-1 Layer III Xing header + ID3v1 GB18030 TAG)
        let mp3URL = tempDir.appendingPathComponent("02-cost.mp3")
        var frame = Data(repeating: 0, count: 417)
        frame[0] = 0xFF
        frame[1] = 0xFB
        frame[2] = 0x90 // 128kbps, 44100Hz
        frame[3] = 0x00 // Stereo -> side info = 32B, Xing at 36
        frame.replaceSubrange(36..<40, with: Data("Xing".utf8))
        frame[40..<44].withUnsafeMutableBytes { ptr in
            var be = UInt32(1).bigEndian
            memcpy(ptr.baseAddress!, &be, 4)
        }
        frame[44..<48].withUnsafeMutableBytes { ptr in
            var be = UInt32(8250).bigEndian // 8250 * 1152 / 44100 = ~215.51s
            memcpy(ptr.baseAddress!, &be, 4)
        }
        var mp3Data = frame
        let gb18030 = String.Encoding(
            rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue))
        )
        func paddedField(_ text: String, count: Int) -> Data {
            var d = text.data(using: gb18030) ?? Data()
            if d.count > count { d = d.prefix(count) }
            if d.count < count { d.append(Data(repeating: 0, count: count - d.count)) }
            return d
        }
        mp3Data.append(Data("TAG".utf8))
        mp3Data.append(paddedField("爱的代价", count: 30))
        mp3Data.append(paddedField("张艾嘉", count: 30))
        mp3Data.append(paddedField("爱的代价专辑", count: 30))
        mp3Data.append(Data(repeating: 0, count: 35))
        try mp3Data.write(to: mp3URL)

        let cacheURL = tempDir.appendingPathComponent("cache_v2.json")
        let apeItem = PlaylistItem(path: apeURL.path, title: "01-sample", duration: 0)
        let mp3Item = PlaylistItem(path: mp3URL.path, title: "02-cost", duration: 0)

        let writerService = AudioTrackMetadataService(cacheURL: cacheURL)
        writerService.ensureLoaded(for: [apeItem, mp3Item], priorityPath: apeURL.path)

        for _ in 0..<40 {
            let aDone = (writerService.cache[apeURL.path]?.duration ?? 0) > 0
            let mDone = (writerService.cache[mp3URL.path]?.duration ?? 0) > 0
            if aDone && mDone { break }
            try await Task.sleep(nanoseconds: 25_000_000)
        }

        let apeMeta = writerService.metadata(for: apeItem)
        XCTAssertEqual(apeMeta.formatLabel, "APE")
        XCTAssertEqual(apeMeta.title, "爱在深秋")
        XCTAssertEqual(apeMeta.artist, "谭咏麟")
        XCTAssertEqual(apeMeta.album, "爱的根源")
        XCTAssertEqual(apeMeta.sampleRateHz, 44100)
        XCTAssertEqual(apeMeta.bitDepth, 16)
        XCTAssertEqual(apeMeta.duration ?? 0, 200.0, accuracy: 0.05)

        let mp3Meta = writerService.metadata(for: mp3Item)
        XCTAssertEqual(mp3Meta.formatLabel, "MP3")
        XCTAssertEqual(mp3Meta.title, "爱的代价")
        XCTAssertEqual(mp3Meta.artist, "张艾嘉")
        XCTAssertEqual(mp3Meta.album, "爱的代价专辑")
        XCTAssertEqual(mp3Meta.sampleRateHz, 44100)
        XCTAssertEqual(mp3Meta.duration ?? 0, 8250.0 * 1152.0 / 44100.0, accuracy: 0.2)

        // Wait for debounced disk persistence (650ms) and verify synchronous reload
        for _ in 0..<25 {
            if FileManager.default.fileExists(atPath: cacheURL.path) { break }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        let reloadedService = AudioTrackMetadataService(cacheURL: cacheURL)
        XCTAssertEqual(reloadedService.metadata(for: apeItem).title, "爱在深秋")
        XCTAssertEqual(reloadedService.metadata(for: mp3Item).title, "爱的代价")
        XCTAssertEqual(reloadedService.metadata(for: apeItem).duration ?? 0, 200.0, accuracy: 0.05)
    }

    // MARK: - 6. Duplicate Path Selection & Music Mode Volume HUD Suppression

    @MainActor
    func testDuplicatePathSelectionPreservesExactID() {
        let manager = PlaylistManager(isPersistenceEnabled: false, autoRestore: false)
        let first = PlaylistItem(path: "/music/吴克群 - 为你写诗.wav", title: "吴克群 - 为你写诗", duration: 285)
        let duplicate = PlaylistItem(path: "/music/吴克群 - 为你写诗.wav", title: "吴克群 - 为你写诗", duration: 285)

        manager.appendItems([first, duplicate])
        XCTAssertEqual(manager.audioItems.count, 2)

        // Selecting the second duplicate item must stay on index 1 instead of snapping to index 0
        let picked = manager.selectItemInCategory(duplicate, category: .audio)
        XCTAssertEqual(picked?.id, duplicate.id)
        XCTAssertEqual(manager.audioCurrentIndex, 1)
        XCTAssertEqual(manager.currentItem?.id, duplicate.id)
    }

    @MainActor
    func testAudioOnlySuppressesVerticalVolumeHUD() {
        let previousSavedVolume = AppSettings.shared.savedVolume
        defer { AppSettings.shared.savedVolume = previousSavedVolume }

        let player = PlayerCore()
        player.isAudioOnly = true

        player.setVolume(65.0, showOSD: true)
        XCTAssertFalse(player.isVolumeHUDVisible)

        player.toggleMute()
        XCTAssertFalse(player.isVolumeHUDVisible)

        player.showVolumeOSD()
        XCTAssertFalse(player.isVolumeHUDVisible)
    }

    func testCorruptQuestionMarkTagFilteringAndDoubleMojibakeRepair() {
        XCTAssertTrue(AudioTrackMetadataService.isCorruptPlaceholderTag("???"))
        XCTAssertTrue(AudioTrackMetadataService.isCorruptPlaceholderTag("??-??????"))
        XCTAssertTrue(AudioTrackMetadataService.isCorruptPlaceholderTag("????2:???"))
        XCTAssertTrue(AudioTrackMetadataService.isCorruptPlaceholderTag("???'s"))
        XCTAssertTrue(AudioTrackMetadataService.isCorruptPlaceholderTag("？？？"))

        XCTAssertFalse(AudioTrackMetadataService.isCorruptPlaceholderTag("Why?"))
        XCTAssertFalse(AudioTrackMetadataService.isCorruptPlaceholderTag("为什么?"))
        XCTAssertFalse(AudioTrackMetadataService.isCorruptPlaceholderTag("Mr. Question?"))

        XCTAssertEqual(AudioTrackMetadataService.sanitizeTagValue("???"), "")
        XCTAssertEqual(AudioTrackMetadataService.sanitizeTagValue("? ?"), "")
        XCTAssertEqual(AudioTrackMetadataService.sanitizeTagValue("Why?"), "Why?")
        XCTAssertEqual(AudioTrackMetadataService.sanitizeTagValue("Café Müller"), "Café Müller")

        // Single-pass UTF-8 -> Latin-1 mojibake
        let utf8Bytes = Data("大海".utf8)
        let onceMisdecoded = String(data: utf8Bytes, encoding: .isoLatin1)!
        XCTAssertEqual(AudioTrackMetadataService.repairMojibakeIfNeeded(onceMisdecoded), "大海")

        // Double-pass UTF-8 -> Latin-1 -> UTF-8 -> Latin-1 mojibake
        let twiceMisdecoded = String(data: Data(onceMisdecoded.utf8), encoding: .isoLatin1)!
        XCTAssertEqual(AudioTrackMetadataService.repairMojibakeIfNeeded(twiceMisdecoded), "大海")
    }

    func testWAVWithCorruptLISTInfoUsesEmbeddedID3v2Unicode() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("SilkMetaTest_\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let wavURL = dir.appendingPathComponent("unknown.wav")
        let id3ChunkPayload = makeID3v23Tag([
            ("TIT2", utf16LEFramePayload("大海")),
            ("TPE1", utf16LEFramePayload("张雨生")),
            ("TALB", utf16LEFramePayload("大海 (1992)"))
        ])
        let listInfoPayload = makeRIFFInfoPayload([
            ("INAM", "??"),
            ("IART", "???"),
            ("IPRD", "????")
        ])
        let wavData = makeSyntheticWAV(listInfoPayload: listInfoPayload, id3ChunkPayload: id3ChunkPayload)
        try wavData.write(to: wavURL)

        let item = PlaylistItem(path: wavURL.path, title: "unknown")
        let meta = await AudioTrackMetadataService.extractMetadataFromDisk(item: item)

        XCTAssertEqual(meta.title, "大海")
        XCTAssertEqual(meta.artist, "张雨生")
        XCTAssertEqual(meta.album, "大海 (1992)")
        XCTAssertEqual(meta.formatLabel, "WAV")
        XCTAssertEqual(meta.sampleRateHz, 44_100)
        XCTAssertEqual(meta.bitDepth, 16)
        XCTAssertEqual(meta.duration ?? 0, 1.0, accuracy: 0.02)
    }

    func testWAVWithOnlyQuestionMarkLISTInfoFallsBackToFilename() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("SilkMetaTest_\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let wavURL = dir.appendingPathComponent("梁咏琪 - 胆小鬼.wav")
        let listInfoPayload = makeRIFFInfoPayload([
            ("INAM", "???"),
            ("IART", "????"),
            ("IPRD", "???")
        ])
        let wavData = makeSyntheticWAV(listInfoPayload: listInfoPayload, id3ChunkPayload: nil)
        try wavData.write(to: wavURL)

        let item = PlaylistItem(path: wavURL.path, title: "梁咏琪 - 胆小鬼")
        let meta = await AudioTrackMetadataService.extractMetadataFromDisk(item: item)

        XCTAssertEqual(meta.artist, "梁咏琪")
        XCTAssertEqual(meta.title, "胆小鬼")
        XCTAssertEqual(meta.album, "")
        XCTAssertFalse(meta.title.contains("?"))
        XCTAssertFalse(meta.artist.contains("?"))
        XCTAssertEqual(meta.formatLabel, "WAV")
    }

    func testAIFFNativeHeaderAndID3Extraction() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("SilkMetaTest_\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let aiffURL = dir.appendingPathComponent("sample.aiff")
        var comm = Data()
        appendBE16(&comm, 2) // channels
        appendBE32(&comm, 44_100) // sampleFrames -> 1.0s
        appendBE16(&comm, 16) // sampleSize
        comm.append(contentsOf: [0x40, 0x0E, 0xAC, 0x44, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]) // 44100 Hz IEEE-80

        let id3Payload = makeID3v23Tag([
            ("TIT2", utf8FramePayload("风继续吹")),
            ("TPE1", utf8FramePayload("张国荣")),
            ("TALB", utf8FramePayload("Salute"))
        ])

        var chunks = Data()
        appendIFFChunk(&chunks, id: "COMM", payload: comm, bigEndian: true)
        appendIFFChunk(&chunks, id: "NAME", payload: Data("???".utf8), bigEndian: true)
        appendIFFChunk(&chunks, id: "ID3 ", payload: id3Payload, bigEndian: true)

        var form = Data("FORM".utf8)
        appendBE32(&form, UInt32(4 + chunks.count))
        form.append(contentsOf: "AIFF".utf8)
        form.append(chunks)
        try form.write(to: aiffURL)

        let item = PlaylistItem(path: aiffURL.path, title: "sample")
        let meta = await AudioTrackMetadataService.extractMetadataFromDisk(item: item)

        XCTAssertEqual(meta.title, "风继续吹")
        XCTAssertEqual(meta.artist, "张国荣")
        XCTAssertEqual(meta.album, "Salute")
        XCTAssertEqual(meta.formatLabel, "AIFF")
        XCTAssertEqual(meta.sampleRateHz, 44_100)
        XCTAssertEqual(meta.bitDepth, 16)
        XCTAssertEqual(meta.duration ?? 0, 1.0, accuracy: 0.02)
    }

    func testDSFNativeHeaderAndTrailingID3v2Extraction() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("SilkMetaTest_\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let dsfURL = dir.appendingPathComponent("track.dsf")
        let id3Payload = makeID3v23Tag([
            ("TIT2", utf8FramePayload("夜来香")),
            ("TPE1", utf8FramePayload("邓丽君")),
            ("TALB", utf8FramePayload("经典精选"))
        ])
        let metadataOffset: UInt64 = 28 + 52

        var dsd = Data("DSD ".utf8)
        appendLE64(&dsd, 28) // chunkSize
        appendLE64(&dsd, metadataOffset + UInt64(id3Payload.count))
        appendLE64(&dsd, metadataOffset)

        var fmt = Data("fmt ".utf8)
        appendLE64(&fmt, 52) // chunkSize
        appendLE32(&fmt, 1) // formatVersion
        appendLE32(&fmt, 0) // formatID
        appendLE32(&fmt, 2) // channelType
        appendLE32(&fmt, 2) // channelNum
        appendLE32(&fmt, 2_822_400) // sampleFreq (DSD64)
        appendLE32(&fmt, 1) // bitsPerSample
        appendLE64(&fmt, 5_644_800) // sampleCount -> 2.0s
        appendLE32(&fmt, 4096) // blockSizePerChannel
        appendLE32(&fmt, 0) // reserved

        var fileData = Data()
        fileData.append(dsd)
        fileData.append(fmt)
        fileData.append(id3Payload)
        try fileData.write(to: dsfURL)

        let item = PlaylistItem(path: dsfURL.path, title: "track")
        let meta = await AudioTrackMetadataService.extractMetadataFromDisk(item: item)

        XCTAssertEqual(meta.title, "夜来香")
        XCTAssertEqual(meta.artist, "邓丽君")
        XCTAssertEqual(meta.album, "经典精选")
        XCTAssertEqual(meta.formatLabel, "DSD")
        XCTAssertEqual(meta.sampleRateHz, 2_822_400)
        XCTAssertEqual(meta.bitDepth, 1)
        XCTAssertEqual(meta.duration ?? 0, 2.0, accuracy: 0.02)
    }

    @MainActor
    func testStopWithPreserveAudioModePreventsTransientChromeDrop() {
        let player = PlayerCore()
        player.isAudioOnly = true

        player.stop(resetUI: false, preserveAudioMode: true)
        XCTAssertTrue(player.isAudioOnly)

        player.stop(resetUI: true)
        XCTAssertFalse(player.isAudioOnly)
    }

    func testOggOpusHeaderAndVorbisCommentExtraction() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("SilkMetaTest_\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let opusURL = dir.appendingPathComponent("track.opus")

        var opusHead = Data("OpusHead".utf8)
        opusHead.append(1) // version
        opusHead.append(2) // channels
        appendLE16(&opusHead, 312) // pre-skip
        appendLE32(&opusHead, 48_000) // original sample rate
        appendLE16(&opusHead, 0) // output gain
        opusHead.append(0) // channel mapping family

        var opusTags = Data("OpusTags".utf8)
        let vendor = Data("libopus".utf8)
        appendLE32(&opusTags, UInt32(vendor.count))
        opusTags.append(vendor)
        let comments = ["TITLE=海阔天空", "ARTIST=Beyond", "ALBUM=乐与怒"]
        appendLE32(&opusTags, UInt32(comments.count))
        for comment in comments {
            let bytes = Data(comment.utf8)
            appendLE32(&opusTags, UInt32(bytes.count))
            opusTags.append(bytes)
        }

        var fileData = Data()
        fileData.append(makeOggPage(headerType: 0x02, granule: 0, seq: 0, payload: opusHead))
        fileData.append(makeOggPage(headerType: 0x00, granule: 0, seq: 1, payload: opusTags))
        fileData.append(makeOggPage(headerType: 0x04, granule: 48_312, seq: 2, payload: Data([0xFC, 0xFF, 0xFE])))
        try fileData.write(to: opusURL)

        let item = PlaylistItem(path: opusURL.path, title: "track")
        let meta = await AudioTrackMetadataService.extractMetadataFromDisk(item: item)

        XCTAssertEqual(meta.title, "海阔天空")
        XCTAssertEqual(meta.artist, "Beyond")
        XCTAssertEqual(meta.album, "乐与怒")
        XCTAssertEqual(meta.formatLabel, "OPUS")
        XCTAssertEqual(meta.sampleRateHz, 48_000)
        XCTAssertEqual(meta.duration ?? 0, 1.0, accuracy: 0.02)
    }

    @MainActor
    func testQueueManualSelectionScrollSuppressionAcrossCrossfadeAndNavigation() {
        let clickedID = UUID()
        let nextTrackID = UUID()
        let now = Date()
        let deadline = now.addingTimeInterval(3.5)

        // During crossfade or after file load completes, playlist.currentItem matches clickedID -> stay suppressed
        XCTAssertTrue(
            MusicModeView.shouldSuppressAutoScroll(
                suppressedID: clickedID,
                deadline: deadline,
                selectedID: clickedID,
                now: now.addingTimeInterval(0.05)
            )
        )
        XCTAssertTrue(
            MusicModeView.shouldSuppressAutoScroll(
                suppressedID: clickedID,
                deadline: deadline,
                selectedID: clickedID,
                now: now.addingTimeInterval(1.0)
            )
        )

        // Subsequent Next/Prev/EOF selecting a different track must immediately allow auto-scroll
        XCTAssertFalse(
            MusicModeView.shouldSuppressAutoScroll(
                suppressedID: clickedID,
                deadline: deadline,
                selectedID: nextTrackID,
                now: now.addingTimeInterval(0.2)
            )
        )

        // Once suppression deadline expires or ID cleared, auto-scroll is active again
        XCTAssertFalse(
            MusicModeView.shouldSuppressAutoScroll(
                suppressedID: clickedID,
                deadline: deadline,
                selectedID: clickedID,
                now: now.addingTimeInterval(4.0)
            )
        )
        XCTAssertFalse(
            MusicModeView.shouldSuppressAutoScroll(
                suppressedID: nil,
                deadline: deadline,
                selectedID: clickedID,
                now: now
            )
        )
    }

    // MARK: - Binary Fixture Helpers

    private func makeOggPage(headerType: UInt8, granule: UInt64, seq: UInt32, payload: Data) -> Data {
        precondition(payload.count < 255)
        var page = Data("OggS".utf8)
        page.append(0) // stream structure version
        page.append(headerType)
        appendLE64(&page, granule)
        appendLE32(&page, 1) // serial
        appendLE32(&page, seq)
        appendLE32(&page, 0) // CRC placeholder
        page.append(1) // page segments
        page.append(UInt8(payload.count))
        page.append(payload)
        return page
    }

    private func makeSyntheticWAV(listInfoPayload: Data, id3ChunkPayload: Data?) -> Data {
        var fmt = Data()
        appendLE16(&fmt, 1) // PCM
        appendLE16(&fmt, 2) // channels
        appendLE32(&fmt, 44_100) // sampleRate
        appendLE32(&fmt, 176_400) // byteRate
        appendLE16(&fmt, 4) // blockAlign
        appendLE16(&fmt, 16) // bitsPerSample

        var body = Data()
        appendIFFChunk(&body, id: "fmt ", payload: fmt, bigEndian: false)
        appendIFFChunk(&body, id: "LIST", payload: listInfoPayload, bigEndian: false)
        appendIFFChunk(&body, id: "data", payload: Data(repeating: 0, count: 176_400), bigEndian: false)
        if let id3ChunkPayload {
            appendIFFChunk(&body, id: "id3 ", payload: id3ChunkPayload, bigEndian: false)
        }

        var riff = Data("RIFF".utf8)
        appendLE32(&riff, UInt32(4 + body.count))
        riff.append(contentsOf: "WAVE".utf8)
        riff.append(body)
        return riff
    }

    private func makeRIFFInfoPayload(_ entries: [(String, String)]) -> Data {
        var data = Data("INFO".utf8)
        for (key, value) in entries {
            var bytes = Data(value.utf8)
            bytes.append(0)
            appendIFFChunk(&data, id: key, payload: bytes, bigEndian: false)
        }
        return data
    }

    private func makeID3v23Tag(_ frames: [(String, Data)]) -> Data {
        var body = Data()
        for (id, payload) in frames {
            body.append(contentsOf: id.utf8.prefix(4))
            appendBE32(&body, UInt32(payload.count))
            body.append(contentsOf: [0, 0]) // flags
            body.append(payload)
        }
        let sz = UInt32(body.count)
        var tag = Data([
            0x49, 0x44, 0x33, 0x03, 0x00, 0x00,
            UInt8((sz >> 21) & 0x7F),
            UInt8((sz >> 14) & 0x7F),
            UInt8((sz >> 7) & 0x7F),
            UInt8(sz & 0x7F)
        ])
        tag.append(body)
        return tag
    }

    private func utf16LEFramePayload(_ text: String) -> Data {
        var data = Data([0x01, 0xFF, 0xFE])
        if let encoded = text.data(using: .utf16LittleEndian) {
            data.append(encoded)
        }
        data.append(contentsOf: [0x00, 0x00])
        return data
    }

    private func utf8FramePayload(_ text: String) -> Data {
        var data = Data([0x03])
        data.append(contentsOf: text.utf8)
        return data
    }

    private func appendIFFChunk(_ buffer: inout Data, id: String, payload: Data, bigEndian: Bool) {
        buffer.append(contentsOf: id.utf8.prefix(4))
        if bigEndian {
            appendBE32(&buffer, UInt32(payload.count))
        } else {
            appendLE32(&buffer, UInt32(payload.count))
        }
        buffer.append(payload)
        if (payload.count & 1) == 1 {
            buffer.append(0)
        }
    }

    private func appendLE16(_ buffer: inout Data, _ v: UInt16) {
        buffer.append(UInt8(v & 0xFF))
        buffer.append(UInt8((v >> 8) & 0xFF))
    }

    private func appendLE32(_ buffer: inout Data, _ v: UInt32) {
        buffer.append(UInt8(v & 0xFF))
        buffer.append(UInt8((v >> 8) & 0xFF))
        buffer.append(UInt8((v >> 16) & 0xFF))
        buffer.append(UInt8((v >> 24) & 0xFF))
    }

    private func appendLE64(_ buffer: inout Data, _ v: UInt64) {
        appendLE32(&buffer, UInt32(v & 0xFFFF_FFFF))
        appendLE32(&buffer, UInt32((v >> 32) & 0xFFFF_FFFF))
    }

    private func appendBE16(_ buffer: inout Data, _ v: UInt16) {
        buffer.append(UInt8((v >> 8) & 0xFF))
        buffer.append(UInt8(v & 0xFF))
    }

    private func appendBE32(_ buffer: inout Data, _ v: UInt32) {
        buffer.append(UInt8((v >> 24) & 0xFF))
        buffer.append(UInt8((v >> 16) & 0xFF))
        buffer.append(UInt8((v >> 8) & 0xFF))
        buffer.append(UInt8(v & 0xFF))
    }
}
