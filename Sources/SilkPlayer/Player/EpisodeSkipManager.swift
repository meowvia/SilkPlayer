import Foundation

/// Model holding detected or memorized skip ranges for a video episode.
public struct EpisodeSkipRange: Equatable, Sendable {
    public let introEndTime: Double?
    public let outroStartTime: Double?
    public let source: SkipSource

    public enum SkipSource: String, Sendable {
        case chapterExplicit = "chapter_explicit"
        case chapterHeuristic = "chapter_heuristic"
        case seriesMemory = "series_memory"
        case none = "none"
    }

    public init(introEndTime: Double?, outroStartTime: Double?, source: SkipSource) {
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

        // If cleanTitle is just the episode badge or purely digits/season code, fallback to parent directory
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

    /// Resolves the intro end time and outro start time for the given playback context.
    public func resolveSkipRange(duration: Double, chapters: [ChapterItem], filePath: String?) -> EpisodeSkipRange {
        guard duration > 60.0 else {
            return EpisodeSkipRange(introEndTime: nil, outroStartTime: nil, source: .none)
        }

        var detectedIntro: Double? = nil
        var detectedOutro: Double? = nil
        var isExplicit = false

        // 1. Explicit Chapter Keyword Scan (Intro)
        if !chapters.isEmpty {
            for (idx, ch) in chapters.prefix(6).enumerated() {
                let lower = ch.title.lowercased()
                let isIntroName = lower.contains("intro") ||
                                  lower.contains("opening") ||
                                  lower.contains(" op") ||
                                  lower.hasPrefix("op") ||
                                  lower.contains("片头") ||
                                  lower.contains("前情") ||
                                  lower.contains("recap") ||
                                  lower.contains("previously") ||
                                  lower.contains("序幕") ||
                                  lower.contains("序曲") ||
                                  lower.contains("main title") ||
                                  lower.contains("titles") ||
                                  lower.contains("theme") ||
                                  lower.contains("主题")

                if isIntroName {
                    isExplicit = true
                    if idx + 1 < chapters.count {
                        let nextTime = chapters[idx + 1].time
                        if nextTime > ch.time && nextTime <= 480.0 {
                            detectedIntro = nextTime
                            break
                        }
                    }
                    if ch.time > 10.0 && ch.time <= 480.0 {
                        detectedIntro = ch.time
                        break
                    }
                }
            }

            // Explicit Chapter Keyword Scan (Outro)
            for ch in chapters.suffix(4) {
                let lower = ch.title.lowercased()
                let isOutroName = lower.contains("outro") ||
                                  lower.contains("ending") ||
                                  lower.contains(" ed") ||
                                  lower.hasPrefix("ed") ||
                                  lower.contains("片尾") ||
                                  lower.contains("credit") ||
                                  lower.contains("credits") ||
                                  lower.contains("preview") ||
                                  lower.contains("预告") ||
                                  lower.contains("尾声") ||
                                  lower.contains("演职员") ||
                                  lower.contains("制作人")

                if isOutroName {
                    let fromEnd = duration - ch.time
                    if fromEnd >= 15.0 && fromEnd <= 480.0 {
                        detectedOutro = ch.time
                        isExplicit = true
                        break
                    }
                }
            }
        }

        // 2. Heuristic Chapter Scan for standard TV Rips (e.g. Chapter 01, Chapter 02...)
        if detectedIntro == nil && !chapters.isEmpty {
            let firstCh = chapters[0]
            if firstCh.time > 20.0 && firstCh.time <= 300.0 {
                // If first chapter entry starts at 20s~300s, it marks where Act 1 starts after intro
                detectedIntro = firstCh.time
            } else if firstCh.time <= 5.0 && chapters.count >= 2 {
                let secondCh = chapters[1]
                if chapters.count >= 3 {
                    let thirdCh = chapters[2]
                    let introCandidateDuration = thirdCh.time - secondCh.time
                    // Pattern A: Cold open is first (40s~360s), followed by intro sequence (25s~135s)
                    if secondCh.time >= 40.0 && secondCh.time <= 360.0 && introCandidateDuration >= 25.0 && introCandidateDuration <= 135.0 {
                        detectedIntro = thirdCh.time
                    }
                }
                // Pattern B: No cold open or short teaser, Chapter 1 is intro ending at Chapter 2
                if detectedIntro == nil && secondCh.time >= 25.0 && secondCh.time <= 270.0 {
                    detectedIntro = secondCh.time
                }
            }
        }

        if detectedOutro == nil && chapters.count >= 2 {
            let lastCh = chapters.last!
            let fromEnd = duration - lastCh.time
            // If last chapter starts 20s ~ 360s before the end of the video
            if fromEnd >= 20.0 && fromEnd <= 360.0 {
                detectedOutro = lastCh.time
            } else if chapters.count >= 3 {
                // In case there is an end-credits chapter followed by a post-credits scene/preview
                let prevCh = chapters[chapters.count - 2]
                let prevFromEnd = duration - prevCh.time
                if prevFromEnd >= 40.0 && prevFromEnd <= 420.0 && fromEnd < 90.0 {
                    detectedOutro = prevCh.time
                }
            }
        }

        // 3. Fallback to Series Memory if either intro or outro is missing
        if let path = filePath, (!path.isEmpty) {
            let key = seriesKey(for: path)
            if let entry = memoryCache[key] {
                if detectedIntro == nil, let savedIntro = entry["intro"], savedIntro > 5.0 && savedIntro < duration * 0.4 {
                    detectedIntro = savedIntro
                }
                if detectedOutro == nil {
                    if let offset = entry["outroOffset"], offset >= 15.0 && offset <= 480.0 {
                        detectedOutro = duration - offset
                    } else if let savedOutro = entry["outro"], savedOutro > duration * 0.6 && savedOutro < duration - 10.0 {
                        detectedOutro = savedOutro
                    }
                }
                if !isExplicit && (detectedIntro != nil || detectedOutro != nil) {
                    return EpisodeSkipRange(introEndTime: detectedIntro, outroStartTime: detectedOutro, source: .seriesMemory)
                }
            }
        }

        let source: EpisodeSkipRange.SkipSource = isExplicit ? .chapterExplicit : ((detectedIntro != nil || detectedOutro != nil) ? .chapterHeuristic : .none)
        return EpisodeSkipRange(introEndTime: detectedIntro, outroStartTime: detectedOutro, source: source)
    }

    /// Remembers manual or confirmed skip points for all episodes in the same series.
    public func saveMemory(for filePath: String, intro: Double?, outro: Double?, duration: Double? = nil) {
        guard !filePath.isEmpty else { return }
        let key = seriesKey(for: filePath)
        var dict: [String: Double] = memoryCache[key] ?? [:]
        if let i = intro, i > 0 {
            dict["intro"] = i
        }
        if let o = outro, o > 0 {
            dict["outro"] = o
            if let d = duration, d > o {
                dict["outroOffset"] = d - o
            }
        }
        memoryCache[key] = dict
        UserDefaults.standard.set(memoryCache, forKey: memoryKey)
    }
}
