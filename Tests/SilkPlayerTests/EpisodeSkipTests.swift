import XCTest
@testable import SilkPlayer

@MainActor
final class EpisodeSkipTests: XCTestCase {

    func testExplicitIntroAndOutroDetection() {
        let chapters = [
            ChapterItem(id: 0, title: "Prologue", time: 0.0),
            ChapterItem(id: 1, title: "Opening Theme", time: 90.0),
            ChapterItem(id: 2, title: "Main Story", time: 180.0),
            ChapterItem(id: 3, title: "Ending Credits", time: 2400.0)
        ]
        let range = EpisodeSkipManager.shared.resolveSkipRange(
            duration: 2500.0,
            chapters: chapters,
            filePath: "/Volumes/Media/TV/Severance/S01E01.mkv"
        )
        XCTAssertEqual(range.source, .chapterExplicit)
        XCTAssertEqual(range.introStartTime, 90.0)
        XCTAssertEqual(range.introEndTime, 180.0)
        XCTAssertEqual(range.outroStartTime, 2400.0)
        XCTAssertTrue(range.hasIntro)
        XCTAssertTrue(range.hasOutro)
    }

    func testDetectiveHoleRealWorldChapterStructure() {
        // Real Detective Hole E08 chapters: Cold open 00:00~03:35, Opening Credits 03:35~04:12 (36.5s)
        let chapters = [
            ChapterItem(id: 0, title: "Opening Credits", time: 215.416),
            ChapterItem(id: 1, title: "Chapter 01", time: 252.0),
            ChapterItem(id: 2, title: "End Credits", time: 2444.0)
        ]
        let range = EpisodeSkipManager.shared.resolveSkipRange(
            duration: 2653.0,
            chapters: chapters,
            filePath: "/Volumes/HDD2T/影音娱乐/电视剧/哈利警探/Detective.Hole.S01E08.The.Woman.in.the.Water.2160p.NF.WEB-DL.DDP.5.1.Atmos.H.265-BlackTV.mkv"
        )
        XCTAssertEqual(range.source, .chapterExplicit)
        XCTAssertEqual(range.introStartTime, 215.416)
        XCTAssertEqual(range.introEndTime, 252.0)
        XCTAssertEqual(range.outroStartTime, 2444.0)
    }

    func testStrangerThingsRealWorldChapterStructure() {
        // Real Stranger Things S01E05 chapters: Cold open up to 08:16, Opening Credits 08:16~09:05 (48.8s)
        let chapters = [
            ChapterItem(id: 0, title: "Opening Credits", time: 496.788),
            ChapterItem(id: 1, title: "Chapter 01", time: 545.607),
            ChapterItem(id: 2, title: "End Credits", time: 3052.0)
        ]
        let range = EpisodeSkipManager.shared.resolveSkipRange(
            duration: 3226.0,
            chapters: chapters,
            filePath: "/Volumes/HDD2T/影音娱乐/电视剧/怪奇物语 第一季/Stranger.Things.S01E05.Chapter.Five.The.Flea.and.the.Acrobat.2160p.NF.WEB-DL.DDP.5.1.HDR10.H.265-BlackTV.mkv"
        )
        XCTAssertEqual(range.source, .chapterExplicit)
        XCTAssertEqual(range.introStartTime, 496.788)
        XCTAssertEqual(range.introEndTime, 545.607)
        XCTAssertEqual(range.outroStartTime, 3052.0)
    }

    func testGenericTvRipHeuristicsNoColdOpen() {
        // Typical Handbrake / MakeMKV chaptering without names, direct intro
        let chapters = [
            ChapterItem(id: 0, title: "Chapter 01", time: 0.0),
            ChapterItem(id: 1, title: "Chapter 02", time: 85.0),
            ChapterItem(id: 2, title: "Chapter 03", time: 650.0),
            ChapterItem(id: 3, title: "Chapter 04", time: 2600.0)
        ]
        let range = EpisodeSkipManager.shared.resolveSkipRange(
            duration: 2700.0,
            chapters: chapters,
            filePath: "/Volumes/Media/TV/Shogun/S01E01.mkv"
        )
        XCTAssertEqual(range.source, .chapterHeuristic)
        XCTAssertEqual(range.introStartTime, 0.0)
        XCTAssertEqual(range.introEndTime, 85.0)
        XCTAssertEqual(range.outroStartTime, 2600.0)
    }

    func testGenericTvRipHeuristicsWithColdOpen() {
        // Cold open from 00:00 to 02:30 (150s), then intro from 02:30 to 04:00 (240s, 90s intro)
        let chapters = [
            ChapterItem(id: 0, title: "Chapter 01", time: 0.0),
            ChapterItem(id: 1, title: "Chapter 02", time: 150.0),
            ChapterItem(id: 2, title: "Chapter 03", time: 240.0),
            ChapterItem(id: 3, title: "Chapter 04", time: 1200.0),
            ChapterItem(id: 4, title: "Chapter 05", time: 2850.0)
        ]
        let range = EpisodeSkipManager.shared.resolveSkipRange(
            duration: 3000.0,
            chapters: chapters,
            filePath: "/Volumes/Media/TV/BreakingBad/S01E01.mkv"
        )
        XCTAssertEqual(range.source, .chapterHeuristic)
        XCTAssertEqual(range.introStartTime, 150.0)
        XCTAssertEqual(range.introEndTime, 240.0)
        XCTAssertEqual(range.outroStartTime, 2850.0)
    }

    func testSeriesMemoryInheritanceForChapterlessEpisode() {
        let ep1Path = "/Volumes/Media/TV/TedLasso/S03E01.mkv"
        let ep2Path = "/Volumes/Media/TV/TedLasso/S03E02.mkv"

        // Ep 1 registers memory
        EpisodeSkipManager.shared.saveMemory(
            for: ep1Path,
            introStart: 0.0,
            introEnd: 95.0,
            outroStart: 2700.0,
            duration: 2800.0
        )

        // Ep 2 has no chapters at all
        let rangeEp2 = EpisodeSkipManager.shared.resolveSkipRange(
            duration: 3100.0,
            chapters: [],
            filePath: ep2Path
        )
        XCTAssertEqual(rangeEp2.source, .seriesMemory)
        XCTAssertEqual(rangeEp2.introStartTime, 0.0)
        XCTAssertEqual(rangeEp2.introEndTime, 95.0)
        // Outro should be derived from outroOffset (2800 - 2700 = 100s offset from end) -> 3100 - 100 = 3000
        XCTAssertEqual(rangeEp2.outroStartTime, 3000.0)
    }

    func testScrubberSnapInvariants() {
        let chapters = [ChapterItem(id: 0, title: "Ch1", time: 0.0), ChapterItem(id: 1, title: "Ch2", time: 500.0)]
        let snappedStart = PlayerScrubberView.snapTime(89.5, duration: 100.0, chapters: chapters, introStartTime: 90.0, introTime: 180.0, outroTime: 2400.0)
        XCTAssertEqual(snappedStart, 90.0)

        let snappedEnd = PlayerScrubberView.snapTime(179.2, duration: 100.0, chapters: chapters, introStartTime: 90.0, introTime: 180.0, outroTime: 2400.0)
        XCTAssertEqual(snappedEnd, 180.0)

        let snappedOutro = PlayerScrubberView.snapTime(2399.2, duration: 100.0, chapters: chapters, introStartTime: 90.0, introTime: 180.0, outroTime: 2400.0)
        XCTAssertEqual(snappedOutro, 2400.0)
    }
}
