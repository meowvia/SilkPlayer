import Foundation

/// Model holding detected or memorized skip ranges for a video episode.
public struct EpisodeSkipRange: Equatable, Sendable {
    public let introStartTime: Double?
    public let introEndTime: Double?
    public let outroStartTime: Double?
    public let source: SkipSource

    public enum SkipSource: String, Sendable {
        case chapterExplicit = "chapter_explicit"
        case chapterHeuristic = "chapter_heuristic"
        case seriesMemory = "series_memory"
        case none = "none"
    }

    public var hasIntro: Bool {
        guard let s = introStartTime, let e = introEndTime else { return false }
        return e > s && (e - s) >= 10.0
    }

    public var hasOutro: Bool {
        guard let o = outroStartTime else { return false }
        return o > 0
    }

    public init(introStartTime: Double?, introEndTime: Double?, outroStartTime: Double?, source: SkipSource) {
        self.introStartTime = introStartTime
        self.introEndTime = introEndTime
        self.outroStartTime = outroStartTime
        self.source = source
    }
}

/// Centralized manager for detecting, caching, and inheriting episode intro and outro markers.
@MainActor
public final class EpisodeSkipManager {
    public static let shared = EpisodeSkipManager()

    private let memoryKey = "SilkEpisodeSkipMemory"
    private var memoryCache: [String: [String: Double]] = [:]

    private init() {
        if let data = UserDefaults.standard.dictionary(forKey: memoryKey) as? [String: [String: Double]] {
            self.memoryCache = data
        }
    }

    /// Derives a normalized series identifier from the file path or directory.
    public func seriesKey(for path: String) -> String {
        let url = URL(fileURLWithPath: path)
        let filename = url.deletingPathExtension().lastPathComponent
        let sanitized = MediaFilenameSanitizer.sanitize(filename)
        let clean = sanitized.cleanTitle.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        let isOnlyEpisodeCode: Bool = {
            if let badge = sanitized.episodeBadge?.lowercased(), clean == badge {
                return true
            }
            if let full = sanitized.fullSeasonEpisodeBadge?.lowercased(), clean == full {
                return true
            }
            if clean.range(of: #"^s\d+(?:e\d+)?$"#, options: .regularExpression) != nil {
                return true
            }
            if clean.range(of: #"^(?:ep?|第)?\d+(?:集|话)?$"#, options: .regularExpression) != nil {
                return true
            }
            return false
        }()

        if !isOnlyEpisodeCode && !clean.isEmpty && clean.count > 2 {
            return clean
        }

        let parent = url.deletingLastPathComponent()
        let parentName = parent.lastPathComponent.lowercased()
        if parentName.range(of: #"^(?:season\s*\d+|s\d+|specials|extra)$"#, options: .regularExpression) != nil {
            return parent.deletingLastPathComponent().path.lowercased()
        }
        return parent.path.lowercased()
    }

    /// Resolves the intro interval [introStartTime, introEndTime] and outroStartTime.
    public func resolveSkipRange(duration: Double, chapters: [ChapterItem], filePath: String?) -> EpisodeSkipRange {
        guard duration > 60.0 else {
            return EpisodeSkipRange(introStartTime: nil, introEndTime: nil, outroStartTime: nil, source: .none)
        }

        var detectedIntroStart: Double? = nil
        var detectedIntroEnd: Double? = nil
        var detectedOutroStart: Double? = nil
        var isExplicitIntro = false
        var isExplicitOutro = false

        // Upper time horizon for opening sequences: first 25% of media or 15 minutes (900 seconds)
        let introSearchLimit = max(300.0, min(900.0, duration * 0.35))

        // 1. Explicit Chapter Keyword Scan (Intro)
        if !chapters.isEmpty {
            for (idx, ch) in chapters.enumerated() {
                guard ch.time <= introSearchLimit else { break }
                let lower = ch.title.lowercased()

                let isExplicitOpening = lower.contains("opening") ||
                                       lower.contains("intro") ||
                                       lower.contains("op") ||
                                       lower.contains("片头") ||
                                       lower.contains("序幕") ||
                                       lower.contains("序曲") ||
                                       lower.contains("main title") ||
                                       lower.contains("opening title") ||
                                       lower.contains("theme song") ||
                                       lower.contains("主题曲")

                // Notice: In many Western releases (NF, HBO, Amazon), opening credits are tagged "Opening Credits",
                // while end credits are tagged "End Credits" or "Credits".
                // If chapter title contains "credits" within the introSearchLimit and is NOT near EOF:
                let isIntroCredits = lower.contains("opening credits") ||
                                     (lower.contains("credits") && ch.time <= introSearchLimit && ch.time < duration * 0.40)

                if isExplicitOpening || isIntroCredits {
                    isExplicitIntro = true
                    detectedIntroStart = ch.time
                    // Find the end of this intro chapter
                    if idx + 1 < chapters.count {
                        let nextTime = chapters[idx + 1].time
                        let candidateDuration = nextTime - ch.time
                        // An opening credits sequence typically lasts between 15s and 180s
                        if candidateDuration >= 15.0 && candidateDuration <= 240.0 {
                            detectedIntroEnd = nextTime
                        } else if candidateDuration > 240.0 {
                            // If the next chapter is far away (e.g. 15 minutes), try to check series memory or default
                            detectedIntroEnd = ch.time + 85.0
                        }
                    } else {
                        detectedIntroEnd = min(ch.time + 85.0, duration)
                    }
                    break
                }
            }

            // Explicit Chapter Keyword Scan (Outro / Credits)
            // Search in chapters near the end (past 50% of the video)
            for ch in chapters.reversed() {
                guard ch.time >= duration * 0.50 else { break }
                let lower = ch.title.lowercased()
                let fromEnd = duration - ch.time

                let isExplicitEnding = lower.contains("outro") ||
                                       lower.contains("ending") ||
                                       lower.contains("ed") ||
                                       lower.contains("片尾") ||
                                       lower.contains("end credits") ||
                                       lower.contains("closing credits") ||
                                       lower.contains("credits") ||
                                       lower.contains("preview") ||
                                       lower.contains("预告") ||
                                       lower.contains("尾声") ||
                                       lower.contains("演职员") ||
                                       lower.contains("制作人")

                if isExplicitEnding && fromEnd >= 15.0 && fromEnd <= 540.0 {
                    detectedOutroStart = ch.time
                    isExplicitOutro = true
                    break
                }
            }
        }

        // 2. Heuristic Chapter Scan for generic chapters (e.g. Chapter 01, Chapter 02...)
        if (detectedIntroStart == nil || detectedIntroEnd == nil) && chapters.count >= 2 {
            // Scan consecutive chapter intervals in the intro search limit
            for i in 0..<(chapters.count - 1) {
                let currentCh = chapters[i]
                let nextCh = chapters[i + 1]
                guard currentCh.time <= introSearchLimit else { break }

                let span = nextCh.time - currentCh.time
                // In TV shows, title sequences almost universally span 20s to 125s
                if span >= 20.0 && span <= 125.0 {
                    // Pattern A: Cold open first (e.g. currentCh.time is 40s~720s), followed by intro
                    // Pattern B: No cold open (currentCh.time <= 5.0s)
                    if currentCh.time <= 5.0 || currentCh.time >= 20.0 {
                        detectedIntroStart = currentCh.time <= 5.0 ? 0.0 : currentCh.time
                        detectedIntroEnd = nextCh.time
                        break
                    }
                }
            }
        }

        if detectedOutroStart == nil && chapters.count >= 2 {
            let lastCh = chapters.last!
            let fromEnd = duration - lastCh.time
            // If last chapter starts 20s ~ 360s before the end of the video
            if fromEnd >= 20.0 && fromEnd <= 360.0 {
                detectedOutroStart = lastCh.time
            } else if chapters.count >= 3 {
                // In case there is an end-credits chapter followed by a short post-credits scene/preview
                let prevCh = chapters[chapters.count - 2]
                let prevFromEnd = duration - prevCh.time
                if prevFromEnd >= 35.0 && prevFromEnd <= 420.0 && fromEnd < 90.0 {
                    detectedOutroStart = prevCh.time
                }
            }
        }

        // 3. Fallback to Series Memory
        if let path = filePath, (!path.isEmpty) {
            let key = seriesKey(for: path)
            if let entry = memoryCache[key] {
                // If intro is missing, check if this show has a fixed intro duration
                if (detectedIntroStart == nil || detectedIntroEnd == nil) {
                    if let savedDuration = entry["introDuration"], savedDuration >= 15.0 && savedDuration <= 180.0 {
                        // If file has chapters, see if any chapter transition matches this duration
                        var matchedChapter = false
                        if chapters.count >= 2 {
                            for i in 0..<(chapters.count - 1) {
                                let cSpan = chapters[i + 1].time - chapters[i].time
                                if abs(cSpan - savedDuration) <= 4.0 && chapters[i].time <= introSearchLimit {
                                    detectedIntroStart = chapters[i].time <= 5.0 ? 0.0 : chapters[i].time
                                    detectedIntroEnd = chapters[i + 1].time
                                    matchedChapter = true
                                    break
                                }
                            }
                        }
                        // If no chapter transition matched, check if intro starts at fixed offset (e.g. direct intro)
                        if !matchedChapter, let savedStart = entry["introStart"], let savedEnd = entry["introEnd"] {
                            if savedStart <= 5.0 {
                                detectedIntroStart = 0.0
                                detectedIntroEnd = savedEnd
                            }
                        }
                    }
                }

                // If outro is missing, derive from outroOffset
                if detectedOutroStart == nil {
                    if let offset = entry["outroOffset"], offset >= 15.0 && offset <= 540.0 {
                        detectedOutroStart = duration - offset
                    } else if let savedOutro = entry["outro"], savedOutro > duration * 0.6 && savedOutro < duration - 10.0 {
                        detectedOutroStart = savedOutro
                    }
                }

                if !isExplicitIntro && !isExplicitOutro && (detectedIntroEnd != nil || detectedOutroStart != nil) {
                    return EpisodeSkipRange(
                        introStartTime: detectedIntroStart,
                        introEndTime: detectedIntroEnd,
                        outroStartTime: detectedOutroStart,
                        source: .seriesMemory
                    )
                }
            }
        }

        let isExplicit = isExplicitIntro || isExplicitOutro
        let isHeuristic = (detectedIntroEnd != nil || detectedOutroStart != nil)
        let source: EpisodeSkipRange.SkipSource = isExplicit ? .chapterExplicit : (isHeuristic ? .chapterHeuristic : .none)

        return EpisodeSkipRange(
            introStartTime: detectedIntroStart,
            introEndTime: detectedIntroEnd,
            outroStartTime: detectedOutroStart,
            source: source
        )
    }

    /// Remembers manual or confirmed skip points for all episodes in the same series.
    public func saveMemory(for filePath: String, introStart: Double?, introEnd: Double?, outroStart: Double?, duration: Double? = nil) {
        guard !filePath.isEmpty else { return }
        let key = seriesKey(for: filePath)
        var dict: [String: Double] = memoryCache[key] ?? [:]

        if let s = introStart {
            dict["introStart"] = s
        }
        if let e = introEnd {
            dict["introEnd"] = e
        }
        if let s = introStart, let e = introEnd, e > s {
            dict["introDuration"] = e - s
        }
        if let o = outroStart, o > 0 {
            dict["outro"] = o
            if let d = duration, d > o {
                dict["outroOffset"] = d - o
            }
        }
        memoryCache[key] = dict
        UserDefaults.standard.set(memoryCache, forKey: memoryKey)
    }
}
