import XCTest
import AppKit
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
}
