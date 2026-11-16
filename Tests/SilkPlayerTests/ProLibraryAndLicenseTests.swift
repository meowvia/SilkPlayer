import XCTest
import Foundation
import CryptoKit
import SilkCoreKit
@testable import SilkPlayer

@MainActor
final class ProLibraryAndLicenseTests: XCTestCase {

    private var tempDirectories: [URL] = []

    override func tearDown() async throws {
        for dir in tempDirectories {
            try? FileManager.default.removeItem(at: dir)
        }
        tempDirectories.removeAll()
    }

    private func makeTempDir() throws -> URL {
        let raw = FileManager.default.temporaryDirectory
            .appendingPathComponent("SilkProTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: raw, withIntermediateDirectories: true)
        let dir = raw.standardizedFileURL.resolvingSymlinksInPath()
        tempDirectories.append(dir)
        return dir
    }

    private var isCIMockEnvironment: Bool {
        ProcessInfo.processInfo.environment["GITHUB_ACTIONS"] == "true"
    }

    private func base64URLEncode(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private func signTestReceipt(
        privateKey: Curve25519.Signing.PrivateKey,
        hardwareId: String,
        expiresAt: TimeInterval? = nil,
        keyId: String = "key_test_01"
    ) throws -> String {
        struct Payload: Encodable {
            let v: Int
            let keyId: String
            let mask: String
            let plan: String
            let maxDevices: Int
            let deviceCount: Int
            let hw: String
            let iat: Double
            let exp: Double?
        }

        let payload = Payload(
            v: 1,
            keyId: keyId,
            mask: "SILK-****-TEST",
            plan: "SilkPlayer Pro",
            maxDevices: 3,
            deviceCount: 1,
            hw: hardwareId,
            iat: Date().timeIntervalSince1970,
            exp: expiresAt
        )
        let payloadData = try JSONEncoder().encode(payload)
        let signature = try privateKey.signature(for: payloadData)
        return "SILK1.\(base64URLEncode(payloadData)).\(base64URLEncode(signature))"
    }

    // MARK: - 1. Asymmetric Ed25519 License Verification Tests

    func testEd25519LicenseVerificationAcceptanceAndRejections() async throws {
        guard !isCIMockEnvironment else { return }

        let privateKey = Curve25519.Signing.PrivateKey()
        let pubBase64 = privateKey.publicKey.rawRepresentation.base64EncodedString()

        let engine = SilkProLicenseEngine(
            publicKeyBase64: pubBase64,
            endpointBase: "https://example.invalid",
            hardwareId: "hw-mac-alpha",
            usePersistentStorage: false
        )

        // Default purchase URL must be empty / nil until store is published
        XCTAssertNil(engine.purchaseURL)
        XCTAssertFalse(engine.isProActive)

        // 1. Valid hardware-bound Ed25519 receipt activates Pro cleanly
        let validToken = try signTestReceipt(privateKey: privateKey, hardwareId: "hw-mac-alpha")
        let outcome = await engine.activate(licenseKey: validToken)
        if case .success(let receipt) = outcome {
            XCTAssertEqual(receipt.keyId, "key_test_01")
            XCTAssertEqual(receipt.hardwareId, "hw-mac-alpha")
            XCTAssertTrue(engine.isProActive)
        } else {
            XCTFail("Expected valid Ed25519 token to succeed, got \(outcome)")
        }

        // 2. Deactivate restores unlicensed state
        await engine.deactivate()
        XCTAssertFalse(engine.isProActive)
        XCTAssertNil(engine.activeReceipt)

        // 3. Tampered payload fails cryptographic signature verification
        let segments = validToken.split(separator: ".").map(String.init)
        var flipped = segments[1]
        let replacementChar: Character = (flipped.first == "A") ? "B" : "A"
        flipped.replaceSubrange(flipped.startIndex...flipped.startIndex, with: String(replacementChar))
        let tamperedToken = "SILK1.\(flipped).\(segments[2])"
        let tamperedVerify = engine.verifySignedToken(tamperedToken)
        XCTAssertEqual(tamperedVerify, .failure(.invalidSignature))

        // 4. Hardware mismatch rejection
        let otherMacToken = try signTestReceipt(privateKey: privateKey, hardwareId: "hw-mac-other")
        XCTAssertEqual(engine.verifySignedToken(otherMacToken), .failure(.hardwareMismatch))

        // 5. Expired token rejection
        let expiredToken = try signTestReceipt(
            privateKey: privateKey,
            hardwareId: "hw-mac-alpha",
            expiresAt: Date().timeIntervalSince1970 - 60
        )
        XCTAssertEqual(engine.verifySignedToken(expiredToken), .failure(.expired))

        // 6. Configurable checkout URL parsing (enforces HTTPS)
        engine.purchaseURLString = "http://insecure.1999909.xyz/buy/silkplayer-pro"
        XCTAssertNil(engine.purchaseURL, "Non-HTTPS URL must be rejected")
        engine.purchaseURLString = "https://checkout.1999909.xyz/buy/silkplayer-pro"
        XCTAssertEqual(engine.purchaseURL?.absoluteString, "https://checkout.1999909.xyz/buy/silkplayer-pro")
    }

    // MARK: - 2. SQLite + FTS5 Stat-Only Indexing, Audio/Video Split, Pinyin Search & Watch Memory

    func testMediaLibraryIndexingSeparationPinyinAndWatchMemoryPersistence() async throws {
        guard !isCIMockEnvironment else { return }

        let root = try makeTempDir()
        let dbURL = root.appendingPathComponent("test_library.sqlite")
        let mediaRoot = root.appendingPathComponent("MediaRoot", isDirectory: true)

        let moviesDir = mediaRoot.appendingPathComponent("Movies", isDirectory: true)
        let seriesDir = mediaRoot.appendingPathComponent("Series/Three Body/Season 01", isDirectory: true)
        let audioDir = mediaRoot.appendingPathComponent("Music/Jay Chou/Fantasy", isDirectory: true)
        try FileManager.default.createDirectory(at: moviesDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: seriesDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: audioDir, withIntermediateDirectories: true)

        let movieFile = moviesDir.appendingPathComponent("流浪地球2.2023.2160p.WEB-DL.HEVC.Atmos.mkv")
        let moviePoster = moviesDir.appendingPathComponent("poster.jpg")
        let ep1File = seriesDir.appendingPathComponent("Three.Body.S01E01.1080p.x265.mp4")
        let ep2File = seriesDir.appendingPathComponent("Three.Body.S01E02.1080p.x265.mp4")
        let track1File = audioDir.appendingPathComponent("01 - 爱在西元前.flac")
        let track2File = audioDir.appendingPathComponent("02 - 简单爱.flac")
        let albumCover = audioDir.appendingPathComponent("cover.jpg")

        for f in [movieFile, moviePoster, ep1File, ep2File, track1File, track2File, albumCover] {
            try Data("dummy-media-bytes".utf8).write(to: f)
        }

        let engine = SilkMediaLibraryEngine(databaseURL: dbURL, usePersistentBookmarkStorage: false)
        let added = await engine.addLocalSource(url: mediaRoot, displayName: "TestNAS")
        XCTAssertNotNil(added)
        XCTAssertEqual(engine.sources.count, 1)
        XCTAssertEqual(engine.items.count, 5)

        // Verify automatic Movie / Series / Audio classification
        let movies = engine.items.filter { $0.kind == .movie }
        let episodes = engine.items.filter { $0.kind == .seriesEpisode }
        let tracks = engine.items.filter { $0.kind == .audio }
        XCTAssertEqual(movies.count, 1)
        XCTAssertEqual(episodes.count, 2)
        XCTAssertEqual(tracks.count, 2)

        let movie = try XCTUnwrap(movies.first)
        XCTAssertEqual(movie.resolutionTag, "4K")
        XCTAssertEqual(movie.videoCodecTag, "HEVC")
        XCTAssertEqual(movie.audioSpecTag, "Atmos")
        XCTAssertEqual(movie.posterPath, moviePoster.path)

        let ep1 = try XCTUnwrap(episodes.first(where: { $0.episodeNumber == 1 }))
        XCTAssertEqual(ep1.seasonNumber, 1)
        XCTAssertEqual(ep1.seriesName, "Three Body")

        let track2 = try XCTUnwrap(tracks.first(where: { $0.trackNumber == 2 }))
        XCTAssertEqual(track2.albumName, "Fantasy")
        XCTAssertEqual(track2.artistName, "Jay Chou")
        XCTAssertEqual(track2.audioSpecTag, "FLAC")
        XCTAssertEqual(track2.posterPath, albumCover.path)

        // Verify FTS5 + Pinyin & Initials Instant Search
        let pinyinMatches = await engine.search(query: "lldq")
        XCTAssertEqual(pinyinMatches.map(\.path), [movieFile.path])

        let audioMatches = await engine.search(query: "jiandan")
        XCTAssertEqual(audioMatches.map(\.path), [track2File.path])

        let codecMatches = await engine.search(query: "Atmos")
        XCTAssertEqual(codecMatches.map(\.path), [movieFile.path])

        // Verify Watch Memory transitions & persistence across incremental re-scan
        await engine.recordPlaybackProgress(path: ep1File.path, position: 620, duration: 2400)
        let afterProgress = engine.items.first(where: { $0.path == ep1File.path })
        XCTAssertEqual(afterProgress?.watchState, .inProgress)
        XCTAssertEqual(afterProgress?.positionSeconds ?? 0, 620, accuracy: 0.1)

        // Add episode 3 and remove episode 2, then rescan
        let ep3File = seriesDir.appendingPathComponent("Three.Body.S01E03.1080p.x265.mp4")
        try Data("ep3".utf8).write(to: ep3File)
        try FileManager.default.removeItem(at: ep2File)
        await engine.rescanAll()

        XCTAssertEqual(engine.items.count, 5)
        XCTAssertNil(engine.items.first(where: { $0.path == ep2File.path }))
        XCTAssertNotNil(engine.items.first(where: { $0.path == ep3File.path }))

        let preservedEp1 = try XCTUnwrap(engine.items.first(where: { $0.path == ep1File.path }))
        XCTAssertEqual(preservedEp1.watchState, .inProgress)
        XCTAssertEqual(preservedEp1.positionSeconds, 620, accuracy: 0.1)

        // Reaching near end transitions cleanly to .watched
        await engine.recordPlaybackProgress(path: ep1File.path, position: 2395, duration: 2400)
        let watchedEp1 = try XCTUnwrap(engine.items.first(where: { $0.path == ep1File.path }))
        XCTAssertEqual(watchedEp1.watchState, .watched)
        XCTAssertEqual(watchedEp1.positionSeconds, 0, accuracy: 0.1)

        // Reopen fresh engine instance pointing to same SQLite file to verify durable disk persistence
        let reloadedEngine = SilkMediaLibraryEngine(databaseURL: dbURL, usePersistentBookmarkStorage: false)
        await reloadedEngine.loadFromDatabase()
        XCTAssertEqual(reloadedEngine.items.count, 5)
        XCTAssertEqual(reloadedEngine.items.first(where: { $0.path == ep1File.path })?.watchState, .watched)
    }

    // MARK: - 3. AppSettings Pro Toggles & Window Integration Tests

    func testProSettingsTogglesAndInitialTabRouting() {
        let settings = AppSettings.shared
        let prevHome = settings.proLibraryHomeEnabled
        let prevHideDrawer = settings.proHideLegacyPlaylistDrawer
        let prevDedicatedAudio = settings.proDedicatedAudioLibrary
        let prevAutoScan = settings.proAutoScanOnLaunch

        defer {
            settings.proLibraryHomeEnabled = prevHome
            settings.proHideLegacyPlaylistDrawer = prevHideDrawer
            settings.proDedicatedAudioLibrary = prevDedicatedAudio
            settings.proAutoScanOnLaunch = prevAutoScan
            settings.requestedSettingsTab = nil
            PlayerWindowManager.shared.closeSettings()
        }

        settings.proLibraryHomeEnabled = false
        XCTAssertFalse(settings.proLibraryHomeEnabled)
        settings.proHideLegacyPlaylistDrawer = false
        XCTAssertFalse(settings.proHideLegacyPlaylistDrawer)
        settings.proDedicatedAudioLibrary = false
        XCTAssertFalse(settings.proDedicatedAudioLibrary)
        settings.proAutoScanOnLaunch = false
        XCTAssertFalse(settings.proAutoScanOnLaunch)

        PlayerWindowManager.shared.openSettings(initialTab: 2)
        XCTAssertEqual(settings.requestedSettingsTab, 2)
        if let win = PlayerWindowManager.shared.settingsWindow {
            XCTAssertEqual(win.minSize.width, 520, accuracy: 0.5)
            XCTAssertEqual(win.minSize.height, 490, accuracy: 0.5)
        }
    }

    func testAppearanceAndThemeSeparationAndUnifiedDriving() {
        let settings = AppSettings.shared
        let origMode = settings.appearanceMode
        let origTheme = settings.proLibraryTheme

        defer {
            settings.appearanceMode = origMode
            settings.proLibraryTheme = origTheme
            settings.applyAppearance()
        }

        // 1. When Pro is inactive: appearanceMode directly dictates effectiveScheme & effectiveAppearance
        if !SilkProLicenseEngine.shared.isProActive {
            settings.appearanceMode = .light
            XCTAssertEqual(settings.effectiveColorScheme, .light)
            XCTAssertEqual(settings.effectiveNSAppearance, NSAppearance(named: .aqua))

            settings.appearanceMode = .dark
            XCTAssertEqual(settings.effectiveColorScheme, .dark)
            XCTAssertEqual(settings.effectiveNSAppearance, NSAppearance(named: .darkAqua))

            settings.appearanceMode = .system
            XCTAssertNil(settings.effectiveColorScheme)
            XCTAssertNil(settings.effectiveNSAppearance)
        }

        // 2. Pro Theme property validation and persistence
        settings.proLibraryTheme = .nuanbai
        XCTAssertEqual(settings.proLibraryTheme, .nuanbai)
        XCTAssertTrue(settings.proLibraryTheme.isLight)

        settings.proLibraryTheme = .shenghui
        XCTAssertEqual(settings.proLibraryTheme, .shenghui)
        XCTAssertFalse(settings.proLibraryTheme.isLight)

        settings.proLibraryTheme = .iceBlue
        XCTAssertEqual(settings.proLibraryTheme, .iceBlue)
        XCTAssertFalse(settings.proLibraryTheme.isLight)

        settings.proLibraryTheme = .qingci
        XCTAssertEqual(settings.proLibraryTheme, .qingci)
        XCTAssertTrue(settings.proLibraryTheme.isLight)
    }

    // MARK: - 4. SMB Input Parsing & Share Enumeration Tests

    func testSMBInputParsingAndSmbutilShareParsing() {
        guard !isCIMockEnvironment else { return }

        let fullURL = SilkSMBMountService.parseSMBInput("smb://root:s3cr3t@192.168.100.234/HDD1T")
        XCTAssertEqual(fullURL.host, "192.168.100.234")
        XCTAssertEqual(fullURL.share, "HDD1T")
        XCTAssertEqual(fullURL.username, "root")
        XCTAssertEqual(fullURL.password, "s3cr3t")

        let hostOnly = SilkSMBMountService.parseSMBInput("smb://192.168.100.234")
        XCTAssertEqual(hostOnly.host, "192.168.100.234")
        XCTAssertNil(hostOnly.share)
        XCTAssertNil(hostOnly.username)
        XCTAssertNil(hostOnly.password)

        let hostAndShare = SilkSMBMountService.parseSMBInput("192.168.100.234/Cloud")
        XCTAssertEqual(hostAndShare.host, "192.168.100.234")
        XCTAssertEqual(hostAndShare.share, "Cloud")

        let sampleSmbutilOutput = """
        Share                                           Type       Comments
        -------------------------------------------------------------------------------
        Cloud                                           Disk      CloudDrive2
        HDD2T                                           Disk      2TB Media
        HDD1T                                           Disk      1TB Media
        IPC$                                            Pipe      IPC Service (Samba)

        4 shares listed
        """
        let shares = SilkSMBMountService.parseSmbutilViewOutput(sampleSmbutilOutput)
        XCTAssertEqual(shares.map(\.name), ["Cloud", "HDD2T", "HDD1T"])
        XCTAssertFalse(shares.contains(where: { $0.name == "IPC$" }))
    }

    // MARK: - 5. Interactive Tree Folder Whitelist/Blacklist & Lazy Listing Tests

    func testFolderSelectionTreeRulesAndExports() {
        guard !isCIMockEnvironment else { return }
        var rule = SilkFolderSelectionRule(emptyUnselected: true)
        XCTAssertFalse(rule.isActive)
        XCTAssertEqual(rule.state(for: ""), .unchecked)

        // Check only two specific subfolders (whitelist mode)
        rule.toggle("Movies")
        rule.toggle("Anime")
        XCTAssertTrue(rule.isActive)
        XCTAssertEqual(rule.state(for: ""), .mixed)
        XCTAssertEqual(rule.state(for: "Movies"), .checked)
        XCTAssertEqual(rule.state(for: "Private"), .unchecked)
        XCTAssertEqual(rule.exportedIncludedRelativePaths, ["Anime", "Movies"])
        XCTAssertEqual(rule.exportedExcludedRelativePaths, [])

        // Toggle whole root -> becomes checked (no partial exclusions)
        rule.toggle("")
        XCTAssertEqual(rule.state(for: ""), .checked)
        XCTAssertEqual(rule.exportedIncludedRelativePaths, [])
        XCTAssertEqual(rule.exportedExcludedRelativePaths, [])

        // Exclude sensitive folder while keeping root checked
        rule.toggle("Private")
        XCTAssertEqual(rule.state(for: ""), .mixed)
        XCTAssertEqual(rule.state(for: "Private"), .unchecked)
        XCTAssertEqual(rule.state(for: "Movies"), .checked)
        XCTAssertEqual(rule.exportedIncludedRelativePaths, [])
        XCTAssertEqual(rule.exportedExcludedRelativePaths, ["Private"])

        // Re-include one subfolder nested inside excluded folder
        rule.toggle("Private/TravelVideos")
        XCTAssertEqual(rule.state(for: "Private"), .mixed)
        XCTAssertEqual(rule.state(for: "Private/Docs"), .unchecked)
        XCTAssertEqual(rule.state(for: "Private/TravelVideos"), .checked)
        XCTAssertEqual(rule.exportedIncludedRelativePaths, [".", "Private/TravelVideos"])
        XCTAssertEqual(rule.exportedExcludedRelativePaths, ["Private"])
    }

    func testFolderWhitelistBlacklistScanningAndInstantPrune() async throws {
        guard !isCIMockEnvironment else { return }

        let tempDir = try makeTempDir()
        let dbURL = tempDir.appendingPathComponent("tree_filter.sqlite")
        let rootDir = tempDir.appendingPathComponent("NASShare", isDirectory: true)
        let moviesDir = rootDir.appendingPathComponent("Movies", isDirectory: true)
        let privateDir = rootDir.appendingPathComponent("Private", isDirectory: true)
        let travelDir = privateDir.appendingPathComponent("TravelVideos", isDirectory: true)
        let workDir = rootDir.appendingPathComponent("Work", isDirectory: true)
        let eaDir = rootDir.appendingPathComponent("@eaDir", isDirectory: true)
        let recycleDir = rootDir.appendingPathComponent("#recycle", isDirectory: true)

        for dir in [moviesDir, travelDir, workDir, eaDir, recycleDir] {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }

        let publicMovie = moviesDir.appendingPathComponent("Dune.2021.2160p.mkv")
        let secretClip = privateDir.appendingPathComponent("SecretClip.mp4")
        let tripVideo = travelDir.appendingPathComponent("Trip2025.mkv")
        let workDemo = workDir.appendingPathComponent("MeetingDemo.mp4")
        let eaThumb = eaDir.appendingPathComponent("SYNOINDEX.mp4")
        let deleted = recycleDir.appendingPathComponent("Trash.mkv")
        for f in [publicMovie, secretClip, tripVideo, workDemo, eaThumb, deleted] {
            try Data("m".utf8).write(to: f)
        }

        // Lazy 1-level listing ignores NAS junk directories and does not descend recursively
        let topDirs = SilkSMBMountService.listImmediateSubfolders(rootPath: rootDir.path)
        XCTAssertEqual(topDirs.map(\.name), ["Movies", "Private", "Work"])

        let engine = SilkMediaLibraryEngine(databaseURL: dbURL, usePersistentBookmarkStorage: false)
        let addedOpt = await engine.addLocalSource(
            url: rootDir,
            displayName: "FilteredNAS",
            includedRelativePaths: ["Movies"],
            excludedRelativePaths: []
        )
        let added = try XCTUnwrap(addedOpt)
        XCTAssertEqual(engine.items.map(\.fileName), ["Dune.2021.2160p.mkv"])

        // Switch to root scan minus Private/Work, keeping Private/TravelVideos re-included
        await engine.updateSourceFolderFilters(
            id: added.id,
            includedRelativePaths: [".", "Private/TravelVideos"],
            excludedRelativePaths: ["Private", "Work"],
            rescan: false
        )
        await engine.rescanSource(id: added.id)
        XCTAssertEqual(Set(engine.items.map(\.fileName)), ["Dune.2021.2160p.mkv", "Trip2025.mkv"])

        // Updating filter immediately prunes excluded items without requiring a rescan
        await engine.updateSourceFolderFilters(
            id: added.id,
            includedRelativePaths: ["Movies"],
            excludedRelativePaths: [],
            rescan: false
        )
        XCTAssertEqual(engine.items.map(\.fileName), ["Dune.2021.2160p.mkv"])
        XCTAssertEqual(engine.sources.first?.itemCount, 1)
    }

    // MARK: - 6. NFS Parsing & Folder-First Movie/Series Separation Tests

    func testNFSInputAndShowmountParsing() {
        guard !isCIMockEnvironment else { return }

        let nfsURL = SilkSMBMountService.parseNetworkInput("nfs://192.168.100.234/mnt/hdd1t/media")
        XCTAssertEqual(nfsURL.shareProtocol, .nfs)
        XCTAssertEqual(nfsURL.host, "192.168.100.234")
        XCTAssertEqual(nfsURL.share, "/mnt/hdd1t/media")

        let showmountSample = """
        Exports list on 192.168.100.234:
        /mnt/hdd1t                          192.168.100.0/24
        /mnt/hdd2t                          Everyone
        """
        let exports = SilkSMBMountService.parseShowmountOutput(showmountSample)
        XCTAssertEqual(exports.map(\.name), ["/mnt/hdd1t", "/mnt/hdd2t"])
    }

    func testFolderFirstNamingForMoviesAndSeries() async throws {
        guard !isCIMockEnvironment else { return }

        let tempDir = try makeTempDir()
        let dbURL = tempDir.appendingPathComponent("folder_first.sqlite")
        let rootDir = tempDir.appendingPathComponent("LANRoot", isDirectory: true)

        let singleMovieFolder = rootDir.appendingPathComponent("Inception (2010)", isDirectory: true)
        let collectionFolder = rootDir.appendingPathComponent("Movies", isDirectory: true)
        let seriesSeasonFolder = rootDir.appendingPathComponent("三体 (2023)/Season 01", isDirectory: true)

        for dir in [singleMovieFolder, collectionFolder, seriesSeasonFolder] {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }

        let singleMovieFile = singleMovieFolder.appendingPathComponent("bdr_remux_2160p_x265_dts.mkv")
        let multiMovieA = collectionFolder.appendingPathComponent("Dune.Part.Two.2024.2160p.WEB-DL.mkv")
        let multiMovieB = collectionFolder.appendingPathComponent("Oppenheimer.2023.1080p.x264.mkv")
        let ep1 = seriesSeasonFolder.appendingPathComponent("01.mkv")
        let ep2 = seriesSeasonFolder.appendingPathComponent("02.mkv")

        for f in [singleMovieFile, multiMovieA, multiMovieB, ep1, ep2] {
            try Data("video".utf8).write(to: f)
        }

        let engine = SilkMediaLibraryEngine(databaseURL: dbURL, usePersistentBookmarkStorage: false)
        let added = await engine.addLocalSource(url: rootDir, displayName: "LAN")
        XCTAssertNotNil(added)

        let singleMovie = try XCTUnwrap(engine.items.first(where: { $0.path == singleMovieFile.path }))
        XCTAssertEqual(singleMovie.kind, .movie)
        XCTAssertEqual(singleMovie.title, "Inception (2010)")

        let movieA = try XCTUnwrap(engine.items.first(where: { $0.path == multiMovieA.path }))
        XCTAssertEqual(movieA.kind, .movie)
        XCTAssertEqual(movieA.title, "Dune Part Two 2024")

        let movieB = try XCTUnwrap(engine.items.first(where: { $0.path == multiMovieB.path }))
        XCTAssertEqual(movieB.kind, .movie)
        XCTAssertEqual(movieB.title, "Oppenheimer 2023")

        let seriesEp1 = try XCTUnwrap(engine.items.first(where: { $0.path == ep1.path }))
        XCTAssertEqual(seriesEp1.kind, .seriesEpisode)
        XCTAssertEqual(seriesEp1.seriesName, "三体 (2023)")
        XCTAssertEqual(seriesEp1.seasonNumber, 1)
        XCTAssertEqual(seriesEp1.episodeNumber, 1)

        let seriesEp2 = try XCTUnwrap(engine.items.first(where: { $0.path == ep2.path }))
        XCTAssertEqual(seriesEp2.kind, .seriesEpisode)
        XCTAssertEqual(seriesEp2.seriesName, "三体 (2023)")
        XCTAssertEqual(seriesEp2.seasonNumber, 1)
        XCTAssertEqual(seriesEp2.episodeNumber, 2)
    }

    func testAdNoiseStrippingAndSeriesFolderMerge() async throws {
        guard !isCIMockEnvironment else { return }

        XCTAssertEqual(SilkLibraryTheme.allCases.map(\.displayName).count, 4)
        XCTAssertTrue(SilkLibraryTheme.allCases.contains(.shenghui))
        XCTAssertTrue(SilkLibraryTheme.allCases.contains(.iceBlue))
        XCTAssertTrue(SilkLibraryTheme.allCases.contains(.nuanbai))
        XCTAssertTrue(SilkLibraryTheme.allCases.contains(.qingci))

        let tempDir = try makeTempDir()
        let dbURL = tempDir.appendingPathComponent("noise_merge.sqlite")
        let rootDir = tempDir.appendingPathComponent("MediaRoot", isDirectory: true)

        let wedAdFolder = rootDir.appendingPathComponent("【高清剧集网发布 www.TTHDTT.com】星期三 第二季 Wednesday S02 2022 NF DDP5 1 H 265-ColorTV", isDirectory: true)
        let wedCleanFolder = rootDir.appendingPathComponent("星期三 第二季", isDirectory: true)
        let moviesDir = rootDir.appendingPathComponent("电影", isDirectory: true)

        for dir in [wedAdFolder, wedCleanFolder, moviesDir] {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }

        let wedEp1 = wedAdFolder.appendingPathComponent("S02E05.【高清剧集网发布 www.TTHDTT.com】星期三 第二季 Wednesday S02 2022 NF DDP5 1 H 265-ColorTV.mkv")
        let wedEp2 = wedCleanFolder.appendingPathComponent("S02E01.mkv")
        let moviePromo = moviesDir.appendingPathComponent("wp.6v电影.地址发布页.www.6v123.net.收藏不迷路.4K.mkv")
        let movieHan = moviesDir.appendingPathComponent("哈尔滨.韩语中字.1080p.mp4")
        let movieTech = moviesDir.appendingPathComponent("zl2.iT.H.265.DDP5.1.WEB.mkv")

        for f in [wedEp1, wedEp2, moviePromo, movieHan, movieTech] {
            try Data("video".utf8).write(to: f)
        }

        let engine = SilkMediaLibraryEngine(databaseURL: dbURL, usePersistentBookmarkStorage: false)
        _ = await engine.addLocalSource(url: rootDir, displayName: "LAN")

        let ep1Item = try XCTUnwrap(engine.items.first(where: { $0.path == wedEp1.path }))
        let ep2Item = try XCTUnwrap(engine.items.first(where: { $0.path == wedEp2.path }))
        XCTAssertEqual(ep1Item.seriesName, "星期三")
        XCTAssertEqual(ep1Item.seriesName, ep2Item.seriesName)
        XCTAssertEqual(ep1Item.seasonNumber, 2)
        XCTAssertEqual(ep2Item.seasonNumber, 2)

        let promoItem = try XCTUnwrap(engine.items.first(where: { $0.path == moviePromo.path }))
        XCTAssertEqual(promoItem.title, "wp")

        let hanItem = try XCTUnwrap(engine.items.first(where: { $0.path == movieHan.path }))
        XCTAssertEqual(hanItem.title, "哈尔滨")

        let techItem = try XCTUnwrap(engine.items.first(where: { $0.path == movieTech.path }))
        XCTAssertEqual(techItem.title, "zl2")
    }

    func testNestedEpisodeFolderInFolderGrouping() async throws {
        guard !isCIMockEnvironment else { return }

        let tempDir = try makeTempDir()
        let dbURL = tempDir.appendingPathComponent("nested_grouping.sqlite")
        let rootDir = tempDir.appendingPathComponent("MediaRoot", isDirectory: true)

        let seriesRoot = rootDir.appendingPathComponent("电视剧/嗜血法医：杀魔复生 第二季", isDirectory: true)
        let batchFolder1 = seriesRoot.appendingPathComponent("嗜血法医：杀魔复生.Dexter.Resurrection.S02E01-02.6v电影 地址发布页 www.6v123.net 收藏不迷路", isDirectory: true)
        let batchFolder2 = seriesRoot.appendingPathComponent("嗜血法医：杀魔复生.Dexter.Resurrection.S02E03.6v电影 地址发布页 www.6v123.net 收藏不迷路", isDirectory: true)

        for dir in [batchFolder1, batchFolder2] {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }

        let ep1 = batchFolder1.appendingPathComponent("嗜血法医：杀魔复生.Dexter.Resurrection.S02E01.Risky.Business.1080p.HD中英双字[最新电影www.dyg7.com].mp4")
        let ep2 = batchFolder1.appendingPathComponent("嗜血法医：杀魔复生.Dexter.Resurrection.S02E02.Fallen.1080p.HD中英双字[最新电影www.dyg7.com].mp4")
        let ep3 = batchFolder2.appendingPathComponent("嗜血法医：杀魔复生.Dexter.Resurrection.S02E03.Live.Free.and.Die.1080p.HD中英双字[最新电影www.dyg7.com].mp4")

        for f in [ep1, ep2, ep3] {
            try Data("video".utf8).write(to: f)
        }

        let engine = SilkMediaLibraryEngine(databaseURL: dbURL, usePersistentBookmarkStorage: false)
        _ = await engine.addLocalSource(url: rootDir, displayName: "LAN")

        XCTAssertEqual(engine.items.count, 3)

        let item1 = try XCTUnwrap(engine.items.first(where: { $0.path == ep1.path }))
        let item2 = try XCTUnwrap(engine.items.first(where: { $0.path == ep2.path }))
        let item3 = try XCTUnwrap(engine.items.first(where: { $0.path == ep3.path }))

        // All 3 episodes must share the exact same seriesName without any episode/batch or ad tokens!
        XCTAssertEqual(item1.seriesName, "嗜血法医：杀魔复生")
        XCTAssertEqual(item2.seriesName, "嗜血法医：杀魔复生")
        XCTAssertEqual(item3.seriesName, "嗜血法医：杀魔复生")
        XCTAssertFalse(item1.seriesName?.contains("S02E01") == true)
        XCTAssertFalse(item3.seriesName?.contains("S02E03") == true)
        XCTAssertFalse(item1.seriesName?.contains("第二季") == true)

        XCTAssertEqual(item1.seasonNumber, 2)
        XCTAssertEqual(item1.episodeNumber, 1)
        XCTAssertEqual(item2.seasonNumber, 2)
        XCTAssertEqual(item2.episodeNumber, 2)
        XCTAssertEqual(item3.seasonNumber, 2)
        XCTAssertEqual(item3.episodeNumber, 3)
    }

    func testMultiSeasonAggregationAndSeasonPillsGrouping() async throws {
        guard !isCIMockEnvironment else { return }

        let tempDir = try makeTempDir()
        let dbURL = tempDir.appendingPathComponent("multi_season.sqlite")
        let rootDir = tempDir.appendingPathComponent("MediaRoot", isDirectory: true)

        let season1 = rootDir.appendingPathComponent("电视剧/怪奇物语 第一季", isDirectory: true)
        let season2 = rootDir.appendingPathComponent("电视剧/怪奇物语 第二季", isDirectory: true)
        let season3 = rootDir.appendingPathComponent("电视剧/怪奇物语 第三季", isDirectory: true)
        let season4 = rootDir.appendingPathComponent("电视剧/怪奇物语 第四季", isDirectory: true)
        let season5 = rootDir.appendingPathComponent("电视剧/怪奇物语 第五季", isDirectory: true)

        for d in [season1, season2, season3, season4, season5] {
            try FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        }

        // Write sample episodes across all 5 seasons
        let s1e1 = season1.appendingPathComponent("Stranger.Things.S01E01.mkv")
        let s1e8 = season1.appendingPathComponent("Stranger.Things.S01E08.mkv")
        let s2e1 = season2.appendingPathComponent("怪奇物语.S02E01.mkv")
        let s2e9 = season2.appendingPathComponent("怪奇物语.S02E09.mkv")
        let s3e1 = season3.appendingPathComponent("怪奇物语.S03E01.mkv")
        let s4e1 = season4.appendingPathComponent("怪奇物语.S04E01.mkv")
        let s5e8 = season5.appendingPathComponent("怪奇物语.S05E08.mkv")

        for f in [s1e1, s1e8, s2e1, s2e9, s3e1, s4e1, s5e8] {
            try Data("mock video content".utf8).write(to: f)
        }

        let engine = SilkMediaLibraryEngine(databaseURL: dbURL, usePersistentBookmarkStorage: false)
        _ = await engine.addLocalSource(url: rootDir, displayName: "LAN")

        XCTAssertEqual(engine.items.count, 7)

        // All 7 episodes across all 5 seasons MUST collapse under one pure seriesName
        for item in engine.items {
            XCTAssertEqual(item.seriesName, "怪奇物语")
        }

        let seasons = Set(engine.items.compactMap(\.seasonNumber))
        XCTAssertEqual(seasons, [1, 2, 3, 4, 5])
    }

    // MARK: - 6. Mount-Index-Playback Stability Tests

    func testLargeScale4000FileIndexingAndImmediateResolve() async throws {
        guard !isCIMockEnvironment else { return }

        let tempDir = try makeTempDir()
        let dbURL = tempDir.appendingPathComponent("scale4k.sqlite")
        let rootDir = tempDir.appendingPathComponent("ScaleRoot", isDirectory: true)
        try FileManager.default.createDirectory(at: rootDir, withIntermediateDirectories: true)

        let totalFiles = 4050
        let batchFolders = 20
        for b in 0..<batchFolders {
            let sub = rootDir.appendingPathComponent(String(format: "ClipFolder_%02d", b), isDirectory: true)
            try FileManager.default.createDirectory(at: sub, withIntermediateDirectories: true)
        }
        let emptyData = Data()
        for idx in 0..<totalFiles {
            let folderIdx = idx % batchFolders
            let fileURL = rootDir
                .appendingPathComponent(String(format: "ClipFolder_%02d", folderIdx), isDirectory: true)
                .appendingPathComponent(String(format: "SampleClip_%04d.mp4", idx))
            _ = FileManager.default.createFile(atPath: fileURL.path, contents: emptyData)
        }

        let engine = SilkMediaLibraryEngine(databaseURL: dbURL, usePersistentBookmarkStorage: false)
        let added = await engine.addLocalSource(url: rootDir, displayName: "Scale4K")
        XCTAssertNotNil(added)
        XCTAssertEqual(engine.items.count, totalFiles)

        // Immediately resolve first, middle, and last items cleanly without stalling
        for checkIdx in [0, totalFiles / 2, totalFiles - 1] {
            let target = engine.items[checkIdx]
            let resolved = await engine.resolvePlayableURL(for: target.path)
            XCTAssertNotNil(resolved)
            XCTAssertEqual(resolved?.standardizedFileURL.path, URL(fileURLWithPath: target.path).standardizedFileURL.path)
        }
    }

    func testRemoveSourceMidScanDoesNotResurrectRecords() async throws {
        guard !isCIMockEnvironment else { return }

        let tempDir = try makeTempDir()
        let dbURL = tempDir.appendingPathComponent("remove_race.sqlite")
        let rootDir = tempDir.appendingPathComponent("RaceRoot", isDirectory: true)
        try FileManager.default.createDirectory(at: rootDir, withIntermediateDirectories: true)

        for idx in 0..<400 {
            let f = rootDir.appendingPathComponent("Clip_\(idx).mp4")
            _ = FileManager.default.createFile(atPath: f.path, contents: Data())
        }

        let engine = SilkMediaLibraryEngine(databaseURL: dbURL, usePersistentBookmarkStorage: false)
        let addedSource = await engine.addLocalSource(url: rootDir, displayName: "RaceSource")
        let source = try XCTUnwrap(addedSource)
        XCTAssertEqual(engine.items.count, 400)

        engine.enqueueBackgroundRescan(sourceIds: [source.id])
        await engine.removeSource(id: source.id)
        await engine.rescanAll()

        XCTAssertTrue(engine.sources.isEmpty)
        XCTAssertTrue(engine.items.isEmpty)

        let reloaded = SilkMediaLibraryEngine(databaseURL: dbURL, usePersistentBookmarkStorage: false)
        await reloaded.loadFromDatabase()
        XCTAssertTrue(reloaded.sources.isEmpty)
        XCTAssertTrue(reloaded.items.isEmpty)
    }

    func testResolvePlayableURLReturnsNilForMissingFile() async throws {
        guard !isCIMockEnvironment else { return }

        let tempDir = try makeTempDir()
        let dbURL = tempDir.appendingPathComponent("missing_file.sqlite")
        let rootDir = tempDir.appendingPathComponent("MissingRoot", isDirectory: true)
        try FileManager.default.createDirectory(at: rootDir, withIntermediateDirectories: true)

        let mediaFile = rootDir.appendingPathComponent("TemporaryClip.mkv")
        try Data("video".utf8).write(to: mediaFile)

        let engine = SilkMediaLibraryEngine(databaseURL: dbURL, usePersistentBookmarkStorage: false)
        _ = await engine.addLocalSource(url: rootDir, displayName: "MissingRoot")
        XCTAssertEqual(engine.items.count, 1)

        try FileManager.default.removeItem(at: mediaFile)
        let resolved = await engine.resolvePlayableURL(for: mediaFile.path)
        XCTAssertNil(resolved)
    }

    func testPlaylistManager4000ItemSetPlaylistThroughput() {
        let items = (0..<4050).map { idx in
            PlaylistItem(
                path: String(format: "/tmp/silk_scale/Clip_%04d.mp4", idx),
                title: "Clip \(idx)",
                duration: 120.0
            )
        }
        let manager = PlaylistManager(isPersistenceEnabled: false, autoRestore: false)
        let start = CFAbsoluteTimeGetCurrent()
        manager.setPlaylist(playlistItems: items, startingIndex: 2025)
        let elapsed = CFAbsoluteTimeGetCurrent() - start

        XCTAssertEqual(manager.count, 4050)
        XCTAssertEqual(manager.currentIndex, 2025)
        XCTAssertLessThan(elapsed, 0.5)
    }

    func testCardOnlyRenameAndLibraryRemovalPersistAcrossRescans() async throws {
        guard !isCIMockEnvironment else { return }

        let tempDir = try makeTempDir()
        let dbURL = tempDir.appendingPathComponent("rename_remove.sqlite")
        let rootDir = tempDir.appendingPathComponent("MediaRoot", isDirectory: true)
        try FileManager.default.createDirectory(at: rootDir, withIntermediateDirectories: true)

        let movieA = rootDir.appendingPathComponent("Movie.Alpha.2024.1080p.mkv")
        let movieB = rootDir.appendingPathComponent("Movie.Beta.2024.1080p.mkv")
        try Data("alpha".utf8).write(to: movieA)
        try Data("beta".utf8).write(to: movieB)

        let engine = SilkMediaLibraryEngine(databaseURL: dbURL, usePersistentBookmarkStorage: false)
        _ = await engine.addLocalSource(url: rootDir, displayName: "MediaRoot")
        XCTAssertEqual(engine.items.count, 2)
        XCTAssertTrue(engine.items.allSatisfy { $0.createdTimestamp > 0 })

        await engine.renameMediaItem(path: movieA.path, newTitle: "Custom Alpha Display")
        XCTAssertEqual(engine.items.first(where: { $0.path == movieA.path })?.title, "Custom Alpha Display")

        await engine.removeMediaItemFromLibrary(path: movieB.path)
        XCTAssertEqual(engine.items.count, 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: movieB.path))

        // Rescan & reload must preserve custom card title and keep removed-from-library item hidden
        await engine.rescanAll()
        XCTAssertEqual(engine.items.count, 1)
        XCTAssertEqual(engine.items.first?.title, "Custom Alpha Display")

        let reloaded = SilkMediaLibraryEngine(databaseURL: dbURL, usePersistentBookmarkStorage: false)
        await reloaded.loadFromDatabase()
        XCTAssertEqual(reloaded.items.count, 1)
        XCTAssertEqual(reloaded.items.first?.title, "Custom Alpha Display")
        XCTAssertTrue(reloaded.items.first?.createdTimestamp ?? 0 > 0)
    }

    func testSilkCloudSyncRecordSerializationAndKeyGeneration() {
        let key = SilkCloudSyncService.makeSyncKey(fileName: "Inception.2010.2160p.mkv", durationSeconds: 8880.4)
        XCTAssertEqual(key, "inception.2010.2160p.mkv::8880")

        let record = SilkCloudSyncRecord(
            key: key,
            fileName: "Inception.2010.2160p.mkv",
            positionSeconds: 4200.5,
            durationSeconds: 8880.4,
            watchState: "inProgress",
            lastPlayedAt: 1731500000.0
        )
        let data = try? JSONEncoder().encode(record)
        XCTAssertNotNil(data)
        if let data {
            let decoded = try? JSONDecoder().decode(SilkCloudSyncRecord.self, from: data)
            XCTAssertEqual(decoded, record)
        }
    }

    func testMultiChannelAudioOutputChannelsPreference() {
        let engine = SilkPlayerEngine()
        XCTAssertEqual(engine.preferredAudioOutputChannels, 0)
        engine.preferredAudioOutputChannels = 8
        XCTAssertEqual(engine.preferredAudioOutputChannels, 8)
        engine.preferredAudioOutputChannels = 6
        XCTAssertEqual(engine.preferredAudioOutputChannels, 6)
    }
}
